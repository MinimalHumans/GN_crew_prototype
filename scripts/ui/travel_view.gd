extends Control
## Travel View — Processes a journey jump by jump.
## Each jump: deduct fuel/food, advance day, encounter check (with crew approach options),
## crew simulation tick, crew events. After final jump, arrive at destination.

@onready var title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var jump_label: Label = $MarginContainer/VBox/JumpLabel
@onready var travel_log: RichTextLabel = $MarginContainer/VBox/TravelLog
@onready var status_label: Label = $MarginContainer/VBox/StatusBar/StatusLabel
@onready var continue_button: Button = $MarginContainer/VBox/ContinueButton

var _current_jump: int = 0
var _total_jumps: int = 0
var _destination_id: int = -1
var _destination_name: String = ""
var _origin_name: String = ""
var _danger_level: String = "low"
var _journey_complete: bool = false

# Decision event state
var _decision_pending: bool = false
var _pending_decision: Dictionary = {}
var _decision_container: VBoxContainer = null

# Encounter state
var _encounter_pending: bool = false
var _current_encounter: Dictionary = {}
var _encounter_difficulty: int = 0
var _encounter_container: VBoxContainer = null

# Rescue recruitment state
var _rescue_pending: bool = false
var _rescue_survivor: CrewMember = null


# === INITIALIZATION ===

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)

	_destination_id = GameManager.travel_destination_id
	_total_jumps = GameManager.travel_jumps
	_danger_level = GameManager.travel_route.get("danger_level", "low")

	var dest_planet: Dictionary = DatabaseManager.get_planet(_destination_id)
	_destination_name = dest_planet.get("name", "Unknown")
	var origin_planet: Dictionary = GameManager.get_current_planet()
	_origin_name = origin_planet.get("name", "Unknown")

	title_label.text = "%s  →  %s" % [_origin_name, _destination_name]
	jump_label.text = "Preparing for departure..."
	_update_status()

	_append_log("[color=#4A90D9]Departing %s. Course set for %s — %d jumps.[/color]" % [
		_origin_name, _destination_name, _total_jumps
	])

	var danger_color: String = GameManager.get_danger_color(_danger_level)
	var danger_display: String = GameManager.get_danger_display(_danger_level)
	_append_log("[color=%s]Route danger: %s[/color]" % [danger_color, danger_display])

	# Gorvian fuel efficiency notice (one-time per session)
	var gorvian_reduction: float = GameManager.get_gorvian_fuel_reduction()
	if gorvian_reduction > 0.0 and not GameManager.gorvian_fuel_logged:
		_append_log("[color=#4CAF50]Gorvian crew reducing fuel consumption by %.0f%%.[/color]" % (gorvian_reduction * 100.0))
		GameManager.gorvian_fuel_logged = true

	_append_log("")

	# Initialize mission condition tracking
	MissionConditionTracker.initialize_for_travel()

	# Apply one-time crew composition conditions
	if GameManager.get_active_missions().size() > 0:
		var roster: Array[CrewMember] = GameManager.get_crew_roster()
		var crew_annotations: Array[String] = MissionConditionTracker.apply_crew_conditions(roster)
		if not crew_annotations.is_empty():
			_append_log("")
			for annotation: String in crew_annotations:
				if annotation != "":
					_append_log(annotation)

	continue_button.text = "Begin Jump 1"
	continue_button.grab_focus()


# === JUMP PROCESSING ===

func _on_continue_pressed() -> void:
	if _journey_complete:
		_arrive()
		return

	_current_jump += 1

	# On first jump, clear the origin planet's mission board and recruitment cache
	if _current_jump == 1:
		DatabaseManager.clear_missions_available(GameManager.current_planet_id)
		GameManager.cached_recruitment_candidates = []
		GameManager.cached_recruitment_planet_id = -1

	# Process the jump (fuel, food, day)
	var result: Dictionary = GameManager.process_jump()
	EventBus.travel_jump_completed.emit(_current_jump, _total_jumps)

	# Update display
	jump_label.text = "Jump %d of %d" % [_current_jump, _total_jumps]
	_update_status()

	# Travel atmosphere text with crew flavor
	var travel_text: String = TextTemplates.get_travel_text()
	var crew_count: int = GameManager.get_crew_count()
	var crew_flavor: String = ""
	if crew_count > 0:
		crew_flavor = " " + CrewEventTemplates.get_travel_crew_text(GameManager.get_ship_morale())
	_append_log("[color=#F7FAFC]Jump %d of %d. %s%s[/color]" % [
		_current_jump, _total_jumps, travel_text, crew_flavor])

	# Fuel/food/day reports
	_append_log("[color=#718096]  Fuel: -%.0f (%.0f remaining)[/color]" % [
		result.fuel_used, GameManager.fuel_current])
	if result.food_used > 0:
		_append_log("[color=#718096]  Food: -%.1f (%.1f remaining)[/color]" % [
			result.food_used, GameManager.food_supply])
	_append_log("[color=#718096]  Day %d[/color]" % GameManager.day_count)

	# Check for fuel exhaustion after jump
	if GameManager.fuel_current <= 0.0:
		_handle_stranded()
		return

	# Random encounter check
	var encounter_chance: float = GameManager.get_encounter_chance(_danger_level)
	if randf() < encounter_chance:
		var enc: Dictionary = ChallengeResolver.pick_encounter(_danger_level)
		_encounter_difficulty = ChallengeResolver.get_encounter_difficulty(_danger_level)
		_show_encounter(enc)
		return  # Wait for player to resolve encounter

	# No encounter — finish jump normally
	_finish_jump(false)


func _finish_jump(had_encounter: bool, was_combat: bool = false, roles_tested: Array = []) -> void:
	## Completes jump processing after encounter (if any) resolves.
	var crew_count: int = GameManager.get_crew_count()

	if not had_encounter:
		GameManager.record_event("quiet")
		# Apply quiet transit condition to missions that care about it (accumulates silently)
		MissionConditionTracker.apply_event_to_all_missions("quiet_transit", [])

	# --- Crew simulation tick ---
	if crew_count > 0:
		var sim_result: Dictionary = CrewSimulation.tick_jump(
			had_encounter, was_combat, _encounter_difficulty, roles_tested)

		for event_text: String in sim_result.get("events", []):
			_append_log(event_text)

		# Generate crew events
		var roster: Array[CrewMember] = GameManager.get_crew_roster()
		var event_result: Dictionary = CrewEventGenerator.generate_events(roster)

		for bg: String in event_result.get("background", []):
			_append_log(bg)
		for nudge: String in event_result.get("nudges", []):
			_append_log(nudge)

		var decision: Dictionary = event_result.get("decision", {})
		if not decision.is_empty():
			_append_log("")
			_show_decision_event(decision)
			return  # Wait for decision resolution before finishing

	_append_log("")
	_check_journey_complete()


func _check_journey_complete() -> void:
	if _current_jump >= _total_jumps:
		_journey_complete = true
		_append_log("[color=#4A90D9]%s is in sight. Preparing to dock.[/color]" % _destination_name)
		continue_button.text = "Arrive at %s" % _destination_name
	else:
		continue_button.text = "Continue to Jump %d" % (_current_jump + 1)


func _arrive() -> void:
	GameManager.arrive_at_planet(_destination_id)


# === ENCOUNTER SYSTEM ===

func _show_encounter(encounter: Dictionary) -> void:
	_current_encounter = encounter
	_encounter_pending = true
	continue_button.disabled = true

	_append_log("")
	_append_log("[color=#E67E22]═══════ %s ═══════[/color]" % encounter.title.to_upper())
	var descriptions: Array = encounter.get("descriptions", ["An encounter!"])
	_append_log("[color=#F7FAFC]%s[/color]" % descriptions[randi() % descriptions.size()])
	_append_log("")

	# Build approach options with crew info and odds
	_encounter_container = VBoxContainer.new()
	_encounter_container.add_theme_constant_override("separation", 4)

	var approaches: Array = encounter.get("approaches", [])
	var roster: Array[CrewMember] = GameManager.get_crew_roster()

	for i: int in range(approaches.size()):
		var approach: Dictionary = approaches[i]
		var label_text: String = approach.label
		var info_text: String = ""

		if approach.primary == "" and approach.get("auto_result", "") == "ignore":
			# No-check option (like Ignore distress signal)
			info_text = "No challenge"
		elif approach.primary != "":
			# Get crew-aware preview
			var preview: Dictionary = ChallengeResolver.get_approach_info(
				roster, approach.primary, approach.get("secondary", ""), _encounter_difficulty)
			var p_name: String = preview.primary.display_name
			var s_name: String = preview.get("secondary", {}).get("display_name", "")
			var rating: String = preview.rating_word
			var rating_color: String = preview.rating_color

			if s_name != "":
				info_text = "%s (primary), %s (support) — [color=%s]%s[/color]" % [
					p_name, s_name, rating_color, rating]
			else:
				info_text = "%s — [color=%s]%s[/color]" % [p_name, rating_color, rating]

		# Create button
		var btn: Button = Button.new()
		btn.text = "%d. %s" % [i + 1, label_text]
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_approach_selected.bind(i))
		_encounter_container.add_child(btn)

		# Info label below button
		if info_text != "":
			var info_lbl: RichTextLabel = RichTextLabel.new()
			info_lbl.bbcode_enabled = true
			info_lbl.text = "   %s" % info_text
			info_lbl.fit_content = true
			info_lbl.scroll_active = false
			info_lbl.custom_minimum_size = Vector2(0, 27)
			info_lbl.add_theme_font_size_override("normal_font_size", 15)
			_encounter_container.add_child(info_lbl)

	# Insert before continue button
	continue_button.get_parent().add_child(_encounter_container)
	continue_button.get_parent().move_child(_encounter_container, continue_button.get_index())
	GameManager.record_event("combat")


func _on_approach_selected(approach_idx: int) -> void:
	# Clean up UI
	if _encounter_container != null:
		_encounter_container.queue_free()
		_encounter_container = null

	var approach: Dictionary = _current_encounter.approaches[approach_idx]
	var was_combat: bool = approach.get("is_combat", false)
	var roles_tested: Array = []

	# Handle special cases
	if approach.get("auto_result", "") == "ignore":
		_handle_ignore_distress()
		return

	if approach.primary == "":
		# No check needed — auto-resolve
		_append_log("[color=#F7FAFC]  → Resolved without incident.[/color]")
		_append_log("[color=#E67E22]═══════════════════════════════[/color]")
		_encounter_pending = false
		continue_button.disabled = false
		_finish_jump(false)
		return

	# Resolve the challenge
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	var result: Dictionary = ChallengeResolver.resolve_crew_challenge(
		roster, approach.primary, approach.get("secondary", ""), _encounter_difficulty)

	# Build roles tested array
	if approach.primary != "":
		roles_tested.append(approach.primary.to_upper().replace(" ", "_"))
	if approach.get("secondary", "") != "":
		roles_tested.append(approach.secondary.to_upper().replace(" ", "_"))

	# Log result
	var outcome_text: String = ChallengeResolver.get_encounter_outcome_text(
		_current_encounter.id, result.tier)
	var tier_color: String = _get_tier_color(result.tier)
	_append_log("[color=%s]  → %s (%s)[/color]" % [tier_color, outcome_text, result.tier.replace("_", " ").capitalize()])

	# Apply crew consequences
	var consequence_events: Array[String] = ChallengeResolver.apply_crew_consequences(result, roster)
	for event_text: String in consequence_events:
		_append_log(event_text)

	# Apply mission condition modifiers based on combat outcome
	var combat_category: String
	match result.tier:
		"critical_success", "success":
			combat_category = "combat_success"
		"critical_failure":
			combat_category = "combat_critical_fail"
		"failure":
			combat_category = "combat_failure"
		_:
			combat_category = "combat_incident"

	# Always apply the general combat_incident category
	var incident_annotations: Array[String] = MissionConditionTracker.apply_event_to_all_missions("combat_incident", roster)
	for ann: String in incident_annotations:
		if ann != "":
			_append_log(ann)

	# Apply the specific outcome category if different from general
	if combat_category != "combat_incident":
		var outcome_annotations: Array[String] = MissionConditionTracker.apply_event_to_all_missions(combat_category, roster)
		for ann: String in outcome_annotations:
			if ann != "":
				_append_log(ann)

	# Hull damage on failure
	if result.tier in ["failure", "critical_failure"]:
		var hull_dmg: int = randi_range(5, 15) if result.tier == "failure" else randi_range(10, 25)
		var hull_result: Dictionary = GameManager.apply_hull_damage(hull_dmg)
		_append_log("[color=#C0392B]Hull damage: -%d HP[/color]" % hull_dmg)

		if hull_result.destroyed:
			_handle_ship_destroyed()
			return

		if GameManager.hull_current < GameManager.hull_max / 2:
			_append_log(CrewEventTemplates.get_service_suggestion("hull_damaged"))

		# Apply hull damage condition to missions
		var hull_annotations: Array[String] = MissionConditionTracker.apply_event_to_all_missions("hull_damage", roster)
		for ann: String in hull_annotations:
			if ann != "":
				_append_log(ann)

	_append_log("[color=#E67E22]═══════════════════════════════[/color]")

	# Check for distress signal rescue on success
	if _current_encounter.id == "distress_signal" and result.tier in ["critical_success", "success"]:
		_show_rescue_offer()
		return

	# Process relationship effects from encounter
	if roster.size() >= 2:
		CrewSimulation.process_mission_result(result.tier, roles_tested)

	_encounter_pending = false
	continue_button.disabled = false
	_finish_jump(true, was_combat, roles_tested)


func _handle_ignore_distress() -> void:
	_append_log("[color=#718096]  → You note the coordinates and move on.[/color]")

	# Social crew feel guilt
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	for cm: CrewMember in roster:
		if cm.social > 60:
			cm.morale = clampf(cm.morale - 3.0, 0.0, 100.0)
			DatabaseManager.update_crew_member(cm.id, {"morale": cm.morale})
			_append_log("[color=#718096]%s stares at the fading beacon as you jump away.[/color]" % cm.crew_name)
			break  # Only log once

	# Ignoring a distress signal when you have a distress_signal mission type active
	var active: Array = GameManager.get_active_missions()
	for m: Dictionary in active:
		if m.get("mission_type", "") == "distress_signal":
			MissionConditionTracker.apply_modifier(m.id, "ignored_distress", 30,
				"Ignored a distress signal", "[color=#C0392B][Distress Signal] You ignored a distress call while carrying a rescue mission.[/color]")
			_append_log("[color=#C0392B][Distress Signal] You ignored a distress call while carrying a rescue mission.[/color]")

	_append_log("[color=#E67E22]═══════════════════════════════[/color]")
	_encounter_pending = false
	continue_button.disabled = false
	_finish_jump(false)


# === DISTRESS SIGNAL RESCUE ===

func _show_rescue_offer() -> void:
	_rescue_pending = true
	_rescue_survivor = ChallengeResolver.generate_rescue_survivor()
	_encounter_pending = false

	_append_log("")
	_append_log("[color=#27AE60]You pull a %s %s from the wreckage. They're shaken but alive.[/color]" % [
		_rescue_survivor.get_species_name(), _rescue_survivor.get_role_name()])
	_append_log("[color=#718096]  %s — Stats: Sta %d / Cog %d / Ref %d / Soc %d / Res %d[/color]" % [
		_rescue_survivor.crew_name, _rescue_survivor.stamina, _rescue_survivor.cognition,
		_rescue_survivor.reflexes, _rescue_survivor.social, _rescue_survivor.resourcefulness])
	_append_log("[color=#718096]  Loyalty: %.0f (grateful)  |  Morale: %.0f (traumatized)[/color]" % [
		_rescue_survivor.loyalty, _rescue_survivor.morale])
	_append_log("[color=#718096]  \"%s\"[/color]" % _rescue_survivor.personality)

	# Show accept/decline buttons
	_encounter_container = VBoxContainer.new()
	_encounter_container.add_theme_constant_override("separation", 4)

	var accept_btn: Button = Button.new()
	accept_btn.text = "1. Take them aboard (free, no recruitment fee)"
	accept_btn.custom_minimum_size = Vector2(0, 48)
	accept_btn.add_theme_font_size_override("font_size", 18)
	accept_btn.pressed.connect(_on_rescue_accept)
	_encounter_container.add_child(accept_btn)

	var decline_btn: Button = Button.new()
	decline_btn.text = "2. Patch them up and point them to the nearest station"
	decline_btn.custom_minimum_size = Vector2(0, 48)
	decline_btn.add_theme_font_size_override("font_size", 18)
	decline_btn.pressed.connect(_on_rescue_decline)
	_encounter_container.add_child(decline_btn)

	continue_button.get_parent().add_child(_encounter_container)
	continue_button.get_parent().move_child(_encounter_container, continue_button.get_index())


func _on_rescue_accept() -> void:
	if _encounter_container != null:
		_encounter_container.queue_free()
		_encounter_container = null

	var crew_id: int = ChallengeResolver.recruit_rescue_survivor(_rescue_survivor)
	if crew_id >= 0:
		_append_log("[color=#27AE60]%s joins your crew. They look at you with grateful eyes.[/color]" % _rescue_survivor.crew_name)
	else:
		_append_log("[color=#E67E22]No room aboard. You give them supplies and wish them well.[/color]")
		# Still get morale bonus for kindness
		CrewEventGenerator._adjust_all_morale(3.0)

	_rescue_pending = false
	_rescue_survivor = null
	continue_button.disabled = false
	_finish_jump(true)


func _on_rescue_decline() -> void:
	if _encounter_container != null:
		_encounter_container.queue_free()
		_encounter_container = null

	_append_log("[color=#718096]You patch them up, give them supplies, and point them to the nearest station.[/color]")
	# Ship-wide morale +3 for the kindness
	CrewEventGenerator._adjust_all_morale(3.0)
	_append_log("[color=#27AE60]The crew respects the decision. Morale +3.[/color]")

	_rescue_pending = false
	_rescue_survivor = null
	continue_button.disabled = false
	_finish_jump(true)


# === STRANDED (FUEL EXHAUSTION) ===

func _handle_stranded() -> void:
	_journey_complete = false
	continue_button.disabled = true

	_append_log("")
	_append_log("[color=#C0392B]═══════ STRANDED ═══════[/color]")
	_append_log("[color=#C0392B]Fuel tanks are empty. The ship drifts in open space.[/color]")
	_append_log("")

	# Build emergency options
	_encounter_container = VBoxContainer.new()
	_encounter_container.add_theme_constant_override("separation", 4)

	# Option 1: Jettison cargo for emergency fuel (if player has cargo)
	var total_cargo: int = GameManager.get_total_cargo()
	if total_cargo > 0:
		var cargo_to_dump: int = mini(total_cargo, 5)
		var sell_btn: Button = Button.new()
		sell_btn.text = "1. Jettison cargo for emergency fuel (%d units cargo → %.0f fuel)" % [
			cargo_to_dump, cargo_to_dump * 2.0]
		sell_btn.custom_minimum_size = Vector2(0, 48)
		sell_btn.add_theme_font_size_override("font_size", 18)
		sell_btn.pressed.connect(_on_stranded_jettison)
		_encounter_container.add_child(sell_btn)

	# Option 2: Distress call (costs time — advances day by 3, small credits cost)
	var distress_btn: Button = Button.new()
	var distress_cost: int = 100
	distress_btn.text = "2. Send distress call (costs %d credits, 3 days)" % distress_cost
	distress_btn.custom_minimum_size = Vector2(0, 48)
	distress_btn.add_theme_font_size_override("font_size", 18)
	distress_btn.disabled = GameManager.credits < distress_cost
	distress_btn.pressed.connect(_on_stranded_distress.bind(distress_cost))
	_encounter_container.add_child(distress_btn)

	# Option 3: Limp to nearest planet (abort travel, return to origin)
	var limp_btn: Button = Button.new()
	limp_btn.text = "3. Limp back to %s on reserve power (abort journey)" % _origin_name
	limp_btn.custom_minimum_size = Vector2(0, 48)
	limp_btn.add_theme_font_size_override("font_size", 18)
	limp_btn.pressed.connect(_on_stranded_limp)
	_encounter_container.add_child(limp_btn)

	continue_button.get_parent().add_child(_encounter_container)
	continue_button.get_parent().move_child(_encounter_container, continue_button.get_index())


func _on_stranded_jettison() -> void:
	if _encounter_container != null:
		_encounter_container.queue_free()
		_encounter_container = null

	# Sell up to 5 units of the most plentiful cargo for 2 fuel each
	var cargo: Array = DatabaseManager.get_cargo(GameManager.save_id)
	var jettisoned: int = 0
	for c: Dictionary in cargo:
		if jettisoned >= 5:
			break
		var available: int = c.get("quantity", 0)
		if available <= 0:
			continue
		var to_dump: int = mini(available, 5 - jettisoned)
		DatabaseManager.update_cargo(GameManager.save_id, c.commodity_id, available - to_dump)
		jettisoned += to_dump

	var fuel_gained: float = float(jettisoned) * 2.0
	GameManager.fuel_current = minf(GameManager.fuel_max, GameManager.fuel_current + fuel_gained)
	DatabaseManager.update_ship(GameManager.current_ship_id, {"fuel_current": GameManager.fuel_current})
	EventBus.fuel_changed.emit(GameManager.fuel_current, GameManager.fuel_max)

	_append_log("[color=#E67E22]Jettisoned %d units of cargo. Recovered %.0f fuel.[/color]" % [jettisoned, fuel_gained])
	_update_status()
	continue_button.disabled = false
	_check_journey_complete()


func _on_stranded_distress(cost: int) -> void:
	if _encounter_container != null:
		_encounter_container.queue_free()
		_encounter_container = null

	GameManager.spend_credits(cost)
	# Advance 3 days
	for i: int in range(3):
		GameManager.day_count += 1
		EventBus.day_advanced.emit(GameManager.day_count)

	# Rescue ship refuels enough for remaining jumps + 2 buffer
	var jumps_remaining: int = _total_jumps - _current_jump
	var fuel_needed: float = float(jumps_remaining + 2) * GameManager.get_fuel_cost_per_jump()
	GameManager.fuel_current = minf(GameManager.fuel_max, GameManager.fuel_current + fuel_needed)
	DatabaseManager.update_ship(GameManager.current_ship_id, {"fuel_current": GameManager.fuel_current})
	EventBus.fuel_changed.emit(GameManager.fuel_current, GameManager.fuel_max)

	_append_log("[color=#E67E22]A passing freighter answers your distress call. They charge %d credits and it costs you 3 days, but the tanks are topped off enough to continue.[/color]" % cost)

	# Crew morale hit from the indignity
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	for cm: CrewMember in roster:
		cm.morale = maxf(0.0, cm.morale - 5.0)
		DatabaseManager.update_crew_member(cm.id, {"morale": cm.morale})
	if not roster.is_empty():
		_append_log("[color=#718096]The crew is shaken. Morale drops across the board.[/color]")

	_update_status()
	continue_button.disabled = false
	_check_journey_complete()


func _on_stranded_limp() -> void:
	if _encounter_container != null:
		_encounter_container.queue_free()
		_encounter_container = null

	_append_log("[color=#E67E22]You fire the reserve thrusters and limp back to %s. The journey is aborted.[/color]" % _origin_name)

	# Give just enough fuel to not be stuck at zero
	GameManager.fuel_current = 1.0
	DatabaseManager.update_ship(GameManager.current_ship_id, {"fuel_current": GameManager.fuel_current})
	EventBus.fuel_changed.emit(GameManager.fuel_current, GameManager.fuel_max)

	# Advance 2 days for the limp
	for i: int in range(2):
		GameManager.day_count += 1
		EventBus.day_advanced.emit(GameManager.day_count)

	# Return to origin planet
	GameManager.arrive_at_planet(GameManager.current_planet_id)


# === DECISION EVENT DISPLAY ===

func _show_decision_event(event_data: Dictionary) -> void:
	_pending_decision = event_data
	_decision_pending = true
	continue_button.disabled = true

	_append_log("[color=#E6D159]══════════════════════════════[/color]")
	_append_log("[color=#E6D159]  %s[/color]" % event_data.title)
	_append_log("[color=#F7FAFC]  %s[/color]" % event_data.description)
	_append_log("")

	_decision_container = VBoxContainer.new()
	_decision_container.add_theme_constant_override("separation", 4)

	var options: Array = event_data.options
	for i: int in range(options.size()):
		var option: Dictionary = options[i]
		var btn: Button = Button.new()
		btn.text = "%d. %s" % [i + 1, option.label]
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_decision_choice.bind(i))
		_decision_container.add_child(btn)

		if option.has("hint"):
			var hint: Label = Label.new()
			hint.text = "   %s" % option.hint
			hint.add_theme_font_size_override("font_size", 15)
			hint.add_theme_color_override("font_color", Color("#718096"))
			_decision_container.add_child(hint)

	continue_button.get_parent().add_child(_decision_container)
	continue_button.get_parent().move_child(_decision_container, continue_button.get_index())


func _on_decision_choice(choice: int) -> void:
	if _decision_container != null:
		_decision_container.queue_free()
		_decision_container = null

	var result_text: String = CrewEventGenerator.resolve_decision(
		_pending_decision.id, choice, _pending_decision)

	_append_log("[color=#F7FAFC]  → %s[/color]" % result_text)
	_append_log("[color=#E6D159]══════════════════════════════[/color]")

	EventBus.decision_event_resolved.emit(_pending_decision.id, choice)
	_decision_pending = false
	_pending_decision = {}
	continue_button.disabled = false

	_append_log("")
	_check_journey_complete()


# === DISPLAY ===

func _update_status() -> void:
	var crew_count: int = GameManager.get_crew_count()
	var hardcore_tag: String = " [HARDCORE]" if GameManager.hardcore_hull else ""
	if crew_count > 0:
		var morale_word: String = GameManager.get_ship_morale_word()
		var morale_color: String = GameManager.get_ship_morale_color()
		status_label.text = "Fuel: %.0f/%.0f  |  Food: %s  |  Hull: %d/%d  |  Day %d  |  Morale: %s%s" % [
			GameManager.fuel_current, GameManager.fuel_max,
			GameManager.get_food_days_remaining(),
			GameManager.hull_current, GameManager.hull_max,
			GameManager.day_count,
			morale_word,
			hardcore_tag,
		]
	else:
		status_label.text = "Fuel: %.0f/%.0f  |  Food: %s  |  Hull: %d/%d  |  Day %d%s" % [
			GameManager.fuel_current, GameManager.fuel_max,
			GameManager.get_food_days_remaining(),
			GameManager.hull_current, GameManager.hull_max,
			GameManager.day_count,
			hardcore_tag,
		]


func _get_tier_color(tier: String) -> String:
	match tier:
		"critical_success":
			return "#27AE60"
		"success":
			return "#27AE60"
		"marginal_success":
			return "#E67E22"
		"failure":
			return "#C0392B"
		"critical_failure":
			return "#C0392B"
		_:
			return "#718096"


func _append_log(text: String) -> void:
	travel_log.append_text(text + "\n")


# === SHIP DESTRUCTION (Phase 9) ===

func _handle_ship_destroyed() -> void:
	## Handles ship reaching 0 hull in hardcore mode.
	_journey_complete = false
	continue_button.disabled = true

	# Clean up any pending encounter/decision UI
	if _encounter_container != null:
		_encounter_container.queue_free()
		_encounter_container = null
	if _decision_container != null:
		_decision_container.queue_free()
		_decision_container = null

	_append_log("")
	_append_log("[color=#C0392B]═══════════════════════════════════════[/color]")
	_append_log("[color=#C0392B][b]SHIP DESTROYED[/b][/color]")
	_append_log("")
	_append_log("[color=#C0392B]The hull gives way. Warning klaxons scream through corridors[/color]")
	_append_log("[color=#C0392B]that are already filling with smoke. Emergency systems fail[/color]")
	_append_log("[color=#C0392B]one by one. The last thing you see is the stars through the[/color]")
	_append_log("[color=#C0392B]breach — cold, indifferent, beautiful.[/color]")
	_append_log("")

	# Crew status
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if not roster.is_empty():
		_append_log("[color=#718096]Escape pods launched. The crew may survive — but this ship will not.[/color]")
		var crew_names: Array[String] = []
		for cm: CrewMember in roster:
			crew_names.append(cm.crew_name)
		_append_log("[color=#718096]Crew lost: %s[/color]" % ", ".join(crew_names))

	_append_log("")
	_append_log("[color=#C0392B]Captain %s's journey ends here.[/color]" % GameManager.captain_name)
	_append_log("[color=#C0392B]═══════════════════════════════════════[/color]")

	# Show game over options
	_show_game_over_options()


func _show_game_over_options() -> void:
	var options_container: VBoxContainer = VBoxContainer.new()
	options_container.add_theme_constant_override("separation", 12)

	# Statistics summary
	var stats_lbl: Label = Label.new()
	stats_lbl.text = "Days survived: %d  |  Credits earned: %d  |  Level: %d" % [
		GameManager.day_count, GameManager.total_credits_earned, GameManager.captain_level]
	stats_lbl.add_theme_font_size_override("font_size", 21)
	stats_lbl.add_theme_color_override("font_color", Color("#718096"))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_container.add_child(stats_lbl)

	# Legacy summary
	var legacies: Array = DatabaseManager.get_crew_legacies(GameManager.save_id)
	if not legacies.is_empty():
		var legacy_lbl: Label = Label.new()
		legacy_lbl.text = "Crew remembered: %d" % legacies.size()
		legacy_lbl.add_theme_font_size_override("font_size", 18)
		legacy_lbl.add_theme_color_override("font_color", Color("#718096"))
		legacy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		options_container.add_child(legacy_lbl)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	options_container.add_child(spacer)

	# New game button
	var new_game_btn: Button = Button.new()
	new_game_btn.text = "Start New Game"
	new_game_btn.custom_minimum_size = Vector2(0, 66)
	new_game_btn.add_theme_font_size_override("font_size", 27)
	new_game_btn.pressed.connect(func() -> void:
		GameManager.is_game_active = false
		get_tree().change_scene_to_file("res://scenes/ui/new_game.tscn")
	)
	options_container.add_child(new_game_btn)

	# Main menu button
	var menu_btn: Button = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(0, 54)
	menu_btn.add_theme_font_size_override("font_size", 21)
	menu_btn.add_theme_color_override("font_color", Color("#718096"))
	menu_btn.pressed.connect(func() -> void:
		GameManager.is_game_active = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	options_container.add_child(menu_btn)

	continue_button.get_parent().add_child(options_container)
	continue_button.visible = false
