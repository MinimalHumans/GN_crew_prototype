class_name BlackMarketView
extends VBoxContainer
## BlackMarketView — Off-the-books missions with higher risk/reward.
## Available at Nexus Station (12) and Char (11) only.
## Requires Krellvani crew member or captain Resourcefulness > 55.

signal back_pressed
signal log_message(text: String)

var planet_id: int = -1
var _generated_missions: Array[Dictionary] = []

# Color constants
const COLOR_GOOD: String = "#27AE60"
const COLOR_BAD: String = "#C0392B"
const COLOR_MUTED: String = "#718096"
const COLOR_ACCENT: String = "#4A90D9"
const COLOR_CREDITS: String = "#E6D159"
const COLOR_WARNING: String = "#E67E22"
const COLOR_BLACK_MARKET: String = "#BF8C33"

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


# === UI BUILDING ===

func _build_ui() -> void:
	var header: HBoxContainer = HBoxContainer.new()
	var back_btn: Button = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(120, 48)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back_btn)

	var title: Label = Label.new()
	title.text = "  BLACK MARKET"
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

	# Check access and generate missions
	var access: Dictionary = _check_access()
	if not access.allowed:
		var locked_lbl: Label = Label.new()
		locked_lbl.text = access.reason
		locked_lbl.add_theme_font_size_override("font_size", 18)
		locked_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		locked_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_container.add_child(locked_lbl)
		return

	# Access granted
	var access_lbl: Label = Label.new()
	access_lbl.text = access.reason
	access_lbl.add_theme_font_size_override("font_size", 14)
	access_lbl.add_theme_color_override("font_color", Color(COLOR_BLACK_MARKET))
	content_container.add_child(access_lbl)

	# Generate missions if we haven't yet
	if _generated_missions.is_empty():
		_generated_missions = _generate_black_market_missions()

	_refresh_all()


# === ACCESS CHECK ===

func _check_access() -> Dictionary:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()

	for cm: CrewMember in roster:
		if cm.species == CrewMember.Species.KRELLVANI:
			return {"allowed": true, "reason": "Krellvani contacts opened doors."}

	if GameManager.resourcefulness > 55:
		return {"allowed": true, "reason": "Your reputation precedes you."}

	return {"allowed": false, "reason": "You need Krellvani contacts or a stronger reputation (Resourcefulness > 55) to access the back room."}


# === MISSION GENERATION ===

func _generate_black_market_missions() -> Array[Dictionary]:
	var missions: Array[Dictionary] = MissionGenerator.generate_missions(
		planet_id, GameManager.captain_level, randi_range(2, 3))

	for m: Dictionary in missions:
		m.reward = int(float(m.reward) * 1.5)
		m.title = "[Off-Book] %s" % m.title
		m.difficulty = mini(m.difficulty + 1, 5)
		m.description = "No questions asked. %s" % m.description

	return missions


# === REFRESH ===

func _refresh_all() -> void:
	if credits_label:
		credits_label.text = "%d cr" % GameManager.credits
	if not content_container:
		return

	# Only clear mission cards, keep access label
	var children: Array[Node] = []
	for child: Node in content_container.get_children():
		children.append(child)
	# Remove everything after the first child (access label)
	for i: int in range(1, children.size()):
		children[i].queue_free()

	if _generated_missions.is_empty():
		var none_lbl: Label = Label.new()
		none_lbl.text = "No jobs available right now. Check back later."
		none_lbl.add_theme_font_size_override("font_size", 18)
		none_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		content_container.add_child(none_lbl)
		return

	var desc_lbl: Label = Label.new()
	desc_lbl.text = "Someone at the back table has work. Higher pay, higher difficulty, no questions asked."
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(desc_lbl)

	content_container.add_child(HSeparator.new())

	for i: int in range(_generated_missions.size()):
		var mission: Dictionary = _generated_missions[i]
		_build_mission_card(mission, i)


func _build_mission_card(mission: Dictionary, index: int) -> void:
	var card: VBoxContainer = VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)

	# Title
	var title_lbl: Label = Label.new()
	title_lbl.text = mission.title
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(COLOR_BLACK_MARKET))
	card.add_child(title_lbl)

	# Description
	var desc_lbl: Label = Label.new()
	desc_lbl.text = mission.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc_lbl)

	# Details row
	var details_row: HBoxContainer = HBoxContainer.new()
	details_row.add_theme_constant_override("separation", 16)

	var reward_lbl: Label = Label.new()
	reward_lbl.text = "Reward: %d cr" % mission.reward
	reward_lbl.add_theme_font_size_override("font_size", 15)
	reward_lbl.add_theme_color_override("font_color", Color(COLOR_CREDITS))
	details_row.add_child(reward_lbl)

	var diff_lbl: Label = Label.new()
	var stars: String = ""
	for s: int in range(mission.difficulty):
		stars += "*"
	diff_lbl.text = "Difficulty: %s" % stars
	diff_lbl.add_theme_font_size_override("font_size", 15)
	details_row.add_child(diff_lbl)

	var dest_name: String = ""
	var dest_planet: Dictionary = DatabaseManager.get_planet(mission.get("destination_id", -1))
	if not dest_planet.is_empty():
		dest_name = dest_planet.get("name", "Unknown")
	var dest_lbl: Label = Label.new()
	dest_lbl.text = "Destination: %s" % dest_name
	dest_lbl.add_theme_font_size_override("font_size", 15)
	details_row.add_child(dest_lbl)

	card.add_child(details_row)

	# Roles tested
	var roles_str: String = mission.get("roles_tested", "[]")
	var roles: Variant = JSON.parse_string(roles_str)
	if roles is Array and not roles.is_empty():
		var roles_lbl: Label = Label.new()
		roles_lbl.text = "Roles: %s" % ", ".join(roles)
		roles_lbl.add_theme_font_size_override("font_size", 13)
		roles_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		card.add_child(roles_lbl)

	# Accept button
	var accept_btn: Button = Button.new()
	accept_btn.text = "Accept Contract"
	accept_btn.custom_minimum_size = Vector2(200, 42)
	accept_btn.add_theme_font_size_override("font_size", 16)
	var idx: int = index
	# Soft lose state: disable difficulty 3+ for crewless captains with crew-capable ships
	if GameManager.get_crew_count() == 0 and GameManager.crew_max > 0 and mission.difficulty >= 3:
		accept_btn.disabled = true
		accept_btn.tooltip_text = "Too dangerous without crew"
		var restrict_lbl: Label = Label.new()
		restrict_lbl.text = "Requires crew for this difficulty"
		restrict_lbl.add_theme_font_size_override("font_size", 11)
		restrict_lbl.add_theme_color_override("font_color", Color(COLOR_BAD))
		card.add_child(restrict_lbl)
	else:
		accept_btn.pressed.connect(func() -> void: _on_accept_black_market(idx))
	card.add_child(accept_btn)

	card.add_child(HSeparator.new())
	content_container.add_child(card)


# === ACCEPTANCE ===

func _on_accept_black_market(index: int) -> void:
	if index < 0 or index >= _generated_missions.size():
		return

	var mission_data: Dictionary = _generated_missions[index]

	if GameManager.accept_mission(mission_data):
		log_message.emit("[color=%s]Off-the-books contract accepted: %s[/color]" % [COLOR_BLACK_MARKET, mission_data.title])

		# COMPASSIONATE crew take loyalty hit
		var roster: Array[CrewMember] = GameManager.get_crew_roster()
		for cm: CrewMember in roster:
			if cm.value_preference == "COMPASSIONATE" and cm.value_evidence_count >= 3:
				cm.loyalty = maxf(0.0, cm.loyalty - 3.0)
				DatabaseManager.update_crew_member(cm.id, {"loyalty": cm.loyalty})
				log_message.emit("[color=%s]%s looks uncomfortable with this arrangement.[/color]" % [COLOR_MUTED, cm.crew_name])

		# Remove the accepted mission from our list
		_generated_missions.remove_at(index)
		GameManager.save_game()
	else:
		log_message.emit("[color=%s]Can't accept more missions (max %d).[/color]" % [COLOR_BAD, GameManager.MAX_ACTIVE_MISSIONS])

	_refresh_all()
