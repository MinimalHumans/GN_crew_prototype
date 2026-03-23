class_name WellnessView
extends VBoxContainer
## WellnessView — Premium rest service. Full fatigue reset, significant morale boost.
## Available at Haven, Lirien, Korrath Prime, Tessara only.

signal back_pressed
signal log_message(text: String)

var planet_id: int = -1
var _treated_this_visit: Dictionary = {}  # {crew_id: true}

const WELLNESS_COST: int = 80
const WELLNESS_DAYS: int = 2

# Color constants
const COLOR_GOOD: String = "#27AE60"
const COLOR_BAD: String = "#C0392B"
const COLOR_MUTED: String = "#718096"
const COLOR_ACCENT: String = "#4A90D9"
const COLOR_CREDITS: String = "#E6D159"

# UI refs
var credits_label: Label
var content_container: VBoxContainer


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
	title.text = "  WELLNESS RETREAT"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)

	credits_label = Label.new()
	credits_label.text = "%d cr" % GameManager.credits
	credits_label.add_theme_color_override("font_color", Color(COLOR_CREDITS))
	header.add_child(credits_label)
	add_child(header)

	# Time cost notice
	var notice: Label = Label.new()
	notice.text = "Premium rest and recovery. Cost: %d credits per crew member. Time: %d days per session." % [WELLNESS_COST, WELLNESS_DAYS]
	notice.add_theme_font_size_override("font_size", 16)
	notice.add_theme_color_override("font_color", Color(COLOR_MUTED))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_container)

	_refresh_all()


# === REFRESH ===

func _refresh_all() -> void:
	if credits_label:
		credits_label.text = "%d cr" % GameManager.credits
	if not content_container:
		return
	for child: Node in content_container.get_children():
		child.queue_free()

	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No crew to treat."
		empty_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		empty_lbl.add_theme_font_size_override("font_size", 21)
		content_container.add_child(empty_lbl)
		return

	# Treat All button
	var untreated_count: int = 0
	for cm: CrewMember in roster:
		if not _treated_this_visit.has(cm.id):
			untreated_count += 1

	if untreated_count > 0:
		var total_cost: int = WELLNESS_COST * untreated_count
		var treat_all_btn: Button = Button.new()
		treat_all_btn.text = "Treat All Untreated (%d cr, %d days)" % [total_cost, WELLNESS_DAYS]
		treat_all_btn.custom_minimum_size = Vector2(0, 48)
		treat_all_btn.add_theme_font_size_override("font_size", 18)
		treat_all_btn.disabled = GameManager.credits < total_cost
		treat_all_btn.pressed.connect(func() -> void: _treat_all())
		content_container.add_child(treat_all_btn)
		content_container.add_child(HSeparator.new())

	for cm: CrewMember in roster:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var info: Label = Label.new()
		info.text = "%s — Morale: %.0f  Fatigue: %.0f" % [cm.crew_name, cm.morale, cm.fatigue]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 18)
		if cm.grief_state == "GRIEVING":
			info.text += "  [Grieving]"
		row.add_child(info)

		if _treated_this_visit.has(cm.id):
			var done_lbl: Label = Label.new()
			done_lbl.text = "Treated"
			done_lbl.add_theme_font_size_override("font_size", 15)
			done_lbl.add_theme_color_override("font_color", Color(COLOR_GOOD))
			row.add_child(done_lbl)
		else:
			var treat_btn: Button = Button.new()
			treat_btn.text = "Treat (%d cr, %d days)" % [WELLNESS_COST, WELLNESS_DAYS]
			treat_btn.custom_minimum_size = Vector2(220, 42)
			treat_btn.add_theme_font_size_override("font_size", 15)
			treat_btn.disabled = GameManager.credits < WELLNESS_COST
			var cm_id: int = cm.id
			treat_btn.pressed.connect(func() -> void: _treat_crew_member(cm_id))
			row.add_child(treat_btn)

		content_container.add_child(row)


# === TREATMENT ===

func _treat_crew_member(crew_id: int) -> void:
	var cm: CrewMember = _get_crew_member(crew_id)
	if cm == null:
		return
	if not GameManager.spend_credits(WELLNESS_COST):
		log_message.emit("[color=%s]Not enough credits.[/color]" % COLOR_BAD)
		return

	GameManager.advance_docked_day(WELLNESS_DAYS)

	cm.fatigue = 0.0
	var morale_boost: float = 20.0 if cm.morale < 40.0 else 10.0
	cm.morale = clampf(cm.morale + morale_boost, 0.0, 100.0)

	var update_data: Dictionary = {
		"fatigue": 0.0,
		"morale": cm.morale,
	}

	# Grief acceleration
	if cm.grief_state == "GRIEVING" and cm.grief_ticks_remaining > 0:
		cm.grief_ticks_remaining = maxi(0, cm.grief_ticks_remaining - 5)
		update_data["grief_ticks_remaining"] = cm.grief_ticks_remaining
		log_message.emit("[color=%s]The quiet time helps %s process their grief.[/color]" % [COLOR_MUTED, cm.crew_name])

	DatabaseManager.update_crew_member(cm.id, update_data)

	log_message.emit("[color=%s]%s emerges from the retreat looking renewed. Fatigue cleared, morale boosted. %d days passed.[/color]" % [
		COLOR_GOOD, cm.crew_name, WELLNESS_DAYS])
	log_message.emit("[color=#555B66]  ↳ Fatigue reset. Morale +%.0f.[/color]" % morale_boost)

	_treated_this_visit[cm.id] = true
	GameManager.save_game()
	_refresh_all()


func _treat_all() -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	var untreated: Array[CrewMember] = []
	for cm: CrewMember in roster:
		if not _treated_this_visit.has(cm.id):
			untreated.append(cm)

	var total_cost: int = WELLNESS_COST * untreated.size()
	if not GameManager.spend_credits(total_cost):
		log_message.emit("[color=%s]Not enough credits.[/color]" % COLOR_BAD)
		return

	GameManager.advance_docked_day(WELLNESS_DAYS)

	for cm: CrewMember in untreated:
		cm.fatigue = 0.0
		var morale_boost: float = 20.0 if cm.morale < 40.0 else 10.0
		cm.morale = clampf(cm.morale + morale_boost, 0.0, 100.0)

		var update_data: Dictionary = {
			"fatigue": 0.0,
			"morale": cm.morale,
		}

		if cm.grief_state == "GRIEVING" and cm.grief_ticks_remaining > 0:
			cm.grief_ticks_remaining = maxi(0, cm.grief_ticks_remaining - 5)
			update_data["grief_ticks_remaining"] = cm.grief_ticks_remaining

		DatabaseManager.update_crew_member(cm.id, update_data)
		_treated_this_visit[cm.id] = true

	log_message.emit("[color=%s]The entire crew enjoys the retreat. Everyone refreshed. %d days passed.[/color]" % [
		COLOR_GOOD, WELLNESS_DAYS])

	GameManager.save_game()
	_refresh_all()


func _get_crew_member(crew_id: int) -> CrewMember:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	for cm: CrewMember in roster:
		if cm.id == crew_id:
			return cm
	return null
