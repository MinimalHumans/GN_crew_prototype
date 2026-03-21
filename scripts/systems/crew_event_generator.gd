class_name CrewEventGenerator
## CrewEventGenerator — Generates narrative events from crew state.
## Runs each simulation tick, evaluates conditions, produces three tiers of events:
## Background (80%), Nudge (10%), Decision (10%).

# Track previous morale/fatigue thresholds to detect crossings
static var _prev_morale: Dictionary = {}  # {crew_id: float}
static var _prev_fatigue: Dictionary = {}  # {crew_id: float}


# === MAIN TICK ===

static func generate_events(roster: Array[CrewMember]) -> Dictionary:
	## Returns {background: Array[String], nudges: Array[String], decision: Dictionary or empty}.
	var background: Array[String] = []
	var nudges: Array[String] = []
	var decision: Dictionary = {}

	if roster.is_empty():
		return {"background": background, "nudges": nudges, "decision": decision}

	# --- Background events (capped at 2 per tick) ---
	var bg_events: Array[String] = _generate_background_events(roster)
	# Group events with their follow-up lines (↳ prefix) so shuffle doesn't separate them
	var event_groups: Array[Array] = []
	var current_group: Array[String] = []
	for line: String in bg_events:
		if line.find("↳") != -1 and not current_group.is_empty():
			current_group.append(line)
		else:
			if not current_group.is_empty():
				event_groups.append(current_group)
			current_group = [line]
	if not current_group.is_empty():
		event_groups.append(current_group)
	# Shuffle and cap groups
	event_groups.shuffle()
	var groups_added: int = 0
	for group: Array in event_groups:
		if groups_added >= 2:
			break
		for line: String in group:
			background.append(line)
		groups_added += 1

	# --- Nudge events (with cooldown) ---
	nudges = _generate_nudge_events(roster)

	# --- Decision events (spacing: 15 ticks minimum) ---
	if GameManager.ticks_since_last_decision >= 15:
		decision = _check_decision_events(roster)

	# Update tracking for next tick
	for cm: CrewMember in roster:
		_prev_morale[cm.id] = cm.morale
		_prev_fatigue[cm.id] = cm.fatigue

	return {"background": background, "nudges": nudges, "decision": decision}


# === BACKGROUND EVENTS (80%) ===

static func _generate_background_events(roster: Array[CrewMember]) -> Array[String]:
	var events: Array[String] = []

	for cm: CrewMember in roster:
		var old_morale: float = _prev_morale.get(cm.id, cm.morale)
		var old_fatigue: float = _prev_fatigue.get(cm.id, cm.fatigue)

		# Morale threshold crossings
		if cm.morale >= 70.0 and old_morale < 70.0:
			events.append("[color=#27AE60]%s[/color]" % CrewEventTemplates.get_morale_high_text(cm.crew_name))
			events.append("[color=#555B66]  ↳ High morale is improving performance.[/color]")
		elif cm.morale < 35.0 and old_morale >= 35.0:
			events.append("[color=#E67E22]%s[/color]" % CrewEventTemplates.get_morale_low_text(cm.crew_name))
			events.append("[color=#555B66]  ↳ Low morale is hurting performance.[/color]")

		# Fatigue threshold crossings
		if cm.fatigue > 75.0 and old_fatigue <= 75.0:
			events.append("[color=#E67E22]%s[/color]" % CrewEventTemplates.get_fatigue_high_text(cm.crew_name))
			events.append("[color=#555B66]  ↳ High fatigue is reducing effectiveness.[/color]")
			events.append(CrewEventTemplates.get_service_suggestion("fatigue_high"))

		# Purpose events
		if cm.ticks_since_role_used >= 20 and cm.ticks_since_role_used % 10 == 0:
			events.append(CrewEventTemplates.format_observation(CrewEventTemplates.get_purpose_bored_text(cm.crew_name)))
			events.append(CrewEventTemplates.get_service_suggestion("purpose_bored"))

	# Food low event
	var food_days: float = _get_food_days_remaining()
	if food_days <= 1.0 and food_days >= 0.0:
		events.append(CrewEventTemplates.format_negative(CrewEventTemplates.get_food_low_text()))

	# Random slice-of-life (8% chance per tick — increased in Phase 6 with expanded text pool)
	if roster.size() >= 2 and randf() < 0.08:
		var idx_a: int = randi() % roster.size()
		var idx_b: int = (idx_a + 1 + randi() % (roster.size() - 1)) % roster.size()
		var text: String = CrewEventTemplates.get_slice_of_life(
			roster[idx_a].crew_name, roster[idx_b].crew_name)
		events.append(CrewEventTemplates.format_observation(text))

	# Phase 4.2: Memory-referenced dialogue (30% chance per crew member with memories)
	for cm: CrewMember in roster:
		if cm.memories.is_empty():
			cm.load_memories()
		if not cm.memories.is_empty() and randf() < 0.20:
			# Pick a random memory and generate dialogue
			var mem: Dictionary = cm.memories[randi() % cm.memories.size()]
			var tag: String = mem.get("emotional_tag", "")
			if tag != "":
				var dialogue: String = CrewEventTemplates.get_memory_dialogue(cm.crew_name, tag)
				events.append(CrewEventTemplates.format_observation(dialogue))

	return events


# === NUDGE EVENTS (10%) ===

static func _generate_nudge_events(roster: Array[CrewMember]) -> Array[String]:
	var nudges: Array[String] = []

	# Ship-wide morale warning
	if _can_nudge("morale"):
		var ship_morale: float = GameManager.get_ship_morale()
		if ship_morale < 40.0:
			nudges.append(CrewEventTemplates.format_nudge(CrewEventTemplates.get_nudge_text("morale")))
			nudges.append(CrewEventTemplates.get_service_suggestion("morale_low"))
			GameManager.nudge_cooldowns["morale"] = 10

	# Relationship warning
	if _can_nudge("relationship") and roster.size() >= 2:
		for i: int in range(roster.size()):
			for j: int in range(i + 1, roster.size()):
				var val: float = DatabaseManager.get_relationship_value(roster[i].id, roster[j].id)
				if val < -40.0:
					nudges.append(CrewEventTemplates.format_nudge(CrewEventTemplates.get_nudge_text(
						"relationship", roster[i].crew_name, roster[j].crew_name)))
					nudges.append(CrewEventTemplates.get_service_suggestion("crew_conflict"))
					GameManager.nudge_cooldowns["relationship"] = 10
					break
			if nudges.size() > 0:
				break

	# Food warning
	if _can_nudge("food"):
		if _get_food_days_remaining() < 3.0:
			nudges.append(CrewEventTemplates.format_nudge(CrewEventTemplates.get_nudge_text("food")))
			nudges.append(CrewEventTemplates.get_service_suggestion("food_low"))
			GameManager.nudge_cooldowns["food"] = 10

	# Fatigue warning
	if _can_nudge("fatigue"):
		var avg_fatigue: float = 0.0
		for cm: CrewMember in roster:
			avg_fatigue += cm.fatigue
		avg_fatigue /= float(roster.size())
		if avg_fatigue > 60.0:
			nudges.append(CrewEventTemplates.format_nudge(CrewEventTemplates.get_nudge_text("fatigue")))
			nudges.append(CrewEventTemplates.get_service_suggestion("fatigue_high"))
			GameManager.nudge_cooldowns["fatigue"] = 10

	# Pay warning
	if _can_nudge("pay"):
		if GameManager.pay_split >= 0.6:
			var avg_morale: float = 0.0
			for cm: CrewMember in roster:
				avg_morale += cm.morale
			avg_morale /= float(roster.size())
			if avg_morale < 50.0:
				nudges.append(CrewEventTemplates.format_nudge(CrewEventTemplates.get_nudge_text("pay")))
				GameManager.nudge_cooldowns["pay"] = 10

	return nudges


# === DECISION EVENTS (10%) ===

static func _check_decision_events(roster: Array[CrewMember]) -> Dictionary:
	## Checks conditions for all decision events. Returns the first one that fires, or empty.

	# 1. Crew Conflict — pair relationship < -50
	for i: int in range(roster.size()):
		for j: int in range(i + 1, roster.size()):
			var val: float = DatabaseManager.get_relationship_value(roster[i].id, roster[j].id)
			if val < -50.0:
				return _build_crew_conflict(roster[i], roster[j])

	# 2. Medical Request — crew fatigue > 85
	for cm: CrewMember in roster:
		if cm.fatigue > 85.0:
			return _build_medical_request(cm)

	# 3. Pay Dispute — 60/40 split and any crew morale < 30
	if GameManager.pay_split >= 0.6:
		for cm: CrewMember in roster:
			if cm.morale < 30.0:
				return _build_pay_dispute(cm)

	# 4. Homesick — crew aboard 30+ days, hasn't visited faction zone
	for cm: CrewMember in roster:
		var days_aboard: int = GameManager.day_count - cm.hired_day
		if days_aboard >= 30:
			var faction: String = cm.get_species_name()
			var planet: Dictionary = GameManager.get_current_planet()
			if planet.get("faction", "") != faction:
				return _build_homesick(cm)

	# 5. Shared Discovery — science officer with high morale and purpose
	for cm: CrewMember in roster:
		if cm.role == CrewMember.Role.SCIENCE_OFFICER and cm.morale > 70.0 and cm.ticks_since_role_used < 5:
			if randf() < 0.3:  # Not every tick
				return _build_shared_discovery(cm)

	# 6. Stowaway — 2% per jump, max once
	if not GameManager.stowaway_found and randf() < 0.02:
		return _build_stowaway()

	# 7. Phase 5.2: Loyalty ultimatum — departure stage 3
	for cm: CrewMember in roster:
		if cm.loyalty_departure_stage >= 3 and cm.loyalty > 0.0:
			return _build_loyalty_ultimatum(cm)

	# 8. Phase 5.3: Quarantine decision — 2+ same-species infected
	var species_sick_count: Dictionary = {}
	for cm: CrewMember in roster:
		if cm.has_diseases():
			var species_key: String = cm.get_species_name()
			species_sick_count[species_key] = species_sick_count.get(species_key, 0) + 1
	for species_key: String in species_sick_count:
		if species_sick_count[species_key] >= 2:
			return _build_quarantine_decision(roster, species_key)

	return {}


# === DECISION EVENT BUILDERS ===

static func _build_crew_conflict(cm_a: CrewMember, cm_b: CrewMember) -> Dictionary:
	var can_mediate: bool = GameManager.social > 50
	var options: Array[Dictionary] = [
		{
			"label": "Side with %s" % cm_a.crew_name,
			"hint": "This will upset %s." % cm_b.crew_name,
			"effects": {"type": "crew_conflict_side_a", "crew_a": cm_a.id, "crew_b": cm_b.id},
		},
		{
			"label": "Side with %s" % cm_b.crew_name,
			"hint": "This will upset %s." % cm_a.crew_name,
			"effects": {"type": "crew_conflict_side_b", "crew_a": cm_a.id, "crew_b": cm_b.id},
		},
	]
	if can_mediate:
		options.append({
			"label": "Mediate — demand they work it out",
			"hint": "Requires social skill. Neither will be happy, but it may help long-term.",
			"effects": {"type": "crew_conflict_mediate", "crew_a": cm_a.id, "crew_b": cm_b.id},
		})
	options.append({
		"label": "Ignore it",
		"hint": "Things may get worse.",
		"effects": {"type": "crew_conflict_ignore", "crew_a": cm_a.id, "crew_b": cm_b.id},
	})

	return {
		"id": "crew_conflict",
		"title": "Crew Conflict",
		"description": "%s and %s are at each other's throats. %s corners you in the corridor: 'Captain, either they go or I will.'" % [
			cm_a.crew_name, cm_b.crew_name, cm_a.crew_name],
		"options": options,
	}


static func _build_medical_request(cm: CrewMember) -> Dictionary:
	return {
		"id": "medical_request",
		"title": "Medical Request",
		"description": "%s approaches you. 'Captain, I can't keep this up. I need real rest — a few quiet jumps, or I'm going to collapse.'" % cm.crew_name,
		"options": [
			{
				"label": "Agree to easy missions",
				"hint": "Their recovery will improve, but avoid combat.",
				"effects": {"type": "medical_agree", "crew_id": cm.id},
			},
			{
				"label": "Push through",
				"hint": "'We don't have that luxury.' This will hurt morale.",
				"effects": {"type": "medical_push", "crew_id": cm.id},
			},
			{
				"label": "Promise to dock soon",
				"hint": "You'll need to dock within 3 jumps to keep this promise.",
				"effects": {"type": "medical_promise", "crew_id": cm.id},
			},
		],
	}


static func _build_pay_dispute(cm: CrewMember) -> Dictionary:
	return {
		"id": "pay_dispute",
		"title": "Pay Dispute",
		"description": "%s speaks for the group. 'We need to talk about the split, Captain. We're doing the work. We deserve a fair share.'" % cm.crew_name,
		"options": [
			{
				"label": "Improve to 50/50",
				"hint": "Fair split. The crew will be pleased.",
				"effects": {"type": "pay_5050"},
			},
			{
				"label": "Improve to 40/60 (crew-favoring)",
				"hint": "Generous. Big morale boost but less income for you.",
				"effects": {"type": "pay_4060"},
			},
			{
				"label": "Hold firm",
				"hint": "'The split stays.' The crew won't like this.",
				"effects": {"type": "pay_hold", "speaker_id": cm.id},
			},
			{
				"label": "Offer a one-time bonus (200 cr)",
				"hint": "Buys time but doesn't fix the root cause.",
				"effects": {"type": "pay_bonus"},
			},
		],
	}


static func _build_homesick(cm: CrewMember) -> Dictionary:
	var homeworld: String = _get_faction_homeworld(cm.get_species_name())
	return {
		"id": "homesick",
		"title": "Homesick",
		"description": "%s has been staring out the viewport toward %s space. 'Captain, I haven't been home in a while. Could we swing through %s on our next run?'" % [
			cm.crew_name, cm.get_species_name(), homeworld],
		"options": [
			{
				"label": "Agree to visit",
				"hint": "Visit their homeworld within 10 jumps for a big morale boost.",
				"effects": {"type": "homesick_agree", "crew_id": cm.id, "homeworld": homeworld},
			},
			{
				"label": "Maybe soon",
				"hint": "No commitment. A small disappointment.",
				"effects": {"type": "homesick_maybe", "crew_id": cm.id},
			},
			{
				"label": "We go where the work is",
				"hint": "This will hurt their morale.",
				"effects": {"type": "homesick_refuse", "crew_id": cm.id},
			},
		],
	}


static func _build_shared_discovery(cm: CrewMember) -> Dictionary:
	return {
		"id": "shared_discovery",
		"title": "Anomalous Readings",
		"description": "Your science officer %s rushes to the bridge with a finding: anomalous readings from a nearby sector. 'Captain, this could be significant. But investigating means a detour — two extra jumps off our route.'" % cm.crew_name,
		"options": [
			{
				"label": "Investigate",
				"hint": "Costs extra fuel and time, but could yield XP and discoveries.",
				"effects": {"type": "discovery_investigate", "crew_id": cm.id},
			},
			{
				"label": "Stay on course",
				"hint": "'Log it for later.' The science officer won't be happy.",
				"effects": {"type": "discovery_decline", "crew_id": cm.id},
			},
			{
				"label": "Let the crew vote",
				"hint": "The crew appreciates being heard, regardless of outcome.",
				"effects": {"type": "discovery_vote", "crew_id": cm.id},
			},
		],
	}


static func _build_stowaway() -> Dictionary:
	var species_options: Array[String] = ["Human", "Gorvian", "Vellani", "Krellvani"]
	var stow_species: String = species_options[randi() % species_options.size()]
	var role_options: Array[String] = ["Engineer", "Medic", "Navigator", "Generalist"]
	var stow_role: String = role_options[randi() % role_options.size()]

	return {
		"id": "stowaway",
		"title": "Stowaway Found",
		"description": "Your security chief finds someone hiding in the cargo bay. A young %s %s, clearly desperate. 'Please, Captain. I had to get off that station. I'll work. I'll do anything.'" % [stow_species, stow_role],
		"options": [
			{
				"label": "Take them on",
				"hint": "Free crew member. High loyalty, but low starting morale.",
				"effects": {"type": "stowaway_accept", "species": stow_species, "role": stow_role},
			},
			{
				"label": "Turn them in at next port",
				"hint": "Small credit reward. No crew gain.",
				"effects": {"type": "stowaway_turn_in"},
			},
			{
				"label": "Give them supplies and let them go",
				"hint": "Costs some food. The crew will respect the kindness.",
				"effects": {"type": "stowaway_release"},
			},
		],
	}


static func _build_loyalty_ultimatum(cm: CrewMember) -> Dictionary:
	var value_hint: String = ""
	if cm.value_evidence_count >= 3:
		value_hint = " They value %s." % CrewMember.VALUE_PREFERENCE_DISPLAY.get(cm.value_preference, "fairness")
	return {
		"id": "loyalty_ultimatum",
		"title": "Ultimatum",
		"description": "%s corners you in the corridor. 'Captain, I've had enough. Something needs to change, or I'm leaving at the next port.'%s" % [cm.crew_name, value_hint],
		"options": [
			{
				"label": "Improve pay split",
				"hint": "Adjust to 50/50 or better. Shows you're willing to compromise.",
				"effects": {"type": "ultimatum_pay", "crew_id": cm.id},
			},
			{
				"label": "Promise safer routes",
				"hint": "'I'll keep us out of trouble.' They'll hold you to it.",
				"effects": {"type": "ultimatum_safety", "crew_id": cm.id},
			},
			{
				"label": "Appeal to loyalty",
				"hint": "'We've been through too much together to give up now.'",
				"effects": {"type": "ultimatum_appeal", "crew_id": cm.id},
			},
			{
				"label": "Let them go",
				"hint": "'If that's how you feel, I won't stop you.'",
				"effects": {"type": "ultimatum_accept", "crew_id": cm.id},
			},
		],
	}


static func _build_quarantine_decision(roster: Array[CrewMember], species_key: String) -> Dictionary:
	var sick_names: Array[String] = []
	for cm: CrewMember in roster:
		if cm.has_diseases() and cm.get_species_name() == species_key:
			sick_names.append(cm.crew_name)
	var names_str: String = ", ".join(sick_names)
	return {
		"id": "quarantine_decision",
		"title": "Disease Outbreak",
		"description": "Multiple %s crew are showing symptoms — %s. The disease could spread to the rest of the crew." % [species_key, names_str],
		"options": [
			{
				"label": "Quarantine the sick",
				"hint": "Isolates infected crew. Reduces spread but hurts their morale.",
				"effects": {"type": "quarantine_enforce", "species": species_key},
			},
			{
				"label": "Keep them on duty",
				"hint": "'We need every hand.' Higher spread risk but no morale penalty.",
				"effects": {"type": "quarantine_refuse", "species": species_key},
			},
			{
				"label": "Dock at nearest hospital",
				"hint": "Promise to seek medical help. Costs time and credits.",
				"effects": {"type": "quarantine_hospital", "species": species_key},
			},
		],
	}


# === DECISION RESOLUTION ===

static func resolve_decision(event_id: String, choice: int, event_data: Dictionary) -> String:
	## Applies mechanical consequences of a decision choice. Returns result text.
	GameManager.ticks_since_last_decision = 0

	# Phase 5.4: Crew-generated mission decisions
	if event_data.get("type", "") == "crew_generated_mission":
		var action: String = event_data.options[choice].get("action", "")
		var cgm_events: Array[String] = CrewSimulation.resolve_crew_gen_mission_decision(
			event_id, choice, event_data)
		for ev: String in cgm_events:
			EventBus.message_logged.emit(ev, Color.WHITE)
		if action == "accept":
			return "You set course for their personal mission."
		return "You decline. There are more pressing matters."

	# Phase 5.5: Retirement decisions
	if event_data.get("type", "") == "retirement":
		var ret_events: Array[String] = CrewSimulation.resolve_retirement_decision(
			event_data, choice)
		for ev: String in ret_events:
			EventBus.message_logged.emit(ev, Color.WHITE)
		return "The crew processes the news."

	# Phase 5.5: Death acknowledgement (single-option modal)
	if event_data.get("type", "") == "crew_death":
		return "The crew falls silent."

	var effects: Dictionary = event_data.options[choice].effects

	var result_text: String = _resolve_decision_effects(effects)

	# Phase 5.2: Apply loyalty effects for all decision types
	var loyalty_roster: Array[CrewMember] = GameManager.get_crew_roster()
	var loyalty_events: Array[String] = CrewSimulation.apply_decision_loyalty(loyalty_roster, effects.type)
	for le: String in loyalty_events:
		EventBus.message_logged.emit(le, Color.WHITE)

	return result_text


static func _resolve_decision_effects(effects: Dictionary) -> String:
	## Internal: resolves decision effects. Returns result text.
	match effects.type:
		# --- Crew Conflict ---
		"crew_conflict_side_a":
			_adjust_morale(effects.crew_a, 10.0)
			_adjust_morale(effects.crew_b, -15.0)
			_adjust_relationship(effects.crew_a, effects.crew_b, -20.0)
			return "You sided with one crew member. The other seethes quietly."
		"crew_conflict_side_b":
			_adjust_morale(effects.crew_a, -15.0)
			_adjust_morale(effects.crew_b, 10.0)
			_adjust_relationship(effects.crew_a, effects.crew_b, -20.0)
			return "You sided with one crew member. The other seethes quietly."
		"crew_conflict_mediate":
			_adjust_morale(effects.crew_a, -5.0)
			_adjust_morale(effects.crew_b, -5.0)
			_adjust_relationship(effects.crew_a, effects.crew_b, 10.0)
			# Increment conflicts_mediated on all high-Social crew
			var roster: Array[CrewMember] = GameManager.get_crew_roster()
			for cm: CrewMember in roster:
				if cm.social > 60:
					cm.conflicts_mediated += 1
					DatabaseManager.update_crew_member(cm.id, {"conflicts_mediated": cm.conflicts_mediated})
			return "Neither is happy, but they agree to try. Your authority held."
		"crew_conflict_ignore":
			_adjust_morale(effects.crew_a, -8.0)
			_adjust_morale(effects.crew_b, -8.0)
			return "You walk away. The tension lingers. This isn't over."

		# --- Medical Request ---
		"medical_agree":
			# Double fatigue recovery for 5 ticks
			var crew: Dictionary = DatabaseManager.get_crew_member(effects.crew_id)
			var new_fatigue: float = maxf(0.0, crew.get("fatigue", 50.0) - 10.0)
			DatabaseManager.update_crew_member(effects.crew_id, {"fatigue": new_fatigue})
			return "You agree to take it easy. They look relieved."
		"medical_push":
			_adjust_morale(effects.crew_id, -10.0)
			return "'We don't have that luxury.' They nod, but the light goes out of their eyes."
		"medical_promise":
			GameManager.pending_promises.append({
				"type": "dock_soon",
				"ticks_remaining": 3,
				"crew_id": effects.crew_id,
			})
			return "'We'll stop at the next port.' They hold you to it."

		# --- Pay Dispute ---
		"pay_5050":
			GameManager.set_pay_split(0.5)
			_adjust_all_morale(8.0)
			return "You adjust the split to 50/50. The crew nods approvingly."
		"pay_4060":
			GameManager.set_pay_split(0.4)
			_adjust_all_morale(15.0)
			return "A generous split. The crew looks genuinely grateful."
		"pay_hold":
			_adjust_all_morale(-10.0)
			_adjust_loyalty(effects.speaker_id, -5.0)
			return "'The split stays.' Cold silence. The crew disperses."
		"pay_bonus":
			if GameManager.credits >= 200:
				GameManager.spend_credits(200)
				_adjust_all_morale(5.0)
				return "You hand out bonuses. It helps, for now."
			else:
				return "You don't have enough credits for the bonus."

		# --- Homesick ---
		"homesick_agree":
			GameManager.pending_promises.append({
				"type": "visit_homeworld",
				"ticks_remaining": 10,
				"crew_id": effects.crew_id,
				"homeworld": effects.homeworld,
			})
			return "Their face lights up. 'Thank you, Captain. It means a lot.'"
		"homesick_maybe":
			_adjust_morale(effects.crew_id, -3.0)
			return "They nod, but you can see the disappointment."
		"homesick_refuse":
			_adjust_morale(effects.crew_id, -8.0)
			return "'We go where the work is.' They turn away without a word."

		# --- Shared Discovery ---
		"discovery_investigate":
			GameManager.add_xp(30)
			_adjust_morale(effects.crew_id, 10.0)
			_adjust_all_morale(3.0)
			return "The detour pays off! Fascinating readings, valuable data, and the crew enjoyed the adventure."
		"discovery_decline":
			_adjust_morale(effects.crew_id, -5.0)
			DatabaseManager.update_crew_member(effects.crew_id, {
				"ticks_since_role_used": 10,
			})
			return "'Log it for later.' The science officer's shoulders slump."
		"discovery_vote":
			var ship_morale: float = GameManager.get_ship_morale()
			_adjust_all_morale(3.0)  # Crew appreciates being asked
			if ship_morale > 50.0:
				GameManager.add_xp(30)
				_adjust_morale(effects.crew_id, 8.0)
				return "The crew votes to investigate. The detour yields results, and everyone feels heard."
			else:
				_adjust_morale(effects.crew_id, -3.0)
				return "The crew votes to stay on course. Practical, if disappointing. At least they were asked."

		# --- Stowaway ---
		"stowaway_accept":
			GameManager.stowaway_found = true
			var stowaway_id: int = _create_stowaway(effects.species, effects.role)
			if stowaway_id >= 0:
				return "You take the stowaway aboard. They look at you with desperate gratitude."
			return "There's no room for another crew member right now. You give them what supplies you can."
		"stowaway_turn_in":
			GameManager.stowaway_found = true
			GameManager.add_credits(50)
			return "You'll turn them in at the next port. A small bounty, but credits are credits."
		"stowaway_release":
			GameManager.stowaway_found = true
			GameManager.food_supply = maxf(0.0, GameManager.food_supply - 3.0)
			EventBus.food_changed.emit(GameManager.food_supply)
			_adjust_all_morale(3.0)
			return "You give them food and wish them luck. The crew watches them go with quiet respect."

		# --- Phase 5.2: Loyalty Ultimatum ---
		"ultimatum_pay":
			GameManager.set_pay_split(minf(0.5, GameManager.pay_split))
			_adjust_loyalty(effects.crew_id, 10.0)
			_adjust_morale(effects.crew_id, 8.0)
			return "You adjust the pay split. They nod slowly. 'That's a start, Captain.'"
		"ultimatum_safety":
			GameManager.pending_promises.append({
				"type": "safe_routes",
				"ticks_remaining": 10,
				"crew_id": effects.crew_id,
			})
			_adjust_loyalty(effects.crew_id, 5.0)
			return "'I'll keep us out of the worst of it.' They look skeptical, but willing to wait."
		"ultimatum_appeal":
			# Works better with high captain Social
			if GameManager.social > 55:
				_adjust_loyalty(effects.crew_id, 8.0)
				_adjust_morale(effects.crew_id, 5.0)
				return "Your words land. 'You're right, Captain. We've been through worse.' They stay."
			else:
				_adjust_loyalty(effects.crew_id, 2.0)
				return "They don't look convinced, but they're not leaving yet. Barely."
		"ultimatum_accept":
			# Let them go at next port
			var crew_data: Dictionary = DatabaseManager.get_crew_member(effects.crew_id)
			var crew_name: String = crew_data.get("name", "Unknown")
			DatabaseManager.update_crew_member(effects.crew_id, {"loyalty": 0.0, "loyalty_departure_stage": 3})
			return "'If that's how you feel.' %s will leave at the next port." % crew_name

		# --- Phase 5.3: Quarantine Decision ---
		"quarantine_enforce":
			var roster: Array[CrewMember] = GameManager.get_crew_roster()
			for cm: CrewMember in roster:
				if cm.has_diseases() and cm.get_species_name() == effects.species:
					cm.is_quarantined = true
					cm.quarantine_ticks = 10
					DatabaseManager.update_crew_member(cm.id, {"is_quarantined": 1, "quarantine_ticks": 10})
					_adjust_morale(cm.id, -8.0)
			EventBus.quarantine_started.emit()
			return "Quarantine enforced. The sick crew are isolated. They understand, but it's hard."
		"quarantine_refuse":
			return "You keep everyone on duty. The crew trades worried glances, but nobody argues."
		"quarantine_hospital":
			GameManager.pending_promises.append({
				"type": "dock_hospital",
				"ticks_remaining": 5,
				"crew_id": -1,
			})
			_adjust_all_morale(3.0)
			return "'We'll find a hospital.' The crew looks relieved. You need to dock at a hospital planet soon."

	return "Decision resolved."


# === EFFECT HELPERS ===

static func _adjust_morale(crew_id: int, delta: float) -> void:
	var data: Dictionary = DatabaseManager.get_crew_member(crew_id)
	if data.is_empty():
		return
	var new_morale: float = clampf(data.get("morale", 50.0) + delta, 0.0, 100.0)
	DatabaseManager.update_crew_member(crew_id, {"morale": new_morale})


static func _adjust_all_morale(delta: float) -> void:
	var crew: Array = DatabaseManager.get_active_crew(GameManager.save_id)
	for row: Dictionary in crew:
		var new_morale: float = clampf(row.get("morale", 50.0) + delta, 0.0, 100.0)
		DatabaseManager.update_crew_member(row.id, {"morale": new_morale})


static func _adjust_loyalty(crew_id: int, delta: float) -> void:
	var data: Dictionary = DatabaseManager.get_crew_member(crew_id)
	if data.is_empty():
		return
	var new_loyalty: float = clampf(data.get("loyalty", 50.0) + delta, 0.0, 100.0)
	DatabaseManager.update_crew_member(crew_id, {"loyalty": new_loyalty})


static func _adjust_relationship(crew_a_id: int, crew_b_id: int, delta: float) -> void:
	var current: float = DatabaseManager.get_relationship_value(crew_a_id, crew_b_id)
	var new_val: float = clampf(current + delta, -100.0, 100.0)
	DatabaseManager.update_relationship(crew_a_id, crew_b_id, new_val)


static func _create_stowaway(species_str: String, role_str: String) -> int:
	## Creates a stowaway crew member with moderate stats and high loyalty.
	if GameManager.get_available_crew_slots() < 1.0:
		return -1
	var cm: CrewMember = CrewMember.new()
	cm.crew_name = TextTemplates.get_crew_name(species_str.to_upper())
	cm.species = CrewMember._parse_species(species_str.to_upper())
	cm.role = CrewMember._parse_role(role_str.to_upper())
	cm.stamina = randi_range(35, 50)
	cm.cognition = randi_range(35, 50)
	cm.reflexes = randi_range(35, 50)
	cm.social = randi_range(35, 50)
	cm.resourcefulness = randi_range(35, 50)
	cm.morale = 35.0  # Low starting morale
	cm.loyalty = 80.0  # High loyalty — grateful
	cm.personality = "Desperate, grateful."
	cm.hired_day = GameManager.day_count

	var data: Dictionary = cm.to_dict()
	var crew_id: int = DatabaseManager.insert_crew_member(GameManager.save_id, data)

	# Create relationships with existing crew
	var existing: Array = DatabaseManager.get_active_crew(GameManager.save_id)
	for row: Dictionary in existing:
		if row.id == crew_id:
			continue
		var existing_species: CrewMember.Species = CrewMember._parse_species(row.species)
		var friction: int = CrewMember.get_friction_between(cm.species, existing_species)
		DatabaseManager.insert_crew_relationship(crew_id, row.id, float(friction))

	EventBus.crew_recruited.emit(crew_id, cm.crew_name)
	EventBus.crew_changed.emit()
	return crew_id


static func _get_faction_homeworld(species_name: String) -> String:
	match species_name:
		"Human":
			return "Haven"
		"Gorvian":
			return "Korrath Prime"
		"Vellani":
			return "Lirien"
		"Krellvani":
			return "Ironmaw"
		_:
			return "Haven"


static func _can_nudge(nudge_type: String) -> bool:
	return not GameManager.nudge_cooldowns.has(nudge_type)


static func _get_food_days_remaining() -> float:
	var rate: float = GameManager.get_food_cost_per_jump()
	if rate <= 0.0:
		return 999.0
	return GameManager.food_supply / rate
