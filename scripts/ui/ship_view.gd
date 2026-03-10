class_name ShipView
extends VBoxContainer
## ShipView — Persistent crew management screen.
## Shows ship status, crew grid with slot cards, and detail profiles.

signal back_pressed
signal log_message(text: String)

# Color constants
const COLOR_GOOD: String = "#27AE60"
const COLOR_BAD: String = "#C0392B"
const COLOR_WARN: String = "#E67E22"
const COLOR_MUTED: String = "#718096"
const COLOR_ACCENT: String = "#4A90D9"
const COLOR_CREDITS: String = "#E6D159"

var crew_grid: GridContainer
var detail_panel: VBoxContainer
var scroll_container: ScrollContainer
var selected_crew_id: int = -1


func _ready() -> void:
	EventBus.crew_changed.connect(_refresh_crew_grid)
	_build_ui()


# === UI BUILDING ===

func _build_ui() -> void:
	# Header row
	var header: HBoxContainer = HBoxContainer.new()
	var back_btn: Button = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(80, 32)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back_btn)

	var title: Label = Label.new()
	title.text = "  SHIP — %s  (%s-class)" % [GameManager.ship_name, GameManager.ship_class.capitalize()]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	header.add_child(title)

	var crew_status: Label = Label.new()
	crew_status.text = "Crew: %d/%d" % [GameManager.get_crew_count(), GameManager.crew_max]
	crew_status.add_theme_font_size_override("font_size", 13)
	header.add_child(crew_status)
	add_child(header)

	# Ship status bar
	var status_row: HBoxContainer = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 16)

	var hull_lbl: Label = Label.new()
	hull_lbl.text = "Hull: %d/%d" % [GameManager.hull_current, GameManager.hull_max]
	hull_lbl.add_theme_font_size_override("font_size", 11)
	status_row.add_child(hull_lbl)

	var fuel_lbl: Label = Label.new()
	fuel_lbl.text = "Fuel: %.0f/%.0f" % [GameManager.fuel_current, GameManager.fuel_max]
	fuel_lbl.add_theme_font_size_override("font_size", 11)
	status_row.add_child(fuel_lbl)

	var cargo_lbl: Label = Label.new()
	cargo_lbl.text = "Cargo: %d/%d" % [GameManager.get_total_cargo(), GameManager.cargo_max]
	cargo_lbl.add_theme_font_size_override("font_size", 11)
	status_row.add_child(cargo_lbl)

	var food_lbl: Label = Label.new()
	food_lbl.text = "Food: %s" % GameManager.get_food_days_remaining()
	food_lbl.add_theme_font_size_override("font_size", 11)
	status_row.add_child(food_lbl)

	# Ship-wide morale indicator (only when crew exists)
	if GameManager.get_crew_count() > 0:
		var morale_word: String = GameManager.get_ship_morale_word()
		var morale_color: String = GameManager.get_ship_morale_color()
		var morale_lbl: Label = Label.new()
		morale_lbl.text = "Crew Morale: %s" % morale_word
		morale_lbl.add_theme_font_size_override("font_size", 11)
		morale_lbl.add_theme_color_override("font_color", Color(morale_color))
		status_row.add_child(morale_lbl)

	add_child(status_row)
	add_child(HSeparator.new())

	if GameManager.crew_max <= 0:
		var no_crew: Label = Label.new()
		no_crew.text = "Your ship has no crew berths. Upgrade to a Corvette or Frigate to recruit crew."
		no_crew.add_theme_color_override("font_color", Color(COLOR_MUTED))
		no_crew.add_theme_font_size_override("font_size", 12)
		no_crew.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(no_crew)
		return

	# Main content: scrollable area with grid + detail panel
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)

	# Section label
	var grid_label: Label = Label.new()
	grid_label.text = "CREW ROSTER"
	grid_label.add_theme_font_size_override("font_size", 12)
	grid_label.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	content.add_child(grid_label)

	# Crew grid
	crew_grid = GridContainer.new()
	crew_grid.columns = _get_grid_columns()
	crew_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew_grid.add_theme_constant_override("h_separation", 6)
	crew_grid.add_theme_constant_override("v_separation", 6)
	_populate_crew_grid()
	content.add_child(crew_grid)

	content.add_child(HSeparator.new())

	# Detail panel (shown when a crew member is selected)
	detail_panel = VBoxContainer.new()
	detail_panel.add_theme_constant_override("separation", 4)
	content.add_child(detail_panel)

	scroll_container.add_child(content)
	add_child(scroll_container)


func _get_grid_columns() -> int:
	match GameManager.ship_class:
		"corvette":
			return 2
		"frigate":
			return 3
		_:
			return 2


# === CREW GRID ===

func _populate_crew_grid() -> void:
	if crew_grid == null:
		return

	for child: Node in crew_grid.get_children():
		child.queue_free()

	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	var total_slots: int = GameManager.crew_max

	# Add filled slots
	for cm: CrewMember in roster:
		crew_grid.add_child(_make_crew_slot(cm))

	# Add empty slots
	var filled: int = roster.size()
	for i: int in range(filled, total_slots):
		crew_grid.add_child(_make_empty_slot())


func _make_crew_slot(cm: CrewMember) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 60)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)

	# Name row with status dot
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)

	var dot: Label = Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 10)
	dot.add_theme_color_override("font_color", Color(cm.get_status_color()))
	name_row.add_child(dot)

	var name_lbl: Label = Label.new()
	name_lbl.text = cm.crew_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(cm.get_species_color()))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)
	vbox.add_child(name_row)

	# Role and species
	var info_lbl: Label = Label.new()
	info_lbl.text = "%s — %s" % [cm.get_role_name(), cm.get_species_name()]
	info_lbl.add_theme_font_size_override("font_size", 10)
	info_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	vbox.add_child(info_lbl)

	# Select button
	var select_btn: Button = Button.new()
	select_btn.text = "Profile"
	select_btn.custom_minimum_size = Vector2(0, 24)
	select_btn.add_theme_font_size_override("font_size", 10)
	select_btn.pressed.connect(_on_crew_selected.bind(cm))
	vbox.add_child(select_btn)

	card.add_child(vbox)
	return card


func _make_empty_slot() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 60)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var empty_lbl: Label = Label.new()
	empty_lbl.text = "— Empty Berth —"
	empty_lbl.add_theme_font_size_override("font_size", 12)
	empty_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(empty_lbl)

	var hint_lbl: Label = Label.new()
	hint_lbl.text = "Visit a Recruitment Station"
	hint_lbl.add_theme_font_size_override("font_size", 9)
	hint_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint_lbl)

	card.add_child(vbox)
	return card


func _refresh_crew_grid() -> void:
	_populate_crew_grid()
	# Clear detail panel if selected crew was dismissed
	if selected_crew_id >= 0:
		var crew_data: Dictionary = DatabaseManager.get_crew_member(selected_crew_id)
		if crew_data.is_empty() or not bool(crew_data.get("is_active", 0)):
			_clear_detail_panel()


# === CREW PROFILE DETAIL ===

func _on_crew_selected(cm: CrewMember) -> void:
	selected_crew_id = cm.id
	_show_crew_profile(cm)


func _show_crew_profile(cm: CrewMember) -> void:
	_clear_detail_panel()

	# Profile header
	var prof_header: Label = Label.new()
	prof_header.text = "CREW PROFILE"
	prof_header.add_theme_font_size_override("font_size", 12)
	prof_header.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	detail_panel.add_child(prof_header)

	# Name, species, role
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)

	var name_lbl: Label = Label.new()
	name_lbl.text = cm.crew_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(cm.get_species_color()))
	name_row.add_child(name_lbl)

	var species_role: Label = Label.new()
	species_role.text = "%s %s" % [cm.get_species_name(), cm.get_role_name()]
	species_role.add_theme_font_size_override("font_size", 13)
	name_row.add_child(species_role)

	var hired_lbl: Label = Label.new()
	hired_lbl.text = "  (Hired day %d)" % cm.hired_day
	hired_lbl.add_theme_font_size_override("font_size", 11)
	hired_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	name_row.add_child(hired_lbl)

	detail_panel.add_child(name_row)

	# Stat bars
	detail_panel.add_child(_make_full_stat_bars(cm))

	# Morale / Fatigue / Loyalty bars
	detail_panel.add_child(_make_condition_bars(cm))

	# Personality
	var pers_lbl: Label = Label.new()
	pers_lbl.text = cm.personality
	pers_lbl.add_theme_font_size_override("font_size", 11)
	pers_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	detail_panel.add_child(pers_lbl)

	# Species trait
	var trait_lbl: Label = Label.new()
	trait_lbl.text = "Species: %s" % cm.get_species_trait_text()
	trait_lbl.add_theme_font_size_override("font_size", 11)
	trait_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(trait_lbl)

	# Relationships
	_add_relationship_summary(cm)

	# Placeholders for future tiers
	var memory_lbl: Label = Label.new()
	memory_lbl.text = "Formative memories: None yet. (Phase 4)"
	memory_lbl.add_theme_font_size_override("font_size", 10)
	memory_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	detail_panel.add_child(memory_lbl)

	var traits_lbl: Label = Label.new()
	traits_lbl.text = "Acquired traits: None yet. (Phase 4)"
	traits_lbl.add_theme_font_size_override("font_size", 10)
	traits_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	detail_panel.add_child(traits_lbl)

	# Dismiss button
	detail_panel.add_child(HSeparator.new())

	var dismiss_row: HBoxContainer = HBoxContainer.new()
	dismiss_row.add_theme_constant_override("separation", 8)

	var dismiss_btn: Button = Button.new()
	dismiss_btn.text = "Dismiss Crew Member"
	dismiss_btn.custom_minimum_size = Vector2(160, 32)
	dismiss_btn.add_theme_font_size_override("font_size", 12)
	dismiss_btn.pressed.connect(_on_dismiss_pressed.bind(cm))
	dismiss_row.add_child(dismiss_btn)

	detail_panel.add_child(dismiss_row)


func _make_full_stat_bars(cm: CrewMember) -> VBoxContainer:
	## Creates detailed stat bars with effective values.
	var container: VBoxContainer = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var stats: Array[Array] = [
		["Stamina", cm.stamina, cm.get_effective_stat("stamina")],
		["Cognition", cm.cognition, cm.get_effective_stat("cognition")],
		["Reflexes", cm.reflexes, cm.get_effective_stat("reflexes")],
		["Social", cm.social, cm.get_effective_stat("social")],
		["Resourcefulness", cm.resourcefulness, cm.get_effective_stat("resourcefulness")],
	]

	# Identify primary stat
	var primary: String = CrewMember.ROLE_PRIMARY_STAT.get(cm.role, "resourcefulness")

	for stat: Array in stats:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var label: Label = Label.new()
		label.text = stat[0]
		label.add_theme_font_size_override("font_size", 11)
		label.custom_minimum_size = Vector2(100, 0)

		# Highlight primary stat
		var stat_key: String = stat[0].to_lower()
		if stat_key == primary:
			label.add_theme_color_override("font_color", Color(COLOR_ACCENT))
			label.text += " ★"
		else:
			label.add_theme_color_override("font_color", Color(COLOR_MUTED))
		row.add_child(label)

		var bar: ProgressBar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = stat[1]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(80, 14)
		row.add_child(bar)

		var val_lbl: Label = Label.new()
		val_lbl.text = "%d (eff: %.0f)" % [stat[1], stat[2]]
		val_lbl.add_theme_font_size_override("font_size", 10)
		val_lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(val_lbl)

		container.add_child(row)

	return container


func _make_condition_bars(cm: CrewMember) -> HBoxContainer:
	## Creates morale, fatigue, loyalty bars.
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	# Morale
	var morale_box: HBoxContainer = HBoxContainer.new()
	morale_box.add_theme_constant_override("separation", 4)

	var morale_label: Label = Label.new()
	morale_label.text = "Morale:"
	morale_label.add_theme_font_size_override("font_size", 11)
	morale_box.add_child(morale_label)

	var morale_bar: ProgressBar = ProgressBar.new()
	morale_bar.min_value = 0
	morale_bar.max_value = 100
	morale_bar.value = cm.morale
	morale_bar.show_percentage = false
	morale_bar.custom_minimum_size = Vector2(60, 12)
	morale_box.add_child(morale_bar)

	var morale_val: Label = Label.new()
	morale_val.text = "%.0f" % cm.morale
	morale_val.add_theme_font_size_override("font_size", 10)
	var morale_color: String = COLOR_GOOD if cm.morale > 60.0 else (COLOR_BAD if cm.morale < 30.0 else COLOR_WARN)
	morale_val.add_theme_color_override("font_color", Color(morale_color))
	morale_box.add_child(morale_val)
	row.add_child(morale_box)

	# Fatigue
	var fatigue_box: HBoxContainer = HBoxContainer.new()
	fatigue_box.add_theme_constant_override("separation", 4)

	var fatigue_label: Label = Label.new()
	fatigue_label.text = "Fatigue:"
	fatigue_label.add_theme_font_size_override("font_size", 11)
	fatigue_box.add_child(fatigue_label)

	var fatigue_bar: ProgressBar = ProgressBar.new()
	fatigue_bar.min_value = 0
	fatigue_bar.max_value = 100
	fatigue_bar.value = cm.fatigue
	fatigue_bar.show_percentage = false
	fatigue_bar.custom_minimum_size = Vector2(60, 12)
	fatigue_box.add_child(fatigue_bar)

	var fatigue_val: Label = Label.new()
	fatigue_val.text = "%.0f" % cm.fatigue
	fatigue_val.add_theme_font_size_override("font_size", 10)
	var fatigue_color: String = COLOR_GOOD if cm.fatigue < 40.0 else (COLOR_BAD if cm.fatigue > 70.0 else COLOR_WARN)
	fatigue_val.add_theme_color_override("font_color", Color(fatigue_color))
	fatigue_box.add_child(fatigue_val)
	row.add_child(fatigue_box)

	# Loyalty
	var loyalty_box: HBoxContainer = HBoxContainer.new()
	loyalty_box.add_theme_constant_override("separation", 4)

	var loyalty_label: Label = Label.new()
	loyalty_label.text = "Loyalty:"
	loyalty_label.add_theme_font_size_override("font_size", 11)
	loyalty_box.add_child(loyalty_label)

	var loyalty_bar: ProgressBar = ProgressBar.new()
	loyalty_bar.min_value = 0
	loyalty_bar.max_value = 100
	loyalty_bar.value = cm.loyalty
	loyalty_bar.show_percentage = false
	loyalty_bar.custom_minimum_size = Vector2(60, 12)
	loyalty_box.add_child(loyalty_bar)

	var loyalty_val: Label = Label.new()
	loyalty_val.text = "%.0f" % cm.loyalty
	loyalty_val.add_theme_font_size_override("font_size", 10)
	loyalty_box.add_child(loyalty_val)
	row.add_child(loyalty_box)

	return row


func _add_relationship_summary(cm: CrewMember) -> void:
	## Adds relationship lines for this crew member.
	var relationships: Array = DatabaseManager.get_crew_relationships(cm.id)
	if relationships.is_empty():
		var no_rel: Label = Label.new()
		no_rel.text = "No crew relationships."
		no_rel.add_theme_font_size_override("font_size", 10)
		no_rel.add_theme_color_override("font_color", Color(COLOR_MUTED))
		detail_panel.add_child(no_rel)
		return

	var rel_header: Label = Label.new()
	rel_header.text = "Relationships:"
	rel_header.add_theme_font_size_override("font_size", 11)
	rel_header.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	detail_panel.add_child(rel_header)

	for rel: Dictionary in relationships:
		# Figure out who the other person is
		var other_id: int = rel.crew_b_id if rel.crew_a_id == cm.id else rel.crew_a_id
		var other_data: Dictionary = DatabaseManager.get_crew_member(other_id)
		if other_data.is_empty():
			continue
		var other_name: String = other_data.get("name", "Unknown")
		var value: float = rel.get("value", 0.0)

		var rel_lbl: Label = Label.new()
		var color: String
		var descriptor: String
		if value > 50.0:
			color = COLOR_GOOD
			descriptor = "Friendly"
		elif value > 20.0:
			color = COLOR_GOOD
			descriptor = "Warm"
		elif value >= -20.0:
			color = COLOR_MUTED
			descriptor = "Neutral"
		elif value >= -50.0:
			color = COLOR_WARN
			descriptor = "Tense"
		else:
			color = COLOR_BAD
			descriptor = "Hostile"

		rel_lbl.text = "  %s: %s (%+.0f)" % [other_name, descriptor, value]
		rel_lbl.add_theme_font_size_override("font_size", 10)
		rel_lbl.add_theme_color_override("font_color", Color(color))
		detail_panel.add_child(rel_lbl)


func _clear_detail_panel() -> void:
	if detail_panel == null:
		return
	for child: Node in detail_panel.get_children():
		child.queue_free()
	selected_crew_id = -1


# === DISMISS FLOW ===

func _on_dismiss_pressed(cm: CrewMember) -> void:
	## Shows confirmation before dismissing.
	_clear_detail_panel()

	var confirm_lbl: Label = Label.new()
	confirm_lbl.text = "Dismiss %s (%s %s)? This cannot be undone." % [
		cm.crew_name, cm.get_species_name(), cm.get_role_name()]
	confirm_lbl.add_theme_font_size_override("font_size", 13)
	confirm_lbl.add_theme_color_override("font_color", Color(COLOR_BAD))
	confirm_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(confirm_lbl)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "Confirm Dismiss"
	confirm_btn.custom_minimum_size = Vector2(130, 32)
	confirm_btn.add_theme_font_size_override("font_size", 12)
	confirm_btn.pressed.connect(_confirm_dismiss.bind(cm))
	btn_row.add_child(confirm_btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 32)
	cancel_btn.add_theme_font_size_override("font_size", 12)
	cancel_btn.pressed.connect(_show_crew_profile.bind(cm))
	btn_row.add_child(cancel_btn)

	detail_panel.add_child(btn_row)


func _confirm_dismiss(cm: CrewMember) -> void:
	var dismiss_text: String = TextTemplates.get_dismiss_text(cm.crew_name)
	GameManager.dismiss_crew(cm.id)
	log_message.emit("[color=%s]%s[/color]" % [COLOR_MUTED, dismiss_text])
	_clear_detail_panel()
	_populate_crew_grid()
