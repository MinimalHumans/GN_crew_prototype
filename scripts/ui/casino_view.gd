class_name CasinoView
extends VBoxContainer
## CasinoView — Gambling service. Crew risk wallet credits for morale/credits.
## Available at Nexus Station only (with high-stakes variant).

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


func _is_nexus_station() -> bool:
	return planet_id == 12


# === UI BUILDING ===

func _build_ui() -> void:
	var header: HBoxContainer = HBoxContainer.new()
	var back_btn: Button = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(120, 48)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back_btn)

	var title: Label = Label.new()
	title.text = "  CASINO"
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

	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No crew to gamble."
		empty_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		empty_lbl.add_theme_font_size_override("font_size", 21)
		content_container.add_child(empty_lbl)
		return

	var desc: Label = Label.new()
	desc.text = "Try your luck. No time cost — gambling is quick. Resourcefulness improves odds."
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(COLOR_MUTED))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(desc)

	for cm: CrewMember in roster:
		var section: VBoxContainer = VBoxContainer.new()
		section.add_theme_constant_override("separation", 4)

		var info_row: HBoxContainer = HBoxContainer.new()
		info_row.add_theme_constant_override("separation", 12)
		var name_lbl: Label = Label.new()
		name_lbl.text = "%s — Wallet: %d cr  Resourcefulness: %d" % [cm.crew_name, int(cm.wallet), cm.resourcefulness]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 18)
		info_row.add_child(name_lbl)
		section.add_child(info_row)

		# Stake options
		var stakes: Array[Array] = [
			[20, "Low (20 cr)"],
			[50, "Medium (50 cr)"],
			[100, "High (100 cr)"],
		]
		if _is_nexus_station():
			stakes.append([250, "High-Stakes (250 cr)"])

		var btn_row: HBoxContainer = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 6)

		for stake_info: Array in stakes:
			var stake: int = stake_info[0]
			var stake_label: String = stake_info[1]

			# Crew pays button
			var crew_btn: Button = Button.new()
			crew_btn.text = "%s (Wallet)" % stake_label
			crew_btn.custom_minimum_size = Vector2(0, 36)
			crew_btn.add_theme_font_size_override("font_size", 13)
			crew_btn.disabled = cm.wallet < float(stake)
			var cm_id: int = cm.id
			var s: int = stake
			crew_btn.pressed.connect(func() -> void: _gamble(cm_id, s, true))
			btn_row.add_child(crew_btn)

		section.add_child(btn_row)

		# Captain-funded row
		var capt_row: HBoxContainer = HBoxContainer.new()
		capt_row.add_theme_constant_override("separation", 6)

		for stake_info: Array in stakes:
			var stake: int = stake_info[0]
			var stake_label: String = stake_info[1]

			var capt_btn: Button = Button.new()
			capt_btn.text = "%s (Captain)" % stake_label
			capt_btn.custom_minimum_size = Vector2(0, 36)
			capt_btn.add_theme_font_size_override("font_size", 13)
			capt_btn.disabled = GameManager.credits < stake
			var cm_id: int = cm.id
			var s: int = stake
			capt_btn.pressed.connect(func() -> void: _gamble(cm_id, s, false))
			capt_row.add_child(capt_btn)

		section.add_child(capt_row)
		section.add_child(HSeparator.new())
		content_container.add_child(section)


# === GAMBLING ===

func _gamble(crew_id: int, stake: int, from_wallet: bool) -> void:
	var cm: CrewMember = _get_crew_member(crew_id)
	if cm == null:
		return

	# Deduct stake
	if from_wallet:
		if cm.wallet < float(stake):
			log_message.emit("[color=%s]%s can't afford that stake.[/color]" % [COLOR_BAD, cm.crew_name])
			return
		cm.wallet -= float(stake)
	else:
		if not GameManager.spend_credits(stake):
			log_message.emit("[color=%s]Not enough credits.[/color]" % COLOR_BAD)
			return

	# Roll: base 1-100, Resourcefulness adds up to +20
	var roll: int = randi_range(1, 100) + cm.resourcefulness / 5

	var result_text: String
	var morale_change: float = 0.0
	var payout: int = 0

	if roll > 130:
		# Jackpot
		payout = stake * 5
		morale_change = 15.0
		result_text = "[color=%s]JACKPOT! %s can't believe it. %d credits![/color]" % [COLOR_CREDITS, cm.crew_name, payout]
	elif roll > 100:
		# Big win
		payout = stake * 3
		morale_change = 10.0
		result_text = "[color=%s]%s wins big — %d credits. Drinks are on them.[/color]" % [COLOR_GOOD, cm.crew_name, payout]
	elif roll > 70:
		# Small win
		payout = int(float(stake) * 1.5)
		morale_change = 5.0
		result_text = "[color=%s]%s comes out ahead — %d credits.[/color]" % [COLOR_GOOD, cm.crew_name, payout]
	elif roll > 40:
		# Break even
		payout = stake
		morale_change = 0.0
		result_text = "[color=%s]%s breaks even. Could have been worse.[/color]" % [COLOR_MUTED, cm.crew_name]
	elif roll > 15:
		# Loss
		payout = 0
		morale_change = -5.0
		result_text = "[color=%s]%s loses their stake. The table takes all.[/color]" % [COLOR_WARNING, cm.crew_name]
	else:
		# Bad loss
		payout = 0
		morale_change = -10.0
		result_text = "[color=%s]%s loses badly and starts an argument with the dealer. Security gets involved.[/color]" % [COLOR_BAD, cm.crew_name]
		# Relationship damage with a random crewmate
		var roster: Array[CrewMember] = GameManager.get_crew_roster()
		if roster.size() > 1:
			var bystander: CrewMember = roster[randi() % roster.size()]
			if bystander.id != cm.id:
				var rel: float = DatabaseManager.get_relationship_value(cm.id, bystander.id)
				DatabaseManager.update_relationship(cm.id, bystander.id, rel - 5.0)

	# Apply payout
	if from_wallet and payout > 0:
		cm.wallet += float(payout)
	elif not from_wallet and payout > 0:
		GameManager.add_credits(payout)

	# Apply morale
	cm.morale = clampf(cm.morale + morale_change, 0.0, 100.0)
	DatabaseManager.update_crew_member(cm.id, {
		"wallet": cm.wallet,
		"lifetime_earnings": cm.lifetime_earnings,
		"morale": cm.morale,
	})

	log_message.emit(result_text)
	if morale_change != 0.0:
		log_message.emit("[color=#555B66]  ↳ Morale %+.0f.[/color]" % morale_change)

	GameManager.save_game()
	_refresh_all()


func _get_crew_member(crew_id: int) -> CrewMember:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	for cm: CrewMember in roster:
		if cm.id == crew_id:
			return cm
	return null
