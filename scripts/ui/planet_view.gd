extends Control
## Planet View — Primary hub screen.
## Left panel: planet visual, player info, ship info.
## Right panel: service buttons (or shop/mission board sub-panels), message log.

enum PanelMode { SERVICES, SHOP, MISSION_BOARD, SHIPYARD, RECRUITMENT, SHIP_VIEW, HOSPITAL, CANTINA, TRAINING, WELLNESS, CASINO, CULTURAL, BLACK_MARKET }
var current_panel: PanelMode = PanelMode.SERVICES
var _pending_decision: Dictionary = {}
var _decision_container: VBoxContainer = null

# === NODE REFERENCES — LEFT PANEL ===
@onready var planet_rect: ColorRect = $HSplit/LeftPanel/Margin/LeftVBox/PlanetSection/PlanetRect
@onready var planet_name_label: Label = $HSplit/LeftPanel/Margin/LeftVBox/PlanetSection/PlanetNameLabel
@onready var faction_label: Label = $HSplit/LeftPanel/Margin/LeftVBox/PlanetSection/FactionLabel
# Player info
@onready var captain_name_label: Label = $HSplit/LeftPanel/Margin/LeftVBox/PlayerSection/CaptainNameLabel
@onready var level_label: Label = $HSplit/LeftPanel/Margin/LeftVBox/PlayerSection/LevelRow/LevelLabel
@onready var xp_bar: ProgressBar = $HSplit/LeftPanel/Margin/LeftVBox/PlayerSection/LevelRow/XPBar
@onready var credits_label: Label = $HSplit/LeftPanel/Margin/LeftVBox/PlayerSection/CreditsLabel
# Ship info
@onready var ship_name_label: Label = $HSplit/LeftPanel/Margin/LeftVBox/ShipSection/ShipNameLabel
@onready var hull_bar: ProgressBar = $HSplit/LeftPanel/Margin/LeftVBox/ShipSection/HullRow/HullBar
@onready var hull_value_label: Label = $HSplit/LeftPanel/Margin/LeftVBox/ShipSection/HullRow/HullValue
@onready var fuel_bar: ProgressBar = $HSplit/LeftPanel/Margin/LeftVBox/ShipSection/FuelRow/FuelBar
@onready var fuel_value_label: Label = $HSplit/LeftPanel/Margin/LeftVBox/ShipSection/FuelRow/FuelValue
@onready var cargo_label: Label = $HSplit/LeftPanel/Margin/LeftVBox/ShipSection/CargoLabel
@onready var food_label: Label = $HSplit/LeftPanel/Margin/LeftVBox/ShipSection/FoodLabel
@onready var crew_label: Label = $HSplit/LeftPanel/Margin/LeftVBox/ShipSection/CrewLabel

# === NODE REFERENCES — RIGHT PANEL ===
@onready var service_header: Label = $HSplit/RightPanel/Margin/RightVBox/ServiceHeader
@onready var service_container: VBoxContainer = $HSplit/RightPanel/Margin/RightVBox/ServiceContainer
@onready var message_log: RichTextLabel = $HSplit/RightPanel/Margin/RightVBox/MessageLog
@onready var day_label: Label = $HSplit/RightPanel/Margin/RightVBox/BottomBar/DayLabel
@onready var ship_button: Button = $HSplit/RightPanel/Margin/RightVBox/BottomBar/ShipButton
@onready var save_button: Button = $HSplit/RightPanel/Margin/RightVBox/BottomBar/SaveButton
@onready var menu_button: Button = $HSplit/RightPanel/Margin/RightVBox/BottomBar/MenuButton

# Service button display names keyed by their database service string
const SERVICE_DISPLAY: Dictionary = {
	"mission_board": "Mission Board",
	"shop": "Shop",
	"recruitment": "Recruitment Station",
	"hospital": "Hospital",
	"shipyard": "Shipyard",
	"cantina": "Cantina",
	"training": "Training Facility",
	"wellness": "Wellness Center",
	"casino": "Casino",
	"cultural": "Cultural Experience",
	"black_market": "Black Market",
}


# === INITIALIZATION ===

func _ready() -> void:
	ship_button.pressed.connect(_show_ship_view)
	save_button.pressed.connect(_on_save_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	# Connect to EventBus for live updates
	EventBus.credits_changed.connect(func(_n: int) -> void: _update_player_info())
	EventBus.fuel_changed.connect(func(_c: float, _m: float) -> void: _update_ship_info())
	EventBus.food_changed.connect(func(_s: float) -> void: _update_ship_info())
	EventBus.hull_changed.connect(func(_c: int, _m: int) -> void: _update_ship_info())
	EventBus.level_up.connect(_on_level_up)
	EventBus.xp_gained.connect(func(_a: int, _t: int) -> void: _update_player_info())
	EventBus.crew_changed.connect(func() -> void: _update_ship_info())
	EventBus.decision_event_fired.connect(_on_decision_event)
	EventBus.win_condition_reached.connect(_on_win_condition)

	_update_planet_display()
	_update_player_info()
	_update_ship_info()
	_build_service_buttons()
	_log_arrival()
	_process_crew_arrival()
	_check_mission_completions()


# === PLANET DISPLAY ===

func _update_planet_display() -> void:
	var planet: Dictionary = GameManager.get_current_planet()
	if planet.is_empty():
		planet_name_label.text = "Unknown"
		faction_label.text = ""
		return

	planet_name_label.text = planet.name
	var type_display: String = planet.type.replace("_", " ").capitalize()
	# Show faction emblem indicator based on access level
	var access: GameManager.AccessLevel = GameManager.get_faction_access_level(GameManager.current_planet_id)
	var access_indicator: String = ""
	if planet.get("is_neutral", 0) == 1:
		access_indicator = " [N]"
	elif access == GameManager.AccessLevel.INSIDER:
		access_indicator = " [+]"
	elif access == GameManager.AccessLevel.OUTSIDER:
		access_indicator = " [-]"
	faction_label.text = "%s  —  %s Zone%s" % [type_display, planet.zone, access_indicator]

	# Tint the planet rect by faction color
	var faction_color: Color = TextTemplates.get_faction_color(planet.faction)
	planet_rect.color = faction_color.darkened(0.3)


# === PLAYER INFO ===

func _update_player_info() -> void:
	captain_name_label.text = "Cpt. %s" % GameManager.captain_name

	if GameManager.captain_level >= GameManager.MAX_LEVEL:
		level_label.text = "Level %d — MAX" % GameManager.captain_level
		xp_bar.max_value = 1.0
		xp_bar.value = 1.0
	else:
		var next_threshold: int = GameManager.get_xp_for_next_level()
		level_label.text = "Level %d — %d / %d XP" % [GameManager.captain_level, GameManager.captain_xp, next_threshold]
		xp_bar.max_value = next_threshold
		xp_bar.value = GameManager.captain_xp

	credits_label.text = "%d credits" % GameManager.credits


# === SHIP INFO ===

func _update_ship_info() -> void:
	ship_name_label.text = "%s  (%s-class)" % [GameManager.ship_name, GameManager.ship_class.capitalize()]

	hull_bar.max_value = GameManager.hull_max
	hull_bar.value = GameManager.hull_current
	hull_value_label.text = "%d/%d" % [GameManager.hull_current, GameManager.hull_max]

	fuel_bar.max_value = GameManager.fuel_max
	fuel_bar.value = GameManager.fuel_current
	fuel_value_label.text = "%.0f/%.0f" % [GameManager.fuel_current, GameManager.fuel_max]

	var total_cargo: int = GameManager.get_total_cargo()
	cargo_label.text = "Cargo: %d / %d units" % [total_cargo, GameManager.cargo_max]
	food_label.text = "Food: %s" % GameManager.get_food_days_remaining()
	crew_label.text = "Crew: %d / %d" % [GameManager.get_crew_count(), GameManager.crew_max]

	if GameManager.docked_days_this_visit > 0:
		day_label.text = "Day %d  (Docked: %d)" % [GameManager.day_count, GameManager.docked_days_this_visit]
	else:
		day_label.text = "Day %d" % GameManager.day_count


# === SERVICE BUTTONS ===

func _build_service_buttons() -> void:
	# Clear existing buttons
	for child: Node in service_container.get_children():
		child.queue_free()

	var planet: Dictionary = GameManager.get_current_planet()
	if planet.is_empty():
		return

	var services: Array = JSON.parse_string(planet.services)
	if services == null:
		services = []

	# Add a button per available service
	for service_key: String in services:
		if not SERVICE_DISPLAY.has(service_key):
			continue
		var btn: Button = Button.new()
		btn.text = SERVICE_DISPLAY[service_key]
		btn.custom_minimum_size = Vector2(0, 57)
		btn.pressed.connect(_on_service_pressed.bind(service_key))
		service_container.add_child(btn)

	# Depart button — always available
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	service_container.add_child(spacer)

	var depart_btn: Button = Button.new()
	depart_btn.text = "Depart"
	depart_btn.custom_minimum_size = Vector2(0, 66)
	depart_btn.add_theme_font_size_override("font_size", 27)
	depart_btn.pressed.connect(_on_depart_pressed)
	service_container.add_child(depart_btn)


func _on_service_pressed(service_key: String) -> void:
	match service_key:
		"mission_board":
			_show_mission_board()
		"shop":
			_show_shop()
		"recruitment":
			_show_recruitment()
		"hospital":
			_show_hospital()
		"shipyard":
			_show_shipyard()
		"cantina":
			_show_cantina()
		"training":
			_show_training()
		"wellness":
			_show_wellness()
		"casino":
			_show_casino()
		"cultural":
			_show_cultural()
		"black_market":
			_show_black_market()
		_:
			_append_log("[color=#718096]%s — not yet implemented.[/color]" % service_key)


# === PANEL SWITCHING ===

func _show_shop() -> void:
	_clear_service_area()
	service_header.text = "SHOP"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var shop: ShopView = ShopView.new(GameManager.current_planet_id)
	shop.back_pressed.connect(_show_services)
	shop.log_message.connect(_append_log)
	shop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(shop)
	current_panel = PanelMode.SHOP


func _show_mission_board() -> void:
	_clear_service_area()
	service_header.text = "MISSION BOARD"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var board: MissionBoardView = MissionBoardView.new(GameManager.current_planet_id)
	board.back_pressed.connect(_show_services)
	board.log_message.connect(_append_log)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(board)
	current_panel = PanelMode.MISSION_BOARD


func _show_shipyard() -> void:
	_clear_service_area()
	service_header.text = "SHIPYARD"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var shipyard: ShipyardView = ShipyardView.new()
	shipyard.back_pressed.connect(_show_services)
	shipyard.log_message.connect(_append_log)
	shipyard.ship_purchased.connect(func() -> void: _update_ship_info(); _update_player_info())
	shipyard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(shipyard)
	current_panel = PanelMode.SHIPYARD


func _show_recruitment() -> void:
	_clear_service_area()
	service_header.text = "RECRUITMENT STATION"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var recruitment: RecruitmentView = RecruitmentView.new(GameManager.current_planet_id)
	recruitment.back_pressed.connect(_show_services)
	recruitment.log_message.connect(_append_log)
	recruitment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(recruitment)
	current_panel = PanelMode.RECRUITMENT


func _show_hospital() -> void:
	_clear_service_area()
	service_header.text = "HOSPITAL"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var hospital: HospitalView = HospitalView.new(GameManager.current_planet_id)
	hospital.back_pressed.connect(_show_services)
	hospital.log_message.connect(_append_log)
	hospital.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(hospital)
	current_panel = PanelMode.HOSPITAL


func _show_cantina() -> void:
	_clear_service_area()
	service_header.text = "CANTINA"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var cantina: CantinaView = CantinaView.new(GameManager.current_planet_id)
	cantina.back_pressed.connect(_show_services)
	cantina.log_message.connect(_append_log)
	cantina.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(cantina)
	current_panel = PanelMode.CANTINA


func _show_training() -> void:
	_clear_service_area()
	service_header.text = "TRAINING FACILITY"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var training: TrainingView = TrainingView.new(GameManager.current_planet_id)
	training.back_pressed.connect(_show_services)
	training.log_message.connect(_append_log)
	training.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(training)
	current_panel = PanelMode.TRAINING


func _show_wellness() -> void:
	_clear_service_area()
	service_header.text = "WELLNESS CENTER"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var wellness: WellnessView = WellnessView.new(GameManager.current_planet_id)
	wellness.back_pressed.connect(_show_services)
	wellness.log_message.connect(_append_log)
	wellness.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(wellness)
	current_panel = PanelMode.WELLNESS


func _show_casino() -> void:
	_clear_service_area()
	service_header.text = "CASINO"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var casino: CasinoView = CasinoView.new(GameManager.current_planet_id)
	casino.back_pressed.connect(_show_services)
	casino.log_message.connect(_append_log)
	casino.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(casino)
	current_panel = PanelMode.CASINO


func _show_cultural() -> void:
	_clear_service_area()
	service_header.text = "CULTURAL EXPERIENCE"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var cultural: CulturalView = CulturalView.new(GameManager.current_planet_id)
	cultural.back_pressed.connect(_show_services)
	cultural.log_message.connect(_append_log)
	cultural.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(cultural)
	current_panel = PanelMode.CULTURAL


func _show_black_market() -> void:
	_clear_service_area()
	service_header.text = "BLACK MARKET"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var black_market: BlackMarketView = BlackMarketView.new(GameManager.current_planet_id)
	black_market.back_pressed.connect(_show_services)
	black_market.log_message.connect(_append_log)
	black_market.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(black_market)
	current_panel = PanelMode.BLACK_MARKET


func _show_win_screen() -> void:
	_clear_service_area()
	service_header.text = "VICTORY"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var win: WinScreen = WinScreen.new()
	win.back_pressed.connect(_show_services)
	win.log_message.connect(_append_log)
	win.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(win)


func _on_win_condition(_total_earned: int) -> void:
	_append_log("")
	_append_log("[color=#FFD700]═══════════════════════════════════════[/color]")
	_append_log("[color=#FFD700][b]VICTORY! You have earned 25,000 lifetime credits![/b][/color]")
	_append_log("[color=#FFD700]Your name will echo through the shipping lanes.[/color]")
	_append_log("[color=#FFD700]═══════════════════════════════════════[/color]")
	_append_log("[color=#718096]View your full summary from the Ship View, or continue playing.[/color]")
	# Auto-show the win screen
	_show_win_screen()


func _show_ship_view() -> void:
	_clear_service_area()
	service_header.text = "SHIP VIEW"
	service_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.size_flags_stretch_ratio = 2.0
	var ship_view: ShipView = ShipView.new()
	ship_view.back_pressed.connect(_show_services)
	ship_view.log_message.connect(_append_log)
	ship_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_container.add_child(ship_view)
	current_panel = PanelMode.SHIP_VIEW


func _show_services() -> void:
	_clear_service_area()
	service_header.text = "SERVICES"
	service_container.size_flags_vertical = 0
	service_container.size_flags_stretch_ratio = 1.0
	_build_service_buttons()
	current_panel = PanelMode.SERVICES


func _clear_service_area() -> void:
	for child: Node in service_container.get_children():
		child.queue_free()


# === MISSION COMPLETION ON ARRIVAL ===

func _check_mission_completions() -> void:
	var results: Array[Dictionary] = GameManager.complete_missions_at_planet(GameManager.current_planet_id)
	for result: Dictionary in results:
		_display_mission_result(result)
	if not results.is_empty():
		_update_player_info()
		_update_ship_info()


func _display_mission_result(result: Dictionary) -> void:
	var mission: Dictionary = result.mission
	var outcome_text: String = TextTemplates.get_mission_outcome_text(result.outcome_tier)
	var tier_color: String = _get_tier_color(result.outcome_tier)

	_append_log("")
	_append_log("[color=#4A90D9]━━━ Mission Complete: %s ━━━[/color]" % mission.title)

	# Line 1: Outcome with tier
	_append_log("[color=%s]%s[/color]" % [tier_color, outcome_text])

	# Line 2: Transit conditions summary — what affected this mission
	var modifiers: Array = result.get("condition_modifiers", [])
	if not modifiers.is_empty():
		var positive_sources: Array[String] = []
		var negative_sources: Array[String] = []
		for mod: Dictionary in modifiers:
			if mod.value < 0:
				positive_sources.append(mod.source)
			elif mod.value > 0:
				negative_sources.append(mod.source)

		if not positive_sources.is_empty():
			var unique_pos: Array[String] = _deduplicate(positive_sources)
			_append_log("[color=#27AE60]  Helped by: %s[/color]" % ", ".join(unique_pos))
		if not negative_sources.is_empty():
			var unique_neg: Array[String] = _deduplicate(negative_sources)
			_append_log("[color=#C0392B]  Hindered by: %s[/color]" % ", ".join(unique_neg))
	else:
		_append_log("[color=#718096]  No significant transit conditions affected this mission.[/color]")

	# Line 3: Crew contribution — who handled it and how well
	var primary_role: String = result.get("primary_role", "")
	var secondary_role: String = result.get("secondary_role", "")
	if primary_role != "":
		var crew_line: String = "  Crew: %s" % primary_role
		if secondary_role != "":
			crew_line += ", %s (support)" % secondary_role
		_append_log("[color=#718096]%s[/color]" % crew_line)

	# Line 4: What would have changed the result (only on non-critical-success)
	if result.outcome_tier != "critical_success":
		var suggestion: String = _get_improvement_suggestion(result)
		if suggestion != "":
			_append_log("[color=#555B66]  %s[/color]" % suggestion)

	# Line 5: Difficulty breakdown (subtle, for players who want to understand the system)
	var base_diff: int = result.get("base_difficulty", 0)
	var cond_mod: int = result.get("condition_modifier", 0)
	var eff_diff: int = result.get("effective_difficulty", base_diff)
	if cond_mod != 0:
		var mod_color: String = "#27AE60" if cond_mod < 0 else "#C0392B"
		_append_log("[color=#555B66]  Base difficulty: %d → Effective: %d [color=%s](%+d from transit)[/color][/color]" % [
			base_diff, eff_diff, mod_color, cond_mod])

	# Rewards
	if result.credit_reward > 0:
		_append_log("[color=#27AE60]  +%d credits[/color]" % result.credit_reward)
	if result.xp_reward > 0:
		_append_log("[color=#4A90D9]  +%d XP[/color]" % result.xp_reward)
	if result.hull_damage > 0:
		_append_log("[color=#C0392B]  Hull damage: -%d HP[/color]" % result.hull_damage)

	# Crew consequence events from the mission
	var crew_events: Array = result.get("crew_events", [])
	for event_text: String in crew_events:
		_append_log("  %s" % event_text)

	_append_log("[color=#4A90D9]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]")


func _get_tier_color(tier: String) -> String:
	match tier:
		"critical_success": return "#27AE60"
		"success": return "#27AE60"
		"marginal_success": return "#E67E22"
		"failure": return "#C0392B"
		"critical_failure": return "#C0392B"
		_: return "#718096"


func _get_improvement_suggestion(result: Dictionary) -> String:
	## Returns a "what would have helped" line based on negative condition modifiers.
	var suggestion_modifiers: Array = result.get("condition_modifiers", [])

	# Find the largest negative contributor (highest positive value = most harmful)
	var worst_source: String = ""
	var worst_value: int = 0
	for mod: Dictionary in suggestion_modifiers:
		if mod.value > worst_value:
			worst_value = mod.value
			worst_source = mod.get("type", "")

	if worst_source == "":
		return ""

	match worst_source:
		"no_medic":
			return "A Medic would have made a significant difference."
		"no_engineer":
			return "An Engineer could have mitigated technical problems."
		"no_gunner":
			return "A Gunner would have improved combat readiness."
		"no_science_officer":
			return "A Science Officer was needed for this mission type."
		"no_security":
			return "A Security Chief would have improved safety."
		"combat_incident", "combat_failure", "combat_critical_fail":
			return "A safer route would have avoided combat complications."
		"hull_damage":
			return "Maintaining hull integrity would have helped."
		"low_morale":
			return "Better crew morale would have improved performance."
		"faction_outsider":
			return "Faction connections at the destination would have eased things."

	return ""


func _deduplicate(arr: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	var deduped: Array[String] = []
	for s: String in arr:
		if not seen.has(s):
			seen[s] = true
			deduped.append(s)
	return deduped


# === LEVEL-UP NOTIFICATION ===

func _on_level_up(new_level: int) -> void:
	_update_player_info()
	var level_text: String = TextTemplates.get_level_up_text(new_level)
	_append_log("")
	_append_log("[color=#E6D159]==============================[/color]")
	_append_log("[color=#E6D159]  LEVEL UP! Captain is now Level %d[/color]" % new_level)
	_append_log("[color=#E6D159]  All stats +%d[/color]" % GameManager.STAT_PER_LEVEL)
	_append_log("[color=#718096]  %s[/color]" % level_text)
	_append_log("[color=#E6D159]==============================[/color]")
	_append_log("")


func _on_depart_pressed() -> void:
	GameManager.save_game()
	GameManager.change_scene("res://scenes/travel/node_map.tscn")


# === MESSAGE LOG ===

func _log_arrival() -> void:
	var planet: Dictionary = GameManager.get_current_planet()
	if planet.is_empty():
		return

	var arrival: String = TextTemplates.get_arrival_text(planet.name)
	_append_log("[color=#4A90D9]%s[/color]" % arrival)
	_append_log("[color=#718096]%s[/color]" % planet.description)

	# Phase 3: Faction access arrival flavor text
	_log_faction_access(planet)


func _process_crew_arrival() -> void:
	## Runs crew simulation arrival tick — fatigue recovery, comfort food, promise fulfillment.
	if GameManager.get_crew_count() <= 0:
		return

	var arrival_events: Array[String] = CrewSimulation.tick_planet_arrival()
	if arrival_events.is_empty():
		return

	_append_log("")
	for event_text: String in arrival_events:
		_append_log(event_text)

	# Show ship-wide morale summary on arrival
	var morale_word: String = GameManager.get_ship_morale_word()
	var morale_color: String = GameManager.get_ship_morale_color()
	_append_log("[color=%s]Ship morale: %s[/color]" % [morale_color, morale_word])
	_append_log("")


func _log_faction_access(planet: Dictionary) -> void:
	## Shows subtle faction access flavor text on arrival.
	if planet.get("is_neutral", 0) == 1:
		_append_log("[color=#718096]Neutral ground. All factions trade freely here.[/color]")
		return

	var access: GameManager.AccessLevel = GameManager.get_faction_access_level(GameManager.current_planet_id)
	var faction: String = planet.get("faction", "")
	var faction_color: String = TextTemplates.get_faction_hex_color(faction)

	match access:
		GameManager.AccessLevel.OUTSIDER:
			var text: String = TextTemplates.get_faction_access_text("outsider", planet.name, faction)
			_append_log("[color=%s]%s[/color]" % [faction_color, text])
		GameManager.AccessLevel.INSIDER:
			var text: String = TextTemplates.get_faction_access_text("insider", planet.name, faction)
			_append_log("[color=%s]%s[/color]" % [faction_color, text])
		_:
			pass  # Baseline — no special message

	# Phase 3.2: Gorvian cold sensitivity on cold planets
	if planet.get("cold_environment", 0) == 1:
		var roster: Array[CrewMember] = GameManager.get_crew_roster()
		for cm: CrewMember in roster:
			if cm.species == CrewMember.Species.GORVIAN:
				var new_morale: float = maxf(0.0, cm.morale - 3.0)
				DatabaseManager.update_crew_member(cm.id, {"morale": new_morale})
				_append_log("[color=#E67E22]%s shivers in the cold. Gorvians don't handle freezing well.[/color]" % cm.crew_name)
				_append_log("[color=#555B66]  ↳ Morale dropped.[/color]")


func _append_log(text: String) -> void:
	if text.strip_edges() == "" or text.begins_with("[color=#FFD700]═"):
		message_log.append_text(text + "\n")
		return
	var day_prefix: String = "[color=#718096][Day %d][/color] " % GameManager.day_count
	message_log.append_text(day_prefix + text + "\n")


# === BOTTOM BAR ===

func _on_save_pressed() -> void:
	GameManager.save_game()
	_append_log("[color=#27AE60]Game saved.[/color]")


func _on_menu_pressed() -> void:
	GameManager.save_game()
	GameManager.is_game_active = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# === DECISION EVENTS (Phase 5.4/5.5) ===

func _on_decision_event(event_data: Dictionary) -> void:
	## Handles decision events that fire during planet arrival (retirement, death, etc.).
	_pending_decision = event_data
	_show_planet_decision(event_data)


func _show_planet_decision(event_data: Dictionary) -> void:
	## Displays a decision popup in the message log area.
	if _decision_container != null:
		_decision_container.queue_free()

	_decision_container = VBoxContainer.new()
	_decision_container.add_theme_constant_override("separation", 4)

	var sep: HSeparator = HSeparator.new()
	_decision_container.add_child(sep)

	var text_lbl: RichTextLabel = RichTextLabel.new()
	text_lbl.bbcode_enabled = true
	text_lbl.fit_content = true
	text_lbl.scroll_active = false
	text_lbl.text = "[color=#E6D159]%s[/color]" % event_data.get("text", "")
	text_lbl.custom_minimum_size = Vector2(0, 40)
	_decision_container.add_child(text_lbl)

	var options: Array = event_data.get("options", [])
	for i: int in range(options.size()):
		var btn: Button = Button.new()
		btn.text = options[i].get("text", "Option %d" % (i + 1))
		btn.custom_minimum_size = Vector2(0, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_planet_decision_choice.bind(i))
		_decision_container.add_child(btn)

	_decision_container.add_child(HSeparator.new())

	# Add before the message log
	var parent: Node = message_log.get_parent()
	parent.add_child(_decision_container)
	parent.move_child(_decision_container, message_log.get_index())


func _on_planet_decision_choice(choice: int) -> void:
	if _decision_container != null:
		_decision_container.queue_free()
		_decision_container = null

	var result_text: String = CrewEventGenerator.resolve_decision(
		_pending_decision.get("id", ""), choice, _pending_decision)

	_append_log("[color=#F7FAFC]  → %s[/color]" % result_text)
	_pending_decision = {}
	_update_ship_info()
