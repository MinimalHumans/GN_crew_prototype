class_name WinScreen
extends VBoxContainer
## WinScreen — Victory summary displayed when the player reaches 25,000 lifetime credits.
## Shows game statistics, crew history, and relationship highlights.
## Presented as a service panel within planet_view.

signal back_pressed
signal log_message(text: String)

# Color constants
const COLOR_GOOD: String = "#27AE60"
const COLOR_BAD: String = "#C0392B"
const COLOR_MUTED: String = "#718096"
const COLOR_ACCENT: String = "#4A90D9"
const COLOR_CREDITS: String = "#E6D159"
const COLOR_GOLD: String = "#FFD700"
const COLOR_ROMANCE: String = "#FF69B4"


func _ready() -> void:
	_build_ui()


# === UI BUILDING ===

func _build_ui() -> void:
	# Header row
	var header: HBoxContainer = HBoxContainer.new()
	var back_btn: Button = Button.new()
	back_btn.text = "< Continue Playing"
	back_btn.custom_minimum_size = Vector2(200, 48)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back_btn)

	var title: Label = Label.new()
	title.text = "  VICTORY — CAPTAIN'S LEGACY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(COLOR_GOLD))
	header.add_child(title)
	add_child(header)

	# Scroll container
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	# Victory message
	var victory_msg: RichTextLabel = RichTextLabel.new()
	victory_msg.bbcode_enabled = true
	victory_msg.fit_content = true
	victory_msg.scroll_active = false
	victory_msg.text = "[color=%s][b]Congratulations, Captain %s![/b][/color]\n\nYou have earned [color=%s]%s credits[/color] across your career — enough to retire in comfort, fund a fleet, or forge a new path among the stars. Your name echoes through the shipping lanes.\n\nBut the stars still call. You may continue your journey." % [
		COLOR_GOLD, GameManager.captain_name, COLOR_CREDITS,
		_format_number(GameManager.total_credits_earned)]
	content.add_child(victory_msg)

	# === STATISTICS ===
	content.add_child(_make_section_label("VOYAGE STATISTICS"))
	_add_statistics_section(content)

	# === CREW HISTORY ===
	content.add_child(_make_section_label("CREW HISTORY"))
	_add_crew_history_section(content)

	# === RELATIONSHIP HIGHLIGHTS ===
	content.add_child(_make_section_label("RELATIONSHIP HIGHLIGHTS"))
	_add_relationship_section(content)

	# === LEGACY ===
	content.add_child(_make_section_label("CREW LEGACY"))
	_add_legacy_section(content)


func _make_section_label(text: String) -> VBoxContainer:
	var wrapper: VBoxContainer = VBoxContainer.new()
	var sep: HSeparator = HSeparator.new()
	wrapper.add_child(sep)
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	wrapper.add_child(lbl)
	return wrapper


func _add_statistics_section(content: VBoxContainer) -> void:
	var stats_grid: GridContainer = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 30)
	stats_grid.add_theme_constant_override("v_separation", 6)

	# Gather data
	var days: int = GameManager.day_count
	var earned: int = GameManager.total_credits_earned
	var spent: int = GameManager.total_credits_spent
	var current_credits: int = GameManager.credits
	var level: int = GameManager.captain_level
	var ship_class: String = GameManager.ship_class.capitalize()

	# Count missions completed from database
	var missions_completed: int = _count_completed_missions()

	# Count planets visited
	var visited: Array = DatabaseManager.get_visited_planets(GameManager.save_id)
	var planets_count: int = visited.size()

	# Count crew (all time)
	var all_crew: Array = _get_all_crew_ever()
	var active_crew: Array = DatabaseManager.get_crew_roster(GameManager.save_id)
	var total_recruited: int = all_crew.size()
	var crew_lost: int = 0
	for cm: Dictionary in all_crew:
		if cm.get("is_active", 1) == 0:
			crew_lost += 1

	_add_stat_row(stats_grid, "Days Played", str(days))
	_add_stat_row(stats_grid, "Captain Level", str(level))
	_add_stat_row(stats_grid, "Final Ship", ship_class)
	_add_stat_row(stats_grid, "Credits Earned (Lifetime)", _format_number(earned))
	_add_stat_row(stats_grid, "Credits Spent (Lifetime)", _format_number(spent))
	_add_stat_row(stats_grid, "Credits On Hand", _format_number(current_credits))
	_add_stat_row(stats_grid, "Missions Completed", str(missions_completed))
	_add_stat_row(stats_grid, "Planets Visited", "%d / 12" % planets_count)
	_add_stat_row(stats_grid, "Crew Recruited (Total)", str(total_recruited))
	_add_stat_row(stats_grid, "Crew Lost / Departed", str(crew_lost))
	_add_stat_row(stats_grid, "Active Crew", str(active_crew.size()))

	content.add_child(stats_grid)


func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(COLOR_MUTED))
	grid.add_child(label)

	var value: Label = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 20)
	grid.add_child(value)


func _add_crew_history_section(content: VBoxContainer) -> void:
	var all_crew: Array = _get_all_crew_ever()
	if all_crew.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "You sailed alone — a true solo captain."
		lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		lbl.add_theme_font_size_override("font_size", 20)
		content.add_child(lbl)
		return

	for cm_data: Dictionary in all_crew:
		var cm: CrewMember = CrewMember.from_dict(cm_data)
		var row: HBoxContainer = HBoxContainer.new()

		var name_lbl: Label = Label.new()
		var status_color: String = COLOR_GOOD if cm.is_active else COLOR_MUTED
		var status_text: String = "Active" if cm.is_active else _get_departure_status(cm_data)
		name_lbl.text = "%s — %s %s" % [cm.crew_name, cm.get_species_name(), cm.get_role_name()]
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color(status_color))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var status_lbl: Label = Label.new()
		status_lbl.text = "[%s]" % status_text
		status_lbl.add_theme_font_size_override("font_size", 18)
		status_lbl.add_theme_color_override("font_color", Color(status_color))
		row.add_child(status_lbl)

		content.add_child(row)


func _add_relationship_section(content: VBoxContainer) -> void:
	# Get all relationships with high values
	var relationships: Array = DatabaseManager.get_all_crew_relationships(GameManager.save_id)
	var strong_bonds: Array = []
	var romances: Array = []

	for rel: Dictionary in relationships:
		var value: float = rel.get("value", 0.0)
		if rel.get("is_romantic", 0) == 1:
			romances.append(rel)
		elif value >= 60.0:
			strong_bonds.append(rel)

	if romances.is_empty() and strong_bonds.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "No significant bonds formed during this voyage."
		lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		lbl.add_theme_font_size_override("font_size", 20)
		content.add_child(lbl)
		return

	# Show romances first
	for rel: Dictionary in romances:
		var name_a: String = _get_crew_name(rel.get("crew_a_id", -1))
		var name_b: String = _get_crew_name(rel.get("crew_b_id", -1))
		var lbl: Label = Label.new()
		lbl.text = "♥ %s & %s — Romance (bond: %.0f)" % [name_a, name_b, rel.get("value", 0.0)]
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(COLOR_ROMANCE))
		content.add_child(lbl)

	# Show strong bonds
	for rel: Dictionary in strong_bonds:
		var name_a: String = _get_crew_name(rel.get("crew_a_id", -1))
		var name_b: String = _get_crew_name(rel.get("crew_b_id", -1))
		var lbl: Label = Label.new()
		lbl.text = "★ %s & %s — Strong bond (%.0f)" % [name_a, name_b, rel.get("value", 0.0)]
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(COLOR_GOOD))
		content.add_child(lbl)


func _add_legacy_section(content: VBoxContainer) -> void:
	var legacies: Array = DatabaseManager.get_crew_legacies(GameManager.save_id)
	if legacies.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "No crew have departed to leave a lasting legacy."
		lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		lbl.add_theme_font_size_override("font_size", 20)
		content.add_child(lbl)
		return

	for legacy: Dictionary in legacies:
		var dep_type: String = legacy.get("departure_type", "")
		var color: String = COLOR_MUTED
		match dep_type:
			"retirement": color = COLOR_GOOD
			"death": color = COLOR_BAD
			"voluntary": color = "#E67E22"
			_: color = COLOR_MUTED

		var lbl: Label = Label.new()
		lbl.text = "%s (%s) — Day %d: %s" % [
			legacy.get("crew_name", "Unknown"),
			legacy.get("crew_role", ""),
			legacy.get("day_departed", 0),
			legacy.get("legacy_text", "")]
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(color))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(lbl)


# === HELPERS ===

func _get_all_crew_ever() -> Array:
	## Returns all crew members (active and inactive) for the current save.
	var db: SQLite = DatabaseManager.db
	if db == null:
		return []
	return db.select_rows("crew_members", "save_id = %d" % GameManager.save_id, ["*"])


func _count_completed_missions() -> int:
	## Count completed missions from the mission log or estimate from earnings.
	## Since we don't have a dedicated completed missions counter, estimate from credits earned.
	## A rough average mission pays ~150 credits.
	var db: SQLite = DatabaseManager.db
	if db == null:
		return 0
	# Check if missions_completed table exists, otherwise estimate
	var result: Array = db.select_rows("crew_memories",
		"save_id = %d AND trigger_tag = 'mission_success'" % GameManager.save_id, ["id"])
	return result.size()


func _get_departure_status(cm_data: Dictionary) -> String:
	var death_day: int = cm_data.get("death_day", 0)
	if death_day > 0:
		return "Died day %d" % death_day
	return "Departed"


func _get_crew_name(crew_id: int) -> String:
	if crew_id < 0:
		return "Unknown"
	var data: Dictionary = DatabaseManager.get_crew_member(crew_id)
	return data.get("name", "Unknown")


func _format_number(n: int) -> String:
	var s: String = str(n)
	if n < 1000:
		return s
	var result: String = ""
	var count: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result
