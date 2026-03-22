class_name MissionConditionTracker
## MissionConditionTracker — Tracks per-mission condition modifiers during transit.
## Conditions accumulate from travel events and modify effective difficulty at resolution.
## In-memory only — no database persistence needed.


# Active condition records: {mission_id: {modifiers: Array[Dictionary], tags: Array[String]}}
# Each modifier: {type: String, value: int, source: String, display: String}
# tags: rolling list of event type strings for the narrative report
static var _active_conditions: Dictionary = {}


# === CORE TRACKING ===

static func initialize_for_travel() -> void:
	## Called when travel begins. Sets up condition tracking for all active missions.
	_active_conditions.clear()
	var missions: Array = GameManager.get_active_missions()
	for mission: Dictionary in missions:
		_active_conditions[mission.id] = {
			"modifiers": [],
			"tags": [],
			"hull_at_start": GameManager.hull_current,
		}


static func clear() -> void:
	## Called after all missions at a destination resolve.
	_active_conditions.clear()


static func apply_modifier(mission_id: int, modifier_type: String, value: int, source: String, display: String) -> void:
	## Applies a single condition modifier to a specific mission.
	if not _active_conditions.has(mission_id):
		return
	_active_conditions[mission_id].modifiers.append({
		"type": modifier_type,
		"value": value,
		"source": source,
		"display": display,
	})


static func add_tag(mission_id: int, tag: String) -> void:
	## Adds an event tag for the narrative report.
	if not _active_conditions.has(mission_id):
		return
	_active_conditions[mission_id].tags.append(tag)


static func get_total_modifier(mission_id: int) -> int:
	## Returns the sum of all condition modifiers for a mission.
	if not _active_conditions.has(mission_id):
		return 0
	var total: int = 0
	for mod: Dictionary in _active_conditions[mission_id].modifiers:
		total += mod.value
	return total


static func get_modifiers(mission_id: int) -> Array:
	## Returns the full modifier list for narrative report generation.
	if not _active_conditions.has(mission_id):
		return []
	return _active_conditions[mission_id].modifiers


static func get_tags(mission_id: int) -> Array:
	if not _active_conditions.has(mission_id):
		return []
	return _active_conditions[mission_id].tags


static func get_hull_at_start(mission_id: int) -> int:
	if not _active_conditions.has(mission_id):
		return GameManager.hull_max
	return _active_conditions[mission_id].get("hull_at_start", GameManager.hull_max)


# === CONDITION PROFILES ===

static func get_condition_profile(mission_type: String) -> Dictionary:
	## Returns the condition sensitivity profile for a mission type.
	## Keys are event categories, values are difficulty modifier amounts.
	match mission_type:
		"cargo_delivery":
			return {
				"combat_incident": 10,         # Cargo at risk during combat
				"hull_damage": 15,             # Hull damage may damage cargo
				"hull_intact": -5,             # Full hull = cargo safe
				"engineer_veteran": -8,        # Good engineer protects cargo
				"no_engineer": 10,             # No engineer = cargo risk
			}
		"passenger_transport":
			return {
				"combat_incident": 15,         # Passengers terrified
				"combat_critical_fail": 20,    # Passengers injured
				"medic_present": -8,           # Medic reassures passengers
				"no_medic": 15,                # No medic = passenger anxiety
				"high_morale": -5,             # Happy crew = happy passengers
				"low_morale": 10,              # Miserable crew scares passengers
				"comms_veteran": -5,           # Good comms officer soothes nerves
			}
		"trade_run":
			return {
				"combat_incident": 8,          # Trade goods at risk
				"hull_damage": 10,             # Damaged goods
				"hull_intact": -5,             # Clean delivery
				"faction_insider": -8,         # Better trade terms
				"faction_outsider": 8,         # Worse trade terms
				"comms_veteran": -5,           # Better negotiations
			}
		"survey":
			return {
				"science_officer_present": -10, # Core role filled
				"no_science_officer": 15,       # Can't survey without science
				"science_veteran": -8,          # Expert surveyor
				"quiet_transit": -5,            # Uninterrupted data collection
				"combat_incident": 5,           # Disrupted instruments
				"navigator_veteran": -5,        # Precise positioning
			}
		"retrieval":
			return {
				"combat_incident": 5,
				"security_present": -8,         # Security handles extraction
				"no_security": 10,
				"engineer_veteran": -5,         # Technical recovery help
				"hull_damage": 8,
			}
		"escort":
			return {
				"combat_incident": -5,          # Combat PROVES escort competence
				"combat_success": -10,          # Winning fights = good escort
				"combat_failure": 15,           # Losing fights = bad escort
				"gunner_veteran": -8,
				"no_gunner": 10,
				"navigator_veteran": -5,
			}
		"patrol":
			return {
				"combat_incident": -8,          # Encounters are the point
				"combat_success": -10,          # Successful patrol
				"quiet_transit": 5,             # Nothing to report = incomplete patrol
				"security_present": -5,
				"gunner_veteran": -5,
			}
		"distress_signal":
			return {
				"medic_present": -10,           # Can treat survivors
				"no_medic": 12,                 # Can't treat survivors
				"engineer_veteran": -5,         # Salvage/repair skills
				"combat_incident": 5,           # Delayed response
				"hull_damage": 8,               # Less capacity to help
			}
		# Faction-exclusive mission types
		"diplomatic_courier":
			return {
				"combat_incident": 15,          # Diplomacy disrupted
				"comms_veteran": -10,
				"faction_insider": -8,
				"hull_intact": -5,
				"high_morale": -5,
			}
		"trade_regulation":
			return {
				"comms_veteran": -8,
				"science_veteran": -5,
				"faction_insider": -8,
				"combat_incident": 5,
			}
		"census_survey":
			return {
				"science_officer_present": -10,
				"navigator_veteran": -5,
				"quiet_transit": -5,
				"combat_incident": 5,
			}
		"technical_recovery":
			return {
				"engineer_veteran": -10,
				"security_present": -5,
				"combat_incident": 5,
				"hull_damage": 8,
			}
		"deep_mining":
			return {
				"engineer_veteran": -8,
				"navigator_veteran": -5,
				"combat_incident": 5,
				"hull_damage": 10,
			}
		"research_transport":
			return {
				"science_veteran": -10,
				"navigator_veteran": -5,
				"hull_intact": -8,
				"combat_incident": 10,
			}
		"cultural_exchange":
			return {
				"comms_veteran": -10,
				"medic_present": -5,
				"high_morale": -8,
				"low_morale": 10,
				"combat_incident": 5,
			}
		"refugee_relocation":
			return {
				"medic_present": -10,
				"navigator_veteran": -5,
				"combat_incident": 15,
				"hull_damage": 10,
				"high_morale": -5,
			}
		"frontier_medical":
			return {
				"medic_present": -15,
				"no_medic": 20,
				"science_veteran": -5,
				"combat_incident": 5,
			}
		"bounty_hunting":
			return {
				"combat_incident": -5,
				"combat_success": -10,
				"security_present": -8,
				"gunner_veteran": -8,
				"quiet_transit": 5,
			}
		"contested_salvage":
			return {
				"engineer_veteran": -8,
				"security_present": -5,
				"combat_incident": 5,
				"hull_damage": 8,
			}
		"security_escort":
			return {
				"gunner_veteran": -10,
				"navigator_veteran": -5,
				"combat_success": -8,
				"combat_failure": 15,
				"hull_damage": 10,
			}
		_:
			return {
				"combat_incident": 5,
				"hull_damage": 8,
			}


# === EVENT APPLICATION ===

static func apply_event_to_all_missions(event_category: String, roster: Array[CrewMember]) -> Array[String]:
	## Called when a transit event occurs. Checks all active missions against their
	## condition profiles and applies relevant modifiers. Returns annotation strings
	## for the travel log.
	var annotations: Array[String] = []

	for mission_id: int in _active_conditions:
		# Look up the mission data to get its type
		var missions: Array = DatabaseManager.get_missions_active(GameManager.save_id)
		var mission: Dictionary = {}
		for m: Dictionary in missions:
			if m.id == mission_id:
				mission = m
				break
		if mission.is_empty():
			continue

		var mission_type: String = mission.get("mission_type", "")
		var profile: Dictionary = get_condition_profile(mission_type)

		if not profile.has(event_category):
			continue

		var modifier_value: int = profile[event_category]
		var display_name: String = TextTemplates.get_mission_type_display(mission_type)

		# Build annotation text
		var annotation: String = _get_annotation_text(event_category, display_name, modifier_value)
		if annotation != "":
			annotations.append(annotation)

		# Apply the modifier
		var source: String = _get_source_text(event_category)
		apply_modifier(mission_id, event_category, modifier_value, source, annotation)
		add_tag(mission_id, event_category)

	return annotations


static func apply_crew_conditions(roster: Array[CrewMember]) -> Array[String]:
	## Called once at travel start. Evaluates crew composition against all active
	## mission profiles and applies one-time crew-based modifiers.
	## Returns annotation strings.
	var annotations: Array[String] = []

	# Determine crew state
	var has_medic: bool = false
	var has_engineer: bool = false
	var has_gunner: bool = false
	var has_navigator: bool = false
	var has_science: bool = false
	var has_security: bool = false
	var has_comms: bool = false

	var medic_veteran: bool = false
	var engineer_veteran: bool = false
	var gunner_veteran: bool = false
	var navigator_veteran: bool = false
	var science_veteran: bool = false
	var security_veteran: bool = false
	var comms_veteran: bool = false

	for cm: CrewMember in roster:
		var is_vet: bool = cm.get_growth_label() in ["Veteran", "Expert"]
		match cm.role:
			CrewMember.Role.MEDIC:
				has_medic = true
				if is_vet: medic_veteran = true
			CrewMember.Role.ENGINEER:
				has_engineer = true
				if is_vet: engineer_veteran = true
			CrewMember.Role.GUNNER:
				has_gunner = true
				if is_vet: gunner_veteran = true
			CrewMember.Role.NAVIGATOR:
				has_navigator = true
				if is_vet: navigator_veteran = true
			CrewMember.Role.SCIENCE_OFFICER:
				has_science = true
				if is_vet: science_veteran = true
			CrewMember.Role.SECURITY_CHIEF:
				has_security = true
				if is_vet: security_veteran = true
			CrewMember.Role.COMMS_OFFICER:
				has_comms = true
				if is_vet: comms_veteran = true

	# Check ship morale
	var ship_morale: float = GameManager.get_ship_morale()
	var high_morale: bool = ship_morale > 65.0
	var low_morale: bool = ship_morale < 35.0

	# Check faction access at destination
	var destination_id: int = GameManager.travel_destination_id
	var faction_insider: bool = false
	var faction_outsider: bool = false
	if destination_id > 0:
		var access: GameManager.AccessLevel = GameManager.get_faction_access_level(destination_id)
		faction_insider = access == GameManager.AccessLevel.INSIDER
		faction_outsider = access == GameManager.AccessLevel.OUTSIDER

	# Map crew state to condition categories
	var crew_conditions: Dictionary = {
		"medic_present": has_medic,
		"no_medic": not has_medic and roster.size() > 0,
		"engineer_veteran": engineer_veteran,
		"no_engineer": not has_engineer and roster.size() > 0,
		"gunner_veteran": gunner_veteran,
		"no_gunner": not has_gunner and roster.size() > 0,
		"navigator_veteran": navigator_veteran,
		"science_officer_present": has_science,
		"no_science_officer": not has_science and roster.size() > 0,
		"science_veteran": science_veteran,
		"security_present": has_security,
		"no_security": not has_security and roster.size() > 0,
		"comms_veteran": comms_veteran,
		"high_morale": high_morale,
		"low_morale": low_morale,
		"faction_insider": faction_insider,
		"faction_outsider": faction_outsider,
	}

	for condition_key: String in crew_conditions:
		if not crew_conditions[condition_key]:
			continue
		var event_annotations: Array[String] = apply_event_to_all_missions(condition_key, roster)
		annotations.append_array(event_annotations)

	return annotations


static func apply_hull_condition() -> Array[String]:
	## Called at resolution time. Checks hull integrity over the journey.
	var annotations: Array[String] = []

	for mission_id: int in _active_conditions:
		var hull_start: int = get_hull_at_start(mission_id)
		var hull_now: int = GameManager.hull_current

		if hull_now >= hull_start:
			# Hull intact — apply hull_intact condition
			var anns: Array[String] = apply_event_to_all_missions("hull_intact", [])
			annotations.append_array(anns)
			break  # Only need to check once since hull is ship-wide
		elif hull_now < hull_start - 10:
			# Significant hull damage
			var anns: Array[String] = apply_event_to_all_missions("hull_damage", [])
			annotations.append_array(anns)
			break

	return annotations


# === ANNOTATION TEXT ===

static func _get_annotation_text(event_category: String, mission_display: String, value: int) -> String:
	## Returns a travel log annotation for this condition modifier.
	match event_category:
		"combat_incident":
			if value > 0:
				return "[color=#718096][%s] Combat during transit complicates the mission.[/color]" % mission_display
			else:
				return "[color=#718096][%s] Combat encounter logged — mission validated.[/color]" % mission_display
		"combat_critical_fail":
			return "[color=#E67E22][%s] Critical failure during transit — serious complications.[/color]" % mission_display
		"combat_success":
			return "[color=#27AE60][%s] Successful combat bolsters the mission.[/color]" % mission_display
		"combat_failure":
			return "[color=#C0392B][%s] Combat failure undermines mission credibility.[/color]" % mission_display
		"hull_damage":
			return "[color=#E67E22][%s] Hull damage during transit affects the mission.[/color]" % mission_display
		"hull_intact":
			return "[color=#27AE60][%s] Clean transit — hull integrity maintained.[/color]" % mission_display
		"medic_present":
			return "[color=#27AE60][%s] Medic aboard improves mission prospects.[/color]" % mission_display
		"no_medic":
			return "[color=#E67E22][%s] No medic aboard — a gap in the crew.[/color]" % mission_display
		"engineer_veteran":
			return "[color=#27AE60][%s] Veteran engineer contributing to mission success.[/color]" % mission_display
		"no_engineer":
			return "[color=#E67E22][%s] No engineer aboard — technical vulnerability.[/color]" % mission_display
		"gunner_veteran":
			return "[color=#27AE60][%s] Veteran gunner strengthens the mission.[/color]" % mission_display
		"no_gunner":
			return "[color=#E67E22][%s] No gunner aboard — combat vulnerability.[/color]" % mission_display
		"navigator_veteran":
			return "[color=#27AE60][%s] Veteran navigator optimizing the route.[/color]" % mission_display
		"science_officer_present":
			return "[color=#27AE60][%s] Science officer enhancing mission capability.[/color]" % mission_display
		"no_science_officer":
			return "[color=#E67E22][%s] No science officer — analytical gap.[/color]" % mission_display
		"science_veteran":
			return "[color=#27AE60][%s] Veteran science officer driving mission success.[/color]" % mission_display
		"security_present":
			return "[color=#27AE60][%s] Security chief bolstering mission safety.[/color]" % mission_display
		"no_security":
			return "[color=#E67E22][%s] No security chief — safety concern.[/color]" % mission_display
		"comms_veteran":
			return "[color=#27AE60][%s] Veteran comms officer smoothing the way.[/color]" % mission_display
		"high_morale":
			return "[color=#27AE60][%s] High crew morale boosting mission performance.[/color]" % mission_display
		"low_morale":
			return "[color=#E67E22][%s] Low crew morale dragging on the mission.[/color]" % mission_display
		"faction_insider":
			return "[color=#27AE60][%s] Faction insider status easing the mission.[/color]" % mission_display
		"faction_outsider":
			return "[color=#E67E22][%s] Outsider status complicating the mission.[/color]" % mission_display
		"quiet_transit":
			return ""  # Accumulates silently

	return ""


static func _get_source_text(event_category: String) -> String:
	## Returns a short source label for the narrative report.
	match event_category:
		"combat_incident": return "Combat during transit"
		"combat_critical_fail": return "Critical combat failure"
		"combat_success": return "Successful combat"
		"combat_failure": return "Failed combat"
		"hull_damage": return "Hull damage sustained"
		"hull_intact": return "Hull integrity maintained"
		"medic_present": return "Medic aboard"
		"no_medic": return "No medic"
		"engineer_veteran": return "Veteran engineer"
		"no_engineer": return "No engineer"
		"gunner_veteran": return "Veteran gunner"
		"no_gunner": return "No gunner"
		"navigator_veteran": return "Veteran navigator"
		"science_officer_present": return "Science officer aboard"
		"no_science_officer": return "No science officer"
		"science_veteran": return "Veteran science officer"
		"security_present": return "Security chief aboard"
		"no_security": return "No security chief"
		"comms_veteran": return "Veteran comms officer"
		"high_morale": return "High crew morale"
		"low_morale": return "Low crew morale"
		"faction_insider": return "Faction insider access"
		"faction_outsider": return "Outsider status"
		"quiet_transit": return "Uneventful transit"
	return event_category
