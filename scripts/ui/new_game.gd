extends Control
## New Game Screen — Captain name selection, debug options, and game start.

# === PREPARED CAPTAIN NAMES ===
const CAPTAIN_NAMES: PackedStringArray = [
	"Harlow", "Voss", "Kira", "Dex", "Maren",
	"Sable", "Renn", "Cade", "Thalia", "Juno",
]

# === NODE REFERENCES ===
@onready var name_option: OptionButton = $MarginContainer/VBoxContainer/NameSection/NameOptionButton
@onready var custom_name_input: LineEdit = $MarginContainer/VBoxContainer/NameSection/CustomNameInput
@onready var debug_toggle: Button = $MarginContainer/VBoxContainer/DebugSection/DebugToggleButton
@onready var debug_panel: VBoxContainer = $MarginContainer/VBoxContainer/DebugSection/DebugPanel
@onready var credits_spinbox: SpinBox = $MarginContainer/VBoxContainer/DebugSection/DebugPanel/CreditsRow/CreditsSpinBox
@onready var level_spinbox: SpinBox = $MarginContainer/VBoxContainer/DebugSection/DebugPanel/LevelRow/LevelSpinBox
@onready var ship_option: OptionButton = $MarginContainer/VBoxContainer/DebugSection/DebugPanel/ShipRow/ShipOptionButton
@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton

var _use_custom_name: bool = false


# === INITIALIZATION ===

func _ready() -> void:
	_populate_name_list()
	_setup_debug_panel()

	# Connect signals
	name_option.item_selected.connect(_on_name_selected)
	custom_name_input.text_changed.connect(_on_custom_name_changed)
	debug_toggle.pressed.connect(_on_debug_toggle_pressed)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Initial state
	debug_panel.visible = false
	custom_name_input.visible = false
	start_button.grab_focus()


func _populate_name_list() -> void:
	name_option.clear()
	for name_text: String in CAPTAIN_NAMES:
		name_option.add_item(name_text)
	name_option.add_separator()
	name_option.add_item("Custom Name...")


func _setup_debug_panel() -> void:
	credits_spinbox.min_value = 100
	credits_spinbox.max_value = 50000
	credits_spinbox.step = 100
	credits_spinbox.value = 500

	level_spinbox.min_value = 1
	level_spinbox.max_value = 10
	level_spinbox.step = 1
	level_spinbox.value = 1

	ship_option.clear()
	ship_option.add_item("Skiff (Starter)")
	ship_option.add_item("Corvette (Medium)")
	ship_option.add_item("Frigate (Large)")


# === SIGNAL HANDLERS ===

func _on_name_selected(index: int) -> void:
	# Last non-separator item is "Custom Name..."
	var item_text: String = name_option.get_item_text(index)
	if item_text == "Custom Name...":
		_use_custom_name = true
		custom_name_input.visible = true
		custom_name_input.grab_focus()
	else:
		_use_custom_name = false
		custom_name_input.visible = false


func _on_custom_name_changed(_new_text: String) -> void:
	pass  # Validation could go here


func _on_debug_toggle_pressed() -> void:
	debug_panel.visible = not debug_panel.visible
	if debug_panel.visible:
		debug_toggle.text = "Hide Debug Options"
	else:
		debug_toggle.text = "Show Debug Options"


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_start_pressed() -> void:
	var chosen_name: String = _get_captain_name()
	if chosen_name.strip_edges().is_empty():
		chosen_name = "Captain"

	var starting_credits: int = int(credits_spinbox.value)
	var starting_level: int = int(level_spinbox.value)

	# Delete any existing save before starting fresh
	if DatabaseManager.has_save():
		var old_save: Dictionary = DatabaseManager.load_save()
		if not old_save.is_empty():
			DatabaseManager.delete_save(old_save.id)

	GameManager.start_new_game(chosen_name, starting_credits, starting_level)

	# Handle debug ship override
	var ship_index: int = ship_option.selected
	if ship_index > 0:
		var target_class: String = "corvette" if ship_index == 1 else "frigate"
		_override_starting_ship(target_class)


func _get_captain_name() -> String:
	if _use_custom_name:
		return custom_name_input.text.strip_edges()
	return name_option.get_item_text(name_option.selected)


func _override_starting_ship(target_class: String) -> void:
	## Debug override: replace starting Skiff with a different ship class.
	var template: Dictionary = DatabaseManager.get_ship_template(target_class)
	DatabaseManager.update_ship(GameManager.current_ship_id, {
		"class": template.class,
		"name": template.name,
		"hull_current": template.hull_max,
		"hull_max": template.hull_max,
		"fuel_current": template.fuel_max,
		"fuel_max": template.fuel_max,
		"cargo_max": template.cargo_max,
		"crew_max": template.crew_max,
	})
	GameManager._refresh_ship_state()
