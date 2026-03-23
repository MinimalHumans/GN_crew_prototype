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
var _debug_scroll: ScrollContainer
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
	_panel.custom_minimum_size = Vector2(540, 0)
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

	# Debug section (hidden by default, scrollable)
	_debug_scroll = ScrollContainer.new()
	_debug_scroll.visible = false
	_debug_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debug_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_debug_scroll.custom_minimum_size = Vector2(0, 400)
	_main_vbox.add_child(_debug_scroll)

	_debug_section = VBoxContainer.new()
	_debug_section.add_theme_constant_override("separation", 4)
	_debug_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_scroll.add_child(_debug_section)

	# --- Economy Section ---
	_add_debug_section_header("ECONOMY")
	_add_debug_button("Add 500 Credits", _debug_add_credits)
	_add_debug_button("Add 2,000 Credits (Corvette)", _debug_add_2000)
	_add_debug_button("Add 10,000 Credits (Frigate)", _debug_add_10000)
	_add_debug_button("Show Economy Stats", _debug_economy_stats)
	_add_debug_button("Add 30 Days Food", _debug_add_food)

	# --- Ship Section ---
	_add_debug_section_header("SHIP")
	_add_debug_button("Full Heal Ship", _debug_full_heal)
	_add_debug_button("Level Up", _debug_level_up)
	_add_debug_button("Refuel Ship", _debug_refuel)

	# --- Crew Section ---
	_add_debug_section_header("CREW")
	_add_debug_button("Reset Crew Fatigue", _debug_reset_fatigue)
	_add_debug_button("Boost Crew Morale (+30)", _debug_boost_morale)
	_add_debug_button("Max All Loyalty", _debug_max_loyalty)
	_add_debug_button("Heal All Injuries", _debug_heal_injuries)
	_add_debug_button("Cure All Diseases", _debug_cure_diseases)
	_add_debug_button("Kill Random Crew", _debug_kill_random)

	# --- Simulation Section ---
	_add_debug_section_header("SIMULATION")
	_add_debug_button("Advance 10 Ticks", _debug_advance_10)
	_add_debug_button("Advance 30 Ticks", _debug_advance_30)
	_add_debug_button("Force Decision Event", _debug_force_decision)
	_add_debug_button("Force Retirement Check", _debug_force_retirement)

	# --- Diagnostics Section ---
	_add_debug_section_header("DIAGNOSTICS")
	_add_debug_button("Dump Crew Stats", _debug_dump_crew)
	_add_debug_button("Dump Economy Report", _debug_dump_economy)
	_add_debug_button("Dump Relationship Matrix", _debug_dump_relationships)
	_add_debug_button("Dump Legacy Entries", _debug_dump_legacies)


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
	_debug_scroll.visible = _debug_expanded
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


func _add_debug_section_header(title: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = "— %s —" % title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", ACCENT_COLOR)
	_debug_section.add_child(lbl)


func _debug_add_2000() -> void:
	GameManager.add_credits(2000)
	_show_feedback("+2,000 credits (now %d)" % GameManager.credits, SUCCESS_COLOR)


func _debug_add_10000() -> void:
	GameManager.add_credits(10000)
	_show_feedback("+10,000 credits (now %d)" % GameManager.credits, SUCCESS_COLOR)


func _debug_economy_stats() -> void:
	var earned: int = GameManager.total_credits_earned
	var spent: int = GameManager.total_credits_spent
	var current: int = GameManager.credits
	var days: int = GameManager.day_count
	var daily_rate: String = "%.1f" % (float(spent) / maxf(1.0, float(days)))
	var msg: String = "Credits: %d | Earned: %d | Spent: %d | Burn: %s/day" % [current, earned, spent, daily_rate]
	_show_feedback(msg, ACCENT_COLOR)
	print("[DEBUG] Economy: current=%d, earned=%d, spent=%d, days=%d, burn_rate=%s/day" % [current, earned, spent, days, daily_rate])


func _debug_refuel() -> void:
	GameManager.fuel_current = GameManager.fuel_max
	if GameManager.current_ship_id >= 0:
		DatabaseManager.update_ship(GameManager.current_ship_id, {"fuel_current": GameManager.fuel_max})
	EventBus.fuel_changed.emit(GameManager.fuel_current, GameManager.fuel_max)
	_show_feedback("Fuel refilled (%.0f/%.0f)." % [GameManager.fuel_current, GameManager.fuel_max], SUCCESS_COLOR)


func _debug_max_loyalty() -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		_show_feedback("No crew.", WARN_COLOR)
		return
	for cm: CrewMember in roster:
		DatabaseManager.update_crew_member(cm.id, {"loyalty": 100.0})
	EventBus.crew_changed.emit()
	_show_feedback("All crew loyalty set to 100.", SUCCESS_COLOR)


func _debug_heal_injuries() -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	var healed: int = 0
	for cm: CrewMember in roster:
		if cm.has_injuries():
			DatabaseManager.update_crew_member(cm.id, {"injuries": "[]"})
			healed += 1
	if healed == 0:
		_show_feedback("No injuries to heal.", WARN_COLOR)
	else:
		EventBus.crew_changed.emit()
		_show_feedback("%d crew healed." % healed, SUCCESS_COLOR)


func _debug_cure_diseases() -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	var cured: int = 0
	for cm: CrewMember in roster:
		if cm.has_diseases():
			DatabaseManager.update_crew_member(cm.id, {
				"diseases": "[]",
				"is_quarantined": 0,
				"quarantine_ticks": 0,
			})
			cured += 1
	if cured == 0:
		_show_feedback("No diseases to cure.", WARN_COLOR)
	else:
		EventBus.crew_changed.emit()
		_show_feedback("%d crew cured." % cured, SUCCESS_COLOR)


func _debug_kill_random() -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		_show_feedback("No crew to kill.", WARN_COLOR)
		return
	var victim: CrewMember = roster[randi() % roster.size()]
	var death_events: Array[String] = CrewSimulation.process_crew_death(victim, "debug", roster)
	_show_feedback("%s has died (debug)." % victim.crew_name, DANGER_COLOR)
	for evt: String in death_events:
		print("[DEBUG] Death event: %s" % evt)
	_close()


func _debug_advance_10() -> void:
	_debug_advance_ticks(10)


func _debug_advance_30() -> void:
	_debug_advance_ticks(30)


func _debug_advance_ticks(count: int) -> void:
	_show_feedback("Advancing %d ticks..." % count, ACCENT_COLOR)
	for i: int in range(count):
		GameManager.day_count += 1
		var result: Dictionary = CrewSimulation.tick_jump(false, false, 0, [])
		var events: Array = result.get("events", [])
		for evt: String in events:
			print("[DEBUG] Tick %d: %s" % [i + 1, evt])
	GameManager.save_game()
	EventBus.crew_changed.emit()
	_show_feedback("Advanced %d ticks. Day: %d." % [count, GameManager.day_count], SUCCESS_COLOR)


func _debug_force_retirement() -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		_show_feedback("No crew.", WARN_COLOR)
		return
	var events: Array[String] = CrewSimulation.check_retirement(roster)
	if events.is_empty():
		_show_feedback("No crew eligible for retirement (need loyalty>80, 80+ ticks, morale>60).", WARN_COLOR)
	else:
		_show_feedback("Retirement check fired.", SUCCESS_COLOR)
		_close()


func _debug_dump_crew() -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		_show_feedback("No crew.", WARN_COLOR)
		return
	print("=== CREW STATS DUMP ===")
	for cm: CrewMember in roster:
		print("%s [%s %s] STA:%d COG:%d REF:%d SOC:%d RES:%d | Morale:%.0f Fat:%.0f Loy:%.0f | Traits:%s" % [
			cm.crew_name, cm.get_species_name(), cm.get_role_name(),
			cm.stamina, cm.cognition, cm.reflexes, cm.social, cm.resourcefulness,
			cm.morale, cm.fatigue, cm.loyalty, str(cm.traits)])
	print("======================")
	_show_feedback("Crew stats dumped to console (%d crew)." % roster.size(), SUCCESS_COLOR)


func _debug_dump_economy() -> void:
	print("=== ECONOMY REPORT ===")
	print("Day: %d | Credits: %d" % [GameManager.day_count, GameManager.credits])
	print("Lifetime earned: %d | Lifetime spent: %d" % [GameManager.total_credits_earned, GameManager.total_credits_spent])
	print("Ship class: %s | Hull: %d/%d | Fuel: %.0f/%.0f" % [
		GameManager.ship_class, GameManager.hull_current, GameManager.hull_max,
		GameManager.fuel_current, GameManager.fuel_max])
	print("Food: %.0f | Crew: %d/%d" % [GameManager.food_supply, GameManager.get_crew_roster().size(), GameManager.crew_max])
	print("Win triggered: %s" % str(GameManager.win_triggered))
	print("Hardcore hull: %s" % str(GameManager.hardcore_hull))
	print("======================")
	_show_feedback("Economy report dumped to console.", SUCCESS_COLOR)


func _debug_dump_relationships() -> void:
	var rels: Array = DatabaseManager.get_all_crew_relationships(GameManager.save_id)
	if rels.is_empty():
		_show_feedback("No relationships.", WARN_COLOR)
		return
	print("=== RELATIONSHIP MATRIX ===")
	for rel: Dictionary in rels:
		var name_a: String = DatabaseManager.get_crew_member(rel.crew_a_id).get("name", "?")
		var name_b: String = DatabaseManager.get_crew_member(rel.crew_b_id).get("name", "?")
		var romantic: String = " [ROMANCE]" if rel.get("is_romantic", 0) == 1 else ""
		print("%s <-> %s : %.1f%s" % [name_a, name_b, rel.value, romantic])
	print("===========================")
	_show_feedback("Relationship matrix dumped (%d pairs)." % rels.size(), SUCCESS_COLOR)


func _debug_dump_legacies() -> void:
	var legacies: Array = DatabaseManager.get_crew_legacies(GameManager.save_id)
	if legacies.is_empty():
		_show_feedback("No legacy entries.", WARN_COLOR)
		return
	print("=== LEGACY ENTRIES ===")
	for leg: Dictionary in legacies:
		print("[Day %d] %s (%s) — %s: %s | Effect: %s=%.1f (%s ticks)" % [
			leg.get("day_departed", 0), leg.get("crew_name", "?"), leg.get("crew_role", "?"),
			leg.get("departure_type", "?"), leg.get("legacy_text", ""),
			leg.get("effect_type", "none"), leg.get("effect_value", 0.0),
			str(leg.get("effect_ticks_remaining", -1))])
	print("======================")
	_show_feedback("Legacy entries dumped (%d entries)." % legacies.size(), SUCCESS_COLOR)


func _show_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)
	# Auto-clear after 3 seconds
	var timer: SceneTreeTimer = get_tree().create_timer(3.0, true, false, true)
	timer.timeout.connect(func() -> void: _feedback_label.text = "")
