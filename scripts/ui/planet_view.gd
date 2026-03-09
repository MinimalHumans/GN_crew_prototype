extends Control
## Planet View — Placeholder for Phase 1.3.
## Displays basic planet info and captain/ship status to confirm the game started correctly.

@onready var planet_name_label: Label = $MarginContainer/VBoxContainer/PlanetNameLabel
@onready var faction_label: Label = $MarginContainer/VBoxContainer/FactionLabel
@onready var captain_info: Label = $MarginContainer/VBoxContainer/InfoPanel/CaptainInfo
@onready var ship_info: Label = $MarginContainer/VBoxContainer/InfoPanel/ShipInfo
@onready var message_log: RichTextLabel = $MarginContainer/VBoxContainer/MessageLog
@onready var save_button: Button = $MarginContainer/VBoxContainer/ButtonRow/SaveButton
@onready var menu_button: Button = $MarginContainer/VBoxContainer/ButtonRow/MenuButton


func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	_update_display()
	_log_arrival()

	# Connect to events for live updates
	EventBus.credits_changed.connect(_on_credits_changed)


func _update_display() -> void:
	var planet: Dictionary = GameManager.get_current_planet()
	if planet.is_empty():
		planet_name_label.text = "Unknown Location"
		faction_label.text = ""
	else:
		planet_name_label.text = planet.name
		faction_label.text = "%s — %s Zone" % [planet.type.capitalize(), planet.zone]

	captain_info.text = "Captain %s  |  Level %d  |  XP: %d/%d  |  Credits: %d" % [
		GameManager.captain_name,
		GameManager.captain_level,
		GameManager.captain_xp,
		GameManager.get_xp_for_next_level(),
		GameManager.credits,
	]

	ship_info.text = "%s  |  Hull: %d/%d  |  Fuel: %.0f/%.0f  |  Cargo: 0/%d  |  Crew: 0/%d" % [
		GameManager.ship_name,
		GameManager.hull_current, GameManager.hull_max,
		GameManager.fuel_current, GameManager.fuel_max,
		GameManager.cargo_max,
		GameManager.crew_max,
	]


func _log_arrival() -> void:
	var planet: Dictionary = GameManager.get_current_planet()
	if planet.is_empty():
		return

	_append_log("[color=#4A90D9]Welcome to %s.[/color]" % planet.name)
	_append_log(planet.description)

	var services_json: String = planet.get("services", "[]")
	var services: Array = JSON.parse_string(services_json)
	if services:
		var service_names: PackedStringArray = []
		for s: String in services:
			service_names.append(s.replace("_", " ").capitalize())
		_append_log("[color=#718096]Services: %s[/color]" % ", ".join(service_names))

	_append_log("[color=#718096]Day %d[/color]" % GameManager.day_count)


func _append_log(text: String) -> void:
	message_log.append_text(text + "\n")


func _on_save_pressed() -> void:
	GameManager.save_game()
	_append_log("[color=#27AE60]Game saved.[/color]")


func _on_menu_pressed() -> void:
	GameManager.save_game()
	GameManager.is_game_active = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_credits_changed(_new_amount: int) -> void:
	_update_display()
