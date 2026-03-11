class_name MissionBoardView
extends VBoxContainer
## MissionBoardView — Shows available missions and lets the player accept them.
## Built programmatically and added to the planet view's service area.

signal back_pressed
signal log_message(text: String)

var planet_id: int = -1

# Color constants
const COLOR_GOOD: String = "#27AE60"
const COLOR_BAD: String = "#C0392B"
const COLOR_MUTED: String = "#718096"
const COLOR_ACCENT: String = "#4A90D9"
const COLOR_CREDITS: String = "#E6D159"
const COLOR_WARNING: String = "#E67E22"

# UI refs
var active_label: Label
var mission_list: VBoxContainer
var active_missions_container: VBoxContainer


func _init(p_planet_id: int = -1) -> void:
	planet_id = p_planet_id


func _ready() -> void:
	if planet_id < 0:
		return
	_ensure_missions_exist()
	_build_ui()


# === DATA ===

func _ensure_missions_exist() -> void:
	## Generate missions for this planet if none exist.
	## Faction access modifies count: outsider -1, insider +1.
	var existing: Array = DatabaseManager.get_missions_available(planet_id)
	if existing.is_empty():
		var base_count: int = randi_range(3, 5)
		var access: GameManager.AccessLevel = GameManager.get_faction_access_level(planet_id)
		if access == GameManager.AccessLevel.OUTSIDER:
			base_count = maxi(base_count - 1, 2)
		elif access == GameManager.AccessLevel.INSIDER:
			base_count += 1
		MissionGenerator.generate_and_store(planet_id, GameManager.captain_level, base_count, access)


# === UI BUILDING ===

func _build_ui() -> void:
	# Header
	var header: HBoxContainer = HBoxContainer.new()
	var back_btn: Button = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(80, 32)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back_btn)

	var title: Label = Label.new()
	title.text = "  MISSION BOARD"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	header.add_child(title)

	active_label = Label.new()
	active_label.add_theme_font_size_override("font_size", 13)
	header.add_child(active_label)
	add_child(header)

	_update_active_count()

	# Active missions section (if any)
	active_missions_container = VBoxContainer.new()
	active_missions_container.add_theme_constant_override("separation", 4)
	_build_active_missions()
	add_child(active_missions_container)

	# Separator
	add_child(HSeparator.new())

	# Available missions header
	add_child(_make_section_label("AVAILABLE MISSIONS"))

	# Scrollable mission list
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	mission_list = VBoxContainer.new()
	mission_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_list.add_theme_constant_override("separation", 8)

	_populate_mission_cards()

	scroll.add_child(mission_list)
	add_child(scroll)


func _build_active_missions() -> void:
	for child: Node in active_missions_container.get_children():
		child.queue_free()

	var active: Array = GameManager.get_active_missions()
	if active.is_empty():
		return

	active_missions_container.add_child(_make_section_label("ACTIVE MISSIONS"))

	for mission: Dictionary in active:
		var dest: Dictionary = DatabaseManager.get_planet(mission.destination_id)
		var dest_name: String = dest.get("name", "Unknown")

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var stars: Label = Label.new()
		stars.text = _difficulty_stars(mission.difficulty)
		stars.add_theme_font_size_override("font_size", 11)
		stars.add_theme_color_override("font_color", Color(COLOR_WARNING))
		row.add_child(stars)

		var title_lbl: Label = Label.new()
		title_lbl.text = mission.title
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(title_lbl)

		var dest_lbl: Label = Label.new()
		dest_lbl.text = "-> %s" % dest_name
		dest_lbl.add_theme_font_size_override("font_size", 11)
		dest_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		row.add_child(dest_lbl)

		active_missions_container.add_child(row)


func _populate_mission_cards() -> void:
	for child: Node in mission_list.get_children():
		child.queue_free()

	var missions: Array = DatabaseManager.get_missions_available(planet_id)
	if missions.is_empty():
		var empty: Label = Label.new()
		empty.text = "No missions available."
		empty.add_theme_color_override("font_color", Color(COLOR_MUTED))
		mission_list.add_child(empty)
		return

	for mission: Dictionary in missions:
		mission_list.add_child(_make_mission_card(mission))


func _make_mission_card(mission: Dictionary) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)

	# Title row: stars + title + reward
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)

	var stars: Label = Label.new()
	stars.text = _difficulty_stars(mission.difficulty)
	stars.add_theme_font_size_override("font_size", 12)
	stars.add_theme_color_override("font_color", Color(COLOR_WARNING))
	title_row.add_child(stars)

	var title_lbl: Label = Label.new()
	title_lbl.text = mission.title
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_row.add_child(title_lbl)

	var reward_lbl: Label = Label.new()
	reward_lbl.text = "%d cr" % mission.reward
	reward_lbl.add_theme_font_size_override("font_size", 13)
	reward_lbl.add_theme_color_override("font_color", Color(COLOR_CREDITS))
	title_row.add_child(reward_lbl)

	card_vbox.add_child(title_row)

	# Description (truncated)
	var desc: Label = Label.new()
	desc.text = mission.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(COLOR_MUTED))
	card_vbox.add_child(desc)

	# Details panel (initially hidden)
	var details: VBoxContainer = VBoxContainer.new()
	details.visible = false
	details.add_theme_constant_override("separation", 4)

	# Destination info
	var dest: Dictionary = DatabaseManager.get_planet(mission.destination_id)
	var dest_name: String = dest.get("name", "Unknown")
	var route: Dictionary = DatabaseManager.get_route_between(planet_id, mission.destination_id)

	var route_text: String = "Destination: %s" % dest_name
	if not route.is_empty():
		route_text += " (%d jumps, %s danger)" % [route.jumps, GameManager.get_danger_display(route.danger_level)]
	else:
		# Multi-hop — find path length estimate
		route_text += " (indirect route)"

	var route_lbl: Label = Label.new()
	route_lbl.text = route_text
	route_lbl.add_theme_font_size_override("font_size", 12)
	details.add_child(route_lbl)

	# Roles tested
	var roles: Array = JSON.parse_string(mission.roles_tested)
	if roles != null and not roles.is_empty():
		var roles_lbl: Label = Label.new()
		roles_lbl.text = "Roles tested: %s" % ", ".join(roles)
		roles_lbl.add_theme_font_size_override("font_size", 11)
		roles_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		details.add_child(roles_lbl)

	# Primary stat
	var stat_name: String = TextTemplates.get_mission_primary_stat(mission.type)
	var stat_lbl: Label = Label.new()
	stat_lbl.text = "Tests: %s" % stat_name.capitalize()
	stat_lbl.add_theme_font_size_override("font_size", 11)
	stat_lbl.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	details.add_child(stat_lbl)

	# Accept button row
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)

	var accept_btn: Button = Button.new()
	accept_btn.text = "Accept Mission"
	accept_btn.custom_minimum_size = Vector2(120, 32)

	var active_count: int = DatabaseManager.get_active_mission_count(GameManager.save_id)
	if active_count >= GameManager.MAX_ACTIVE_MISSIONS:
		accept_btn.disabled = true
		accept_btn.tooltip_text = "Max %d active missions" % GameManager.MAX_ACTIVE_MISSIONS
	else:
		accept_btn.pressed.connect(_on_accept_mission.bind(mission))

	btn_row.add_child(accept_btn)

	if active_count >= GameManager.MAX_ACTIVE_MISSIONS:
		var cap_lbl: Label = Label.new()
		cap_lbl.text = "Mission log full (%d/%d)" % [active_count, GameManager.MAX_ACTIVE_MISSIONS]
		cap_lbl.add_theme_font_size_override("font_size", 11)
		cap_lbl.add_theme_color_override("font_color", Color(COLOR_BAD))
		btn_row.add_child(cap_lbl)

	details.add_child(btn_row)
	card_vbox.add_child(details)

	# Toggle details button
	var toggle_btn: Button = Button.new()
	toggle_btn.text = "Details..."
	toggle_btn.flat = true
	toggle_btn.add_theme_font_size_override("font_size", 11)
	toggle_btn.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	toggle_btn.pressed.connect(func() -> void:
		details.visible = not details.visible
		toggle_btn.text = "Hide" if details.visible else "Details..."
	)
	card_vbox.add_child(toggle_btn)

	card.add_child(card_vbox)
	return card


# === ACTIONS ===

func _on_accept_mission(mission_data: Dictionary) -> void:
	if GameManager.accept_mission(mission_data):
		var dest: Dictionary = DatabaseManager.get_planet(mission_data.destination_id)
		log_message.emit("[color=%s]Mission accepted: %s[/color]" % [COLOR_ACCENT, mission_data.title])
		log_message.emit("[color=%s]Travel to %s to complete.[/color]" % [COLOR_MUTED, dest.get("name", "Unknown")])
		# Remove just this mission from available board
		DatabaseManager.remove_mission_available(mission_data.id)
		# Refresh display
		_populate_mission_cards()
		_build_active_missions()
		_update_active_count()
	else:
		log_message.emit("[color=%s]Can't accept more missions (max %d).[/color]" % [COLOR_BAD, GameManager.MAX_ACTIVE_MISSIONS])


# === HELPERS ===

func _update_active_count() -> void:
	var count: int = DatabaseManager.get_active_mission_count(GameManager.save_id)
	active_label.text = "Active: %d/%d" % [count, GameManager.MAX_ACTIVE_MISSIONS]


func _difficulty_stars(difficulty: int) -> String:
	var s: String = ""
	for i: int in range(difficulty):
		s += "*"
	return s


func _make_section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(COLOR_MUTED))
	label.add_theme_font_size_override("font_size", 11)
	return label
