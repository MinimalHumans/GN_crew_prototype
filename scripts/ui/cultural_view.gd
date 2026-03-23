class_name CulturalView
extends VBoxContainer
## CulturalView — Species-specific cultural experiences at faction homeworlds.
## Significant morale/loyalty boost for matching species. Moderate cost, no time cost.

signal back_pressed
signal log_message(text: String)

var planet_id: int = -1
var _attended_this_visit: Dictionary = {}  # {crew_id: true}

const CULTURAL_COST: int = 25

const CULTURAL_EXPERIENCES: Dictionary = {
	"Human": {
		"name": "Civic Ceremony",
		"description": "A formal ceremony celebrating Commonwealth values. Crew observe traditions of order and duty.",
		"matching_morale": 15.0,
		"matching_loyalty": 5.0,
		"tourist_morale": 5.0,
	},
	"Gorvian": {
		"name": "Archive Visit",
		"description": "A guided tour of the Hexarchy's engineering archives. Ancient schematics and technological wonders.",
		"matching_morale": 15.0,
		"matching_loyalty": 5.0,
		"tourist_morale": 5.0,
	},
	"Vellani": {
		"name": "Cultural Performance",
		"description": "A traditional Vellani performance of song and story. The entire crew is invited.",
		"matching_morale": 15.0,
		"matching_loyalty": 5.0,
		"tourist_morale": 5.0,
	},
	"Krellvani": {
		"name": "Honor Sparring",
		"description": "Ritual combat among the Krellvani. Not to the death — but not gentle, either.",
		"matching_morale": 15.0,
		"matching_loyalty": 5.0,
		"tourist_morale": 5.0,
	},
}

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
	title.text = "  CULTURAL SERVICES"
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


# === REFRESH ===

func _refresh_all() -> void:
	if credits_label:
		credits_label.text = "%d cr" % GameManager.credits
	if not content_container:
		return
	for child: Node in content_container.get_children():
		child.queue_free()

	var planet: Dictionary = DatabaseManager.get_planet(planet_id)
	var faction: String = planet.get("faction", "")
	var experience: Dictionary = CULTURAL_EXPERIENCES.get(faction, {})

	if experience.is_empty():
		var none_lbl: Label = Label.new()
		none_lbl.text = "No cultural experiences available here."
		none_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		none_lbl.add_theme_font_size_override("font_size", 21)
		content_container.add_child(none_lbl)
		return

	# Experience description
	var exp_name: Label = Label.new()
	exp_name.text = experience.name
	exp_name.add_theme_font_size_override("font_size", 24)
	exp_name.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	content_container.add_child(exp_name)

	var exp_desc: Label = Label.new()
	exp_desc.text = experience.description
	exp_desc.add_theme_font_size_override("font_size", 16)
	exp_desc.add_theme_color_override("font_color", Color(COLOR_MUTED))
	exp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(exp_desc)

	var cost_lbl: Label = Label.new()
	cost_lbl.text = "Cost: %d credits per crew member. No time cost. %s crew get enhanced benefits." % [CULTURAL_COST, faction]
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	cost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(cost_lbl)

	content_container.add_child(HSeparator.new())

	# Send All button
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No crew to attend."
		empty_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		empty_lbl.add_theme_font_size_override("font_size", 21)
		content_container.add_child(empty_lbl)
		return

	var unattended_count: int = 0
	for cm: CrewMember in roster:
		if not _attended_this_visit.has(cm.id):
			unattended_count += 1

	if unattended_count > 0:
		var send_all_btn: Button = Button.new()
		send_all_btn.text = "Send All (Captain pays %d cr)" % (CULTURAL_COST * unattended_count)
		send_all_btn.custom_minimum_size = Vector2(0, 48)
		send_all_btn.add_theme_font_size_override("font_size", 18)
		send_all_btn.disabled = GameManager.credits < CULTURAL_COST * unattended_count
		send_all_btn.pressed.connect(func() -> void: _attend_all(false))
		content_container.add_child(send_all_btn)

	# Per crew member
	for cm: CrewMember in roster:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var is_matching: bool = cm.get_species_name() == faction
		var name_lbl: Label = Label.new()
		name_lbl.text = "%s (%s %s)" % [cm.crew_name, cm.get_species_name(), cm.get_role_name()]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 18)
		if is_matching:
			name_lbl.add_theme_color_override("font_color", Color(COLOR_GOOD))
		row.add_child(name_lbl)

		if _attended_this_visit.has(cm.id):
			var done_lbl: Label = Label.new()
			done_lbl.text = "Attended"
			done_lbl.add_theme_font_size_override("font_size", 15)
			done_lbl.add_theme_color_override("font_color", Color(COLOR_GOOD))
			row.add_child(done_lbl)
		else:
			# Captain pays
			var capt_btn: Button = Button.new()
			capt_btn.text = "Captain (%d cr)" % CULTURAL_COST
			capt_btn.custom_minimum_size = Vector2(140, 36)
			capt_btn.add_theme_font_size_override("font_size", 13)
			capt_btn.disabled = GameManager.credits < CULTURAL_COST
			var cm_id: int = cm.id
			capt_btn.pressed.connect(func() -> void: _attend_cultural(cm_id, false))
			row.add_child(capt_btn)

			# Crew pays
			var crew_btn: Button = Button.new()
			crew_btn.text = "Wallet (%d cr)" % CULTURAL_COST
			crew_btn.custom_minimum_size = Vector2(140, 36)
			crew_btn.add_theme_font_size_override("font_size", 13)
			crew_btn.disabled = cm.wallet < float(CULTURAL_COST)
			crew_btn.pressed.connect(func() -> void: _attend_cultural(cm_id, true))
			row.add_child(crew_btn)

		content_container.add_child(row)


# === ATTENDANCE ===

func _attend_cultural(crew_id: int, from_wallet: bool) -> void:
	var cm: CrewMember = _get_crew_member(crew_id)
	if cm == null:
		return

	if from_wallet:
		if cm.wallet < float(CULTURAL_COST):
			log_message.emit("[color=%s]%s can't afford it.[/color]" % [COLOR_BAD, cm.crew_name])
			return
		cm.wallet -= float(CULTURAL_COST)
	else:
		if not GameManager.spend_credits(CULTURAL_COST):
			log_message.emit("[color=%s]Not enough credits.[/color]" % COLOR_BAD)
			return

	var planet: Dictionary = DatabaseManager.get_planet(planet_id)
	var faction: String = planet.get("faction", "")
	var experience: Dictionary = CULTURAL_EXPERIENCES.get(faction, {})
	if experience.is_empty():
		return

	var is_matching: bool = cm.get_species_name() == faction

	if is_matching:
		cm.morale = clampf(cm.morale + experience.matching_morale, 0.0, 100.0)
		cm.loyalty = clampf(cm.loyalty + experience.matching_loyalty, 0.0, 100.0)
		DatabaseManager.update_crew_member(cm.id, {
			"wallet": cm.wallet,
			"morale": cm.morale,
			"loyalty": cm.loyalty,
		})
		log_message.emit("[color=%s]%s is deeply moved by the %s. This is home.[/color]" % [
			COLOR_GOOD, cm.crew_name, experience.name])
		log_message.emit("[color=#555B66]  ↳ Morale +%.0f, loyalty +%.0f.[/color]" % [
			experience.matching_morale, experience.matching_loyalty])
	else:
		cm.morale = clampf(cm.morale + experience.tourist_morale, 0.0, 100.0)
		DatabaseManager.update_crew_member(cm.id, {
			"wallet": cm.wallet,
			"morale": cm.morale,
		})
		log_message.emit("[color=%s]%s watches the %s with interest. A window into another culture.[/color]" % [
			COLOR_MUTED, cm.crew_name, experience.name])
		log_message.emit("[color=#555B66]  ↳ Morale +%.0f.[/color]" % experience.tourist_morale)

	_attended_this_visit[cm.id] = true
	GameManager.save_game()
	_refresh_all()


func _attend_all(from_wallet: bool) -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	for cm: CrewMember in roster:
		if _attended_this_visit.has(cm.id):
			continue
		_attend_cultural(cm.id, from_wallet)


func _get_crew_member(crew_id: int) -> CrewMember:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	for cm: CrewMember in roster:
		if cm.id == crew_id:
			return cm
	return null
