extends Control
## Main Menu — Title screen with New Game and Load Game options.

@onready var new_game_button: Button = $VBoxContainer/ButtonContainer/NewGameButton
@onready var load_game_button: Button = $VBoxContainer/ButtonContainer/LoadGameButton
@onready var version_label: Label = $VBoxContainer/VersionLabel


func _ready() -> void:
	# Check if a save exists to enable/disable Load Game
	var has_save: bool = DatabaseManager.has_save()
	load_game_button.disabled = not has_save
	version_label.text = "v0.1.0 — Phase 1"

	if has_save:
		var save: Dictionary = DatabaseManager.load_save()
		if not save.is_empty():
			var hardcore: bool = bool(save.get("hardcore_hull", 0))
			var day: int = save.get("day_count", 1)
			var name_str: String = save.get("captain_name", "Unknown")
			var hc_tag: String = " [Hardcore]" if hardcore else ""
			load_game_button.text = "Continue — Cpt. %s, Day %d%s" % [name_str, day, hc_tag]

	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)

	# Focus the New Game button for keyboard navigation
	new_game_button.grab_focus()


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/new_game.tscn")


func _on_load_game_pressed() -> void:
	if GameManager.load_game():
		GameManager.change_scene("res://scenes/planet/planet_view.tscn")
