class_name ChallengeResolver
## ChallengeResolver — Crew-aware challenge resolution system.
## Finds the best crew member for each role, calculates effective stats,
## resolves challenges, and applies crew consequences (fatigue, morale, injuries).

# === CONSTANTS ===

const GENERALIST_MULTIPLIER: float = 0.65
const CAPTAIN_FIRST_ROLE_MULT: float = 0.7
const CAPTAIN_SECOND_ROLE_MULT: float = 0.4
const SECONDARY_SPECIALIST_BONUS: float = 0.25
const SECONDARY_GENERALIST_BONUS: float = 0.15

# Maps role display names to CrewMember.Role enum values
const ROLE_FROM_NAME: Dictionary = {
	"Gunner": CrewMember.Role.GUNNER,
	"Engineer": CrewMember.Role.ENGINEER,
	"Navigator": CrewMember.Role.NAVIGATOR,
	"Medic": CrewMember.Role.MEDIC,
	"Comms Officer": CrewMember.Role.COMMS_OFFICER,
	"Science Officer": CrewMember.Role.SCIENCE_OFFICER,
	"Security Chief": CrewMember.Role.SECURITY_CHIEF,
	"Generalist": CrewMember.Role.GENERALIST,
}

# Maps role display names to their primary stat
const ROLE_STAT: Dictionary = {
	"Gunner": "reflexes",
	"Engineer": "cognition",
	"Navigator": "cognition",
	"Medic": "social",
	"Comms Officer": "social",
	"Science Officer": "cognition",
	"Security Chief": "stamina",
	"Generalist": "resourcefulness",
}

const BODY_PARTS: Array[String] = [
	"shoulder", "arm", "ribs", "leg", "back", "hand", "knee", "side",
]

# === ENCOUNTER DEFINITIONS ===

const ENCOUNTER_TYPES: Array[Dictionary] = [
	{
		"id": "pirate_attack",
		"title": "Pirate Attack",
		"descriptions": [
			"Pirates emerge from the shadow of an asteroid. Weapons hot, they're demanding your cargo.",
			"A hostile vessel decloaks off your port bow. Pirates — they want everything you've got.",
			"Red warning lights. Pirate raiders on intercept course. No hailing frequency, just threats.",
		],
		"approaches": [
			{"label": "Fight", "primary": "Gunner", "secondary": "Security Chief", "is_combat": true},
			{"label": "Evade", "primary": "Navigator", "secondary": "Engineer", "is_combat": false},
			{"label": "Negotiate", "primary": "Comms Officer", "secondary": "", "is_combat": false},
		],
		"weight_low": 10, "weight_medium": 40, "weight_high": 50,
	},
	{
		"id": "asteroid_field",
		"title": "Asteroid Field",
		"descriptions": [
			"Sensors light up — you've entered a dense debris field. Rocks tumble across your path.",
			"The navigation computer screams warnings. Asteroids everywhere. Need to get through this.",
		],
		"approaches": [
			{"label": "Navigate Through", "primary": "Navigator", "secondary": "Engineer", "is_combat": false},
			{"label": "Power Through", "primary": "Engineer", "secondary": "Gunner", "is_combat": false},
		],
		"weight_low": 30, "weight_medium": 25, "weight_high": 15,
	},
	{
		"id": "patrol_checkpoint",
		"title": "Patrol Checkpoint",
		"descriptions": [
			"A patrol vessel flags you down for inspection. Standard procedure, they claim.",
			"Military checkpoint ahead. They're scanning all traffic through this corridor.",
		],
		"approaches": [
			{"label": "Cooperate", "primary": "Comms Officer", "secondary": "Navigator", "is_combat": false},
			{"label": "Run", "primary": "Navigator", "secondary": "Gunner", "is_combat": false},
		],
		"weight_low": 40, "weight_medium": 20, "weight_high": 10,
	},
	{
		"id": "distress_signal",
		"title": "Distress Signal",
		"descriptions": [
			"Distress beacon detected. A small craft is adrift — life signs fading. Respond?",
		],
		"approaches": [
			{"label": "Investigate", "primary": "Engineer", "secondary": "Medic", "is_combat": false},
			{"label": "Ignore the signal", "primary": "", "secondary": "", "is_combat": false},
		],
		"weight_low": 3, "weight_medium": 8, "weight_high": 8,
	},
]


# === ENCOUNTER SELECTION ===

static func pick_encounter(danger_level: String) -> Dictionary:
	## Picks a random encounter type based on route danger.
	var weight_key: String
	match danger_level:
		"low", "low_medium":
			weight_key = "weight_low"
		"medium":
			weight_key = "weight_medium"
		"high":
			weight_key = "weight_high"
		_:
			weight_key = "weight_low"

	var total: int = 0
	for enc: Dictionary in ENCOUNTER_TYPES:
		total += enc.get(weight_key, 10)

	var roll: int = randi() % maxi(total, 1)
	var cumulative: int = 0
	for enc: Dictionary in ENCOUNTER_TYPES:
		cumulative += enc.get(weight_key, 10)
		if roll < cumulative:
			return enc

	return ENCOUNTER_TYPES[0]


static func get_encounter_difficulty(danger_level: String) -> int:
	## Returns a difficulty value based on route danger.
	match danger_level:
		"low":
			return randi_range(30, 45)
		"low_medium":
			return randi_range(40, 55)
		"medium":
			return randi_range(50, 70)
		"high":
			return randi_range(65, 85)
		_:
			return randi_range(35, 50)


# === CREW LOOKUP ===

static func find_crew_for_role(roster: Array[CrewMember], role_name: String,
		exclude_crew: CrewMember = null) -> Dictionary:
	## Finds the best crew member for a given role.
	## Returns {crew: CrewMember or null, type: String, stat_value: float, display_name: String}
	var target_role: CrewMember.Role = ROLE_FROM_NAME.get(role_name, CrewMember.Role.GENERALIST)
	var stat_name: String = ROLE_STAT.get(role_name, "resourcefulness")

	# Find best specialist
	var best: CrewMember = null
	var best_stat: float = -1.0
	for cm: CrewMember in roster:
		if exclude_crew != null and cm.id == exclude_crew.id:
			continue
		if cm.role == target_role:
			var eff: float = cm.get_effective_stat(stat_name)
			if eff > best_stat:
				best_stat = eff
				best = cm

	if best != null:
		return {"crew": best, "type": "specialist", "stat_value": best_stat,
				"display_name": "%s %s" % [role_name, best.crew_name]}

	# Find best generalist or pinch-hitter
	var best_gen: CrewMember = null
	var best_gen_stat: float = -1.0
	var best_gen_type: String = "generalist"
	# Phase 5.1: Check if excluded crew has a romance partner (for enhanced pinch-hitting)
	var partner_of_excluded: int = -1
	if exclude_crew != null:
		partner_of_excluded = DatabaseManager.get_partner_id(exclude_crew.id)
	for cm: CrewMember in roster:
		if exclude_crew != null and cm.id == exclude_crew.id:
			continue
		if cm.role == CrewMember.Role.GENERALIST:
			var mult: float = cm.get_pinch_hit_effectiveness(role_name)
			var eff: float = cm.get_effective_stat(stat_name) * mult
			if eff > best_gen_stat:
				best_gen_stat = eff
				best_gen = cm
				best_gen_type = "generalist"
		elif cm.role != target_role:
			# Non-matching specialist can pinch-hit
			var mult: float = cm.get_pinch_hit_effectiveness(role_name)
			# Phase 5.1: Romance partner gets enhanced pinch-hitting (50% effectiveness)
			if partner_of_excluded == cm.id:
				mult = maxf(mult, 0.50)
			var eff: float = cm.get_effective_stat(stat_name) * mult
			if eff > best_gen_stat:
				best_gen_stat = eff
				best_gen = cm
				best_gen_type = "pinch_hitter"

	if best_gen != null:
		var display: String = "%s (%s)" % [best_gen.crew_name, "Generalist" if best_gen_type == "generalist" else "Pinch-hitting"]
		return {"crew": best_gen, "type": best_gen_type, "stat_value": best_gen_stat,
				"display_name": display}

	# Captain handles it
	var captain_stat: float = float(GameManager._get_stat(stat_name)) * CAPTAIN_FIRST_ROLE_MULT
	return {"crew": null, "type": "captain", "stat_value": captain_stat,
			"display_name": "Captain (no specialist)"}


# === APPROACH PREVIEW ===

static func get_approach_info(roster: Array[CrewMember], primary_role: String,
		secondary_role: String, difficulty: int) -> Dictionary:
	## Gets preview info for an approach without resolving it.
	## Returns {primary: Dict, secondary: Dict, rating_word: String, rating_color: String}
	var primary: Dictionary = find_crew_for_role(roster, primary_role)
	var secondary: Dictionary = {}
	var secondary_bonus: float = 0.0

	if secondary_role != "":
		secondary = find_crew_for_role(roster, secondary_role, primary.get("crew"))
		if not secondary.is_empty():
			match secondary.type:
				"specialist":
					secondary_bonus = secondary.stat_value * SECONDARY_SPECIALIST_BONUS
				"generalist":
					secondary_bonus = secondary.stat_value * SECONDARY_GENERALIST_BONUS

	var effective: float = primary.stat_value + secondary_bonus
	var expected_roll: float = effective + effective * 0.5  # Average roll
	var rating: String = _get_rating_word(expected_roll, float(difficulty))
	var color: String = _get_rating_color(rating)

	return {
		"primary": primary,
		"secondary": secondary,
		"rating_word": rating,
		"rating_color": color,
	}


# === CHALLENGE RESOLUTION ===

static func resolve_crew_challenge(roster: Array[CrewMember], primary_role: String,
		secondary_role: String, difficulty: int) -> Dictionary:
	## Resolves a challenge using crew stats. Returns full result dictionary.
	var primary: Dictionary = find_crew_for_role(roster, primary_role)
	var secondary: Dictionary = {}
	var secondary_bonus: float = 0.0

	if secondary_role != "":
		secondary = find_crew_for_role(roster, secondary_role, primary.get("crew"))
		if not secondary.is_empty():
			match secondary.type:
				"specialist":
					secondary_bonus = secondary.stat_value * SECONDARY_SPECIALIST_BONUS
				"generalist":
					secondary_bonus = secondary.stat_value * SECONDARY_GENERALIST_BONUS

	var effective: int = int(primary.stat_value + secondary_bonus)

	# Phase 3.2: Gorvian cold sensitivity — -10% performance on cold planets
	var current_planet: Dictionary = GameManager.get_current_planet()
	if current_planet.get("cold_environment", 0) == 1:
		var primary_crew: CrewMember = primary.get("crew")
		if primary_crew != null and primary_crew.species == CrewMember.Species.GORVIAN:
			effective = int(float(effective) * 0.90)

	# Phase 4.2: Memory context bonus
	var primary_crew: CrewMember = primary.get("crew")
	if primary_crew != null:
		primary_crew.load_memories()
		var mem_context: String = _get_encounter_context()
		effective += int(primary_crew.get_memory_bonus(mem_context))

	# Phase 4.3: Trait bonuses
	if primary_crew != null:
		# Reckless: +8 aggressive combat, -5 evasion (applied contextually)
		if primary_crew.has_trait("reckless"):
			if primary_role in ["Gunner", "Security Chief"]:
				effective += 8
			elif primary_role in ["Navigator"]:
				effective -= 5

		# Bonded Pair: +5 when partner is also in encounter
		if primary_crew.has_trait("bonded_pair") and not secondary.is_empty():
			var sec_crew: CrewMember = secondary.get("crew")
			if sec_crew != null and sec_crew.has_trait("bonded_pair"):
				effective += 5

	# Phase 4.4: Ship memory bonuses
	var ship_mems: Array = DatabaseManager.get_ship_memories(GameManager.save_id)
	for smem: Dictionary in ship_mems:
		var smem_context: String = smem.get("context_match", "")
		var smem_type: String = smem.get("modifier_type", "")
		if smem_type != "COHESION" and smem_context == _get_encounter_context():
			effective += int(smem.get("modifier_value", 0.0))

	# Phase 5.1: Romance synergy bonus (+5 when both partners in encounter)
	if primary_crew != null and not secondary.is_empty():
		var sec_crew: CrewMember = secondary.get("crew")
		if sec_crew != null:
			var partner_id: int = DatabaseManager.get_partner_id(primary_crew.id)
			if partner_id == sec_crew.id:
				effective += 5

	# Phase 5.2: Loyalty crisis bonus
	if primary_crew != null:
		var crisis_bonus: float = CrewSimulation.get_loyalty_crisis_bonus(primary_crew)
		if crisis_bonus > 0.0:
			effective = int(float(effective) * (1.0 + crisis_bonus))

	var roll: int = effective + randi_range(0, maxi(effective, 1))

	var tier: String
	if roll > 2 * difficulty:
		tier = "critical_success"
	elif roll > difficulty:
		tier = "success"
	elif roll > int(0.75 * difficulty):
		tier = "marginal_success"
	elif roll > int(0.5 * difficulty):
		tier = "failure"
	else:
		tier = "critical_failure"

	# Phase 4.1: Track pinch-hit experience
	var pinch_hit_data: Array[Dictionary] = []
	var prim_crew: CrewMember = primary.get("crew")
	if prim_crew != null and primary.type in ["generalist", "pinch_hitter"]:
		pinch_hit_data.append({"crew": prim_crew, "own_exp": 0.5, "covered_role": primary_role, "covered_exp": 0.3})

	return {
		"tier": tier,
		"roll": roll,
		"difficulty": difficulty,
		"primary": primary,
		"secondary": secondary,
		"pinch_hit_data": pinch_hit_data,
		"encounter_type": _get_encounter_context(),
	}


# === CREW CONSEQUENCES ===

static func apply_crew_consequences(result: Dictionary, roster: Array[CrewMember]) -> Array[String]:
	## Applies fatigue, morale, injury consequences, memories, and experience after a challenge.
	var events: Array[String] = []
	var has_medic: bool = _has_medic(roster)
	var primary: Dictionary = result.primary
	var secondary: Dictionary = result.get("secondary", {})
	var encounter_type: String = result.get("encounter_type", "encounter")
	var injured_count: int = 0

	# Get medic stat for structured injury system
	var medic_stat: float = 50.0
	for cm: CrewMember in roster:
		if cm.role == CrewMember.Role.MEDIC:
			medic_stat = cm.get_effective_stat("social")
			break

	match result.tier:
		"critical_success":
			if primary.get("crew") != null:
				_apply_purpose(primary.crew)
				_apply_morale_delta(primary.crew, 2.0)
				events.append("[color=#27AE60]%s handled it brilliantly.[/color]" % primary.crew.crew_name)
				# Phase 4.2: Memory on critical success
				CrewSimulation.create_challenge_memory(primary.crew, "critical_success",
					primary.get("display_name", ""), encounter_type)
			if secondary.get("crew") != null:
				_apply_purpose(secondary.crew)

		"success":
			if primary.get("crew") != null:
				_apply_purpose(primary.crew)
				_apply_morale_delta(primary.crew, 1.0)
			if secondary.get("crew") != null:
				_apply_purpose(secondary.crew)

		"marginal_success":
			if primary.get("crew") != null:
				_apply_purpose(primary.crew)
				_apply_fatigue_delta(primary.crew, 8.0)
				if randf() < 0.20:
					var inj_result: Dictionary = CrewSimulation.inflict_structured_injury(
						primary.crew, "MINOR", has_medic, medic_stat)
					if not inj_result.is_empty():
						events.append(inj_result.event_text)
						injured_count += 1
						CrewSimulation.create_injury_memory(primary.crew, "minor")
						# Phase 5.1: Partner injury reaction
						var partner_events: Array[String] = CrewSimulation.trigger_partner_injury_reaction(primary.crew, roster)
						events.append_array(partner_events)

		"failure":
			if primary.get("crew") != null:
				_apply_fatigue_delta(primary.crew, 10.0)
				# Phase 5.2: Loyalty morale anchor
				var morale_penalty: float = CrewSimulation.get_loyalty_morale_anchor(primary.crew, -3.0)
				_apply_morale_delta(primary.crew, morale_penalty)
				events.append("[color=#E67E22]%s is frustrated after the failed attempt.[/color]" % primary.crew.crew_name)
				if randf() < 0.40:
					var inj_result: Dictionary = CrewSimulation.inflict_structured_injury(
						primary.crew, "MINOR", has_medic, medic_stat)
					if not inj_result.is_empty():
						events.append(inj_result.event_text)
						injured_count += 1
						CrewSimulation.create_injury_memory(primary.crew, "minor")
						var partner_events: Array[String] = CrewSimulation.trigger_partner_injury_reaction(primary.crew, roster)
						events.append_array(partner_events)
			if secondary.get("crew") != null:
				_apply_fatigue_delta(secondary.crew, 5.0)

		"critical_failure":
			if primary.get("crew") != null:
				_apply_fatigue_delta(primary.crew, 15.0)
				var morale_penalty: float = CrewSimulation.get_loyalty_morale_anchor(primary.crew, -8.0)
				_apply_morale_delta(primary.crew, morale_penalty)
				# Phase 4.2: Memory on critical failure
				CrewSimulation.create_challenge_memory(primary.crew, "critical_failure",
					primary.get("display_name", ""), encounter_type)
				if randf() < 0.70:
					var inj_result: Dictionary = CrewSimulation.inflict_structured_injury(
						primary.crew, "MODERATE", has_medic, medic_stat)
					if not inj_result.is_empty():
						events.append(inj_result.event_text)
						injured_count += 1
						CrewSimulation.create_injury_memory(primary.crew, "moderate")
						var partner_events: Array[String] = CrewSimulation.trigger_partner_injury_reaction(primary.crew, roster)
						events.append_array(partner_events)
						# Witness memory for other crew
						for cm: CrewMember in roster:
							if cm.id != primary.crew.id:
								CrewSimulation.create_witness_injury_memory(cm, primary.crew.crew_name)
				if randf() < 0.10:
					var inj_result: Dictionary = CrewSimulation.inflict_structured_injury(
						primary.crew, "SEVERE", has_medic, medic_stat)
					if not inj_result.is_empty():
						events.append(inj_result.event_text)
						injured_count += 1
						CrewSimulation.create_injury_memory(primary.crew, "severe")
						var partner_events: Array[String] = CrewSimulation.trigger_partner_injury_reaction(primary.crew, roster)
						events.append_array(partner_events)
			if secondary.get("crew") != null:
				_apply_fatigue_delta(secondary.crew, 10.0)
				var sec_penalty: float = CrewSimulation.get_loyalty_morale_anchor(secondary.crew, -5.0)
				_apply_morale_delta(secondary.crew, sec_penalty)
				events.append("[color=#E67E22]%s took a heavy toll from the encounter.[/color]" % secondary.crew.crew_name)

	# Phase 4.1: Apply pinch-hit experience
	var pinch_data: Array = result.get("pinch_hit_data", [])
	for phd: Dictionary in pinch_data:
		var ph_crew: CrewMember = phd.get("crew")
		if ph_crew != null:
			ph_crew.add_role_experience(phd.get("own_exp", 0.5))
			ph_crew.add_pinch_hit_experience(phd.get("covered_role", ""), phd.get("covered_exp", 0.3))
			DatabaseManager.update_crew_member(ph_crew.id, {
				"role_experience": ph_crew.role_experience,
				"pinch_hit_experience": JSON.stringify(ph_crew.pinch_hit_experience),
			})

	# Phase 5.5: Combat death check on critical failure (difficulty 4-5)
	if result.tier == "critical_failure":
		var difficulty: int = result.get("difficulty", 0)
		if primary.get("crew") != null:
			var death_events: Array[String] = CrewSimulation.check_combat_death(
				primary.crew, difficulty, roster)
			events.append_array(death_events)

	# Phase 4.4: Check for catastrophic loss ship memory
	if injured_count >= 2:
		var catastrophe_events: Array[String] = CrewSimulation.check_catastrophic_loss(roster, injured_count)
		events.append_array(catastrophe_events)

	return events


# === INJURY SYSTEM ===

static func _inflict_injury(cm: CrewMember, severity: String, has_medic: bool) -> String:
	## Creates an injury on a crew member. Returns event text.
	var actual_severity: String = severity
	if has_medic:
		match actual_severity:
			"severe":
				actual_severity = "moderate"
			"moderate":
				actual_severity = "minor"
			"minor":
				return ""  # Negligible — medic patched it up

	var stats: Array[String] = ["stamina", "cognition", "reflexes", "social", "resourcefulness"]
	var stat_affected: String = stats[randi() % stats.size()]
	var body_part: String = BODY_PARTS[randi() % BODY_PARTS.size()]
	var reduction: int
	var ticks: int
	var description: String
	var event_text: String

	match actual_severity:
		"minor":
			reduction = randi_range(2, 5)
			ticks = 10
			description = "%s strain — %s -%d" % [body_part.capitalize(), stat_affected.capitalize(), reduction]
			event_text = "[color=#E67E22]%s took a hit. Nothing serious, but they're nursing a sore %s.[/color]" % [cm.crew_name, body_part]
		"moderate":
			reduction = randi_range(5, 10)
			ticks = 20
			description = "%s injury — %s -%d" % [body_part.capitalize(), stat_affected.capitalize(), reduction]
			event_text = "[color=#C0392B]%s is injured. %s damage — they'll need time to recover.[/color]" % [cm.crew_name, body_part.capitalize()]
		"severe":
			reduction = randi_range(8, 15)
			ticks = 30
			description = "Severe %s injury — %s -%d" % [body_part, stat_affected.capitalize(), reduction]
			event_text = "[color=#C0392B]%s is badly hurt. They need medical attention.[/color]" % cm.crew_name
		_:
			return ""

	# No medic → injuries take 50% longer
	if not has_medic:
		ticks = int(float(ticks) * 1.5)

	var injury: Dictionary = {
		"stat_affected": stat_affected,
		"reduction_amount": reduction,
		"ticks_remaining": ticks,
		"description": description,
	}

	cm.injuries.append(injury)
	DatabaseManager.update_crew_member(cm.id, {"injuries": JSON.stringify(cm.injuries)})
	return event_text


# === OUTCOME TEXT ===

static func get_encounter_outcome_text(encounter_id: String, tier: String) -> String:
	## Returns flavor text for an encounter outcome.
	match tier:
		"critical_success":
			return "Outstanding. Not a scratch."
		"success":
			return "Handled. You push through without major trouble."
		"marginal_success":
			return "Barely scraped through. Could have gone either way."
		"failure":
			return "It went wrong. Damage done, but you survive."
		"critical_failure":
			return "Disaster. You limp away from the wreckage."
		_:
			return "Resolved."


# === RESCUE ENCOUNTER HELPERS ===

static func generate_rescue_survivor() -> CrewMember:
	## Generates a survivor for distress signal rescue encounters.
	var species_options: Array[String] = ["HUMAN", "GORVIAN", "VELLANI", "KRELLVANI"]
	var role_options: Array[String] = ["GUNNER", "ENGINEER", "NAVIGATOR", "MEDIC",
		"COMMS_OFFICER", "SCIENCE_OFFICER", "SECURITY_CHIEF", "GENERALIST"]
	var species_key: String = species_options[randi() % species_options.size()]
	var role_key: String = role_options[randi() % role_options.size()]

	var cm: CrewMember = CrewMember.new()
	cm.crew_name = TextTemplates.get_crew_name(species_key)
	cm.species = CrewMember._parse_species(species_key)
	cm.role = CrewMember._parse_role(role_key)
	# Moderate-to-good stats
	cm.stamina = randi_range(40, 65)
	cm.cognition = randi_range(40, 65)
	cm.reflexes = randi_range(40, 65)
	cm.social = randi_range(40, 65)
	cm.resourcefulness = randi_range(40, 65)
	cm.morale = 40.0  # Traumatized
	cm.loyalty = 65.0  # High — grateful
	cm.personality = "Grateful, haunted by the ordeal."
	cm.hired_day = GameManager.day_count
	return cm


static func recruit_rescue_survivor(survivor: CrewMember) -> int:
	## Adds a rescue survivor as crew. Returns crew_id or -1.
	if GameManager.get_available_crew_slots() < survivor.get_crew_slot_cost(GameManager.ship_class):
		return -1

	var data: Dictionary = survivor.to_dict()
	var crew_id: int = DatabaseManager.insert_crew_member(GameManager.save_id, data)

	# Create relationships with existing crew
	var existing: Array = DatabaseManager.get_active_crew(GameManager.save_id)
	for row: Dictionary in existing:
		if row.id == crew_id:
			continue
		var existing_species: CrewMember.Species = CrewMember._parse_species(row.species)
		var friction: int = CrewMember.get_friction_between(survivor.species, existing_species)
		DatabaseManager.insert_crew_relationship(crew_id, row.id, float(friction))

	EventBus.crew_recruited.emit(crew_id, survivor.crew_name)
	EventBus.crew_changed.emit()
	GameManager.save_game()
	return crew_id


# === HELPERS ===

static func _get_rating_word(expected_roll: float, difficulty: float) -> String:
	var ratio: float = expected_roll / maxf(difficulty, 1.0)
	if ratio > 1.8:
		return "Good odds"
	elif ratio > 1.2:
		return "Decent chance"
	elif ratio > 0.8:
		return "Risky"
	else:
		return "Desperate"


static func _get_rating_color(rating: String) -> String:
	match rating:
		"Good odds":
			return "#27AE60"
		"Decent chance":
			return "#4A90D9"
		"Risky":
			return "#E67E22"
		"Desperate":
			return "#C0392B"
		_:
			return "#718096"


static func _has_medic(roster: Array[CrewMember]) -> bool:
	for cm: CrewMember in roster:
		if cm.role == CrewMember.Role.MEDIC:
			return true
	return false


static func _apply_purpose(cm: CrewMember) -> void:
	cm.ticks_since_role_used = 0
	DatabaseManager.update_crew_member(cm.id, {"ticks_since_role_used": 0})


static func _apply_fatigue_delta(cm: CrewMember, amount: float) -> void:
	cm.fatigue = clampf(cm.fatigue + amount, 0.0, 100.0)
	DatabaseManager.update_crew_member(cm.id, {"fatigue": cm.fatigue})


static func _apply_morale_delta(cm: CrewMember, amount: float) -> void:
	cm.morale = clampf(cm.morale + amount, 0.0, 100.0)
	DatabaseManager.update_crew_member(cm.id, {"morale": cm.morale})


static func _get_encounter_context() -> String:
	## Returns a context string for the current encounter situation.
	# This is a simple heuristic — refine as encounter types grow
	return "combat"
