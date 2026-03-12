extends Control
## Node Map — Shows the 12-planet galaxy with route connections.
## Player selects a connected planet to travel to.

@onready var map_area: Control = $MapLayer/MapArea
@onready var route_drawer: Control = $MapLayer/MapArea/RouteDrawer
@onready var confirm_panel: PanelContainer = $ConfirmPanel
@onready var confirm_title: Label = $ConfirmPanel/Margin/VBox/ConfirmTitle
@onready var confirm_info: Label = $ConfirmPanel/Margin/VBox/ConfirmInfo
@onready var confirm_warning: Label = $ConfirmPanel/Margin/VBox/ConfirmWarning
@onready var proceed_button: Button = $ConfirmPanel/Margin/VBox/ButtonRow/ProceedButton
@onready var cancel_button: Button = $ConfirmPanel/Margin/VBox/ButtonRow/CancelButton
@onready var back_button: Button = $MapLayer/BackButton

var _planet_buttons: Dictionary = {}  # planet_id -> Button
var _selected_planet_id: int = -1
var _connected_ids: Array[int] = []


# === INITIALIZATION ===

func _ready() -> void:
	confirm_panel.visible = false
	proceed_button.pressed.connect(_on_proceed_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_load_map_data()


func _load_map_data() -> void:
	var all_planets: Array = DatabaseManager.get_all_planets()
	var visited_ids: Array[int] = DatabaseManager.get_visited_planet_ids(GameManager.save_id)

	# Figure out which planets are directly connected to current location
	var routes_from: Array = DatabaseManager.get_routes_from(GameManager.current_planet_id)
	_connected_ids = []
	for route: Dictionary in routes_from:
		var other_id: int = route.planet_b_id if route.planet_a_id == GameManager.current_planet_id else route.planet_a_id
		_connected_ids.append(other_id)

	# Create planet buttons
	for planet: Dictionary in all_planets:
		_create_planet_button(planet, visited_ids)

	# Tell the route drawer to draw
	route_drawer.queue_redraw()


func _create_planet_button(planet: Dictionary, visited_ids: Array[int]) -> void:
	var planet_id: int = planet.id
	var pos_norm: Vector2 = TextTemplates.PLANET_POSITIONS.get(planet_id, Vector2(0.5, 0.5))

	var btn: Button = Button.new()
	btn.text = planet.name
	btn.custom_minimum_size = Vector2(165, 45)
	btn.add_theme_font_size_override("font_size", 18)

	# Color and state
	var is_current: bool = (planet_id == GameManager.current_planet_id)
	var is_connected: bool = planet_id in _connected_ids
	var is_visited: bool = planet_id in visited_ids

	if is_current:
		btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		btn.tooltip_text = "You are here"
		btn.disabled = true
	elif is_connected:
		var faction_color: Color = TextTemplates.get_faction_color(planet.faction)
		btn.add_theme_color_override("font_color", faction_color)
		btn.add_theme_color_override("font_hover_color", faction_color.lightened(0.3))
	else:
		btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 0.6))
		btn.disabled = true
		btn.tooltip_text = "No direct route"

	if not is_visited and not is_current:
		btn.add_theme_font_size_override("font_size", 11)

	btn.pressed.connect(_on_planet_pressed.bind(planet_id))

	# We position the button in _process after the map_area is sized
	map_area.add_child(btn)
	_planet_buttons[planet_id] = btn

	# Store normalized position for layout
	btn.set_meta("norm_pos", pos_norm)


func _process(_delta: float) -> void:
	# Position buttons based on actual map_area size
	var area_size: Vector2 = map_area.size
	if area_size.x < 1 or area_size.y < 1:
		return

	for planet_id: int in _planet_buttons:
		var btn: Button = _planet_buttons[planet_id]
		var norm: Vector2 = btn.get_meta("norm_pos")
		var target_pos: Vector2 = Vector2(
			norm.x * area_size.x - btn.size.x * 0.5,
			norm.y * area_size.y - btn.size.y * 0.5,
		)
		btn.position = target_pos

	# Only need to do this once (plus on resize)
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		set_process(true)
		route_drawer.queue_redraw()


# === PLANET SELECTION ===

func _on_planet_pressed(planet_id: int) -> void:
	_selected_planet_id = planet_id
	_show_confirm_panel(planet_id)


func _show_confirm_panel(planet_id: int) -> void:
	var planet: Dictionary = DatabaseManager.get_planet(planet_id)
	var route: Dictionary = DatabaseManager.get_route_between(GameManager.current_planet_id, planet_id)
	if planet.is_empty() or route.is_empty():
		return

	var jumps: int = route.jumps
	var fuel_cost: float = jumps * GameManager.get_fuel_cost_per_jump()
	var danger: String = route.danger_level
	var danger_display: String = GameManager.get_danger_display(danger)
	var danger_color: String = GameManager.get_danger_color(danger)

	confirm_title.text = "Travel to %s" % planet.name
	confirm_info.text = "%d jumps  |  Danger: [color=%s]%s[/color]  |  Fuel cost: %.0f" % [
		jumps, danger_color, danger_display, fuel_cost
	]
	# RichTextLabel would be needed for color in confirm_info, but for simplicity
	# we'll use plain text with the danger level
	confirm_info.text = "%d jumps  |  Danger: %s  |  Fuel: %.0f  |  Food: %.0f" % [jumps, danger_display, fuel_cost, jumps * GameManager.get_food_cost_per_jump()]

	# Check fuel
	var food_cost: float = jumps * GameManager.get_food_cost_per_jump()
	if GameManager.fuel_current < fuel_cost:
		confirm_warning.text = "WARNING: Not enough fuel! Need %.0f, have %.0f." % [fuel_cost, GameManager.fuel_current]
		confirm_warning.add_theme_color_override("font_color", Color(0.75, 0.22, 0.17))
		confirm_warning.visible = true
		proceed_button.disabled = true
	elif GameManager.food_supply < food_cost and food_cost > 0:
		confirm_warning.text = "WARNING: Low food! Need %.0f for trip, have %.0f." % [food_cost, GameManager.food_supply]
		confirm_warning.add_theme_color_override("font_color", Color(0.9, 0.49, 0.13))
		confirm_warning.visible = true
		proceed_button.disabled = false  # Allow travel on low food, just warn
	else:
		var remaining_fuel: String = "Fuel after: %.0f" % (GameManager.fuel_current - fuel_cost)
		var remaining_food: String = "Food after: %.0f" % (GameManager.food_supply - food_cost)
		confirm_warning.text = "%s  |  %s" % [remaining_fuel, remaining_food]
		confirm_warning.add_theme_color_override("font_color", Color(0.443, 0.502, 0.588))
		confirm_warning.visible = true
		proceed_button.disabled = false

	confirm_panel.visible = true


func _on_proceed_pressed() -> void:
	if _selected_planet_id < 0:
		return
	confirm_panel.visible = false
	GameManager.begin_travel(_selected_planet_id)


func _on_cancel_pressed() -> void:
	confirm_panel.visible = false
	_selected_planet_id = -1


func _on_back_pressed() -> void:
	GameManager.change_scene("res://scenes/planet/planet_view.tscn")
