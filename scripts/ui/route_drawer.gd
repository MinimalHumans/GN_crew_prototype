extends Control
## RouteDrawer — Draws route lines between planets on the node map.
## Uses _draw() to render lines based on database route data.


func _draw() -> void:
	var area_size: Vector2 = size
	if area_size.x < 1 or area_size.y < 1:
		return

	var all_routes: Array = DatabaseManager.get_all_routes()
	var current_id: int = GameManager.current_planet_id
	var connected_routes: Array = DatabaseManager.get_routes_from(current_id)

	# Collect connected planet IDs for highlighting
	var connected_pairs: Array[Array] = []
	for route: Dictionary in connected_routes:
		connected_pairs.append([route.planet_a_id, route.planet_b_id])

	for route: Dictionary in all_routes:
		var id_a: int = route.planet_a_id
		var id_b: int = route.planet_b_id
		var pos_a: Vector2 = _get_planet_center(id_a, area_size)
		var pos_b: Vector2 = _get_planet_center(id_b, area_size)

		# Check if this route connects to current planet
		var is_active: bool = false
		for pair: Array in connected_pairs:
			if (pair[0] == id_a and pair[1] == id_b) or (pair[0] == id_b and pair[1] == id_a):
				is_active = true
				break

		var line_color: Color
		var line_width: float
		if is_active:
			# Highlight routes from current planet
			var danger_color_hex: String = GameManager.get_danger_color(route.danger_level)
			line_color = Color(danger_color_hex)
			line_color.a = 0.8
			line_width = 2.5
		else:
			line_color = Color(0.3, 0.3, 0.4, 0.25)
			line_width = 1.0

		draw_line(pos_a, pos_b, line_color, line_width, true)


func _get_planet_center(planet_id: int, area_size: Vector2) -> Vector2:
	var norm: Vector2 = TextTemplates.PLANET_POSITIONS.get(planet_id, Vector2(0.5, 0.5))
	return Vector2(norm.x * area_size.x, norm.y * area_size.y)
