extends Control
## Travel View — Processes a journey jump by jump.
## Each jump: deduct fuel/food, advance day, show text, roll encounter check.
## After final jump, arrive at destination.

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

	# Travel atmosphere text
	var travel_text: String = TextTemplates.get_travel_text()
	_append_log("[color=#F7FAFC]Jump %d of %d. %s[/color]" % [_current_jump, _total_jumps, travel_text])

	# Fuel deduction report
	_append_log("[color=#718096]  Fuel: -%.0f (%.0f remaining)[/color]" % [
		result.fuel_used, GameManager.fuel_current
	])

	# Food deduction (only relevant with crew, but show the system working)
	if result.food_used > 0:
		_append_log("[color=#718096]  Food: -%.1f (%.1f remaining)[/color]" % [
			result.food_used, GameManager.food_supply
		])

	# Day advance
	_append_log("[color=#718096]  Day %d[/color]" % GameManager.day_count)

	# Random encounter check
	_roll_encounter_check()

	_append_log("")

	# Check if journey is complete
	if _current_jump >= _total_jumps:
		_journey_complete = true
		_append_log("[color=#4A90D9]%s is in sight. Preparing to dock.[/color]" % _destination_name)
		continue_button.text = "Arrive at %s" % _destination_name
	else:
		continue_button.text = "Continue to Jump %d" % (_current_jump + 1)


func _roll_encounter_check() -> void:
	## Rolls for a random encounter. Phase 1 just logs the result.
	var chance: float = GameManager.get_encounter_chance(_danger_level)
	var roll: float = randf()
	var triggered: bool = roll < chance

	if triggered:
		_append_log("[color=#E67E22]  ⚠ Encounter detected! (roll %.2f < %.0f%% threshold)[/color]" % [
			roll, chance * 100.0
		])
		_append_log("[color=#718096]    [Encounters not yet implemented — Phase 1.6+][/color]")
	else:
		# Only show debug info occasionally to keep log clean
		print("Encounter check: roll %.2f vs threshold %.2f — no encounter" % [roll, chance])


func _arrive() -> void:
	## Called when the journey is complete. Transition to planet view.
	GameManager.arrive_at_planet(_destination_id)


# === DISPLAY ===

func _update_status() -> void:
	status_label.text = "Fuel: %.0f/%.0f  |  Food: %s  |  Day %d" % [
		GameManager.fuel_current, GameManager.fuel_max,
		GameManager.get_food_days_remaining(),
		GameManager.day_count,
	]


func _append_log(text: String) -> void:
	travel_log.append_text(text + "\n")
