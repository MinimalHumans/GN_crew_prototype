class_name TrainingView
extends VBoxContainer
## TrainingView — Per-crew training sessions that directly add role_experience.
## Available at capitals and research stations; combat-only at frontier/stronghold.

signal back_pressed
signal log_message(text: String)

var planet_id: int = -1

const ROLE_TRAINING_XP: float = 15.0
const CROSS_TRAINING_XP: float = 8.0
const TRAINING_COST: int = 30
const CROSS_TRAINING_COST: int = 40

# Combat-only roles for frontier/stronghold planets
const COMBAT_ROLES: Array[String] = ["Gunner", "Security Chief"]

# Color constants
const COLOR_GOOD: String = "#27AE60"
const COLOR_BAD: String = "#C0392B"
const COLOR_MUTED: String = "#718096"
const COLOR_ACCENT: String = "#4A90D9"
const COLOR_CREDITS: String = "#E6D159"

# UI refs
var credits_label: Label
var content_container: VBoxContainer
var _cross_train_target_cm: CrewMember = null


func _init(p_planet_id: int = -1) -> void:
	planet_id = p_planet_id


func _ready() -> void:
	if planet_id < 0:
		return
	_build_ui()
	EventBus.credits_changed.connect(func(_n: int) -> void: _refresh_all())
	EventBus.crew_changed.connect(func() -> void: _refresh_all())


# === UI BUILDING ===

func _build_ui() -> void:
	var header: HBoxContainer = HBoxContainer.new()
	var back_btn: Button = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(120, 48)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back_btn)

	var title: Label = Label.new()
	title.text = "  TRAINING FACILITY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)

	credits_label = Label.new()
	credits_label.text = "%d cr" % GameManager.credits
	credits_label.add_theme_color_override("font_color", Color(COLOR_CREDITS))
	header.add_child(credits_label)
	add_child(header)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_container)

	_refresh_all()


func _is_combat_only() -> bool:
	var planet: Dictionary = DatabaseManager.get_planet(planet_id)
	var ptype: String = planet.get("type", "hub")
	return ptype in ["frontier", "stronghold", "mining"]


# === REFRESH ===

func _refresh_all() -> void:
	if credits_label:
		credits_label.text = "%d cr" % GameManager.credits
	if not content_container:
		return
	for child: Node in content_container.get_children():
		child.queue_free()

	_cross_train_target_cm = null

	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No crew to train."
		empty_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		empty_lbl.add_theme_font_size_override("font_size", 21)
		content_container.add_child(empty_lbl)
		return

	var combat_only: bool = _is_combat_only()
	if combat_only:
		var note_lbl: Label = Label.new()
		note_lbl.text = "This facility specializes in combat training only (Gunner, Security Chief)."
		note_lbl.add_theme_font_size_override("font_size", 16)
		note_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_container.add_child(note_lbl)

	for cm: CrewMember in roster:
		var section: VBoxContainer = VBoxContainer.new()
		section.add_theme_constant_override("separation", 4)

		# Crew member info
		var info_row: HBoxContainer = HBoxContainer.new()
		info_row.add_theme_constant_override("separation", 12)
		var name_lbl: Label = Label.new()
		name_lbl.text = "%s — %s (%s)" % [cm.crew_name, cm.get_role_name(), cm.get_growth_label()]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 18)
		info_row.add_child(name_lbl)

		var stat_lbl: Label = Label.new()
		stat_lbl.text = "Morale: %.0f  Fatigue: %.0f" % [cm.morale, cm.fatigue]
		stat_lbl.add_theme_font_size_override("font_size", 15)
		stat_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		info_row.add_child(stat_lbl)
		section.add_child(info_row)

		# Buttons
		var btn_row: HBoxContainer = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)

		# Role Training button
		var role_name: String = cm.get_role_name()
		var can_role_train: bool = true
		if combat_only and role_name not in COMBAT_ROLES:
			can_role_train = false

		var train_btn: Button = Button.new()
		train_btn.text = "Train %s (%d cr, 1 day)" % [role_name, TRAINING_COST]
		train_btn.custom_minimum_size = Vector2(0, 42)
		train_btn.add_theme_font_size_override("font_size", 15)
		train_btn.disabled = GameManager.credits < TRAINING_COST or not can_role_train
		var cm_id: int = cm.id
		train_btn.pressed.connect(func() -> void: _train_role(cm_id))
		btn_row.add_child(train_btn)

		# Cross-Train button
		var cross_btn: Button = Button.new()
		cross_btn.text = "Cross-Train (%d cr, 1 day)" % CROSS_TRAINING_COST
		cross_btn.custom_minimum_size = Vector2(0, 42)
		cross_btn.add_theme_font_size_override("font_size", 15)
		cross_btn.disabled = GameManager.credits < CROSS_TRAINING_COST
		cross_btn.pressed.connect(func() -> void: _show_cross_train_options(cm_id))
		btn_row.add_child(cross_btn)

		section.add_child(btn_row)
		section.add_child(HSeparator.new())
		content_container.add_child(section)


# === TRAINING ACTIONS ===

func _train_role(crew_id: int) -> void:
	var cm: CrewMember = _get_crew_member(crew_id)
	if cm == null:
		return
	if not GameManager.spend_credits(TRAINING_COST):
		log_message.emit("[color=%s]Not enough credits.[/color]" % COLOR_BAD)
		return

	GameManager.advance_docked_day(1)

	var old_label: String = cm.get_growth_label()
	cm.add_role_experience(ROLE_TRAINING_XP)
	cm.ticks_since_role_used = 0

	DatabaseManager.update_crew_member(cm.id, {
		"role_experience": cm.role_experience,
		"ticks_since_role_used": 0,
	})

	var new_label: String = cm.get_growth_label()
	if new_label != old_label:
		log_message.emit("[color=%s]%s completes training — now %s! 1 day passed.[/color]" % [COLOR_CREDITS, cm.crew_name, new_label])
		EventBus.crew_skill_gained.emit(cm.id, cm.crew_name, new_label)
	else:
		log_message.emit("[color=%s]%s completes a training session. Experience gained. 1 day passed.[/color]" % [COLOR_GOOD, cm.crew_name])

	GameManager.save_game()
	_refresh_all()


func _show_cross_train_options(crew_id: int) -> void:
	var cm: CrewMember = _get_crew_member(crew_id)
	if cm == null:
		return

	# Replace content with role selection
	for child: Node in content_container.get_children():
		child.queue_free()

	var header_lbl: Label = Label.new()
	header_lbl.text = "Choose cross-training role for %s:" % cm.crew_name
	header_lbl.add_theme_font_size_override("font_size", 21)
	content_container.add_child(header_lbl)

	var combat_only: bool = _is_combat_only()
	var all_roles: Array[String] = ["Gunner", "Engineer", "Navigator", "Medic", "Comms Officer", "Science Officer", "Security Chief"]
	var primary_role: String = cm.get_role_name()

	for role_name: String in all_roles:
		if role_name == primary_role:
			continue
		if combat_only and role_name not in COMBAT_ROLES:
			continue

		var btn: Button = Button.new()
		var current_xp: float = cm.pinch_hit_experience.get(role_name.to_upper().replace(" ", "_"), 0.0)
		btn.text = "%s (current XP: %.0f)" % [role_name, current_xp]
		btn.custom_minimum_size = Vector2(0, 42)
		btn.add_theme_font_size_override("font_size", 18)
		btn.disabled = GameManager.credits < CROSS_TRAINING_COST
		var role_ref: String = role_name
		var cm_id: int = cm.id
		btn.pressed.connect(func() -> void: _cross_train(cm_id, role_ref))
		content_container.add_child(btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 42)
	cancel_btn.pressed.connect(func() -> void: _refresh_all())
	content_container.add_child(cancel_btn)


func _cross_train(crew_id: int, target_role_name: String) -> void:
	var cm: CrewMember = _get_crew_member(crew_id)
	if cm == null:
		return
	if not GameManager.spend_credits(CROSS_TRAINING_COST):
		log_message.emit("[color=%s]Not enough credits.[/color]" % COLOR_BAD)
		return

	GameManager.advance_docked_day(1)

	cm.add_pinch_hit_experience(target_role_name.to_upper().replace(" ", "_"), CROSS_TRAINING_XP)
	cm.ticks_since_role_used = 0

	DatabaseManager.update_crew_member(cm.id, {
		"pinch_hit_experience": JSON.stringify(cm.pinch_hit_experience),
		"ticks_since_role_used": 0,
	})

	log_message.emit("[color=%s]%s completes cross-training in %s. 1 day passed.[/color]" % [COLOR_GOOD, cm.crew_name, target_role_name])

	GameManager.save_game()
	_refresh_all()


func _get_crew_member(crew_id: int) -> CrewMember:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	for cm: CrewMember in roster:
		if cm.id == crew_id:
			return cm
	return null
