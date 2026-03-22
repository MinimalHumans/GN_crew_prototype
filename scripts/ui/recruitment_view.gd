class_name RecruitmentView
extends VBoxContainer
## RecruitmentView — Recruitment station UI for hiring crew.
## Generates candidates, shows profiles, handles acceptance rolls.

signal back_pressed
signal log_message(text: String)

# Color constants
const COLOR_GOOD: String = "#27AE60"
const COLOR_BAD: String = "#C0392B"
const COLOR_MUTED: String = "#718096"
const COLOR_ACCENT: String = "#4A90D9"
const COLOR_CREDITS: String = "#E6D159"

var planet_id: int = -1
var candidates: Array[CrewMember] = []
var candidate_container: VBoxContainer
var expanded_crew_id: int = -1  # Index of expanded candidate (-1 = none)
var pay_split_label: Label


func _init(p_planet_id: int = -1) -> void:
	planet_id = p_planet_id


func _ready() -> void:
	_generate_candidates()
	_build_ui()


# === CANDIDATE GENERATION ===

func _generate_candidates() -> void:
	## Faction access modifies candidate count and quality.
	## Outsider: fewer candidates (-1). Insider: more (+1), better stats.
	## Returns cached candidates if they exist for this planet.
	if GameManager.cached_recruitment_planet_id == planet_id and not GameManager.cached_recruitment_candidates.is_empty():
		candidates = []
		for cm: CrewMember in GameManager.cached_recruitment_candidates:
			candidates.append(cm)
		return

	var base_count: int = randi_range(3, 6)
	var access: GameManager.AccessLevel = GameManager.get_faction_access_level(planet_id)
	if access == GameManager.AccessLevel.OUTSIDER:
		base_count = maxi(base_count - 1, 2)
	elif access == GameManager.AccessLevel.INSIDER:
		base_count += 1
	candidates = CrewGenerator.generate_candidates(planet_id, base_count, GameManager.captain_level)
	# Insider bonus: +5 to all stats for each candidate
	if access == GameManager.AccessLevel.INSIDER:
		for cm: CrewMember in candidates:
			cm.stamina = mini(cm.stamina + 5, 100)
			cm.cognition = mini(cm.cognition + 5, 100)
			cm.reflexes = mini(cm.reflexes + 5, 100)
			cm.social = mini(cm.social + 5, 100)
			cm.resourcefulness = mini(cm.resourcefulness + 5, 100)

	# Cache the generated candidates
	GameManager.cached_recruitment_planet_id = planet_id
	GameManager.cached_recruitment_candidates = []
	for cm: CrewMember in candidates:
		GameManager.cached_recruitment_candidates.append(cm)


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
	title.text = "  RECRUITMENT STATION"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	header.add_child(title)

	var crew_status: Label = Label.new()
	crew_status.text = "Crew: %d/%d" % [GameManager.get_crew_count(), GameManager.crew_max]
	crew_status.add_theme_font_size_override("font_size", 13)
	header.add_child(crew_status)
	add_child(header)

	# Pay split row
	var split_row: HBoxContainer = HBoxContainer.new()
	split_row.add_theme_constant_override("separation", 8)
	pay_split_label = Label.new()
	_update_pay_split_label()
	pay_split_label.add_theme_font_size_override("font_size", 12)
	split_row.add_child(pay_split_label)

	var change_split_btn: Button = Button.new()
	change_split_btn.text = "Change Split"
	change_split_btn.custom_minimum_size = Vector2(100, 26)
	change_split_btn.add_theme_font_size_override("font_size", 11)
	change_split_btn.pressed.connect(_show_pay_split_popup)
	split_row.add_child(change_split_btn)

	var fee_label: Label = Label.new()
	fee_label.text = "  |  Recruitment fee: %d cr" % GameManager.RECRUITMENT_FEE
	fee_label.add_theme_font_size_override("font_size", 12)
	fee_label.add_theme_color_override("font_color", Color(COLOR_MUTED))
	split_row.add_child(fee_label)
	add_child(split_row)

	add_child(HSeparator.new())

	# Scrollable candidate list
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	candidate_container = VBoxContainer.new()
	candidate_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidate_container.add_theme_constant_override("separation", 6)

	_populate_candidates()

	scroll.add_child(candidate_container)
	add_child(scroll)


func _update_pay_split_label() -> void:
	if pay_split_label:
		var split_text: String
		if GameManager.pay_split >= 0.6:
			split_text = "60/40 Captain-favoring"
		elif GameManager.pay_split <= 0.4:
			split_text = "40/60 Crew-favoring"
		else:
			split_text = "50/50 Equitable"
		pay_split_label.text = "Pay Split: %s" % split_text


func _populate_candidates() -> void:
	for child: Node in candidate_container.get_children():
		child.queue_free()

	if candidates.is_empty():
		var empty: Label = Label.new()
		empty.text = "No candidates available."
		empty.add_theme_color_override("font_color", Color(COLOR_MUTED))
		candidate_container.add_child(empty)
		return

	for i: int in range(candidates.size()):
		candidate_container.add_child(_make_candidate_card(candidates[i], i))


func _make_candidate_card(cm: CrewMember, index: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	# Top row: name, species, role
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)

	var name_lbl: Label = Label.new()
	name_lbl.text = cm.crew_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(cm.get_species_color()))
	top_row.add_child(name_lbl)

	var species_lbl: Label = Label.new()
	species_lbl.text = cm.get_species_name()
	species_lbl.add_theme_font_size_override("font_size", 12)
	species_lbl.add_theme_color_override("font_color", Color(cm.get_species_color()))
	top_row.add_child(species_lbl)

	var role_lbl: Label = Label.new()
	role_lbl.text = "  |  %s" % cm.get_role_name()
	role_lbl.add_theme_font_size_override("font_size", 12)
	role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(role_lbl)

	vbox.add_child(top_row)

	# Stat bars (compact)
	vbox.add_child(_make_stat_bars(cm))

	# Comparison with existing crew of same role
	var comparison: Label = _make_comparison_label(cm)
	if comparison != null:
		vbox.add_child(comparison)

	# Personality
	var pers_lbl: Label = Label.new()
	pers_lbl.text = cm.personality
	pers_lbl.add_theme_font_size_override("font_size", 11)
	pers_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	vbox.add_child(pers_lbl)

	# Expand/Recruit button row
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)

	var detail_btn: Button = Button.new()
	detail_btn.text = "Details"
	detail_btn.custom_minimum_size = Vector2(70, 28)
	detail_btn.add_theme_font_size_override("font_size", 11)
	detail_btn.pressed.connect(_show_expanded_profile.bind(cm, index))
	btn_row.add_child(detail_btn)

	var recruit_btn: Button = Button.new()
	recruit_btn.text = "Recruit"
	recruit_btn.custom_minimum_size = Vector2(120, 42)
	recruit_btn.add_theme_font_size_override("font_size", 18)

	var check: Dictionary = GameManager.can_recruit(cm)
	if not check.can:
		recruit_btn.disabled = true
		recruit_btn.tooltip_text = check.reason
	else:
		recruit_btn.pressed.connect(_on_recruit.bind(cm, index))
	btn_row.add_child(recruit_btn)

	vbox.add_child(btn_row)
	card.add_child(vbox)
	return card


func _make_comparison_label(candidate: CrewMember) -> Label:
	## Returns a label comparing this candidate to existing crew of the same role.
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	var same_role: Array[CrewMember] = []
	for cm: CrewMember in roster:
		if cm.role == candidate.role:
			same_role.append(cm)
	if same_role.is_empty():
		return null
	# Compare to best existing crew of same role
	var best: CrewMember = same_role[0]
	for cm: CrewMember in same_role:
		if cm.get_stat_total() > best.get_stat_total():
			best = cm
	var diff: int = candidate.get_stat_total() - best.get_stat_total()
	var color: String = COLOR_GOOD if diff > 0 else (COLOR_BAD if diff < 0 else COLOR_MUTED)
	var sign: String = "+" if diff > 0 else ""
	var lbl: Label = Label.new()
	lbl.text = "vs %s (%s): %s%d total stats" % [best.crew_name, best.get_role_name(), sign, diff]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(color))
	return lbl


func _make_stat_bars(cm: CrewMember) -> HBoxContainer:
	## Creates a compact row of 5 stat indicators.
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var stats: Array[Array] = [
		["STA", cm.stamina], ["COG", cm.cognition], ["REF", cm.reflexes],
		["SOC", cm.social], ["RES", cm.resourcefulness],
	]

	for stat: Array in stats:
		var stat_box: HBoxContainer = HBoxContainer.new()
		stat_box.add_theme_constant_override("separation", 2)

		var label: Label = Label.new()
		label.text = "%s:" % stat[0]
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(COLOR_MUTED))
		label.custom_minimum_size = Vector2(28, 0)
		stat_box.add_child(label)

		var bar: ProgressBar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = stat[1]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(40, 12)
		stat_box.add_child(bar)

		var val_lbl: Label = Label.new()
		val_lbl.text = str(stat[1])
		val_lbl.add_theme_font_size_override("font_size", 10)
		val_lbl.custom_minimum_size = Vector2(22, 0)
		stat_box.add_child(val_lbl)

		row.add_child(stat_box)
	return row


# === EXPANDED PROFILE ===

func _show_expanded_profile(cm: CrewMember, index: int) -> void:
	## Shows full candidate details in a popup-like panel.
	# Build detail text for message log
	log_message.emit("")
	log_message.emit("[color=%s]--- Candidate Profile: %s ---[/color]" % [COLOR_ACCENT, cm.crew_name])
	log_message.emit("[color=%s]%s %s[/color]" % [cm.get_species_color(), cm.get_species_name(), cm.get_role_name()])
	log_message.emit("STA: %d  COG: %d  REF: %d  SOC: %d  RES: %d" % [
		cm.stamina, cm.cognition, cm.reflexes, cm.social, cm.resourcefulness])
	log_message.emit("[color=%s]%s[/color]" % [COLOR_MUTED, cm.personality])
	log_message.emit("[color=%s]Species: %s[/color]" % [COLOR_MUTED, cm.get_species_trait_text()])

	# Krellvani warning on Corvette/Frigate
	if cm.species == CrewMember.Species.KRELLVANI and GameManager.ship_class in ["corvette", "frigate"]:
		log_message.emit("[color=%s]Warning: Krellvani require 1.5 crew slots on this ship class.[/color]" % COLOR_BAD)

	# Compatibility check
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		log_message.emit("[color=%s]No existing crew — no compatibility concerns.[/color]" % COLOR_MUTED)
	else:
		for mate: CrewMember in roster:
			var friction: int = CrewMember.get_friction_between(cm.species, mate.species)
			if friction < 0:
				log_message.emit("[color=%s]May clash with %s (%s) — starting relationship: %d[/color]" % [
					COLOR_BAD, mate.crew_name, mate.get_species_name(), friction])
			elif friction > 0:
				log_message.emit("[color=%s]Should get along with %s (%s) — starting relationship: +%d[/color]" % [
					COLOR_GOOD, mate.crew_name, mate.get_species_name(), friction])

	# Acceptance probability
	var prob: float = GameManager.calculate_acceptance(cm)
	log_message.emit("[color=%s]Estimated acceptance: %.0f%%[/color]" % [COLOR_ACCENT, prob])


# === PAY SPLIT POPUP ===

func _show_pay_split_popup() -> void:
	## Shows pay split selection as buttons in the candidate area.
	for child: Node in candidate_container.get_children():
		child.queue_free()

	var info: Label = Label.new()
	info.text = "Choose how mission rewards are split between captain and crew:"
	info.add_theme_font_size_override("font_size", 12)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	candidate_container.add_child(info)

	# Show last payout context
	var last_payout: Label = Label.new()
	var days_since: int = GameManager.day_count - GameManager.last_payout_day
	var pending: int = GameManager.credits_since_last_payout
	if GameManager.last_payout_day > 0:
		last_payout.text = "Last payout: Day %d (%d days ago). Pending earnings: %d credits." % [
			GameManager.last_payout_day, days_since, pending]
	else:
		last_payout.text = "No payouts yet. Pending earnings: %d credits." % pending
	last_payout.add_theme_font_size_override("font_size", 12)
	last_payout.add_theme_color_override("font_color", Color("#718096"))
	candidate_container.add_child(last_payout)

	var options: Array[Array] = [
		[0.6, "60/40 Captain-Favoring", "You keep 60%. Crew earns less — harder recruitment, morale penalty. Saves credits for upgrades."],
		[0.5, "50/50 Equitable", "Even split. Fair pay, no modifier. Balanced approach."],
		[0.4, "40/60 Crew-Favoring", "Crew keeps 60%. Better recruitment and morale. Costs more — slower ship upgrades."],
	]

	for opt: Array in options:
		var btn: Button = Button.new()
		btn.text = "%s — %s" % [opt[1], opt[2]]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 12)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if GameManager.pay_split == opt[0]:
			btn.text += "  [CURRENT]"
		btn.pressed.connect(_on_pay_split_selected.bind(opt[0], opt[1]))
		candidate_container.add_child(btn)


func _on_pay_split_selected(split: float, name: String) -> void:
	GameManager.set_pay_split(split)
	_update_pay_split_label()
	log_message.emit("[color=%s]Pay split set to %s.[/color]" % [COLOR_ACCENT, name])
	_populate_candidates()


# === RECRUITMENT ===

func _on_recruit(cm: CrewMember, index: int) -> void:
	var result: Dictionary = GameManager.recruit_crew(cm)

	match result.result:
		"accept":
			var text: String = TextTemplates.get_recruit_accept_text(cm.crew_name, cm.get_role_name())
			log_message.emit("[color=%s]%s[/color]" % [COLOR_GOOD, text])
			log_message.emit("[color=%s]-%d credits (recruitment fee)[/color]" % [COLOR_CREDITS, GameManager.RECRUITMENT_FEE])
			# Remove from candidates list and cache
			candidates.remove_at(index)
			_sync_cache_from_candidates()
		"reluctant":
			var text: String = TextTemplates.get_recruit_reluctant_text(cm.crew_name)
			log_message.emit("[color=%s]%s[/color]" % [COLOR_CREDITS, text])
			log_message.emit("[color=%s]-%d credits (recruitment fee). Starting morale: 45.[/color]" % [COLOR_CREDITS, GameManager.RECRUITMENT_FEE])
			candidates.remove_at(index)
			_sync_cache_from_candidates()
		"decline":
			var text: String = TextTemplates.get_recruit_decline_text(cm.crew_name)
			log_message.emit("[color=%s]%s[/color]" % [COLOR_MUTED, text])
			# Candidate stays in pool
		"blocked":
			log_message.emit("[color=%s]%s[/color]" % [COLOR_BAD, result.reason])

	_populate_candidates()


func _sync_cache_from_candidates() -> void:
	## Updates the GameManager recruitment cache to match current candidates list.
	GameManager.cached_recruitment_candidates = []
	for cm: CrewMember in candidates:
		GameManager.cached_recruitment_candidates.append(cm)
