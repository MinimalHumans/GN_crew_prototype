extends Control
## Travel View — Processes a journey jump by jump.
## Each jump: deduct fuel/food, advance day, crew simulation tick,
## encounter check, crew events. After final jump, arrive at destination.

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
var _decision_pending: bool = false
var _pending_decision: Dictionary = {}
var _decision_container: VBoxContainer = null


# === INITIALIZATION ===

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)

	# Read travel state from GameManager
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

	# Fuel deduction report
	_append_log("[color=#718096]  Fuel: -%.0f (%.0f remaining)[/color]" % [
		result.fuel_used, GameManager.fuel_current
	])

	# Food deduction
	if result.food_used > 0:
		_append_log("[color=#718096]  Food: -%.1f (%.1f remaining)[/color]" % [
			result.food_used, GameManager.food_supply
		])

	# Day advance
	_append_log("[color=#718096]  Day %d[/color]" % GameManager.day_count)

	# Random encounter check
	var had_encounter: bool = _roll_encounter_check()

	# --- Crew simulation tick ---
	if crew_count > 0:
		var sim_result: Dictionary = CrewSimulation.tick_jump(had_encounter)

		# Log crew simulation events
		for event_text: String in sim_result.get("events", []):
			_append_log(event_text)

		# Generate crew events
		var roster: Array[CrewMember] = GameManager.get_crew_roster()
		var event_result: Dictionary = CrewEventGenerator.generate_events(roster)

		# Background events
		for bg: String in event_result.get("background", []):
			_append_log(bg)

		# Nudge events
		for nudge: String in event_result.get("nudges", []):
			_append_log(nudge)

		# Decision event — show modal if one fired
		var decision: Dictionary = event_result.get("decision", {})
		if not decision.is_empty():
			_show_decision_event(decision)

		# Record that this was a non-dangerous event (for safety tracking)
		if not had_encounter:
			GameManager.record_event("quiet")

	_append_log("")

	# Check if journey is complete
	if _current_jump >= _total_jumps:
		_journey_complete = true
		_append_log("[color=#4A90D9]%s is in sight. Preparing to dock.[/color]" % _destination_name)
		continue_button.text = "Arrive at %s" % _destination_name
	else:
		continue_button.text = "Continue to Jump %d" % (_current_jump + 1)


func _roll_encounter_check() -> bool:
	## Rolls for a random encounter. Returns true if triggered.
	var chance: float = GameManager.get_encounter_chance(_danger_level)
	var roll: float = randf()
	var triggered: bool = roll < chance

	if triggered:
		_append_log("[color=#E67E22]  ⚠ Encounter detected![/color]")
		_append_log("[color=#718096]    [Encounter system — Phase 3][/color]")
		GameManager.record_event("combat")
	return triggered


func _arrive() -> void:
	## Called when the journey is complete. Transition to planet view.
	GameManager.arrive_at_planet(_destination_id)


# === DECISION EVENT DISPLAY ===

func _show_decision_event(event_data: Dictionary) -> void:
	_pending_decision = event_data
	_decision_pending = true
	continue_button.disabled = true

	_append_log("")
	_append_log("[color=#E6D159]══════════════════════════════[/color]")
	_append_log("[color=#E6D159]  %s[/color]" % event_data.title)
	_append_log("[color=#F7FAFC]  %s[/color]" % event_data.description)
	_append_log("")

	# Create a dedicated container for option buttons
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

	# Insert the decision container before the continue button
	continue_button.get_parent().add_child(_decision_container)
	continue_button.get_parent().move_child(_decision_container, continue_button.get_index())


func _on_decision_choice(choice: int) -> void:
	# Remove the decision container
	if _decision_container != null:
		_decision_container.queue_free()
		_decision_container = null

	# Resolve the decision
	var result_text: String = CrewEventGenerator.resolve_decision(
		_pending_decision.id, choice, _pending_decision)

	_append_log("[color=#F7FAFC]  → %s[/color]" % result_text)
	_append_log("[color=#E6D159]══════════════════════════════[/color]")

	EventBus.decision_event_resolved.emit(_pending_decision.id, choice)
	_decision_pending = false
	_pending_decision = {}
	continue_button.disabled = false


# === DISPLAY ===

func _update_status() -> void:
	var crew_count: int = GameManager.get_crew_count()
	if crew_count > 0:
		var morale_word: String = GameManager.get_ship_morale_word()
		var morale_color: String = GameManager.get_ship_morale_color()
		status_label.text = "Fuel: %.0f/%.0f  |  Food: %s  |  Day %d  |  Crew Morale: [color=%s]%s[/color]" % [
			GameManager.fuel_current, GameManager.fuel_max,
			GameManager.get_food_days_remaining(),
			GameManager.day_count,
			morale_color, morale_word,
		]
	else:
		status_label.text = "Fuel: %.0f/%.0f  |  Food: %s  |  Day %d" % [
			GameManager.fuel_current, GameManager.fuel_max,
			GameManager.get_food_days_remaining(),
			GameManager.day_count,
		]


func _append_log(text: String) -> void:
	travel_log.append_text(text + "\n")
