class_name HospitalView
extends VBoxContainer
## HospitalView — Medical treatment panel for crew injuries, diseases, and checkups.
## Built programmatically and added to the planet view's service area.

signal back_pressed
signal log_message(text: String)

var planet_id: int = -1

# Treatment costs
const INJURY_COST: Dictionary = {
	"MINOR": 50,
	"MODERATE": 150,
	"SEVERE": 400,
}
const DISEASE_CURE_COST: int = 100
const CHECKUP_COST: int = 25
const CHECKUP_BONUS_TICKS: int = 10

# Color constants
const COLOR_GOOD: String = "#27AE60"
const COLOR_BAD: String = "#C0392B"
const COLOR_MUTED: String = "#718096"
const COLOR_ACCENT: String = "#4A90D9"
const COLOR_CREDITS: String = "#E6D159"
const COLOR_WARNING: String = "#E67E22"

# UI refs for refreshing
var injury_container: VBoxContainer
var disease_container: VBoxContainer
var checkup_container: VBoxContainer
var credits_label: Label


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
	# Header row: Back button + title + credits
	var header: HBoxContainer = HBoxContainer.new()
	var back_btn: Button = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(120, 48)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back_btn)

	var title: Label = Label.new()
	title.text = "  HOSPITAL"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)

	credits_label = Label.new()
	credits_label.text = "%d cr" % GameManager.credits
	credits_label.add_theme_color_override("font_color", Color(COLOR_CREDITS))
	header.add_child(credits_label)
	add_child(header)

	# Scroll container for all content
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# === INJURY TREATMENT SECTION ===
	content.add_child(_make_section_label("INJURY TREATMENT"))
	injury_container = VBoxContainer.new()
	content.add_child(injury_container)

	# === DISEASE TREATMENT SECTION ===
	content.add_child(_make_section_label("DISEASE TREATMENT"))
	disease_container = VBoxContainer.new()
	content.add_child(disease_container)

	# === GENERAL CHECKUP SECTION ===
	content.add_child(_make_section_label("GENERAL CHECKUP"))
	checkup_container = VBoxContainer.new()
	content.add_child(checkup_container)

	_refresh_all()


func _make_section_label(text: String) -> VBoxContainer:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	var spacer: MarginContainer = MarginContainer.new()
	spacer.add_theme_constant_override("margin_top", 12)
	spacer.add_child(lbl)
	# Wrap in a VBox so the margin actually works
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_child(spacer)
	return wrapper


# === REFRESH ===

func _refresh_all() -> void:
	if credits_label:
		credits_label.text = "%d cr" % GameManager.credits
	_refresh_injuries()
	_refresh_diseases()
	_refresh_checkups()


func _refresh_injuries() -> void:
	if not injury_container:
		return
	for child: Node in injury_container.get_children():
		child.queue_free()

	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	var found_any: bool = false

	for cm: CrewMember in roster:
		if not cm.has_injuries():
			continue
		for injury: Dictionary in cm.injuries:
			found_any = true
			var severity: String = injury.get("severity", "MINOR")
			var cost: int = INJURY_COST.get(severity, 50)
			var desc: String = injury.get("description", "Injury")
			var ticks: int = injury.get("ticks_remaining", 0)

			var row: HBoxContainer = HBoxContainer.new()
			var info: Label = Label.new()
			info.text = "%s — %s (%s, %d ticks left)" % [cm.crew_name, desc, severity.capitalize(), ticks]
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_theme_font_size_override("font_size", 21)
			row.add_child(info)

			var treat_btn: Button = Button.new()
			treat_btn.text = "Treat (%d cr)" % cost
			treat_btn.custom_minimum_size = Vector2(180, 42)
			treat_btn.disabled = GameManager.credits < cost
			# Capture by value for the closure
			var crew_id: int = cm.id
			var inj_ref: Dictionary = injury
			treat_btn.pressed.connect(func() -> void: _treat_injury(crew_id, inj_ref, cost))
			row.add_child(treat_btn)

			injury_container.add_child(row)

	if not found_any:
		var none_lbl: Label = Label.new()
		none_lbl.text = "No crew members are currently injured."
		none_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		none_lbl.add_theme_font_size_override("font_size", 21)
		injury_container.add_child(none_lbl)


func _refresh_diseases() -> void:
	if not disease_container:
		return
	for child: Node in disease_container.get_children():
		child.queue_free()

	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	var found_any: bool = false

	for cm: CrewMember in roster:
		if not cm.has_diseases():
			continue
		for disease: Dictionary in cm.diseases:
			found_any = true
			var disease_name: String = disease.get("name", "Unknown Disease")
			var ticks: int = disease.get("ticks_remaining", 0)

			var row: HBoxContainer = HBoxContainer.new()
			var info: Label = Label.new()
			info.text = "%s — %s (%d ticks left)" % [cm.crew_name, disease_name, ticks]
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_theme_font_size_override("font_size", 21)
			row.add_child(info)

			var cure_btn: Button = Button.new()
			cure_btn.text = "Cure (%d cr)" % DISEASE_CURE_COST
			cure_btn.custom_minimum_size = Vector2(180, 42)
			cure_btn.disabled = GameManager.credits < DISEASE_CURE_COST
			var crew_id: int = cm.id
			var dis_ref: Dictionary = disease
			cure_btn.pressed.connect(func() -> void: _treat_disease(crew_id, dis_ref))
			row.add_child(cure_btn)

			disease_container.add_child(row)

	if not found_any:
		var none_lbl: Label = Label.new()
		none_lbl.text = "No crew members are currently diseased."
		none_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		none_lbl.add_theme_font_size_override("font_size", 21)
		disease_container.add_child(none_lbl)


func _refresh_checkups() -> void:
	if not checkup_container:
		return
	for child: Node in checkup_container.get_children():
		child.queue_free()

	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		var none_lbl: Label = Label.new()
		none_lbl.text = "No crew aboard."
		none_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		none_lbl.add_theme_font_size_override("font_size", 21)
		checkup_container.add_child(none_lbl)
		return

	var desc_label: Label = Label.new()
	desc_label.text = "A general checkup grants +5 fatigue recovery per tick for %d ticks." % CHECKUP_BONUS_TICKS
	desc_label.add_theme_color_override("font_color", Color(COLOR_MUTED))
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	checkup_container.add_child(desc_label)

	for cm: CrewMember in roster:
		var row: HBoxContainer = HBoxContainer.new()
		var info: Label = Label.new()
		var status_text: String = ""
		if cm.checkup_bonus_ticks > 0:
			status_text = " [active: %d ticks]" % cm.checkup_bonus_ticks
		info.text = "%s — Fatigue: %.0f%s" % [cm.crew_name, cm.fatigue, status_text]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 21)
		row.add_child(info)

		var checkup_btn: Button = Button.new()
		checkup_btn.text = "Checkup (%d cr)" % CHECKUP_COST
		checkup_btn.custom_minimum_size = Vector2(195, 42)
		checkup_btn.disabled = GameManager.credits < CHECKUP_COST or cm.checkup_bonus_ticks > 0
		var crew_id: int = cm.id
		checkup_btn.pressed.connect(func() -> void: _do_checkup(crew_id))
		row.add_child(checkup_btn)

		checkup_container.add_child(row)

	# "Checkup All" button
	var total_cost: int = roster.size() * CHECKUP_COST
	var eligible_count: int = 0
	for cm: CrewMember in roster:
		if cm.checkup_bonus_ticks <= 0:
			eligible_count += 1
	var eligible_cost: int = eligible_count * CHECKUP_COST

	if eligible_count > 1:
		var all_btn: Button = Button.new()
		all_btn.text = "Checkup All Eligible (%d cr for %d crew)" % [eligible_cost, eligible_count]
		all_btn.custom_minimum_size = Vector2(0, 32)
		all_btn.disabled = GameManager.credits < CHECKUP_COST  # At least one
		all_btn.pressed.connect(func() -> void: _do_checkup_all())
		checkup_container.add_child(all_btn)


# === TREATMENT ACTIONS ===

func _treat_injury(crew_id: int, injury: Dictionary, cost: int) -> void:
	if GameManager.credits < cost:
		log_message.emit("[color=%s]Not enough credits for treatment.[/color]" % COLOR_BAD)
		return

	GameManager.credits -= cost
	EventBus.credits_changed.emit(GameManager.credits)

	# Halve remaining recovery ticks
	var new_ticks: int = maxi(1, injury.get("ticks_remaining", 0) / 2)
	injury["ticks_remaining"] = new_ticks

	# Update crew member in database
	var crew_data: Dictionary = DatabaseManager.get_crew_member(crew_id)
	var cm: CrewMember = CrewMember.from_dict(crew_data)
	# Find and update the matching injury
	for inj: Dictionary in cm.injuries:
		if inj.get("description", "") == injury.get("description", "") and \
		   inj.get("severity", "") == injury.get("severity", ""):
			inj["ticks_remaining"] = new_ticks
			break
	DatabaseManager.update_crew_member(crew_id, {"injuries": JSON.stringify(cm.injuries)})

	var severity: String = injury.get("severity", "MINOR").capitalize()
	log_message.emit("[color=%s]%s's %s injury treated. Recovery time halved to %d ticks.[/color]" % [
		COLOR_GOOD, cm.crew_name, severity, new_ticks])

	GameManager.save_game()
	_refresh_all()


func _treat_disease(crew_id: int, disease: Dictionary) -> void:
	if GameManager.credits < DISEASE_CURE_COST:
		log_message.emit("[color=%s]Not enough credits for treatment.[/color]" % COLOR_BAD)
		return

	GameManager.credits -= DISEASE_CURE_COST
	EventBus.credits_changed.emit(GameManager.credits)

	# Remove the disease from crew member
	var crew_data: Dictionary = DatabaseManager.get_crew_member(crew_id)
	var cm: CrewMember = CrewMember.from_dict(crew_data)
	var disease_name: String = disease.get("name", "")
	var remaining: Array = []
	for d: Dictionary in cm.diseases:
		if d.get("name", "") != disease_name:
			remaining.append(d)
	cm.diseases = remaining

	# Clear quarantine if no more contagious diseases
	var still_contagious: bool = false
	for d: Dictionary in cm.diseases:
		if d.get("contagious", false):
			still_contagious = true
			break
	if not still_contagious:
		cm.is_quarantined = false
		cm.quarantine_ticks = 0

	DatabaseManager.update_crew_member(crew_id, {
		"diseases": JSON.stringify(cm.diseases),
		"is_quarantined": 1 if cm.is_quarantined else 0,
		"quarantine_ticks": cm.quarantine_ticks,
	})

	log_message.emit("[color=%s]%s cured of %s.[/color]" % [COLOR_GOOD, cm.crew_name, disease_name])
	if not still_contagious and not cm.is_quarantined:
		log_message.emit("[color=%s]%s released from quarantine.[/color]" % [COLOR_GOOD, cm.crew_name])

	GameManager.save_game()
	_refresh_all()


func _do_checkup(crew_id: int) -> void:
	if GameManager.credits < CHECKUP_COST:
		log_message.emit("[color=%s]Not enough credits for checkup.[/color]" % COLOR_BAD)
		return

	GameManager.credits -= CHECKUP_COST
	EventBus.credits_changed.emit(GameManager.credits)

	DatabaseManager.update_crew_member(crew_id, {"checkup_bonus_ticks": CHECKUP_BONUS_TICKS})

	var crew_data: Dictionary = DatabaseManager.get_crew_member(crew_id)
	var crew_name: String = crew_data.get("name", "Crew member")
	log_message.emit("[color=%s]%s received a general checkup. +5 fatigue recovery for %d ticks.[/color]" % [
		COLOR_GOOD, crew_name, CHECKUP_BONUS_TICKS])

	GameManager.save_game()
	_refresh_all()


func _do_checkup_all() -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	var treated: int = 0
	for cm: CrewMember in roster:
		if cm.checkup_bonus_ticks > 0:
			continue
		if GameManager.credits < CHECKUP_COST:
			break
		GameManager.credits -= CHECKUP_COST
		DatabaseManager.update_crew_member(cm.id, {"checkup_bonus_ticks": CHECKUP_BONUS_TICKS})
		treated += 1

	if treated > 0:
		EventBus.credits_changed.emit(GameManager.credits)
		log_message.emit("[color=%s]%d crew members received checkups. +5 fatigue recovery for %d ticks each.[/color]" % [
			COLOR_GOOD, treated, CHECKUP_BONUS_TICKS])
		GameManager.save_game()
		_refresh_all()
	else:
		log_message.emit("[color=%s]No eligible crew for checkup.[/color]" % COLOR_MUTED)
