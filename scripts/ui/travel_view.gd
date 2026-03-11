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

	continue_button.text = "Begin Jump 1"
	continue_button.grab_focus()


# === JUMP PROCESSING ===

func _on_continue_pressed() -> void:
	if _journey_complete:
		_arrive()
		return

	_current_jump += 1

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
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_approach_selected.bind(i))
		_encounter_container.add_child(btn)

		# Info label below button
		if info_text != "":
			var info_lbl: RichTextLabel = RichTextLabel.new()
			info_lbl.bbcode_enabled = true
			info_lbl.text = "   %s" % info_text
			info_lbl.fit_content = true
			info_lbl.scroll_active = false
			info_lbl.custom_minimum_size = Vector2(0, 18)
			info_lbl.add_theme_font_size_override("normal_font_size", 10)
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

	# Hull damage on failure
	if result.tier in ["failure", "critical_failure"]:
		var hull_dmg: int = randi_range(5, 15) if result.tier == "failure" else randi_range(10, 25)
		GameManager.hull_current = maxi(1, GameManager.hull_current - hull_dmg)
		DatabaseManager.update_ship(GameManager.current_ship_id, {"hull_current": GameManager.hull_current})
		EventBus.hull_changed.emit(GameManager.hull_current, GameManager.hull_max)
		_append_log("[color=#C0392B]Hull damage: -%d HP[/color]" % hull_dmg)

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
	accept_btn.custom_minimum_size = Vector2(0, 32)
	accept_btn.add_theme_font_size_override("font_size", 12)
	accept_btn.pressed.connect(_on_rescue_accept)
	_encounter_container.add_child(accept_btn)

	var decline_btn: Button = Button.new()
	decline_btn.text = "2. Patch them up and point them to the nearest station"
	decline_btn.custom_minimum_size = Vector2(0, 32)
	decline_btn.add_theme_font_size_override("font_size", 12)
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
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_decision_choice.bind(i))
		_decision_container.add_child(btn)

		if option.has("hint"):
			var hint: Label = Label.new()
			hint.text = "   %s" % option.hint
			hint.add_theme_font_size_override("font_size", 10)
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
	if crew_count > 0:
		var morale_word: String = GameManager.get_ship_morale_word()
		var morale_color: String = GameManager.get_ship_morale_color()
		status_label.text = "Fuel: %.0f/%.0f  |  Food: %s  |  Hull: %d/%d  |  Day %d  |  Morale: %s" % [
			GameManager.fuel_current, GameManager.fuel_max,
			GameManager.get_food_days_remaining(),
			GameManager.hull_current, GameManager.hull_max,
			GameManager.day_count,
			morale_word,
		]
	else:
		status_label.text = "Fuel: %.0f/%.0f  |  Food: %s  |  Hull: %d/%d  |  Day %d" % [
			GameManager.fuel_current, GameManager.fuel_max,
			GameManager.get_food_days_remaining(),
			GameManager.hull_current, GameManager.hull_max,
			GameManager.day_count,
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
