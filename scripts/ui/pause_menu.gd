extends CanvasLayer
## PauseMenu — Escape-key overlay accessible from any game screen.
## Contains Resume, Save, Main Menu (with confirmation), and Debug Tools.

# === CONSTANTS ===
const BG_COLOR: Color = Color(0.05, 0.05, 0.12, 0.85)
const PANEL_COLOR: Color = Color(0.1, 0.1, 0.18, 1.0)
const ACCENT_COLOR: Color = Color(0.29, 0.565, 0.851)  # #4A90D9
const TEXT_COLOR: Color = Color(0.969, 0.98, 0.988)  # #F7FAFC
const MUTED_COLOR: Color = Color(0.443, 0.502, 0.588)  # #718096
const SUCCESS_COLOR: Color = Color(0.153, 0.682, 0.376)  # #27AE60
const WARN_COLOR: Color = Color(0.902, 0.494, 0.133)  # #E67E22
const DANGER_COLOR: Color = Color(0.753, 0.224, 0.169)  # #C0392B
const BUTTON_MIN_HEIGHT: float = 36.0
const DEBUG_BUTTON_MIN_HEIGHT: float = 30.0

# === STATE ===
var _is_open: bool = false
var _confirm_visible: bool = false
var _debug_expanded: bool = false

# === NODE REFERENCES ===
var _overlay: ColorRect
var _panel: PanelContainer
var _main_vbox: VBoxContainer
var _confirm_dialog: VBoxContainer
var _debug_section: VBoxContainer
var _debug_toggle: Button
var _feedback_label: Label


# === INITIALIZATION ===

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if not GameManager.is_game_active:
				return
			if _confirm_visible:
				_hide_confirm()
			elif _is_open:
				_close()
			else:
				_open()
			get_viewport().set_input_as_handled()


# === BUILD UI ===

func _build_ui() -> void:
	# Full-screen dark overlay
	_overlay = ColorRect.new()
	_overlay.color = BG_COLOR
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Centered panel
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(360, 0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(_main_vbox)

	# Title
	var title: Label = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	title.add_theme_font_size_override("font_size", 22)
	_main_vbox.add_child(title)

	_add_separator(_main_vbox)

	# Resume
	var resume_btn: Button = _create_button("Resume", BUTTON_MIN_HEIGHT)
	resume_btn.pressed.connect(_close)
	_main_vbox.add_child(resume_btn)

	# Save
	var save_btn: Button = _create_button("Save Game", BUTTON_MIN_HEIGHT)
	save_btn.pressed.connect(_on_save_pressed)
	_main_vbox.add_child(save_btn)

	# Main Menu
	var menu_btn: Button = _create_button("Main Menu", BUTTON_MIN_HEIGHT)
	menu_btn.pressed.connect(_show_confirm)
	_main_vbox.add_child(menu_btn)

	# Feedback label (for save confirmation, debug feedback)
	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 13)
	_feedback_label.add_theme_color_override("font_color", SUCCESS_COLOR)
	_main_vbox.add_child(_feedback_label)

	# Confirmation dialog (hidden by default)
	_confirm_dialog = VBoxContainer.new()
	_confirm_dialog.add_theme_constant_override("separation", 6)
	_confirm_dialog.visible = false
	_main_vbox.add_child(_confirm_dialog)

	var confirm_label: Label = Label.new()
	confirm_label.text = "Save and return to main menu?"
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.add_theme_color_override("font_color", WARN_COLOR)
	confirm_label.add_theme_font_size_override("font_size", 14)
	_confirm_dialog.add_child(confirm_label)

	var confirm_row: HBoxContainer = HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 12)
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_dialog.add_child(confirm_row)

	var yes_btn: Button = _create_button("Yes, Exit", DEBUG_BUTTON_MIN_HEIGHT)
	yes_btn.pressed.connect(_on_confirm_exit)
	confirm_row.add_child(yes_btn)

	var no_btn: Button = _create_button("Cancel", DEBUG_BUTTON_MIN_HEIGHT)
	no_btn.pressed.connect(_hide_confirm)
	confirm_row.add_child(no_btn)

	_add_separator(_main_vbox)

	# Debug Tools toggle
	_debug_toggle = _create_button("▶ Debug Tools", DEBUG_BUTTON_MIN_HEIGHT)
	_debug_toggle.add_theme_color_override("font_color", MUTED_COLOR)
	_debug_toggle.pressed.connect(_toggle_debug)
	_main_vbox.add_child(_debug_toggle)

	# Debug section (hidden by default)
	_debug_section = VBoxContainer.new()
	_debug_section.add_theme_constant_override("separation", 4)
	_debug_section.visible = false
	_main_vbox.add_child(_debug_section)

	_add_debug_button("Add 500 Credits", _debug_add_credits)
	_add_debug_button("Level Up", _debug_level_up)
	_add_debug_button("Full Heal Ship", _debug_full_heal)
	_add_debug_button("Reset Crew Fatigue", _debug_reset_fatigue)
	_add_debug_button("Boost Crew Morale", _debug_boost_morale)
	_add_debug_button("Add 30 Days Food", _debug_add_food)
	_add_debug_button("Force Decision Event", _debug_force_decision)


# === OPEN / CLOSE ===

func _open() -> void:
	_is_open = true
	visible = true
	_feedback_label.text = ""
	_hide_confirm()
	get_tree().paused = true


func _close() -> void:
	_is_open = false
	_confirm_visible = false
	visible = false
	get_tree().paused = false


# === BUTTON HANDLERS ===

func _on_save_pressed() -> void:
	GameManager.save_game()
	_show_feedback("Game saved.", SUCCESS_COLOR)


func _show_confirm() -> void:
	_confirm_visible = true
	_confirm_dialog.visible = true
	_feedback_label.text = ""


func _hide_confirm() -> void:
	_confirm_visible = false
	_confirm_dialog.visible = false


func _on_confirm_exit() -> void:
	GameManager.save_game()
	_close()
	GameManager.is_game_active = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# === DEBUG TOOLS ===

func _toggle_debug() -> void:
	_debug_expanded = not _debug_expanded
	_debug_section.visible = _debug_expanded
	_debug_toggle.text = "▼ Debug Tools" if _debug_expanded else "▶ Debug Tools"


func _debug_add_credits() -> void:
	GameManager.add_credits(500)
	_show_feedback("+500 credits (now %d)" % GameManager.credits, SUCCESS_COLOR)


func _debug_level_up() -> void:
	if GameManager.captain_level >= GameManager.MAX_LEVEL:
		_show_feedback("Already at max level.", WARN_COLOR)
		return
	var next_xp: int = GameManager.get_xp_for_next_level()
	var needed: int = next_xp - GameManager.captain_xp
	if needed > 0:
		GameManager.add_xp(needed)
	_show_feedback("Leveled up to %d." % GameManager.captain_level, SUCCESS_COLOR)


func _debug_full_heal() -> void:
	GameManager.hull_current = GameManager.hull_max
	if GameManager.current_ship_id >= 0:
		DatabaseManager.update_ship(GameManager.current_ship_id, {"hull_current": GameManager.hull_max})
	EventBus.hull_changed.emit(GameManager.hull_current, GameManager.hull_max)
	_show_feedback("Hull fully repaired (%d/%d)." % [GameManager.hull_current, GameManager.hull_max], SUCCESS_COLOR)


func _debug_reset_fatigue() -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		_show_feedback("No crew to reset.", WARN_COLOR)
		return
	for cm: CrewMember in roster:
		DatabaseManager.update_crew_member(cm.id, {"fatigue": 0.0})
	EventBus.crew_changed.emit()
	_show_feedback("All crew fatigue reset to 0.", SUCCESS_COLOR)


func _debug_boost_morale() -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		_show_feedback("No crew to boost.", WARN_COLOR)
		return
	for cm: CrewMember in roster:
		var new_morale: float = minf(100.0, cm.morale + 30.0)
		DatabaseManager.update_crew_member(cm.id, {"morale": new_morale})
	EventBus.crew_changed.emit()
	_show_feedback("All crew morale boosted +30.", SUCCESS_COLOR)


func _debug_add_food() -> void:
	var food_per_jump: float = GameManager.get_food_cost_per_jump()
	var food_to_add: float = food_per_jump * 30.0
	if food_to_add < 30.0:
		food_to_add = 30.0  # Minimum 30 units even solo
	GameManager.food_supply += food_to_add
	if GameManager.current_ship_id >= 0:
		DatabaseManager.update_ship(GameManager.current_ship_id, {"food_supply": GameManager.food_supply})
	EventBus.food_changed.emit(GameManager.food_supply)
	_show_feedback("+%.0f food (%.0f total)." % [food_to_add, GameManager.food_supply], SUCCESS_COLOR)


func _debug_force_decision() -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		_show_feedback("No crew — can't force decision event.", WARN_COLOR)
		return
	# Temporarily bypass spacing requirement
	var old_ticks: int = GameManager.ticks_since_last_decision
	GameManager.ticks_since_last_decision = 100
	var decision: Dictionary = CrewEventGenerator._check_decision_events(roster)
	if decision.is_empty():
		# No conditions met — force a stowaway as fallback
		GameManager.stowaway_found = false
		decision = CrewEventGenerator._build_stowaway()
	GameManager.ticks_since_last_decision = old_ticks
	EventBus.decision_event_fired.emit(decision)
	_show_feedback("Decision event fired.", SUCCESS_COLOR)
	_close()


# === UI HELPERS ===

func _create_button(label: String, min_height: float) -> Button:
	var btn: Button = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, min_height)
	return btn


func _add_separator(parent: VBoxContainer) -> void:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	parent.add_child(sep)


func _add_debug_button(label: String, callback: Callable) -> void:
	var btn: Button = _create_button(label, DEBUG_BUTTON_MIN_HEIGHT)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(callback)
	_debug_section.add_child(btn)


func _show_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)
	# Auto-clear after 3 seconds
	var timer: SceneTreeTimer = get_tree().create_timer(3.0, true, false, true)
	timer.timeout.connect(func() -> void: _feedback_label.text = "")
