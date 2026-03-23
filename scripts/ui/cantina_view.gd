class_name CantinaView
extends VBoxContainer
## CantinaView — Cantina/bar service. Crew socialize, drink, unwind.
## Captain can buy rounds (from captain credits) or crew pay for themselves (from wallet).

signal back_pressed
signal log_message(text: String)

var planet_id: int = -1
var _cantina_used: bool = false

# Planet type cost scaling
const CANTINA_COSTS: Dictionary = {
	"hub": 15,
	"trade_hub": 12,
	"agricultural": 8,
	"capital": 18,
	"mining": 10,
	"research": 12,
	"homeworld": 15,
	"cultural": 15,
	"frontier": 8,
	"stronghold": 12,
	"contested": 10,
	"black_market": 15,
}

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


# === UI BUILDING ===

func _build_ui() -> void:
	var header: HBoxContainer = HBoxContainer.new()
	var back_btn: Button = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(120, 48)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back_btn)

	var title: Label = Label.new()
	title.text = "  CANTINA"
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
		empty_lbl.text = "No crew to visit the cantina."
		empty_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		empty_lbl.add_theme_font_size_override("font_size", 21)
		content_container.add_child(empty_lbl)
		return

	if _cantina_used:
		var done_lbl: Label = Label.new()
		done_lbl.text = "Last call — cantina already visited this stop."
		done_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		done_lbl.add_theme_font_size_override("font_size", 21)
		content_container.add_child(done_lbl)
		return

	# Description
	var desc_lbl: Label = Label.new()
	desc_lbl.text = "The crew could use some shore leave. Buy a round, or let them pay their own way."
	desc_lbl.add_theme_font_size_override("font_size", 18)
	desc_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(desc_lbl)

	# Crew roster preview
	var section_lbl: Label = Label.new()
	section_lbl.text = "CREW"
	section_lbl.add_theme_font_size_override("font_size", 24)
	section_lbl.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	content_container.add_child(section_lbl)

	for cm: CrewMember in roster:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var name_lbl: Label = Label.new()
		name_lbl.text = "%s (%s)" % [cm.crew_name, cm.get_role_name()]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(name_lbl)
		var info_lbl: Label = Label.new()
		info_lbl.text = "Morale: %.0f  Fatigue: %.0f  Wallet: %d cr" % [cm.morale, cm.fatigue, int(cm.wallet)]
		info_lbl.add_theme_font_size_override("font_size", 15)
		info_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
		row.add_child(info_lbl)
		content_container.add_child(row)

	content_container.add_child(HSeparator.new())

	# Funding options
	var costs: Dictionary = _calculate_costs()

	# Option 1: Crew pays
	var crew_pays_btn: Button = Button.new()
	crew_pays_btn.text = "Crew Pays (%d cr each from wallet, 1 day)" % costs.per_crew
	crew_pays_btn.custom_minimum_size = Vector2(0, 48)
	crew_pays_btn.add_theme_font_size_override("font_size", 18)
	crew_pays_btn.pressed.connect(func() -> void: _on_funding_selected("crew_pays"))
	content_container.add_child(crew_pays_btn)

	# Option 2: Captain buys a round
	var round_btn: Button = Button.new()
	round_btn.text = "Captain Buys a Round (%d cr total, 1 day)" % costs.captain_round
	round_btn.custom_minimum_size = Vector2(0, 48)
	round_btn.add_theme_font_size_override("font_size", 18)
	round_btn.disabled = GameManager.credits < costs.captain_round
	round_btn.pressed.connect(func() -> void: _on_funding_selected("captain_round"))
	content_container.add_child(round_btn)

	# Option 3: Captain goes all-in
	var allin_btn: Button = Button.new()
	allin_btn.text = "Captain Goes All-In (~%d cr, 1 day, enhanced effects)" % costs.captain_all_in
	allin_btn.custom_minimum_size = Vector2(0, 48)
	allin_btn.add_theme_font_size_override("font_size", 18)
	allin_btn.disabled = GameManager.credits < costs.captain_all_in
	allin_btn.pressed.connect(func() -> void: _on_funding_selected("all_in"))
	content_container.add_child(allin_btn)


# === COST CALCULATION ===

func _get_per_crew_cost() -> int:
	var planet: Dictionary = DatabaseManager.get_planet(planet_id)
	return CANTINA_COSTS.get(planet.get("type", "hub"), 15)


func _calculate_costs() -> Dictionary:
	var per_crew: int = _get_per_crew_cost()
	var crew_count: int = GameManager.get_crew_roster().size()
	var captain_round: int = per_crew * crew_count
	var captain_all_in: int = int(float(captain_round) * 1.8) + randi_range(0, per_crew * 2)
	return {
		"per_crew": per_crew,
		"captain_round": captain_round,
		"captain_all_in": captain_all_in,
	}


# === FUNDING HANDLERS ===

func _on_funding_selected(funding_type: String) -> void:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	if roster.is_empty():
		return

	var costs: Dictionary = _calculate_costs()

	match funding_type:
		"crew_pays":
			var per_crew: int = costs.per_crew
			for cm: CrewMember in roster:
				if cm.wallet >= float(per_crew):
					cm.wallet -= float(per_crew)
					DatabaseManager.update_crew_member(cm.id, {"wallet": cm.wallet})
			log_message.emit("[color=%s]Each crew member chips in %d credits from their wallet.[/color]" % [COLOR_MUTED, per_crew])

		"captain_round":
			if not GameManager.spend_credits(costs.captain_round):
				log_message.emit("[color=%s]Not enough credits.[/color]" % COLOR_BAD)
				return
			log_message.emit("[color=%s]You buy a round for the crew. %d credits.[/color]" % [COLOR_CREDITS, costs.captain_round])

		"all_in":
			if not GameManager.spend_credits(costs.captain_all_in):
				log_message.emit("[color=%s]Not enough credits.[/color]" % COLOR_BAD)
				return
			log_message.emit("[color=%s]You go all-in. The tab comes to %d credits.[/color]" % [COLOR_CREDITS, costs.captain_all_in])

	# Resolve the cantina visit
	var result: Dictionary = _resolve_cantina(funding_type)
	for event: String in result.events:
		log_message.emit(event)

	_cantina_used = true
	_refresh_all()


# === RESOLUTION ===

func _resolve_cantina(funding_type: String) -> Dictionary:
	var roster: Array[CrewMember] = GameManager.get_crew_roster()
	var events: Array[String] = []

	# Average Social stat determines base quality
	var avg_social: float = 0.0
	for cm: CrewMember in roster:
		avg_social += float(cm.social)
	avg_social /= maxf(float(roster.size()), 1.0)

	var quality_roll: int = randi_range(1, 100) + int(avg_social / 5.0)

	var morale_boost: float = 5.0
	var fatigue_reduction: float = 5.0
	var relationship_boost: float = 3.0

	if quality_roll > 120:
		morale_boost = 15.0
		fatigue_reduction = 10.0
		relationship_boost = 8.0
		events.append("[color=%s]A memorable night. The crew is in high spirits.[/color]" % COLOR_GOOD)
	elif quality_roll > 80:
		morale_boost = 10.0
		fatigue_reduction = 8.0
		relationship_boost = 5.0
		events.append("[color=%s]Good evening out. Exactly what the crew needed.[/color]" % COLOR_GOOD)
	elif quality_roll > 40:
		morale_boost = 5.0
		fatigue_reduction = 5.0
		relationship_boost = 3.0
		events.append("[color=%s]A quiet evening. Nothing special, but the crew relaxes.[/color]" % COLOR_MUTED)
	else:
		morale_boost = 2.0
		fatigue_reduction = 3.0
		relationship_boost = -2.0
		var incident: Dictionary = _generate_incident(roster)
		events.append("[color=%s]%s[/color]" % [COLOR_WARNING, incident.text])
		if incident.has("morale_penalty"):
			morale_boost += incident.morale_penalty

	# All-in bonus
	if funding_type == "all_in":
		morale_boost *= 1.5
		fatigue_reduction *= 1.3
		relationship_boost *= 1.5

	# Apply effects
	for cm: CrewMember in roster:
		cm.morale = clampf(cm.morale + morale_boost, 0.0, 100.0)
		cm.fatigue = maxf(0.0, cm.fatigue - fatigue_reduction)
		DatabaseManager.update_crew_member(cm.id, {
			"morale": cm.morale,
			"fatigue": cm.fatigue,
		})

	# Relationship boosts between random pairs (up to 3 pairs)
	if roster.size() >= 2:
		var pair_count: int = mini(3, roster.size() / 2)
		var shuffled: Array[CrewMember] = roster.duplicate()
		shuffled.shuffle()
		for i: int in range(pair_count):
			var idx_a: int = i * 2
			var idx_b: int = i * 2 + 1
			if idx_b >= shuffled.size():
				break
			var current_rel: float = DatabaseManager.get_relationship_value(shuffled[idx_a].id, shuffled[idx_b].id)
			var new_rel: float = clampf(current_rel + relationship_boost, -100.0, 100.0)
			DatabaseManager.update_relationship(shuffled[idx_a].id, shuffled[idx_b].id, new_rel)
			if relationship_boost > 0:
				events.append("[color=%s]%s and %s shared a good conversation over drinks.[/color]" % [
					COLOR_MUTED, shuffled[idx_a].crew_name, shuffled[idx_b].crew_name])

	# Advance time
	GameManager.advance_docked_day(1)

	events.append("[color=#555B66]  ↳ Morale +%.0f, fatigue -%.0f. 1 day passed.[/color]" % [morale_boost, fatigue_reduction])

	return {"events": events}


func _generate_incident(roster: Array[CrewMember]) -> Dictionary:
	# Species friction incidents
	for i: int in range(roster.size()):
		for j: int in range(i + 1, roster.size()):
			if roster[i].species != roster[j].species:
				var rel: float = DatabaseManager.get_relationship_value(roster[i].id, roster[j].id)
				if rel < -20.0 and randf() < 0.5:
					return {
						"text": "%s and %s got into it at the bar. Words were exchanged. A table was broken." % [
							roster[i].crew_name, roster[j].crew_name],
						"morale_penalty": -5.0,
					}

	# Generic incidents
	var unlucky: CrewMember = roster[randi() % roster.size()]
	var incidents: Array[String] = [
		"%s got into an argument with a local. Had to be pulled out before it escalated." % unlucky.crew_name,
		"%s drank too much and is paying for it. They'll be sluggish tomorrow." % unlucky.crew_name,
		"Someone picked %s's pocket at the bar. Lost a few credits." % unlucky.crew_name,
	]
	return {
		"text": incidents[randi() % incidents.size()],
		"morale_penalty": -3.0,
	}
