class_name CrewSimulation
## CrewSimulation — Central crew simulation engine.
## Ticks once per jump during travel and once on planet arrival.
## Processes needs, morale drift, fatigue, relationship shifts,
## skill progression, memory triggers, trait acquisition, and ship memories.


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
	# Iron Stomach trait: reduce food morale penalty by 50%
	if cm.has_trait("iron_stomach") and modifier < 0.0:
		modifier *= 0.5
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
	# Haunted trait: purpose is always satisfied
	if cm.has_trait("haunted"):
		return 5.0
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
		# Load memories for context-based modifiers
		cm.load_memories()

		# --- Fatigue ---
		var fatigue_delta: float
		var role_str: String = CrewMember._role_to_string(cm.role)
		if had_encounter:
			# Check if this crew member's role was tested
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

		# --- Phase 4.1: Skill progression ---
		var old_label: String = cm.get_growth_label()
		if role_str in roles_tested:
			cm.add_role_experience(3.0)
		elif not had_encounter:
			cm.add_role_experience(0.1)  # Passive maintenance

		# Track combat encounters for Battle-Tested trait
		if had_encounter and encounter_was_combat:
			cm.combat_encounter_count += 1

		# Track total jumps for Spacer's Instinct trait
		cm.total_jumps += 1
		cm.docked_ticks = 0  # Reset docked counter on jump

		# Track low food ticks for Iron Stomach trait
		var food_per_jump: float = 1.0 + float(crew_count)
		var food_days: float = GameManager.food_supply / maxf(food_per_jump, 1.0)
		if food_days < 3.0:
			cm.low_food_ticks += 1

		# Emit skill growth signal on label change
		var new_label: String = cm.get_growth_label()
		if new_label != old_label:
			events.append("[color=#E6D159]%s has grown as a %s — now %s.[/color]" % [cm.crew_name, cm.get_role_name(), new_label])
			EventBus.crew_skill_gained.emit(cm.id, cm.crew_name, new_label)

		# --- Krellvani claustrophobia on Corvette ---
		if cm.species == CrewMember.Species.KRELLVANI and GameManager.ship_class == "corvette":
			cm.morale = maxf(0.0, cm.morale - 5.0)
			if not GameManager.claustrophobia_logged.has(cm.id):
				events.append("[color=#E67E22]%s is uncomfortable — Krellvani don't do well in tight quarters.[/color]" % cm.crew_name)
				GameManager.claustrophobia_logged[cm.id] = true

		# --- Phase 4.3: Trait morale effects ---
		# Haunted: periodic morale dip every 15 ticks
		if cm.has_trait("haunted") and cm.total_jumps % 15 == 0:
			cm.morale = maxf(0.0, cm.morale - 3.0)

		# Spacer's Instinct: already handled via docked_ticks (see tick_planet_arrival)

		# --- Morale drift ---
		var modifier_sum: float = 0.0
		modifier_sum += _get_pay_modifier(GameManager.pay_split)
		modifier_sum += _get_food_modifier(cm, GameManager.food_supply, crew_count)
		modifier_sum += _get_rest_modifier(cm)
		modifier_sum += _get_safety_modifier()
		modifier_sum += _get_purpose_modifier(cm)
		modifier_sum += _get_relationship_modifier(cm.id)
		modifier_sum += cm.morale_bonus  # Permanent bonus (e.g., bonding breakthrough)

		# Phase 4.2: Memory-based morale context
		var context: String = _get_current_context(had_encounter, encounter_was_combat)
		modifier_sum += cm.get_memory_morale_modifier(context)

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

		# --- Injury recovery (Phase 5.3: structured with permanent impairment check) ---
		var recovery_events: Array[String] = check_permanent_impairment(cm)
		events.append_array(recovery_events)

		# --- Disease ticks (Phase 5.3) ---
		var cured: Array[String] = cm.tick_diseases()
		for cure_text: String in cured:
			events.append("[color=#27AE60]%s[/color]" % cure_text)
		if not cured.is_empty():
			DatabaseManager.update_crew_member(cm.id, {"diseases": JSON.stringify(cm.diseases)})

		# --- Phase 4.2: Hull near-death memory trigger ---
		if had_encounter and encounter_was_combat:
			if float(GameManager.hull_current) < 0.25 * float(GameManager.hull_max):
				_try_create_combat_memory(cm, "near_death")

		# --- Phase 4.3: Trait acquisition checks ---
		var trait_events: Array[String] = _check_trait_acquisition(cm, roster)
		events.append_array(trait_events)

		# --- Phase 4.4: Ship culture scaling ---
		_scale_ship_culture(cm)

		# --- Persist crew state ---
		DatabaseManager.update_crew_member(cm.id, {
			"morale": cm.morale,
			"fatigue": cm.fatigue,
			"ticks_since_role_used": cm.ticks_since_role_used,
			"comfort_food_ticks": cm.comfort_food_ticks,
			"injuries": JSON.stringify(cm.injuries),
			"role_experience": cm.role_experience,
			"pinch_hit_experience": JSON.stringify(cm.pinch_hit_experience),
			"combat_encounter_count": cm.combat_encounter_count,
			"total_jumps": cm.total_jumps,
			"low_food_ticks": cm.low_food_ticks,
			"total_injuries_sustained": cm.total_injuries_sustained,
			"docked_ticks": cm.docked_ticks,
			"traits": JSON.stringify(cm.traits),
			"diseases": JSON.stringify(cm.diseases),
			"permanent_impairments": JSON.stringify(cm.permanent_impairments),
			"loyalty": cm.loyalty,
			"loyalty_departure_stage": cm.loyalty_departure_stage,
			"value_evidence_count": cm.value_evidence_count,
			"is_quarantined": 1 if cm.is_quarantined else 0,
			"quarantine_ticks": cm.quarantine_ticks,
		})

	# --- Phase 4.4: Ship memory triggers ---
	if had_encounter and encounter_was_combat:
		var ship_events: Array[String] = _check_ship_memory_triggers(roster)
		events.append_array(ship_events)

	# --- Phase 5.1: Romance processing ---
	var romance_events: Array[String] = _check_romance_eligibility(roster)
	events.append_array(romance_events)
	var romance_effect_events: Array[String] = _process_romance_effects(roster)
	events.append_array(romance_effect_events)

	# --- Phase 5.2: Loyalty processing ---
	var loyalty_events: Array[String] = _process_loyalty_tick(roster)
	events.append_array(loyalty_events)

	# --- Phase 5.3: Disease triggers ---
	var disease_events: Array[String] = _check_disease_triggers(roster, had_encounter)
	events.append_array(disease_events)

	# --- Phase 5.3: Quarantine ticks ---
	var quarantine_events: Array[String] = _process_disease_ticks(roster)
	events.append_array(quarantine_events)

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

		# Track docked ticks for Spacer's Instinct restlessness
		cm.docked_ticks += 1

		# Spacer's Instinct: restless when docked > 5 ticks
		if cm.has_trait("spacers_instinct") and cm.docked_ticks > 5:
			cm.morale = maxf(0.0, cm.morale - 2.0)

		# Check for comfort food: did we buy food at a planet matching this crew's faction?
		var planet: Dictionary = GameManager.get_current_planet()
		if GameManager.last_food_planet_id == GameManager.current_planet_id:
			var species_name: String = cm.get_species_name()
			if planet.get("faction", "") == species_name:
				cm.comfort_food_ticks = 10
				events.append("[color=#4CAF50]%s grins at the sight of proper %s food.[/color]" % [cm.crew_name, species_name])

		# Phase 4.2: First faction homeworld visit memory
		cm.load_memories()
		var planet_faction: String = planet.get("faction", "")
		if cm.get_species_name() == planet_faction:
			# Check if this is the first visit to any planet of their faction
			var has_homeworld_memory: bool = false
			for mem: Dictionary in cm.memories:
				if mem.get("context_match", "").begins_with("faction_homeworld"):
					has_homeworld_memory = true
					break
			if not has_homeworld_memory:
				_create_memory(cm, {
					"trigger_text": "First visit to %s — %s space" % [planet.get("name", "unknown"), planet_faction],
					"emotional_tag": "GRATEFUL",
					"modifier_type": "MORALE_IN_CONTEXT",
					"modifier_value": 5.0,
					"context_match": "faction_homeworld_%s" % planet_faction.to_lower(),
					"significance": 2.0,
				})
				events.append("[color=#4CAF50]%s is moved by the visit to %s. It feels like coming home.[/color]" % [cm.crew_name, planet.get("name", "unknown")])

		# Phase 5.1: Shared rest bonus for couples
		var partner_id: int = DatabaseManager.get_partner_id(cm.id)
		if partner_id >= 0:
			# Partner also docked — 25% extra fatigue recovery
			cm.fatigue = maxf(0.0, cm.fatigue - 2.0)

		# Phase 5.3: Hospital visit check
		var has_hospital: bool = planet.get("has_hospital", 0) == 1
		if has_hospital:
			# Auto-heal minor injuries for free at hospital planets
			var healed_minor: Array = []
			var remaining_inj: Array = []
			for inj: Dictionary in cm.injuries:
				if inj.get("severity", inj.get("description", "")).find("MINOR") != -1 or \
				   inj.get("ticks_remaining", 99) <= 5:
					healed_minor.append(inj)
				else:
					remaining_inj.append(inj)
			if not healed_minor.is_empty():
				cm.injuries = remaining_inj
				events.append("[color=#27AE60]%s received treatment at the hospital. Minor injuries patched up.[/color]" % cm.crew_name)

		# Phase 5.3: Cold environment disease check on arrival
		if planet.get("cold_environment", 0) == 1:
			if cm.species == CrewMember.Species.GORVIAN and not _has_disease(cm, CrewEventTemplates.DISEASE_THERMAL_SHOCK):
				if randf() < 0.15:
					var disease_text: String = _inflict_disease(cm, CrewEventTemplates.DISEASE_THERMAL_SHOCK,
						"stamina", 7, randi_range(15, 20), true, false, _has_medic_in_roster(roster))
					events.append(disease_text)

		# Phase 5.2: Loyalty departure — crew with loyalty 0 leaves at port
		if cm.loyalty <= 0.0 and cm.loyalty_departure_stage >= 3:
			events.append("[color=#C0392B][b]%s has left the crew.[/b] %s[/color]" % [cm.crew_name,
				CrewEventTemplates._pick(CrewEventTemplates.LOYALTY_DEPARTURE).replace("{name}", cm.crew_name)])
			GameManager.dismiss_crew(cm.id)
			EventBus.crew_departed.emit(cm.id, cm.crew_name)
			# Apply morale hit to remaining crew
			for other: CrewMember in roster:
				if other.id == cm.id:
					continue
				var rel: float = DatabaseManager.get_relationship_value(cm.id, other.id)
				if rel > 30.0:
					other.morale = maxf(0.0, other.morale - 5.0)
				elif rel > 0.0:
					other.morale = maxf(0.0, other.morale - 2.0)
			continue  # Skip persisting this crew — they're gone

		# Persist
		DatabaseManager.update_crew_member(cm.id, {
			"fatigue": cm.fatigue,
			"comfort_food_ticks": cm.comfort_food_ticks,
			"docked_ticks": cm.docked_ticks,
			"injuries": JSON.stringify(cm.injuries),
			"diseases": JSON.stringify(cm.diseases),
			"morale": cm.morale,
			"loyalty": cm.loyalty,
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

			# Phase 4.3: Peacemaker trait relationship drift bonus
			if cm_a.has_trait("peacemaker") or cm_b.has_trait("peacemaker"):
				delta += 2.0

			# Phase 4.4: Ship memory cohesion bonus
			var ship_mems: Array = DatabaseManager.get_ship_memories(GameManager.save_id)
			for smem: Dictionary in ship_mems:
				if smem.get("modifier_type", "") == "COHESION":
					delta += smem.get("modifier_value", 0.0)

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

				# Phase 4.3: Bonded Pair trait check
				if new_val > 80.0:
					if not cm_a.has_trait("bonded_pair") and not cm_b.has_trait("bonded_pair"):
						_award_bonded_pair(cm_a, cm_b, events)

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

	# Phase 4.1: Secondary role experience gain
	for cm: CrewMember in roster:
		var role_str: String = CrewMember._role_to_string(cm.role)
		if role_str in roles_tested:
			# Secondary role gets +1.5 (primary already got +3.0 in tick_jump)
			cm.add_role_experience(1.5)
			DatabaseManager.update_crew_member(cm.id, {
				"ticks_since_role_used": 0,
				"role_experience": cm.role_experience,
			})
		else:
			# Not tested but just update ticks
			pass

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


# === PHASE 4.2: MEMORY SYSTEM ===

static func _get_current_context(had_encounter: bool, encounter_was_combat: bool) -> String:
	## Returns a context string for the current game state.
	if encounter_was_combat:
		return "combat"
	elif had_encounter:
		return "encounter"
	return "travel"


static func _create_memory(cm: CrewMember, data: Dictionary) -> void:
	## Creates a memory for a crew member, enforcing the 6-memory cap.
	var day: int = GameManager.day_count
	data["day_acquired"] = day

	# Check memory cap
	var count: int = DatabaseManager.get_crew_memory_count(cm.id)
	if count >= 6:
		# Find and remove least significant memory
		var all_mems: Array = DatabaseManager.get_crew_memories(cm.id)
		var worst_id: int = -1
		var worst_score: float = 999999.0
		for mem: Dictionary in all_mems:
			if mem.get("is_ship_culture", 0) == 1:
				continue  # Don't replace ship culture memories
			var age: float = maxf(1.0, float(day - mem.get("day_acquired", day)))
			var score: float = mem.get("significance", 1.0) / age
			if score < worst_score:
				worst_score = score
				worst_id = mem.get("id", -1)
		if worst_id > 0:
			DatabaseManager.delete_crew_memory(worst_id)

	DatabaseManager.insert_crew_memory(cm.id, data)
	cm.load_memories()  # Refresh cache
	EventBus.crew_memory_formed.emit(cm.id, cm.crew_name, data.get("trigger_text", ""))


static func _try_create_combat_memory(cm: CrewMember, context_type: String) -> void:
	## Creates a combat-related memory based on crew stats.
	# Only create near-death memories once per battle (check if already has one this day)
	for mem: Dictionary in cm.memories:
		if mem.get("day_acquired", 0) == GameManager.day_count and mem.get("context_match", "") == context_type:
			return  # Already created this tick

	var tag: String
	var modifier_val: float
	if cm.stamina > 55:
		tag = "HARDENED"
		modifier_val = 5.0
	else:
		tag = "SHAKEN"
		modifier_val = -5.0

	var planet_name: String = GameManager.get_current_planet().get("name", "deep space")
	_create_memory(cm, {
		"trigger_text": "Survived a near-death battle near %s" % planet_name,
		"emotional_tag": tag,
		"modifier_type": "COMBAT_PERFORMANCE",
		"modifier_value": modifier_val,
		"context_match": "combat",
		"significance": 3.0,
	})


static func create_challenge_memory(cm: CrewMember, outcome_tier: String, role_name: String,
		encounter_type: String) -> void:
	## Called from ChallengeResolver after challenge resolution.
	var context: String = _role_to_memory_context(role_name)
	var planet_name: String = GameManager.get_current_planet().get("name", "deep space")

	if outcome_tier == "critical_success":
		var tag: String = "INSPIRED" if cm.social > 55 else "PROUD"
		var val: float = randf_range(5.0, 10.0)
		_create_memory(cm, {
			"trigger_text": "Critical success during %s near %s" % [encounter_type, planet_name],
			"emotional_tag": tag,
			"modifier_type": context,
			"modifier_value": val,
			"context_match": encounter_type,
			"significance": 3.0,
		})
	elif outcome_tier == "critical_failure":
		var tag: String
		var val: float
		if cm.stamina > 55:
			tag = "HARDENED"
			val = 5.0
		elif cm.cognition > 55:
			tag = "CAUTIOUS"
			val = 3.0
		else:
			tag = "SHAKEN"
			val = -5.0
		_create_memory(cm, {
			"trigger_text": "Critical failure during %s near %s" % [encounter_type, planet_name],
			"emotional_tag": tag,
			"modifier_type": context,
			"modifier_value": val,
			"context_match": encounter_type,
			"significance": 3.0,
		})


static func create_injury_memory(cm: CrewMember, severity: String) -> void:
	## Called when a crew member is injured.
	cm.total_injuries_sustained += 1
	DatabaseManager.update_crew_member(cm.id, {"total_injuries_sustained": cm.total_injuries_sustained})

	# Only create memories for moderate+ injuries
	if severity == "minor":
		return

	var tag: String = "HARDENED" if cm.stamina > 55 else "SHAKEN"
	var planet_name: String = GameManager.get_current_planet().get("name", "deep space")
	_create_memory(cm, {
		"trigger_text": "Injured during an encounter near %s" % planet_name,
		"emotional_tag": tag,
		"modifier_type": "COMBAT_PERFORMANCE",
		"modifier_value": 3.0 if tag == "HARDENED" else -3.0,
		"context_match": "combat",
		"significance": 2.0 if severity == "moderate" else 3.0,
	})


static func create_witness_injury_memory(cm: CrewMember, injured_name: String) -> void:
	## Called when a crew member witnesses another getting injured.
	var tag: String = "CAUTIOUS" if cm.social > 55 else "HARDENED"
	_create_memory(cm, {
		"trigger_text": "Watched %s get hurt in battle" % injured_name,
		"emotional_tag": tag,
		"modifier_type": "SCAN_PERFORMANCE" if tag == "CAUTIOUS" else "COMBAT_PERFORMANCE",
		"modifier_value": 3.0,
		"context_match": "combat",
		"significance": 1.5,
	})


static func _role_to_memory_context(role_name: String) -> String:
	## Maps role names to memory modifier type contexts.
	match role_name:
		"Gunner", "Security Chief":
			return "COMBAT_PERFORMANCE"
		"Navigator":
			return "NAVIGATION_PERFORMANCE"
		"Science Officer":
			return "SCAN_PERFORMANCE"
		"Comms Officer":
			return "SOCIAL_PERFORMANCE"
		_:
			return "COMBAT_PERFORMANCE"


# === PHASE 4.3: TRAIT ACQUISITION ===

static func _check_trait_acquisition(cm: CrewMember, roster: Array[CrewMember]) -> Array[String]:
	## Checks all trait acquisition conditions for a crew member.
	## Returns event text for any newly acquired traits.
	var events: Array[String] = []

	# Battle-Tested: 10+ combat encounters
	if not cm.has_trait("battle_tested") and cm.combat_encounter_count >= 10:
		_award_trait(cm, "battle_tested", events)

	# Spacer's Instinct: 100+ total jumps
	if not cm.has_trait("spacers_instinct") and cm.total_jumps >= 100:
		_award_trait(cm, "spacers_instinct", events)

	# Iron Stomach: 20+ low food ticks
	if not cm.has_trait("iron_stomach") and cm.low_food_ticks >= 20:
		_award_trait(cm, "iron_stomach", events)

	# Peacemaker: Social > 65 and 3+ conflicts mediated
	if not cm.has_trait("peacemaker") and cm.social > 65 and cm.conflicts_mediated >= 3:
		_award_trait(cm, "peacemaker", events)

	# Scarred: had severe injury (30+ tick recovery)
	for injury: Dictionary in cm.injuries:
		if injury.get("ticks_remaining", 0) >= 25 and not cm.has_trait("scarred"):
			_award_trait(cm, "scarred", events)
			break

	# Grudge-Bearer: any relationship < -80
	if not cm.has_trait("grudge_bearer"):
		var rels: Array = DatabaseManager.get_crew_relationships(cm.id)
		for rel: Dictionary in rels:
			if rel.get("value", 0.0) < -80.0:
				_award_trait(cm, "grudge_bearer", events)
				break

	# Haunted: 3+ SHAKEN memories
	if not cm.has_trait("haunted") and cm.count_memories_with_tag("SHAKEN") >= 3:
		_award_trait(cm, "haunted", events)

	# Reckless: 3+ HARDENED combat memories
	if not cm.has_trait("reckless"):
		var hardened_combat: int = 0
		for mem: Dictionary in cm.memories:
			if mem.get("emotional_tag", "") == "HARDENED" and mem.get("context_match", "") == "combat":
				hardened_combat += 1
		if hardened_combat >= 3:
			_award_trait(cm, "reckless", events)

	return events


static func _award_trait(cm: CrewMember, trait_id: String, events: Array[String]) -> void:
	## Awards a trait to a crew member and generates event text.
	cm.traits.append(trait_id)
	DatabaseManager.update_crew_member(cm.id, {"traits": JSON.stringify(cm.traits)})

	var tdef: Dictionary = CrewMember.TRAIT_DEFINITIONS.get(trait_id, {})
	var text: String = tdef.get("acquisition_text", "%s acquired a new trait." % cm.crew_name)
	text = text.replace("{name}", cm.crew_name)
	events.append("[color=#E6D159][b]Trait Acquired:[/b] %s — %s[/color]" % [tdef.get("name", trait_id), text])

	EventBus.crew_trait_acquired.emit(cm.id, cm.crew_name, trait_id, tdef.get("name", trait_id))


static func _award_bonded_pair(cm_a: CrewMember, cm_b: CrewMember, events: Array[String]) -> void:
	## Awards the Bonded Pair trait to both crew members.
	cm_a.traits.append("bonded_pair")
	cm_b.traits.append("bonded_pair")
	DatabaseManager.update_crew_member(cm_a.id, {"traits": JSON.stringify(cm_a.traits)})
	DatabaseManager.update_crew_member(cm_b.id, {"traits": JSON.stringify(cm_b.traits)})

	var tdef: Dictionary = CrewMember.TRAIT_DEFINITIONS.get("bonded_pair", {})
	var text: String = tdef.get("acquisition_text", "").replace("{a}", cm_a.crew_name).replace("{b}", cm_b.crew_name)
	events.append("[color=#E6D159][b]Trait Acquired:[/b] Bonded Pair — %s[/color]" % text)

	EventBus.crew_trait_acquired.emit(cm_a.id, cm_a.crew_name, "bonded_pair", "Bonded Pair")
	EventBus.crew_trait_acquired.emit(cm_b.id, cm_b.crew_name, "bonded_pair", "Bonded Pair")


# === PHASE 4.4: SHIP MEMORIES ===

static func _check_ship_memory_triggers(roster: Array[CrewMember]) -> Array[String]:
	## Checks for ship-wide memory triggers after combat encounters.
	var events: Array[String] = []

	# Near-death battle: hull < 15%
	if float(GameManager.hull_current) < 0.15 * float(GameManager.hull_max):
		# Check if we already have a ship memory from today
		var existing: Array = DatabaseManager.get_ship_memories(GameManager.save_id)
		var already_has: bool = false
		for smem: Dictionary in existing:
			if smem.get("day_acquired", 0) == GameManager.day_count:
				already_has = true
				break

		if not already_has:
			var planet_name: String = GameManager.get_current_planet().get("name", "deep space")
			var mem_data: Dictionary = {
				"event_description": "The Battle of %s" % planet_name,
				"modifier_type": "COHESION",
				"modifier_value": 1.0,  # +1 relationship drift per tick
				"context_match": "combat",
				"day_acquired": GameManager.day_count,
			}
			DatabaseManager.insert_ship_memory(GameManager.save_id, mem_data)
			events.append("[color=#E6D159][b]Ship Memory:[/b] The Battle of %s — the crew survived a near-death engagement. This shared trauma binds them together.[/color]" % planet_name)
			EventBus.ship_memory_formed.emit(mem_data.event_description)

			# Cap ship memories at 10
			_cap_ship_memories()

	return events


static func check_mission_ship_memory(outcome_tier: String, mission_data: Dictionary) -> Array[String]:
	## Called after mission resolution for ship memory triggers.
	var events: Array[String] = []
	var planet_name: String = GameManager.get_current_planet().get("name", "deep space")

	# Faction betrayal: critical failure on faction mission
	if outcome_tier == "critical_failure":
		var planet: Dictionary = GameManager.get_current_planet()
		var faction: String = planet.get("faction", "Unknown")
		var mem_data: Dictionary = {
			"event_description": "Betrayed by %s" % faction,
			"modifier_type": "FACTION_REACTION",
			"modifier_value": -5.0,
			"context_match": "faction_%s" % faction.to_lower(),
			"day_acquired": GameManager.day_count,
		}
		DatabaseManager.insert_ship_memory(GameManager.save_id, mem_data)
		events.append("[color=#C0392B][b]Ship Memory:[/b] Betrayed by %s — the crew won't forget what happened at %s.[/color]" % [faction, planet_name])
		EventBus.ship_memory_formed.emit(mem_data.event_description)
		_cap_ship_memories()

	# Extraordinary discovery: Science Officer critical success on survey
	if outcome_tier == "critical_success":
		var mission_type: String = mission_data.get("mission_type", mission_data.get("type", ""))
		if mission_type == "survey":
			var mem_data: Dictionary = {
				"event_description": "The %s Discovery" % planet_name,
				"modifier_type": "SCAN_PERFORMANCE",
				"modifier_value": 3.0,
				"context_match": "survey",
				"day_acquired": GameManager.day_count,
			}
			DatabaseManager.insert_ship_memory(GameManager.save_id, mem_data)
			events.append("[color=#E6D159][b]Ship Memory:[/b] The %s Discovery — extraordinary findings during the survey. The crew still talks about it.[/color]" % planet_name)
			EventBus.ship_memory_formed.emit(mem_data.event_description)
			_cap_ship_memories()

	return events


static func check_catastrophic_loss(roster: Array[CrewMember], injured_count: int) -> Array[String]:
	## Called when multiple crew are injured in the same event.
	var events: Array[String] = []
	if injured_count >= 2:
		var planet_name: String = GameManager.get_current_planet().get("name", "deep space")
		var mem_data: Dictionary = {
			"event_description": "The %s Disaster" % planet_name,
			"modifier_type": "SCAN_PERFORMANCE",
			"modifier_value": 5.0,
			"context_match": "safety",
			"day_acquired": GameManager.day_count,
		}
		DatabaseManager.insert_ship_memory(GameManager.save_id, mem_data)
		events.append("[color=#C0392B][b]Ship Memory:[/b] The %s Disaster — multiple crew injured. The ship is more cautious now.[/color]" % planet_name)
		EventBus.ship_memory_formed.emit(mem_data.event_description)
		_cap_ship_memories()

	return events


static func _cap_ship_memories() -> void:
	## Removes oldest ship memories if count exceeds 10.
	var all_mems: Array = DatabaseManager.get_ship_memories(GameManager.save_id)
	while all_mems.size() > 10:
		# Remove the oldest (lowest day_acquired)
		var oldest_id: int = all_mems[0].get("id", -1)
		var oldest_day: int = all_mems[0].get("day_acquired", 999999)
		for mem: Dictionary in all_mems:
			if mem.get("day_acquired", 999999) < oldest_day:
				oldest_day = mem.get("day_acquired", 999999)
				oldest_id = mem.get("id", -1)
		if oldest_id > 0:
			DatabaseManager.db.query_with_bindings("DELETE FROM ship_memories WHERE id = ?", [oldest_id])
		all_mems = DatabaseManager.get_ship_memories(GameManager.save_id)


# === PHASE 5.1: ROMANCE SYSTEM ===

static func _check_romance_eligibility(roster: Array[CrewMember]) -> Array[String]:
	## Checks all eligible pairs for romance formation.
	var events: Array[String] = []
	if roster.size() < 2:
		return events

	for i: int in range(roster.size()):
		for j: int in range(i + 1, roster.size()):
			var cm_a: CrewMember = roster[i]
			var cm_b: CrewMember = roster[j]

			# Skip if either is already in a romance
			if DatabaseManager.is_in_romance(cm_a.id) or DatabaseManager.is_in_romance(cm_b.id):
				continue

			var rel_val: float = DatabaseManager.get_relationship_value(cm_a.id, cm_b.id)
			if rel_val < 70.0:
				continue

			# Check personality compatibility
			if not cm_a.is_romance_compatible(cm_b):
				continue

			# Roll probability
			var chance: float
			if rel_val >= 90.0:
				chance = 0.10
			elif rel_val >= 80.0:
				chance = 0.06
			else:
				chance = 0.03

			if randf() < chance:
				# Romance forms!
				DatabaseManager.insert_crew_romance(GameManager.save_id, cm_a.id, cm_b.id, GameManager.day_count)
				var text: String = CrewEventTemplates.get_romance_formation_text(cm_a.crew_name, cm_b.crew_name)
				events.append("[color=#E6D159][b]Romance:[/b] %s[/color]" % text)
				EventBus.romance_formed.emit(cm_a.id, cm_b.id)

	return events


static func _process_romance_effects(roster: Array[CrewMember]) -> Array[String]:
	## Processes ongoing romance effects: linked morale, partner injury concern.
	var events: Array[String] = []
	var romances: Array = DatabaseManager.get_active_romances(GameManager.save_id)

	for rom: Dictionary in romances:
		var cm_a: CrewMember = _find_in_roster(roster, rom.crew_a_id)
		var cm_b: CrewMember = _find_in_roster(roster, rom.crew_b_id)
		if cm_a == null or cm_b == null:
			continue

		# Linked morale: pull toward each other, capped at 3 points per tick
		var morale_diff: float = cm_a.morale - cm_b.morale
		var pull: float = morale_diff * 0.30
		pull = clampf(pull, -3.0, 3.0)
		cm_b.morale = clampf(cm_b.morale + pull, 0.0, 100.0)
		cm_a.morale = clampf(cm_a.morale - pull, 0.0, 100.0)

		# Relationship buffer: +10 drift resistance (harder for romance to decay)
		var rel_val: float = DatabaseManager.get_relationship_value(cm_a.id, cm_b.id)
		if rel_val < 70.0:
			DatabaseManager.update_relationship(cm_a.id, cm_b.id, rel_val + 0.5)

		# Partner injury concern
		if cm_a.has_injuries() and not cm_b.has_injuries():
			# Check for severe injury
			var severe: bool = false
			for inj: Dictionary in cm_a.injuries:
				if inj.get("ticks_remaining", 0) >= 25:
					severe = true
					break
			if severe:
				cm_b.morale = maxf(0.0, cm_b.morale - 0.5)  # Lingering -3 spread over ticks

		if cm_b.has_injuries() and not cm_a.has_injuries():
			var severe: bool = false
			for inj: Dictionary in cm_b.injuries:
				if inj.get("ticks_remaining", 0) >= 25:
					severe = true
					break
			if severe:
				cm_a.morale = maxf(0.0, cm_a.morale - 0.5)

		# Shared rest bonus (at planet — docked)
		if cm_a.docked_ticks > 0 and cm_b.docked_ticks > 0:
			cm_a.fatigue = maxf(0.0, cm_a.fatigue - 1.0)  # 25% bonus rest
			cm_b.fatigue = maxf(0.0, cm_b.fatigue - 1.0)

		# Check for breakup conditions
		if rel_val < 40.0 and rel_val >= 30.0:
			# Warning
			events.append("[color=#E67E22]%s and %s have been arguing more than usual. The crew is trying to stay out of it.[/color]" % [cm_a.crew_name, cm_b.crew_name])
			EventBus.romance_warning.emit(cm_a.id, cm_b.id)
		elif rel_val < 30.0:
			# Breakup
			var breakup_events: Array[String] = _process_breakup(cm_a, cm_b, rom, roster)
			events.append_array(breakup_events)

		# Periodic romance event (every 10-20 ticks)
		var romance_age: int = GameManager.day_count - rom.get("formed_day", GameManager.day_count)
		if romance_age > 0 and romance_age % randi_range(10, 20) == 0:
			var avg_morale: float = (cm_a.morale + cm_b.morale) / 2.0
			var rom_text: String = CrewEventTemplates.get_romance_event_text(cm_a.crew_name, cm_b.crew_name, avg_morale)
			events.append("[color=#718096]%s[/color]" % rom_text)

	return events


static func _process_breakup(cm_a: CrewMember, cm_b: CrewMember, rom: Dictionary,
		roster: Array[CrewMember]) -> Array[String]:
	## Handles a romance breakup.
	var events: Array[String] = []
	var rom_duration: int = GameManager.day_count - rom.get("formed_day", GameManager.day_count)
	var morale_hit: float = minf(25.0, 10.0 + float(rom_duration) / 10.0)

	# End the romance
	DatabaseManager.end_romance(rom.get("id", -1), GameManager.day_count)

	# Morale hits
	cm_a.morale = maxf(0.0, cm_a.morale - morale_hit)
	cm_b.morale = maxf(0.0, cm_b.morale - morale_hit)

	# Crew takes sides
	for cm: CrewMember in roster:
		if cm.id == cm_a.id or cm.id == cm_b.id:
			continue
		var rel_to_a: float = DatabaseManager.get_relationship_value(cm.id, cm_a.id)
		var rel_to_b: float = DatabaseManager.get_relationship_value(cm.id, cm_b.id)
		if rel_to_a > rel_to_b:
			DatabaseManager.update_relationship(cm.id, cm_a.id, rel_to_a + 5.0)
			DatabaseManager.update_relationship(cm.id, cm_b.id, rel_to_b - 5.0)
		elif rel_to_b > rel_to_a:
			DatabaseManager.update_relationship(cm.id, cm_b.id, rel_to_b + 5.0)
			DatabaseManager.update_relationship(cm.id, cm_a.id, rel_to_a - 5.0)

	events.append("[color=#C0392B][b]Breakup:[/b] %s[/color]" % CrewEventTemplates._pick(
		CrewEventTemplates.ROMANCE_BREAKUP).replace("{a}", cm_a.crew_name).replace("{b}", cm_b.crew_name))
	EventBus.romance_ended.emit(cm_a.id, cm_b.id, "breakup")

	return events


static func trigger_partner_injury_reaction(injured_cm: CrewMember, roster: Array[CrewMember]) -> Array[String]:
	## Called when a partner is injured. Returns event text.
	var events: Array[String] = []
	var partner_id: int = DatabaseManager.get_partner_id(injured_cm.id)
	if partner_id < 0:
		return events

	var partner: CrewMember = _find_in_roster(roster, partner_id)
	if partner == null:
		return events

	# Immediate morale hit
	partner.morale = maxf(0.0, partner.morale - 8.0)
	DatabaseManager.update_crew_member(partner.id, {"morale": partner.morale})

	var text: String = CrewEventTemplates._pick(CrewEventTemplates.ROMANCE_INJURY_CONCERN).replace(
		"{a}", partner.crew_name).replace("{b}", injured_cm.crew_name)
	events.append("[color=#E67E22]%s[/color]" % text)

	return events


static func trigger_grief_state(surviving_partner_id: int) -> void:
	## Stub for crew death — to be implemented when death system is added.
	## Should: set morale to 10, performance -30% all stats for 30 ticks.
	## After grief resolves: 70% "Resolved" (+5 all) if loyalty > 60, else 70% "Broken" (-5 all).
	pass


static func _find_in_roster(roster: Array[CrewMember], crew_id: int) -> CrewMember:
	for cm: CrewMember in roster:
		if cm.id == crew_id:
			return cm
	return null


# === PHASE 5.2: LOYALTY SYSTEM ===

static func _process_loyalty_tick(roster: Array[CrewMember]) -> Array[String]:
	## Processes loyalty changes per tick: pay split drift, departure arc.
	var events: Array[String] = []
	var tick_counter: int = GameManager.day_count

	# Pay split loyalty drift (every 20 ticks)
	if tick_counter % 20 == 0:
		for cm: CrewMember in roster:
			var old_loyalty: float = cm.loyalty
			if GameManager.pay_split <= 0.4:
				cm.loyalty = minf(100.0, cm.loyalty + 1.0)
			elif GameManager.pay_split >= 0.6:
				cm.loyalty = maxf(0.0, cm.loyalty - 0.5)
			elif GameManager.pay_split == 0.5:
				cm.loyalty = minf(100.0, cm.loyalty + 0.5)

			if cm.loyalty != old_loyalty:
				EventBus.loyalty_changed.emit(cm.id, cm.loyalty, old_loyalty)

	# Departure arc processing
	for cm: CrewMember in roster:
		var old_stage: int = cm.loyalty_departure_stage
		var new_stage: int = 0

		if cm.loyalty < 10.0:
			new_stage = 3
		elif cm.loyalty < 20.0:
			new_stage = 2
		elif cm.loyalty < 25.0:
			new_stage = 1

		if new_stage != old_stage:
			cm.loyalty_departure_stage = new_stage
			DatabaseManager.update_crew_member(cm.id, {"loyalty_departure_stage": new_stage})

			if new_stage == 1 and old_stage == 0:
				events.append("[color=#E67E22]%s[/color]" % CrewEventTemplates._pick(
					CrewEventTemplates.LOYALTY_WITHDRAWAL).replace("{name}", cm.crew_name))
				EventBus.loyalty_stage_changed.emit(cm.id, cm.crew_name, "withdrawal")
			elif new_stage == 2 and old_stage < 2:
				events.append("[color=#C0392B]%s[/color]" % CrewEventTemplates._pick(
					CrewEventTemplates.LOYALTY_VOCAL).replace("{name}", cm.crew_name))
				EventBus.loyalty_stage_changed.emit(cm.id, cm.crew_name, "vocal")

		# Stage 2: negative morale influence
		if cm.loyalty_departure_stage >= 2:
			# Their negativity affects crew with strong relationships
			for other: CrewMember in roster:
				if other.id == cm.id:
					continue
				var rel: float = DatabaseManager.get_relationship_value(cm.id, other.id)
				if rel > 20.0:
					other.morale = maxf(0.0, other.morale - 0.3)

	return events


static func apply_mission_loyalty(outcome_tier: String, roster: Array[CrewMember]) -> Array[String]:
	## Called after mission resolution. Awards loyalty based on outcome.
	var events: Array[String] = []
	var delta: float = 0.0

	match outcome_tier:
		"critical_success":
			delta = 2.0
		"success":
			delta = 1.0
		"marginal_success":
			delta = 0.0
		"failure":
			delta = 0.0
		"critical_failure":
			delta = -1.0

	if delta != 0.0:
		for cm: CrewMember in roster:
			var old_loyalty: float = cm.loyalty
			cm.loyalty = clampf(cm.loyalty + delta, 0.0, 100.0)
			DatabaseManager.update_crew_member(cm.id, {"loyalty": cm.loyalty})
			if cm.loyalty != old_loyalty:
				EventBus.loyalty_changed.emit(cm.id, cm.loyalty, old_loyalty)

	# Near-death survival bonus
	if float(GameManager.hull_current) < 0.25 * float(GameManager.hull_max):
		for cm: CrewMember in roster:
			cm.loyalty = minf(100.0, cm.loyalty + 3.0)
			DatabaseManager.update_crew_member(cm.id, {"loyalty": cm.loyalty})
		events.append("[color=#27AE60]The crew's trust deepens after surviving together.[/color]")

	return events


static func apply_decision_loyalty(roster: Array[CrewMember], decision_type: String) -> Array[String]:
	## Evaluates crew value preferences against a decision type.
	## Returns event text for reactions.
	var events: Array[String] = []

	# Map decision types to value alignments
	var value_map: Dictionary = {
		# Decision effects that align with values
		"crew_conflict_mediate": {"COMPASSIONATE": true, "PRAGMATIC": false},
		"crew_conflict_side_a": {"BOLD": true, "COMPASSIONATE": false},
		"crew_conflict_side_b": {"BOLD": true, "COMPASSIONATE": false},
		"crew_conflict_ignore": {"PRAGMATIC": true, "COMPASSIONATE": false},
		"medical_agree": {"COMPASSIONATE": true, "BOLD": false},
		"medical_push": {"BOLD": true, "COMPASSIONATE": false},
		"homesick_agree": {"COMPASSIONATE": true, "PRAGMATIC": false},
		"homesick_refuse": {"PRAGMATIC": true, "COMPASSIONATE": false},
		"discovery_investigate": {"EXPLORATORY": true, "PRAGMATIC": false},
		"discovery_decline": {"PRAGMATIC": true, "EXPLORATORY": false},
		"pay_5050": {"PRAGMATIC": true},
		"pay_4060": {"COMPASSIONATE": true},
		"pay_hold": {"BOLD": true, "COMPASSIONATE": false},
	}

	var alignments: Dictionary = value_map.get(decision_type, {})
	if alignments.is_empty():
		return events

	for cm: CrewMember in roster:
		if cm.value_preference == "":
			continue

		var is_positive: bool = alignments.get(cm.value_preference, false) == true
		var is_negative: bool = alignments.has(cm.value_preference) and alignments[cm.value_preference] == false
		var delta: float = 0.0

		if is_positive:
			delta = 2.0
		elif is_negative:
			delta = -1.0 if cm.value_preference != "COMPASSIONATE" else -2.0
		else:
			continue

		cm.loyalty = clampf(cm.loyalty + delta, 0.0, 100.0)
		cm.value_evidence_count += 1
		DatabaseManager.update_crew_member(cm.id, {
			"loyalty": cm.loyalty,
			"value_evidence_count": cm.value_evidence_count,
		})

		# Generate reaction text (not every time — 40% chance)
		if randf() < 0.40:
			var reaction: String = CrewEventTemplates.get_loyalty_reaction_text(
				cm.crew_name, cm.value_preference, is_positive)
			if reaction != "":
				events.append("[color=#718096]%s[/color]" % reaction)

	return events


# === PHASE 5.2: HIGH LOYALTY EFFECTS ===

static func get_loyalty_crisis_bonus(cm: CrewMember) -> float:
	## Returns +5% bonus for high-loyalty crew during crisis.
	if cm.loyalty > 75.0:
		if float(GameManager.hull_current) < 0.30 * float(GameManager.hull_max):
			return 0.05
		if GameManager.get_ship_morale() < 30.0:
			return 0.05
	return 0.0


static func get_loyalty_morale_anchor(cm: CrewMember, penalty: float) -> float:
	## Reduces morale penalties by 25% for high-loyalty crew.
	if cm.loyalty > 75.0 and penalty < 0.0:
		return penalty * 0.75
	return penalty


# === PHASE 5.3: INJURY & DISEASE SYSTEM ===

static func inflict_structured_injury(cm: CrewMember, severity_str: String,
		has_medic: bool, medic_stat: float = 50.0) -> Dictionary:
	## Creates a structured injury with location, severity, role-specific impact.
	## Returns {event_text, severity_used, injury_data} or empty dict if medic prevented.
	var severity: String = severity_str

	# Medic severity downgrade
	if has_medic:
		if severity == "SEVERE":
			var downgrade_chance: float = 0.15 + medic_stat / 200.0
			if randf() < downgrade_chance:
				severity = "MODERATE"
		elif severity == "MODERATE":
			var downgrade_chance: float = 0.30 + medic_stat / 200.0
			if randf() < downgrade_chance:
				severity = "MINOR"
		elif severity == "MINOR":
			return {}  # Medic patches it up

	# Pick random location
	var location: String = CrewMember.INJURY_LOCATIONS[randi() % CrewMember.INJURY_LOCATIONS.size()]

	# Determine stat reductions per affected stat
	var affected_stats: Array = CrewMember.INJURY_LOCATION_STATS.get(location, ["stamina"])
	var reduction_base: int
	var recovery_ticks: int
	var can_permanent: bool = false

	match severity:
		"MINOR":
			reduction_base = randi_range(3, 5)
			recovery_ticks = randi_range(5, 8)
		"MODERATE":
			reduction_base = randi_range(6, 10)
			recovery_ticks = randi_range(15, 25)
		"SEVERE":
			reduction_base = randi_range(10, 15)
			recovery_ticks = randi_range(30, 50)
			can_permanent = randf() < 0.20
		_:
			reduction_base = randi_range(3, 5)
			recovery_ticks = randi_range(5, 8)

	# Medic speeds recovery
	if has_medic:
		recovery_ticks = int(float(recovery_ticks) * 0.6)
	else:
		# No medic: SEVERE injuries can develop complications
		if severity == "SEVERE" and randf() < 0.30:
			recovery_ticks = int(float(recovery_ticks) * 1.5)
			reduction_base += 3

	# Vellani fragile bones: longer injury recovery
	if cm.species == CrewMember.Species.VELLANI:
		recovery_ticks = int(float(recovery_ticks) * 1.3)

	# Build stats_affected array with role-specific multiplier
	var primary_stat: String = CrewMember.ROLE_PRIMARY_STAT.get(cm.role, "resourcefulness")
	var stats_affected: Array = []
	for stat: String in affected_stats:
		var reduction: int = reduction_base
		# Role-specific: 1.5x for primary stat when injury location maps to it
		if stat == primary_stat:
			reduction = int(float(reduction) * 1.5)
		stats_affected.append({"stat": stat, "reduction": reduction})

	var desc_key: String = "%s_%s" % [location, severity]
	var description: String = CrewMember.INJURY_DESCRIPTIONS.get(desc_key, "%s %s injury" % [severity.capitalize(), location.to_lower()])

	var injury_data: Dictionary = {
		"location": location,
		"severity": severity,
		"description": description,
		"stats_affected": stats_affected,
		"ticks_remaining": recovery_ticks,
		"can_become_permanent": can_permanent,
		"day_inflicted": GameManager.day_count,
		# Legacy compatibility fields
		"stat_affected": affected_stats[0] if affected_stats.size() > 0 else "stamina",
		"reduction_amount": reduction_base,
	}

	cm.injuries.append(injury_data)
	cm.total_injuries_sustained += 1
	DatabaseManager.update_crew_member(cm.id, {
		"injuries": JSON.stringify(cm.injuries),
		"total_injuries_sustained": cm.total_injuries_sustained,
	})

	# Generate event text
	var event_text: String
	match severity:
		"MINOR":
			event_text = "[color=#E67E22]%s suffered a %s. Minor — they'll be fine.[/color]" % [cm.crew_name, description.to_lower()]
		"MODERATE":
			event_text = "[color=#C0392B]%s has a %s. They'll need time to recover.[/color]" % [cm.crew_name, description.to_lower()]
		"SEVERE":
			event_text = "[color=#C0392B]%s is badly hurt — %s. They need medical attention.[/color]" % [cm.crew_name, description.to_lower()]
		_:
			event_text = "[color=#E67E22]%s was injured.[/color]" % cm.crew_name

	# Medic intervention text
	if has_medic and severity_str != severity:
		var medic_cm: CrewMember = _find_medic_in_roster(GameManager.get_crew_roster())
		if medic_cm != null:
			event_text += "\n" + "[color=#27AE60]%s[/color]" % CrewEventTemplates._pick(
				CrewEventTemplates.MEDIC_INTERVENTION).replace("{medic}", medic_cm.crew_name).replace("{patient}", cm.crew_name)

	return {"event_text": event_text, "severity_used": severity, "injury_data": injury_data}


static func check_permanent_impairment(cm: CrewMember) -> Array[String]:
	## Called when an injury finishes recovering. Checks for permanent impairment.
	var events: Array[String] = []
	var remaining_injuries: Array = []

	for injury: Dictionary in cm.injuries:
		if injury.get("ticks_remaining", 1) <= 0:
			# Check permanent impairment
			if injury.get("can_become_permanent", false):
				var stats_list: Array = injury.get("stats_affected", [])
				for sa: Dictionary in stats_list:
					var permanent_amount: int = int(float(sa.get("reduction", 5)) * randf_range(0.3, 0.5))
					if permanent_amount > 0:
						cm.permanent_impairments.append({
							"stat": sa.get("stat", "stamina"),
							"amount": permanent_amount,
							"source": injury.get("description", "old injury"),
						})
						events.append("[color=#C0392B]%s's injury has healed as much as it's going to. The %s will never be quite the same. But they've adapted — they see the world differently now.[/color]" % [
							cm.crew_name, injury.get("location", "area").to_lower()])
						EventBus.permanent_impairment.emit(cm.id, cm.crew_name, sa.get("stat", ""), permanent_amount)
				DatabaseManager.update_crew_member(cm.id, {"permanent_impairments": JSON.stringify(cm.permanent_impairments)})

				# Trigger Scarred trait if not already acquired
				if not cm.has_trait("scarred"):
					cm.traits.append("scarred")
					DatabaseManager.update_crew_member(cm.id, {"traits": JSON.stringify(cm.traits)})
					var tdef: Dictionary = CrewMember.TRAIT_DEFINITIONS.get("scarred", {})
					events.append("[color=#E6D159][b]Trait Acquired:[/b] Scarred — %s[/color]" % tdef.get("acquisition_text", "").replace("{name}", cm.crew_name))
					EventBus.crew_trait_acquired.emit(cm.id, cm.crew_name, "scarred", "Scarred")
		else:
			remaining_injuries.append(injury)

	# Also tick remaining injuries
	for injury: Dictionary in remaining_injuries:
		injury.ticks_remaining -= 1

	cm.injuries = remaining_injuries
	return events


static func _inflict_disease(cm: CrewMember, disease_name: String, stat: String,
		reduction: int, ticks: int, contagious: bool, all_stats: bool = false, has_medic: bool = false) -> String:
	## Inflicts a disease on a crew member. Returns event text.
	# Medic reduces severity
	if has_medic:
		reduction = maxi(1, reduction - 2)
		ticks = int(float(ticks) * 0.7)

	var disease: Dictionary = {
		"name": disease_name,
		"stat_affected": stat,
		"reduction": reduction,
		"ticks_remaining": ticks,
		"contagious": contagious,
		"all_stats": all_stats,
		"species_specific": cm.get_species_name().to_upper(),
	}
	cm.diseases.append(disease)
	DatabaseManager.update_crew_member(cm.id, {"diseases": JSON.stringify(cm.diseases)})
	EventBus.crew_diseased.emit(cm.id, disease_name)

	return "[color=#E67E22]%s has contracted %s.[/color]" % [cm.crew_name, disease_name]


static func _check_disease_triggers(roster: Array[CrewMember], had_encounter: bool) -> Array[String]:
	## Checks for disease trigger conditions each tick.
	var events: Array[String] = []
	var has_medic: bool = _has_medic_in_roster(roster)
	var planet: Dictionary = GameManager.get_current_planet()

	# Gorvian cold sensitivity: 10% per visit to cold planet
	if planet.get("cold_environment", 0) == 1:
		for cm: CrewMember in roster:
			if cm.species == CrewMember.Species.GORVIAN and not _has_disease(cm, CrewEventTemplates.DISEASE_THERMAL_SHOCK):
				if randf() < 0.10:
					var text: String = _inflict_disease(cm, CrewEventTemplates.DISEASE_THERMAL_SHOCK,
						"stamina", 7, randi_range(15, 20), true, false, has_medic)
					events.append(text)

	# Low food disease: 5% per tick when food < 2 days for 5+ ticks
	var food_rate: float = GameManager.get_food_cost_per_jump()
	var food_days: float = GameManager.food_supply / maxf(food_rate, 1.0) if food_rate > 0 else 999.0
	if food_days < 2.0:
		for cm: CrewMember in roster:
			if cm.low_food_ticks >= 5 and not _has_disease(cm, "Malnutrition Sickness"):
				if randf() < 0.05:
					var text: String = _inflict_disease(cm, "Malnutrition Sickness",
						"", 3, 10, false, true, has_medic)
					events.append(text)

	# Cargo contamination: 3% per jump
	if had_encounter or randf() < 0.03:
		if GameManager.get_total_cargo() > 0 and randf() < 0.03:
			for cm: CrewMember in roster:
				if cm.has_diseases():
					continue
				var species_name: String = cm.get_species_name().to_upper()
				var disease_name: String = CrewEventTemplates.DISEASE_NAMES.get(species_name, "")
				if disease_name == "" or _has_disease(cm, disease_name):
					continue
				match species_name:
					"GORVIAN":
						events.append(_inflict_disease(cm, disease_name, "cognition", 7, 20, true, false, has_medic))
					"VELLANI":
						events.append(_inflict_disease(cm, disease_name, "stamina", 10, 25, true, false, has_medic))
					"KRELLVANI":
						if GameManager.ship_class == "corvette":
							events.append(_inflict_disease(cm, disease_name, "social", 7, 15, true, false, has_medic))
					"HUMAN":
						events.append(_inflict_disease(cm, disease_name, "", 2, 8, true, true, has_medic))
				break  # Only one crew member per tick

	# Disease spread: 15% per tick (5% with medic) among same species
	var spread_chance: float = 0.05 if has_medic else 0.15
	for cm: CrewMember in roster:
		for disease: Dictionary in cm.diseases:
			if not disease.get("contagious", false):
				continue
			var species_target: String = disease.get("species_specific", "")
			for other: CrewMember in roster:
				if other.id == cm.id:
					continue
				if other.get_species_name().to_upper() != species_target:
					continue
				if _has_disease(other, disease.get("name", "")):
					continue
				if other.is_quarantined:
					if randf() < 0.02:  # Reduced spread during quarantine
						var text: String = _inflict_disease(other, disease.get("name", ""),
							disease.get("stat_affected", ""), disease.get("reduction", 3),
							disease.get("ticks_remaining", 10), true, disease.get("all_stats", false), has_medic)
						events.append(text)
						events.append("[color=#E67E22]The %s has spread despite quarantine. %s is showing symptoms now.[/color]" % [disease.get("name", "disease"), other.crew_name])
						EventBus.disease_spread.emit(other.id, disease.get("name", ""))
				elif randf() < spread_chance:
					var text: String = _inflict_disease(other, disease.get("name", ""),
						disease.get("stat_affected", ""), disease.get("reduction", 3),
						disease.get("ticks_remaining", 10), true, disease.get("all_stats", false), has_medic)
					events.append(text)
					events.append("[color=#E67E22]The %s has spread. %s is showing symptoms now.[/color]" % [disease.get("name", "disease"), other.crew_name])
					EventBus.disease_spread.emit(other.id, disease.get("name", ""))

	return events


static func _process_disease_ticks(roster: Array[CrewMember]) -> Array[String]:
	## Ticks disease timers, processes quarantine, checks cures.
	var events: Array[String] = []
	for cm: CrewMember in roster:
		# Tick quarantine
		if cm.is_quarantined:
			cm.quarantine_ticks -= 1
			if cm.quarantine_ticks <= 0:
				cm.is_quarantined = false
				cm.quarantine_ticks = 0
				DatabaseManager.update_crew_member(cm.id, {"is_quarantined": 0, "quarantine_ticks": 0})
				events.append("[color=#27AE60]%s has completed quarantine and returns to duty.[/color]" % cm.crew_name)

		# Tick diseases
		var cured: Array[String] = cm.tick_diseases()
		for cure_text: String in cured:
			events.append("[color=#27AE60]%s[/color]" % cure_text)
		if not cured.is_empty():
			DatabaseManager.update_crew_member(cm.id, {"diseases": JSON.stringify(cm.diseases)})

		# Vellani + Bone Brittling: auto-upgrade injury severity
		if cm.species == CrewMember.Species.VELLANI and _has_disease(cm, "Bone Brittling"):
			# This is handled at injury time via the structured injury system
			pass

	return events


static func _has_disease(cm: CrewMember, disease_name: String) -> bool:
	for d: Dictionary in cm.diseases:
		if d.get("name", "") == disease_name:
			return true
	return false


static func _has_medic_in_roster(roster: Array[CrewMember]) -> bool:
	for cm: CrewMember in roster:
		if cm.role == CrewMember.Role.MEDIC:
			return true
	return false


static func _find_medic_in_roster(roster: Array[CrewMember]) -> CrewMember:
	for cm: CrewMember in roster:
		if cm.role == CrewMember.Role.MEDIC:
			return cm
	return null


static func _scale_ship_culture(cm: CrewMember) -> void:
	## Scales ship culture memory modifiers from 30% to 60% after 20 ticks aboard.
	if cm.id <= 0:
		return
	var ticks_aboard: int = GameManager.day_count - cm.hired_day
	if ticks_aboard < 20:
		return
	# Check for unscaled ship culture memories
	for mem: Dictionary in cm.memories:
		if mem.get("is_ship_culture", 0) == 1 and mem.get("culture_scaled", 0) == 0:
			# Double the modifier (from 30% to 60% of original)
			var new_val: float = mem.get("modifier_value", 0.0) * 2.0
			DatabaseManager.db.query_with_bindings(
				"UPDATE crew_memories SET modifier_value = ?, culture_scaled = 1 WHERE id = ?",
				[new_val, mem.get("id", -1)]
			)
