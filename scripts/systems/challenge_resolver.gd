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

	# Find best generalist
	var best_gen: CrewMember = null
	var best_gen_stat: float = -1.0
	for cm: CrewMember in roster:
		if exclude_crew != null and cm.id == exclude_crew.id:
			continue
		if cm.role == CrewMember.Role.GENERALIST:
			var eff: float = cm.get_effective_stat(stat_name) * GENERALIST_MULTIPLIER
			if eff > best_gen_stat:
				best_gen_stat = eff
				best_gen = cm

	if best_gen != null:
		return {"crew": best_gen, "type": "generalist", "stat_value": best_gen_stat,
				"display_name": "%s (Generalist)" % best_gen.crew_name}

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

	return {
		"tier": tier,
		"roll": roll,
		"difficulty": difficulty,
		"primary": primary,
		"secondary": secondary,
	}


# === CREW CONSEQUENCES ===

static func apply_crew_consequences(result: Dictionary, roster: Array[CrewMember]) -> Array[String]:
	## Applies fatigue, morale, and injury consequences after a challenge.
	var events: Array[String] = []
	var has_medic: bool = _has_medic(roster)
	var primary: Dictionary = result.primary
	var secondary: Dictionary = result.get("secondary", {})

	match result.tier:
		"critical_success":
			if primary.get("crew") != null:
				_apply_purpose(primary.crew)
				_apply_morale_delta(primary.crew, 2.0)
				events.append("[color=#27AE60]%s handled it brilliantly.[/color]" % primary.crew.crew_name)
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
					var inj: String = _inflict_injury(primary.crew, "minor", has_medic)
					if inj != "":
						events.append(inj)

		"failure":
			if primary.get("crew") != null:
				_apply_fatigue_delta(primary.crew, 10.0)
				_apply_morale_delta(primary.crew, -3.0)
				events.append("[color=#E67E22]%s is frustrated after the failed attempt.[/color]" % primary.crew.crew_name)
				if randf() < 0.40:
					var inj: String = _inflict_injury(primary.crew, "minor", has_medic)
					if inj != "":
						events.append(inj)
			if secondary.get("crew") != null:
				_apply_fatigue_delta(secondary.crew, 5.0)

		"critical_failure":
			if primary.get("crew") != null:
				_apply_fatigue_delta(primary.crew, 15.0)
				_apply_morale_delta(primary.crew, -8.0)
				if randf() < 0.70:
					var inj: String = _inflict_injury(primary.crew, "moderate", has_medic)
					if inj != "":
						events.append(inj)
				if randf() < 0.10:
					var inj: String = _inflict_injury(primary.crew, "severe", has_medic)
					if inj != "":
						events.append(inj)
			if secondary.get("crew") != null:
				_apply_fatigue_delta(secondary.crew, 10.0)
				_apply_morale_delta(secondary.crew, -5.0)
				events.append("[color=#E67E22]%s took a heavy toll from the encounter.[/color]" % secondary.crew.crew_name)

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
