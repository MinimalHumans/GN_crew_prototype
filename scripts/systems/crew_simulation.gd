class_name CrewSimulation
## CrewSimulation — Central crew simulation engine.
## Ticks once per jump during travel and once on planet arrival.
## Processes needs, morale drift, fatigue, and relationship shifts.


# === MORALE NEED MODIFIERS ===

static func _get_pay_modifier(pay_split: float) -> float:
	## Pay satisfaction: 60/40 captain = -8, 50/50 = 0, 40/60 crew = +5.
	if pay_split >= 0.6:
		return -8.0
	elif pay_split <= 0.4:
		return 5.0
	return 0.0


static func _get_food_modifier(cm: CrewMember, food_supply: float, crew_count: int) -> float:
	## Food satisfaction based on days remaining and comfort food bonus.
	var food_per_jump: float = 1.0 + float(crew_count)
	var days_remaining: float = food_supply / maxf(food_per_jump, 1.0)
	var modifier: float = 0.0
	if days_remaining <= 0.0:
		modifier = -20.0
	elif days_remaining <= 3.0:
		modifier = -5.0
	# else neutral
	# Comfort food bonus
	if cm.comfort_food_ticks > 0:
		modifier += 3.0
	return modifier


static func _get_rest_modifier(cm: CrewMember) -> float:
	## Fatigue-based rest satisfaction.
	if cm.fatigue <= 30.0:
		return 3.0
	elif cm.fatigue <= 60.0:
		return 0.0
	elif cm.fatigue <= 80.0:
		return -5.0
	else:
		return -12.0


static func _get_safety_modifier() -> float:
	## Based on rolling danger ratio from GameManager.
	var ratio: float = GameManager.get_danger_ratio()
	if ratio > 0.5:
		return -10.0
	elif ratio > 0.2:
		return -3.0
	elif GameManager.recent_events.size() > 0:
		return 3.0
	return 0.0  # No events yet


static func _get_purpose_modifier(cm: CrewMember) -> float:
	## Based on ticks since role was last exercised.
	if cm.ticks_since_role_used < 5:
		return 3.0
	elif cm.ticks_since_role_used <= 15:
		return 0.0
	elif cm.ticks_since_role_used <= 30:
		return -5.0
	else:
		return -10.0


static func _get_relationship_modifier(crew_id: int) -> float:
	## Based on average relationship value with crewmates.
	var rels: Array = DatabaseManager.get_crew_relationships(crew_id)
	if rels.is_empty():
		return 0.0
	var total: float = 0.0
	for rel: Dictionary in rels:
		total += rel.value
	var avg: float = total / float(rels.size())
	if avg > 30.0:
		return 3.0
	elif avg < -30.0:
		return -5.0
	return 0.0


# === TICK PROCESSING ===

static func tick_jump(had_encounter: bool, encounter_was_combat: bool = false,
		encounter_difficulty: int = 0, roles_tested: Array = []) -> Dictionary:
	## Runs one crew simulation tick during a jump.
	## Returns {events: Array[String], morale_changes: Dictionary}.
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		return {"events": [], "morale_changes": {}}

	var crew_count: int = roster.size()
	var events: Array[String] = []

	# Process each crew member
	for cm: CrewMember in roster:
		# --- Fatigue ---
		var fatigue_delta: float
		if had_encounter:
			# Check if this crew member's role was tested
			var role_str: String = CrewMember._role_to_string(cm.role)
			if role_str in roles_tested:
				fatigue_delta = 5.0 + float(encounter_difficulty) * 2.0
				fatigue_delta = clampf(fatigue_delta, 5.0, 15.0)
				cm.ticks_since_role_used = 0
			else:
				fatigue_delta = 2.0  # General stress from encounter
				cm.ticks_since_role_used += 1
		else:
			fatigue_delta = 2.0  # Quiet jump — less fatigue
			cm.ticks_since_role_used += 1

		cm.fatigue = clampf(cm.fatigue + fatigue_delta, 0.0, 100.0)

		# --- Comfort food countdown ---
		if cm.comfort_food_ticks > 0:
			cm.comfort_food_ticks -= 1

		# --- Morale bonus (permanent, from bonding breakthrough etc.) ---
		# Applied as a constant positive modifier each tick

		# --- Krellvani claustrophobia on Corvette ---
		if cm.species == CrewMember.Species.KRELLVANI and GameManager.ship_class == "corvette":
			cm.morale = maxf(0.0, cm.morale - 5.0)
			if not GameManager.claustrophobia_logged.has(cm.id):
				events.append("[color=#E67E22]%s is uncomfortable — Krellvani don't do well in tight quarters.[/color]" % cm.crew_name)
				GameManager.claustrophobia_logged[cm.id] = true

		# --- Morale drift ---
		var modifier_sum: float = 0.0
		modifier_sum += _get_pay_modifier(GameManager.pay_split)
		modifier_sum += _get_food_modifier(cm, GameManager.food_supply, crew_count)
		modifier_sum += _get_rest_modifier(cm)
		modifier_sum += _get_safety_modifier()
		modifier_sum += _get_purpose_modifier(cm)
		modifier_sum += _get_relationship_modifier(cm.id)
		modifier_sum += cm.morale_bonus  # Permanent bonus (e.g., bonding breakthrough)

		# Calculate target morale and drift toward it
		var target: float = clampf(cm.morale + modifier_sum, 0.0, 100.0)
		var distance: float = absf(target - cm.morale)
		var drift_speed: float = 2.0 + (distance / 30.0) * 3.0  # 2-5 range
		drift_speed = clampf(drift_speed, 2.0, 5.0)

		if target > cm.morale:
			cm.morale = minf(target, cm.morale + drift_speed)
		elif target < cm.morale:
			cm.morale = maxf(target, cm.morale - drift_speed)
		cm.morale = clampf(cm.morale, 0.0, 100.0)

		# --- Injury recovery ---
		var recovered: Array[String] = cm.tick_injuries()
		for recovery_text: String in recovered:
			events.append("[color=#27AE60]%s[/color]" % recovery_text)

		# --- Persist crew state ---
		DatabaseManager.update_crew_member(cm.id, {
			"morale": cm.morale,
			"fatigue": cm.fatigue,
			"ticks_since_role_used": cm.ticks_since_role_used,
			"comfort_food_ticks": cm.comfort_food_ticks,
			"injuries": JSON.stringify(cm.injuries),
		})

	# --- Relationship shifts ---
	var rel_events: Array[String] = _process_relationships_tick(roster, had_encounter, encounter_was_combat, roles_tested)
	events.append_array(rel_events)

	# --- Tick GameManager trackers ---
	GameManager.ticks_since_last_decision += 1
	GameManager.tick_nudge_cooldowns()

	# --- Process expired promises ---
	var expired: Array[Dictionary] = GameManager.tick_promises()
	for promise: Dictionary in expired:
		if promise.type == "dock_soon":
			# Player failed to dock in time — trust violation
			var crew_data: Dictionary = DatabaseManager.get_crew_member(promise.crew_id)
			if not crew_data.is_empty() and bool(crew_data.get("is_active", 0)):
				var new_morale: float = maxf(0.0, crew_data.morale - 15.0)
				DatabaseManager.update_crew_member(promise.crew_id, {"morale": new_morale})
				events.append("[color=#C0392B]%s feels betrayed — you didn't dock as promised.[/color]" % crew_data.name)

	return {"events": events}


static func tick_planet_arrival() -> Array[String]:
	## Runs fatigue recovery and morale adjustments on planet arrival.
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		return []

	var events: Array[String] = []
	var crew_count: int = roster.size()

	for cm: CrewMember in roster:
		# Fatigue recovery — docking counts as rest
		var old_fatigue: float = cm.fatigue
		cm.fatigue = maxf(0.0, cm.fatigue - 8.0)

		# Check for comfort food: did we buy food at a planet matching this crew's faction?
		var planet: Dictionary = GameManager.get_current_planet()
		if GameManager.last_food_planet_id == GameManager.current_planet_id:
			var species_name: String = cm.get_species_name()
			if planet.get("faction", "") == species_name:
				cm.comfort_food_ticks = 10
				events.append("[color=#4CAF50]%s grins at the sight of proper %s food.[/color]" % [cm.crew_name, species_name])

		# Persist
		DatabaseManager.update_crew_member(cm.id, {
			"fatigue": cm.fatigue,
			"comfort_food_ticks": cm.comfort_food_ticks,
		})

		# Log notable fatigue recovery
		if old_fatigue > 60.0 and cm.fatigue <= 30.0:
			events.append("[color=#718096]%s looks well-rested after the shore leave.[/color]" % cm.crew_name)

	# Check for fulfilled dock promises
	var remaining: Array[Dictionary] = []
	for promise: Dictionary in GameManager.pending_promises:
		if promise.type == "dock_soon":
			var crew_data: Dictionary = DatabaseManager.get_crew_member(promise.crew_id)
			if not crew_data.is_empty() and bool(crew_data.get("is_active", 0)):
				var new_morale: float = minf(100.0, crew_data.morale + 10.0)
				DatabaseManager.update_crew_member(promise.crew_id, {"morale": new_morale})
				events.append("[color=#27AE60]%s is grateful you kept your promise to dock.[/color]" % crew_data.name)
		else:
			remaining.append(promise)
	GameManager.pending_promises = remaining

	return events


# === RELATIONSHIP PROCESSING ===

static func _process_relationships_tick(roster: Array[CrewMember], had_encounter: bool,
		encounter_was_combat: bool, roles_tested: Array) -> Array[String]:
	## Processes relationship shifts for all crew pairs during a jump.
	var events: Array[String] = []
	if roster.size() < 2:
		return events

	for i: int in range(roster.size()):
		for j: int in range(i + 1, roster.size()):
			var cm_a: CrewMember = roster[i]
			var cm_b: CrewMember = roster[j]
			var current_val: float = DatabaseManager.get_relationship_value(cm_a.id, cm_b.id)
			var delta: float = 0.0

			# Proximity drift: +0.1 per tick toward familiarity, capped at +10 contribution
			if current_val < 10.0:
				delta += 0.1

			# Shared combat survival
			if had_encounter and encounter_was_combat:
				delta += 2.0  # Base bond from surviving together

			# Shared mission roles tested
			var role_a: String = CrewMember._role_to_string(cm_a.role)
			var role_b: String = CrewMember._role_to_string(cm_b.role)
			if role_a in roles_tested and role_b in roles_tested:
				delta += 2.0

			# Quiet jump social interaction (15% chance per pair)
			if not had_encounter and randf() < 0.15:
				var social_delta: float = _calculate_social_interaction(cm_a, cm_b)
				delta += social_delta
				if social_delta > 0.5:
					var social_event: String = CrewEventTemplates.get_positive_social_text(cm_a.crew_name, cm_b.crew_name)
					events.append("[color=#718096]%s[/color]" % social_event)
				elif social_delta < -0.5:
					var friction_event: String = CrewEventTemplates.get_negative_social_text(cm_a.crew_name, cm_b.crew_name)
					events.append("[color=#718096]%s[/color]" % friction_event)

			# Phase 3.3: Species-specific relationship events
			var species_event: String = _check_species_relationship_event(cm_a, cm_b, current_val)
			if species_event != "":
				events.append(species_event)

			# Apply delta
			if absf(delta) > 0.01:
				var new_val: float = clampf(current_val + delta, -100.0, 100.0)
				DatabaseManager.update_relationship(cm_a.id, cm_b.id, new_val)

				# Big shift events
				if delta >= 5.0:
					events.append("[color=#27AE60]%s and %s seem to be bonding.[/color]" % [cm_a.crew_name, cm_b.crew_name])
				elif delta <= -5.0:
					events.append("[color=#C0392B]%s and %s had a tense exchange.[/color]" % [cm_a.crew_name, cm_b.crew_name])

				# Phase 3.3: Bonding breakthrough check
				var breakthrough_event: String = _check_bonding_breakthrough(cm_a, cm_b, new_val)
				if breakthrough_event != "":
					events.append(breakthrough_event)

	return events


static func _calculate_social_interaction(cm_a: CrewMember, cm_b: CrewMember) -> float:
	## Returns relationship delta from a social interaction based on stat profiles.
	# Find highest stat for each
	var stats_a: Array[int] = [cm_a.stamina, cm_a.cognition, cm_a.reflexes, cm_a.social, cm_a.resourcefulness]
	var stats_b: Array[int] = [cm_b.stamina, cm_b.cognition, cm_b.reflexes, cm_b.social, cm_b.resourcefulness]

	var max_idx_a: int = 0
	var max_idx_b: int = 0
	for k: int in range(5):
		if stats_a[k] > stats_a[max_idx_a]:
			max_idx_a = k
		if stats_b[k] > stats_b[max_idx_b]:
			max_idx_b = k

	# Find lowest stat for each
	var min_idx_a: int = 0
	var min_idx_b: int = 0
	for k: int in range(5):
		if stats_a[k] < stats_a[min_idx_a]:
			min_idx_a = k
		if stats_b[k] < stats_b[min_idx_b]:
			min_idx_b = k

	# Same highest stat = shared interests (+2)
	if max_idx_a == max_idx_b:
		return 2.0
	# Highest stat of one is lowest of the other = friction (-1)
	if max_idx_a == min_idx_b or max_idx_b == min_idx_a:
		return -1.0
	# Otherwise neutral positive (+1)
	return 1.0


# === COMBAT / MISSION RELATIONSHIP HOOKS ===

static func process_mission_result(outcome_tier: String, roles_tested: Array) -> void:
	## Called after a mission resolves. Updates relationships based on shared outcome.
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.size() < 2:
		return

	var is_success: bool = outcome_tier in ["critical_success", "success"]
	var is_failure: bool = outcome_tier in ["failure", "critical_failure"]

	for i: int in range(roster.size()):
		for j: int in range(i + 1, roster.size()):
			var cm_a: CrewMember = roster[i]
			var cm_b: CrewMember = roster[j]
			var role_a: String = CrewMember._role_to_string(cm_a.role)
			var role_b: String = CrewMember._role_to_string(cm_b.role)

			if role_a in roles_tested and role_b in roles_tested:
				var current_val: float = DatabaseManager.get_relationship_value(cm_a.id, cm_b.id)
				var delta: float = 0.0

				if is_success:
					delta = 2.0
				elif is_failure:
					# 50% bond, 50% blame — Social stat increases bonding chance
					var avg_social: float = float(cm_a.social + cm_b.social) / 2.0
					var bond_chance: float = 0.5 + (avg_social - 45.0) / 100.0
					bond_chance = clampf(bond_chance, 0.2, 0.8)
					if randf() < bond_chance:
						delta = 2.0
					else:
						delta = -3.0

				if absf(delta) > 0.01:
					var new_val: float = clampf(current_val + delta, -100.0, 100.0)
					DatabaseManager.update_relationship(cm_a.id, cm_b.id, new_val)

	# Record dangerous event if failure
	if is_failure:
		GameManager.record_event("failure")
	if outcome_tier == "critical_failure":
		GameManager.record_event("critical_failure")

	# Reset ticks_since_role_used for tested roles
	for cm: CrewMember in roster:
		var role_str: String = CrewMember._role_to_string(cm.role)
		if role_str in roles_tested:
			DatabaseManager.update_crew_member(cm.id, {"ticks_since_role_used": 0})


# === PHASE 3.3: SPECIES RELATIONSHIP EVENTS ===

static func _get_species_pair_key(cm_a: CrewMember, cm_b: CrewMember) -> String:
	## Returns a sorted species pair key for lookup.
	var name_a: String = cm_a.get_species_name().to_upper()
	var name_b: String = cm_b.get_species_name().to_upper()
	if name_a < name_b:
		return "%s_%s" % [name_a, name_b]
	return "%s_%s" % [name_b, name_a]


static func _check_species_relationship_event(cm_a: CrewMember, cm_b: CrewMember, rel_value: float) -> String:
	## Checks for species-specific relationship events based on pair and relationship state.
	## Returns event text or empty string.
	if cm_a.species == cm_b.species:
		return ""  # Same species — no special events

	var pair_key: String = _get_species_pair_key(cm_a, cm_b)
	# 10% chance per tick to fire a species event
	if randf() > 0.10:
		return ""

	match pair_key:
		"GORVIAN_KRELLVANI":
			if rel_value < -10.0:
				return "[color=#E67E22]%s[/color]" % CrewEventTemplates.get_species_friction_text(
					cm_a.crew_name, cm_b.crew_name, "GORVIAN_KRELLVANI")
			elif rel_value > 20.0:
				return "[color=#27AE60]%s[/color]" % CrewEventTemplates.get_species_bonding_text(
					cm_a.crew_name, cm_b.crew_name, "GORVIAN_KRELLVANI")
		"GORVIAN_VELLANI":
			if rel_value < -10.0:
				return "[color=#E67E22]%s[/color]" % CrewEventTemplates.get_species_friction_text(
					cm_a.crew_name, cm_b.crew_name, "GORVIAN_VELLANI")
		"KRELLVANI_VELLANI":
			if rel_value > 20.0:
				return "[color=#27AE60]%s[/color]" % CrewEventTemplates.get_species_bonding_text(
					cm_a.crew_name, cm_b.crew_name, "KRELLVANI_VELLANI")
		"GORVIAN_HUMAN":
			if rel_value > 20.0:
				return "[color=#27AE60]%s[/color]" % CrewEventTemplates.get_species_bonding_text(
					cm_a.crew_name, cm_b.crew_name, "GORVIAN_HUMAN")
		"HUMAN_VELLANI":
			if rel_value > 20.0 and randf() < 0.3:
				return "[color=#4CAF50]%s[/color]" % CrewEventTemplates.get_species_bonding_text(
					cm_a.crew_name, cm_b.crew_name, "HUMAN_VELLANI")
	return ""


static func _check_bonding_breakthrough(cm_a: CrewMember, cm_b: CrewMember, rel_value: float) -> String:
	## Checks for cross-species bonding breakthrough at +30 relationship.
	## Gorvian-Krellvani pairs get a special event and +3 permanent morale bonus.
	if cm_a.species == cm_b.species:
		return ""
	if rel_value < 30.0:
		return ""

	# Check if bonding_breakthrough already happened for this pair
	var a_id: int = mini(cm_a.id, cm_b.id)
	var b_id: int = maxi(cm_a.id, cm_b.id)
	var rels: Array = DatabaseManager.get_crew_relationships(a_id)
	for rel: Dictionary in rels:
		if (rel.crew_a_id == a_id and rel.crew_b_id == b_id) or \
		   (rel.crew_a_id == b_id and rel.crew_b_id == a_id):
			if rel.get("bonding_breakthrough", 0) == 1:
				return ""  # Already happened

	# Mark breakthrough as complete
	DatabaseManager.update_bonding_breakthrough(a_id, b_id)

	# Apply +3 permanent morale bonus to both
	cm_a.morale_bonus += 3.0
	cm_b.morale_bonus += 3.0
	DatabaseManager.update_crew_member(cm_a.id, {"morale_bonus": cm_a.morale_bonus})
	DatabaseManager.update_crew_member(cm_b.id, {"morale_bonus": cm_b.morale_bonus})

	var pair_key: String = _get_species_pair_key(cm_a, cm_b)
	if pair_key == "GORVIAN_KRELLVANI":
		return "[color=#E6D159]Breakthrough! %s and %s have bridged the divide between Gorvian and Krellvani. Their bond strengthens the entire crew. (+3 permanent morale)[/color]" % [cm_a.crew_name, cm_b.crew_name]
	return "[color=#E6D159]%s and %s have formed a deep bond across species lines. (+3 permanent morale)[/color]" % [cm_a.crew_name, cm_b.crew_name]
