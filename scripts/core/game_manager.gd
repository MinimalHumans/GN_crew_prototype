extends Node
## GameManager — Holds current game state in memory.
## Handles new game initialization, save/load orchestration, and scene transitions.
## Does NOT query the database directly — calls DatabaseManager.

# === LEVEL THRESHOLDS ===
const XP_THRESHOLDS: Array[int] = [0, 100, 250, 500, 800, 1200, 1800, 2500, 3500, 5000]
const MAX_LEVEL: int = 10
const STAT_PER_LEVEL: int = 2
const BASE_STAT: int = 45

# Ship unlock levels
const CORVETTE_UNLOCK_LEVEL: int = 4
const FRIGATE_UNLOCK_LEVEL: int = 7

# Ship prices
const CORVETTE_PRICE: int = 2000
const FRIGATE_PRICE: int = 8000

# Fuel cost per jump by ship class (per user spec)
const FUEL_PER_JUMP_SKIFF: float = 3.0
const FUEL_PER_JUMP_CORVETTE: float = 5.0
const FUEL_PER_JUMP_FRIGATE: float = 8.0

# Food consumption per jump — captain always eats 1 unit
const FOOD_PER_CAPTAIN_PER_JUMP: float = 1.0
const FOOD_PER_CREW_PER_JUMP: float = 1.0

# Crew constants
const RECRUITMENT_FEE: int = 50
const KRELLVANI_SLOT_COST_SMALL: float = 1.5

# Mission constants
const MAX_ACTIVE_MISSIONS: int = 3
const DIFFICULTY_SCALE_BASE: int = 40
const DIFFICULTY_SCALE_PER_STAR: int = 15

# Encounter probability by danger level (per jump)
const ENCOUNTER_CHANCE_LOW: float = 0.10
const ENCOUNTER_CHANCE_LOW_MEDIUM: float = 0.18
const ENCOUNTER_CHANCE_MEDIUM: float = 0.25
const ENCOUNTER_CHANCE_HIGH: float = 0.40

# === CURRENT GAME STATE (in-memory) ===
var save_id: int = -1
var captain_name: String = ""
var captain_level: int = 1
var captain_xp: int = 0
var credits: int = 500
var current_planet_id: int = 1
var current_ship_id: int = -1
var day_count: int = 1
var pay_split: float = 0.5

# Captain stats
var stamina: int = 45
var cognition: int = 45
var reflexes: int = 45
var social: int = 45
var resourcefulness: int = 45

# Ship state (cached from DB)
var ship_class: String = "skiff"
var ship_name: String = "Skiff"
var hull_current: int = 50
var hull_max: int = 50
var fuel_current: float = 30.0
var fuel_max: float = 30.0
var cargo_max: int = 10
var crew_max: int = 0
var food_supply: float = 0.0

var is_game_active: bool = false

# Travel state (set before entering travel view)
var travel_destination_id: int = -1
var travel_route: Dictionary = {}
var travel_jumps: int = 0
var travel_fuel_cost: float = 0.0

# Crew simulation tracking (in-memory, reset each session)
var recent_events: Array[String] = []  # Rolling window of last 10 event types
var ticks_since_last_decision: int = 100  # Start high so decisions can fire early
var nudge_cooldowns: Dictionary = {}  # {nudge_type: ticks_remaining}
var stowaway_found: bool = false
var pending_promises: Array[Dictionary] = []  # e.g., {"type": "dock", "ticks_remaining": 3, "crew_id": 5}
var last_food_planet_id: int = -1

# Phase 5.4/5.5 state (persisted in save_state)
var last_crew_gen_mission_tick: int = 0
var morale_floor: float = 0.0
var combat_morale_resistance: float = 0.0

# Phase 6: Economy tracking (persisted in save_state)
var total_credits_earned: int = 0
var total_credits_spent: int = 0
var win_triggered: bool = false

# Recruitment candidate cache — cleared on departure
var cached_recruitment_candidates: Array = []  # Array of CrewMember
var cached_recruitment_planet_id: int = -1

# Phase 3 one-time log flags (reset per session)
var gorvian_fuel_logged: bool = false
var claustrophobia_logged: Dictionary = {}  # {crew_id: true}
var cold_morale_logged: Dictionary = {}  # {planet_id: true}

# Faction access level constants
enum AccessLevel { OUTSIDER, BASELINE, INSIDER }
const OUTSIDER_PRICE_MARKUP: float = 1.20
const INSIDER_PRICE_DISCOUNT: float = 0.90


# === INITIALIZATION ===

func start_new_game(p_captain_name: String, starting_credits: int = 500, starting_level: int = 1) -> void:
	## Creates a new game save and initializes all state.
	DatabaseManager.seed_universe()

	save_id = DatabaseManager.create_new_save(p_captain_name, starting_credits, starting_level)
	if save_id < 0:
		push_error("Failed to create new save")
		return

	# Load the state we just created
	_load_state_from_db()
	is_game_active = true

	# Mark Haven as visited
	DatabaseManager.mark_planet_visited(save_id, current_planet_id, day_count)

	EventBus.game_started.emit(captain_name)
	EventBus.planet_arrived.emit(current_planet_id, _get_planet_name(current_planet_id))

	# Transition to planet view
	change_scene("res://scenes/planet/planet_view.tscn")


func load_game() -> bool:
	## Loads the most recent save. Returns true on success.
	var save_data: Dictionary = DatabaseManager.load_save()
	if save_data.is_empty():
		return false

	save_id = save_data.id
	_load_state_from_db()
	is_game_active = true

	EventBus.game_loaded.emit(save_id)
	EventBus.planet_arrived.emit(current_planet_id, _get_planet_name(current_planet_id))
	return true


func _load_state_from_db() -> void:
	var save_data: Dictionary = DatabaseManager.load_save()
	if save_data.is_empty():
		return

	captain_name = save_data.captain_name
	captain_level = save_data.captain_level
	captain_xp = save_data.captain_xp
	credits = save_data.credits
	current_planet_id = save_data.current_planet_id
	current_ship_id = save_data.current_ship_id
	day_count = save_data.day_count
	pay_split = save_data.pay_split
	last_food_planet_id = save_data.get("last_food_planet_id", -1)
	last_crew_gen_mission_tick = save_data.get("last_crew_gen_mission_tick", 0)
	morale_floor = save_data.get("morale_floor", 0.0)
	combat_morale_resistance = save_data.get("combat_morale_resistance", 0.0)
	total_credits_earned = save_data.get("total_credits_earned", 0)
	total_credits_spent = save_data.get("total_credits_spent", 0)
	win_triggered = bool(save_data.get("win_triggered", 0))

	# Load captain stats
	var stats: Dictionary = DatabaseManager.get_captain_stats(save_id)
	if not stats.is_empty():
		stamina = stats.stamina
		cognition = stats.cognition
		reflexes = stats.reflexes
		social = stats.social
		resourcefulness = stats.resourcefulness

	# Load ship state
	_refresh_ship_state()


func _refresh_ship_state() -> void:
	if current_ship_id < 0:
		return
	var ship: Dictionary = DatabaseManager.get_ship(current_ship_id)
	if ship.is_empty():
		return
	ship_class = ship["class"]
	ship_name = ship.name
	hull_current = ship.hull_current
	hull_max = ship.hull_max
	fuel_current = ship.fuel_current
	fuel_max = ship.fuel_max
	cargo_max = ship.cargo_max
	crew_max = ship.crew_max
	food_supply = ship.food_supply


# === SAVE ===

func save_game() -> void:
	if save_id < 0:
		return

	DatabaseManager.update_save_state(save_id, {
		"captain_name": captain_name,
		"captain_level": captain_level,
		"captain_xp": captain_xp,
		"credits": credits,
		"current_planet_id": current_planet_id,
		"current_ship_id": current_ship_id,
		"day_count": day_count,
		"pay_split": pay_split,
		"last_crew_gen_mission_tick": last_crew_gen_mission_tick,
		"morale_floor": morale_floor,
		"combat_morale_resistance": combat_morale_resistance,
		"total_credits_earned": total_credits_earned,
		"total_credits_spent": total_credits_spent,
		"win_triggered": 1 if win_triggered else 0,
	})

	DatabaseManager.update_captain_stats(save_id, {
		"stamina": stamina,
		"cognition": cognition,
		"reflexes": reflexes,
		"social": social,
		"resourcefulness": resourcefulness,
	})

	if current_ship_id >= 0:
		DatabaseManager.update_ship(current_ship_id, {
			"hull_current": hull_current,
			"fuel_current": fuel_current,
			"food_supply": food_supply,
		})

	EventBus.game_saved.emit(save_id)


# === CREDITS ===

func add_credits(amount: int) -> void:
	credits += amount
	total_credits_earned += amount
	EventBus.credits_changed.emit(credits)
	# Check win condition
	if not win_triggered and total_credits_earned >= 25000:
		win_triggered = true
		EventBus.win_condition_reached.emit(total_credits_earned)


func spend_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	total_credits_spent += amount
	EventBus.credits_changed.emit(credits)
	return true


# === XP & LEVELING ===

func add_xp(amount: int) -> void:
	captain_xp += amount
	EventBus.xp_gained.emit(amount, captain_xp)
	_check_level_up()


func _check_level_up() -> void:
	while captain_level < MAX_LEVEL:
		var threshold: int = XP_THRESHOLDS[captain_level]
		if captain_xp >= threshold:
			captain_level += 1
			stamina += STAT_PER_LEVEL
			cognition += STAT_PER_LEVEL
			reflexes += STAT_PER_LEVEL
			social += STAT_PER_LEVEL
			resourcefulness += STAT_PER_LEVEL

			# Persist immediately so stats survive a crash
			DatabaseManager.update_captain_stats(save_id, {
				"stamina": stamina,
				"cognition": cognition,
				"reflexes": reflexes,
				"social": social,
				"resourcefulness": resourcefulness,
			})
			DatabaseManager.update_save_state(save_id, {
				"captain_level": captain_level,
				"captain_xp": captain_xp,
			})

			EventBus.level_up.emit(captain_level)
			EventBus.stats_changed.emit()
		else:
			break


func get_xp_for_next_level() -> int:
	if captain_level >= MAX_LEVEL:
		return XP_THRESHOLDS[MAX_LEVEL - 1]
	return XP_THRESHOLDS[captain_level]


func get_xp_progress() -> float:
	## Returns 0.0-1.0 progress toward next level.
	if captain_level >= MAX_LEVEL:
		return 1.0
	var current_threshold: int = XP_THRESHOLDS[captain_level - 1] if captain_level > 1 else 0
	var next_threshold: int = XP_THRESHOLDS[captain_level]
	var range_size: int = next_threshold - current_threshold
	if range_size <= 0:
		return 1.0
	return float(captain_xp - current_threshold) / float(range_size)


# === TRAVEL ===

func get_fuel_cost_per_jump() -> float:
	## Returns fuel cost per jump based on ship class, reduced by Gorvian crew.
	var base: float
	match ship_class:
		"skiff":
			base = FUEL_PER_JUMP_SKIFF
		"corvette":
			base = FUEL_PER_JUMP_CORVETTE
		"frigate":
			base = FUEL_PER_JUMP_FRIGATE
		_:
			base = FUEL_PER_JUMP_SKIFF
	return base * get_gorvian_fuel_reduction()


func get_food_cost_per_jump() -> float:
	## Returns food consumed per jump with species modifiers.
	## Captain eats 1.0. Vellani eat 0.7x. Krellvani eat 1.3x. Others eat 1.0x.
	return get_species_food_cost()


func get_encounter_chance(danger_level: String) -> float:
	match danger_level:
		"low":
			return ENCOUNTER_CHANCE_LOW
		"low_medium":
			return ENCOUNTER_CHANCE_LOW_MEDIUM
		"medium":
			return ENCOUNTER_CHANCE_MEDIUM
		"high":
			return ENCOUNTER_CHANCE_HIGH
		_:
			return ENCOUNTER_CHANCE_LOW


func get_danger_display(danger_level: String) -> String:
	## Returns a player-facing danger string with color hint.
	match danger_level:
		"low":
			return "Low"
		"low_medium":
			return "Low-Medium"
		"medium":
			return "Medium"
		"high":
			return "High"
		_:
			return "Unknown"


func get_danger_color(danger_level: String) -> String:
	## Returns a BBCode hex color for the danger level.
	match danger_level:
		"low":
			return "#27AE60"
		"low_medium":
			return "#7FB069"
		"medium":
			return "#E67E22"
		"high":
			return "#C0392B"
		_:
			return "#718096"


func begin_travel(destination_id: int) -> void:
	## Sets up travel state and transitions to the travel view.
	travel_destination_id = destination_id
	travel_route = DatabaseManager.get_route_between(current_planet_id, destination_id)
	if travel_route.is_empty():
		push_error("No route between %d and %d" % [current_planet_id, destination_id])
		return
	travel_jumps = travel_route.jumps
	travel_fuel_cost = travel_jumps * get_fuel_cost_per_jump()

	EventBus.travel_started.emit(current_planet_id, destination_id, travel_jumps)
	change_scene("res://scenes/travel/travel_view.tscn")


func arrive_at_planet(planet_id: int) -> void:
	## Called when travel is complete. Updates state and transitions to planet view.
	current_planet_id = planet_id
	cached_recruitment_candidates = []
	cached_recruitment_planet_id = -1
	DatabaseManager.mark_planet_visited(save_id, planet_id, day_count)
	save_game()

	EventBus.travel_completed.emit(planet_id)
	EventBus.planet_arrived.emit(planet_id, _get_planet_name(planet_id))
	change_scene("res://scenes/planet/planet_view.tscn")


func process_jump() -> Dictionary:
	## Processes a single jump: fuel, food, day advance.
	## Returns a dictionary with what happened.
	var result: Dictionary = {
		"fuel_used": get_fuel_cost_per_jump(),
		"food_used": get_food_cost_per_jump(),
		"day": day_count,
	}

	# Deduct fuel
	fuel_current = maxf(0.0, fuel_current - result.fuel_used)
	EventBus.fuel_changed.emit(fuel_current, fuel_max)

	# Deduct food (0 for solo play, ready for Phase 2)
	food_supply = maxf(0.0, food_supply - result.food_used)
	EventBus.food_changed.emit(food_supply)

	# Advance day
	day_count += 1
	EventBus.day_advanced.emit(day_count)

	# Persist ship fuel/food changes
	if current_ship_id >= 0:
		DatabaseManager.update_ship(current_ship_id, {
			"fuel_current": fuel_current,
			"food_supply": food_supply,
		})

	return result


# === SCENE MANAGEMENT ===

func change_scene(scene_path: String) -> void:
	EventBus.scene_change_requested.emit(scene_path)
	get_tree().call_deferred("change_scene_to_file", scene_path)


# === HELPERS ===

func _get_planet_name(planet_id: int) -> String:
	var planet: Dictionary = DatabaseManager.get_planet(planet_id)
	if planet.is_empty():
		return "Unknown"
	return planet.name


func get_current_planet() -> Dictionary:
	return DatabaseManager.get_planet(current_planet_id)


func get_total_cargo() -> int:
	return DatabaseManager.get_total_cargo(save_id)


func get_food_days_remaining() -> String:
	## Returns a display string for food supply.
	var rate: float = get_food_cost_per_jump()
	if rate <= 0:
		return "%.0f units" % food_supply
	var jumps: int = int(food_supply / rate)
	return "%.0f units (~%d jumps)" % [food_supply, jumps]


func can_afford_ship(target_class: String) -> bool:
	match target_class:
		"corvette":
			return captain_level >= CORVETTE_UNLOCK_LEVEL and credits >= CORVETTE_PRICE
		"frigate":
			return captain_level >= FRIGATE_UNLOCK_LEVEL and credits >= FRIGATE_PRICE
		_:
			return false


func get_ship_price(target_class: String) -> int:
	match target_class:
		"corvette":
			return CORVETTE_PRICE
		"frigate":
			return FRIGATE_PRICE
		_:
			return 0


func get_ship_unlock_level(target_class: String) -> int:
	match target_class:
		"corvette":
			return CORVETTE_UNLOCK_LEVEL
		"frigate":
			return FRIGATE_UNLOCK_LEVEL
		_:
			return 1


func purchase_ship(target_class: String) -> bool:
	## Purchases a new ship. Carries over fuel (capped), cargo, and food.
	## Returns false if can't afford or level too low.
	if not can_afford_ship(target_class):
		return false

	# No downgrading
	var class_order: Dictionary = {"skiff": 0, "corvette": 1, "frigate": 2}
	var current_rank: int = class_order.get(ship_class, 0)
	var target_rank: int = class_order.get(target_class, 0)
	if target_rank <= current_rank:
		return false

	var price: int = get_ship_price(target_class)
	var template: Dictionary = DatabaseManager.get_ship_template(target_class)

	# Spend credits
	spend_credits(price)

	# Create new ship in DB
	DatabaseManager.create_ship_for_save(save_id, target_class)

	# Get the new ship id (most recently created)
	var new_ship_id: int = DatabaseManager.get_latest_ship_id(save_id)
	if new_ship_id < 0:
		push_error("Failed to create new ship")
		return false

	# Carry over fuel (capped to new max)
	var carried_fuel: float = minf(fuel_current, template.fuel_max)
	# Carry over food
	var carried_food: float = food_supply

	# Update new ship with carried-over values
	DatabaseManager.update_ship(new_ship_id, {
		"fuel_current": carried_fuel,
		"food_supply": carried_food,
	})

	# Update save to point to new ship
	current_ship_id = new_ship_id
	DatabaseManager.update_save_state(save_id, {
		"current_ship_id": current_ship_id,
	})

	# Refresh cached ship state
	_refresh_ship_state()

	# Emit signals
	EventBus.ship_purchased.emit(target_class)
	EventBus.fuel_changed.emit(fuel_current, fuel_max)
	EventBus.food_changed.emit(food_supply)
	EventBus.hull_changed.emit(hull_current, hull_max)

	save_game()
	return true


func get_cargo_space_remaining() -> int:
	return cargo_max - get_total_cargo()


# === TRADE ===

func buy_commodity(commodity_id: int, quantity: int, price_per_unit: int) -> bool:
	## Buys cargo. Returns false if insufficient credits or cargo space.
	var total_cost: int = price_per_unit * quantity
	if credits < total_cost:
		return false
	if get_cargo_space_remaining() < quantity:
		return false
	spend_credits(total_cost)
	var current_qty: int = DatabaseManager.get_cargo_quantity(save_id, commodity_id)
	DatabaseManager.update_cargo(save_id, commodity_id, current_qty + quantity)
	EventBus.cargo_changed.emit(commodity_id, current_qty + quantity)
	EventBus.trade_completed.emit(commodity_id, quantity, total_cost, true)
	return true


func sell_commodity(commodity_id: int, quantity: int, price_per_unit: int) -> bool:
	## Sells cargo. Returns false if insufficient cargo.
	## Awards 1 XP per 50 credits of estimated profit.
	var current_qty: int = DatabaseManager.get_cargo_quantity(save_id, commodity_id)
	if current_qty < quantity:
		return false
	var revenue: int = price_per_unit * quantity
	DatabaseManager.update_cargo(save_id, commodity_id, current_qty - quantity)
	add_credits(revenue)
	EventBus.cargo_changed.emit(commodity_id, current_qty - quantity)
	EventBus.trade_completed.emit(commodity_id, quantity, revenue, false)

	# Trading XP: estimate profit against galaxy average buy price
	var averages: Dictionary = DatabaseManager.get_galaxy_averages()
	if averages.has(commodity_id):
		var avg_buy: float = averages[commodity_id].avg_buy
		var profit: int = int(revenue - avg_buy * quantity)
		if profit > 0:
			var trade_xp: int = profit / 50
			if trade_xp > 0:
				add_xp(trade_xp)
	return true


# === SUPPLIES ===

func refuel(units: float, cost: int) -> bool:
	if credits < cost:
		return false
	spend_credits(cost)
	fuel_current = minf(fuel_max, fuel_current + units)
	DatabaseManager.update_ship(current_ship_id, {"fuel_current": fuel_current})
	EventBus.fuel_changed.emit(fuel_current, fuel_max)
	return true


func buy_food(units: float, cost: int) -> bool:
	if credits < cost:
		return false
	spend_credits(cost)
	food_supply += units
	last_food_planet_id = current_planet_id
	DatabaseManager.update_ship(current_ship_id, {"food_supply": food_supply})
	DatabaseManager.update_save_state(save_id, {"last_food_planet_id": last_food_planet_id})
	EventBus.food_changed.emit(food_supply)
	return true


func repair_hull(amount: int, cost: int) -> bool:
	if credits < cost:
		return false
	spend_credits(cost)
	hull_current = mini(hull_max, hull_current + amount)
	DatabaseManager.update_ship(current_ship_id, {"hull_current": hull_current})
	EventBus.hull_changed.emit(hull_current, hull_max)
	return true


# === MISSIONS ===

func accept_mission(mission_data: Dictionary) -> bool:
	## Accepts a mission from the board. Returns false if at max capacity.
	if DatabaseManager.get_active_mission_count(save_id) >= MAX_ACTIVE_MISSIONS:
		return false
	var mission_id: int = DatabaseManager.accept_mission(save_id, mission_data)
	if mission_id < 0:
		return false
	EventBus.mission_accepted.emit(mission_id)
	return true


func get_active_missions() -> Array:
	return DatabaseManager.get_missions_active(save_id)


func complete_missions_at_planet(planet_id: int) -> Array[Dictionary]:
	## Checks for active missions targeting this planet, resolves them, returns results.
	var missions: Array = DatabaseManager.get_missions_at_destination(save_id, planet_id)
	var results: Array[Dictionary] = []

	for mission: Dictionary in missions:
		var result: Dictionary = _resolve_mission(mission)
		results.append(result)
		DatabaseManager.remove_active_mission(mission.id)

	return results


func _resolve_mission(mission: Dictionary) -> Dictionary:
	## Runs crew-aware stat check and calculates rewards for a completed mission.
	var scaled_difficulty: int = DIFFICULTY_SCALE_BASE + mission.difficulty * DIFFICULTY_SCALE_PER_STAR
	var roster: Array[CrewMember] = get_crew_roster()

	# Parse roles from mission data
	var roles: Array = JSON.parse_string(mission.get("roles_tested", "[]"))
	if roles == null or roles.is_empty():
		roles = ["Generalist"]
	var primary_role: String = roles[0]
	var secondary_role: String = roles[1] if roles.size() > 1 else ""

	# Use crew-aware resolution if crew exists, otherwise captain-only
	var outcome: Dictionary
	var crew_events: Array[String] = []

	if roster.size() > 0:
		outcome = ChallengeResolver.resolve_crew_challenge(
			roster, primary_role, secondary_role, scaled_difficulty)
		# Apply crew consequences from mission
		crew_events = ChallengeResolver.apply_crew_consequences(outcome, roster)
		# Process relationship effects
		CrewSimulation.process_mission_result(outcome.tier, roles)
	else:
		# Solo captain — fallback to basic resolution
		var primary_stat: String = TextTemplates.get_mission_primary_stat(mission.mission_type)
		var stat_value: int = _get_stat(primary_stat)
		outcome = resolve_challenge(stat_value, scaled_difficulty)

	# Calculate rewards based on outcome tier
	var credit_reward: int = 0
	var xp_reward: int = 0
	var hull_damage: int = 0
	var base_xp: int = 20 * mission.difficulty

	match outcome.tier:
		"critical_success":
			credit_reward = mission.reward
			xp_reward = int(base_xp * 1.5)
		"success":
			credit_reward = mission.reward
			xp_reward = base_xp
		"marginal_success":
			credit_reward = int(mission.reward * 0.75)
			xp_reward = int(base_xp * 0.75)
			hull_damage = randi_range(5, 10)
		"failure":
			credit_reward = int(mission.reward * 0.25)
			xp_reward = int(base_xp * 0.5)
			hull_damage = randi_range(8, 15)
		"critical_failure":
			credit_reward = 0
			xp_reward = int(base_xp * 0.25)
			hull_damage = randi_range(12, 20)

	# Apply rewards
	if credit_reward > 0:
		add_credits(credit_reward)
	if xp_reward > 0:
		add_xp(xp_reward)
	if hull_damage > 0:
		hull_current = maxi(1, hull_current - hull_damage)
		DatabaseManager.update_ship(current_ship_id, {"hull_current": hull_current})
		EventBus.hull_changed.emit(hull_current, hull_max)

	EventBus.mission_completed.emit(mission.id, outcome.tier != "critical_failure")

	# Check for ship memory triggers from mission outcome
	if roster.size() > 0:
		var ship_mem_events: Array[String] = CrewSimulation.check_mission_ship_memory(outcome.tier, mission)
		crew_events.append_array(ship_mem_events)

		# Phase 5.2: Apply loyalty from mission result
		var loyalty_events: Array[String] = CrewSimulation.apply_mission_loyalty(outcome.tier, roster)
		crew_events.append_array(loyalty_events)

	return {
		"mission": mission,
		"outcome_tier": outcome.tier,
		"roll": outcome.roll,
		"credit_reward": credit_reward,
		"xp_reward": xp_reward,
		"hull_damage": hull_damage,
		"crew_events": crew_events,
		"primary_role": primary_role,
		"secondary_role": secondary_role,
	}


func resolve_challenge(stat_value: int, difficulty: int) -> Dictionary:
	## Runs the challenge resolution formula. Returns {tier, roll}.
	var effective_stat: int = stat_value  # No morale/fatigue modifiers in Phase 1
	var roll: int = effective_stat + randi_range(0, effective_stat)

	var tier: String
	if roll > 2 * difficulty:
		tier = "critical_success"
	elif roll > difficulty:
		tier = "success"
	elif roll > int(0.75 * difficulty):
		tier = "marginal_success"
	elif roll > int(0.5 * difficulty):
		tier = "failure"
	else:
		tier = "critical_failure"

	return {"tier": tier, "roll": roll}


# === CREW MANAGEMENT ===

func get_crew_roster() -> Array[CrewMember]:
	## Returns all active crew as CrewMember objects.
	var rows: Array = DatabaseManager.get_active_crew(save_id)
	var roster: Array[CrewMember] = []
	for row: Dictionary in rows:
		roster.append(CrewMember.from_dict(row))
	return roster


func get_crew_count() -> int:
	return DatabaseManager.get_active_crew_count(save_id)


func get_used_crew_slots() -> float:
	## Returns total crew slots used, accounting for Krellvani 1.5x on Corvette.
	var crew: Array = DatabaseManager.get_active_crew(save_id)
	var used: float = 0.0
	for row: Dictionary in crew:
		if row.species == "KRELLVANI" and ship_class in ["corvette", "frigate"]:
			used += KRELLVANI_SLOT_COST_SMALL
		else:
			used += 1.0
	return used


func get_available_crew_slots() -> float:
	return float(crew_max) - get_used_crew_slots()


func can_recruit(candidate: CrewMember) -> Dictionary:
	## Returns {"can": bool, "reason": String}.
	if crew_max <= 0:
		return {"can": false, "reason": "Your ship has no crew berths."}
	var slot_cost: float = candidate.get_crew_slot_cost(ship_class)
	if get_available_crew_slots() < slot_cost:
		if candidate.species == CrewMember.Species.KRELLVANI and ship_class in ["corvette", "frigate"]:
			return {"can": false, "reason": "Not enough crew slots. Krellvani require 1.5 slots on a %s." % ship_class.capitalize()}
		return {"can": false, "reason": "Crew is full (%d/%d)." % [get_crew_count(), crew_max]}
	if credits < RECRUITMENT_FEE:
		return {"can": false, "reason": "Not enough credits for recruitment fee (%d cr)." % RECRUITMENT_FEE}
	return {"can": true, "reason": ""}


func calculate_acceptance(candidate: CrewMember) -> float:
	## Returns acceptance probability (0.0-1.0).
	var prob: float = 70.0

	# Pay split modifier
	if pay_split >= 0.6:
		prob -= 15.0
	elif pay_split <= 0.4:
		prob += 15.0
	# 0.5 = no change

	# Level bonus
	prob += captain_level * 2.0

	# Quality penalty: -1% per avg stat above 55
	var avg_stat: float = candidate.get_average_stat()
	if avg_stat > 55.0:
		prob -= (avg_stat - 55.0)

	return clampf(prob, 20.0, 95.0)


func recruit_crew(candidate: CrewMember) -> Dictionary:
	## Attempts to recruit a candidate. Returns {result: "accept"/"reluctant"/"decline", crew_id: int}.
	var check: Dictionary = can_recruit(candidate)
	if not check.can:
		return {"result": "blocked", "reason": check.reason, "crew_id": -1}

	var prob: float = calculate_acceptance(candidate)
	var roll: float = randf() * 100.0

	if roll <= prob:
		# Full accept
		return _finalize_recruitment(candidate, 60.0, "accept")
	elif roll <= prob + 15.0:
		# Reluctant accept
		return _finalize_recruitment(candidate, 45.0, "reluctant")
	else:
		# Decline
		return {"result": "decline", "crew_id": -1}


func _finalize_recruitment(candidate: CrewMember, starting_morale: float, result_type: String) -> Dictionary:
	## Adds crew to DB, creates relationships, deducts fee.
	spend_credits(RECRUITMENT_FEE)

	var data: Dictionary = candidate.to_dict()
	data["morale"] = starting_morale
	data["hired_day"] = day_count

	var crew_id: int = DatabaseManager.insert_crew_member(save_id, data)

	# Create relationship rows with all existing crew
	var existing_crew: Array = DatabaseManager.get_active_crew(save_id)
	for row: Dictionary in existing_crew:
		if row.id == crew_id:
			continue
		var existing_species: CrewMember.Species = CrewMember._parse_species(row.species)
		var friction: int = CrewMember.get_friction_between(candidate.species, existing_species)
		DatabaseManager.insert_crew_relationship(crew_id, row.id, float(friction))

	# Ship culture propagation: copy ship memories as crew memories at 30% modifier
	var ship_memories: Array = DatabaseManager.get_ship_memories(save_id)
	for sm: Dictionary in ship_memories:
		var scaled_value: float = sm.get("modifier_value", 0.0) * 0.30
		DatabaseManager.insert_crew_memory(crew_id, {
			"trigger_text": sm.get("event_description", ""),
			"emotional_tag": "HARDENED",
			"modifier_type": sm.get("modifier_type", "COMBAT_PERFORMANCE"),
			"modifier_value": scaled_value,
			"context_match": sm.get("context_match", ""),
			"day_acquired": day_count,
			"significance": 3,
			"is_ship_culture": 1,
			"culture_scaled": 0,
		})

	EventBus.crew_recruited.emit(crew_id, candidate.crew_name)
	EventBus.crew_changed.emit()
	save_game()

	return {"result": result_type, "crew_id": crew_id}


func dismiss_crew(crew_id: int) -> void:
	## Dismisses a crew member (sets inactive, removes relationships and memories).
	## For legacy-aware dismissals, use dismiss_crew_with_legacy() instead.
	var crew_data: Dictionary = DatabaseManager.get_crew_member(crew_id)
	var crew_name: String = crew_data.get("name", "Unknown")

	DatabaseManager.deactivate_crew_member(crew_id)
	DatabaseManager.delete_crew_relationships(crew_id)
	DatabaseManager.delete_all_crew_memories(crew_id)

	EventBus.crew_dismissed.emit(crew_id, crew_name)
	EventBus.crew_changed.emit()
	save_game()


func dismiss_crew_with_legacy(crew_id: int, departure_type: String) -> Array[String]:
	## Dismisses a crew member with legacy generation.
	## departure_type: retirement, voluntary, dismissal_positive, dismissal_negative, dismissal_neutral, death
	## Returns array of event text strings for the message log.
	var crew_data: Dictionary = DatabaseManager.get_crew_member(crew_id)
	var crew_name: String = crew_data.get("name", "Unknown")
	var roster: Array[CrewMember] = get_crew_roster()
	var cm: CrewMember = CrewMember.from_dict(crew_data)

	# Generate legacy before deactivation (needs relationships)
	CrewSimulation.generate_departure_legacy(cm, departure_type)
	var legacy_events: Array[String] = []

	# Deactivate crew member
	DatabaseManager.deactivate_crew_member(crew_id)
	DatabaseManager.delete_crew_relationships(crew_id)

	# Emit appropriate signal based on departure type
	if departure_type == "retirement":
		EventBus.crew_retired.emit(crew_id, crew_name)
	elif departure_type == "death":
		EventBus.crew_died.emit(crew_id, crew_name, "")
	else:
		EventBus.crew_dismissed.emit(crew_id, crew_name)
	EventBus.crew_changed.emit()
	save_game()

	return legacy_events


func set_pay_split(new_split: float) -> void:
	pay_split = new_split
	DatabaseManager.update_save_state(save_id, {"pay_split": pay_split})
	EventBus.pay_split_changed.emit(pay_split)


# === FACTION ACCESS SYSTEM ===

func get_faction_access_level(planet_id: int) -> AccessLevel:
	## Calculates access level at a planet based on crew composition.
	## Returns OUTSIDER, BASELINE, or INSIDER.
	var planet: Dictionary = DatabaseManager.get_planet(planet_id)
	if planet.is_empty():
		return AccessLevel.BASELINE

	# Nexus Station is always baseline (neutral ground)
	if planet.get("is_neutral", 0) == 1:
		return AccessLevel.BASELINE

	var planet_faction: String = planet.get("faction", "")
	var roster: Array[CrewMember] = get_crew_roster()
	var matching_count: int = 0
	var has_matching_comms: bool = false
	var has_high_social_comms: bool = false

	# Captain (human) always counts as 1 for Commonwealth planets
	if planet_faction == "Human":
		matching_count += 1

	for cm: CrewMember in roster:
		var species_name: String = cm.get_species_name()
		if species_name == planet_faction:
			if cm.role == CrewMember.Role.COMMS_OFFICER:
				matching_count += 2  # Comms Officer of matching species counts as 2
				has_matching_comms = true
			else:
				matching_count += 1
		elif cm.role == CrewMember.Role.COMMS_OFFICER and cm.social > 60:
			has_high_social_comms = true

	# Insider: 2+ matching crew, or 1 matching Comms Officer
	if matching_count >= 2 or has_matching_comms:
		return AccessLevel.INSIDER
	# Baseline: 1 matching crew, or any Comms Officer with Social > 60
	if matching_count >= 1 or has_high_social_comms:
		return AccessLevel.BASELINE
	# Outsider: 0 matching crew
	return AccessLevel.OUTSIDER


func get_price_modifier(planet_id: int) -> float:
	## Returns the price multiplier for shop goods based on faction access.
	var access: AccessLevel = get_faction_access_level(planet_id)
	match access:
		AccessLevel.OUTSIDER:
			return OUTSIDER_PRICE_MARKUP
		AccessLevel.INSIDER:
			return INSIDER_PRICE_DISCOUNT
		_:
			return 1.0


func get_access_level_name(access: AccessLevel) -> String:
	match access:
		AccessLevel.OUTSIDER:
			return "outsider"
		AccessLevel.INSIDER:
			return "insider"
		_:
			return "baseline"


# === SPECIES TRAIT HELPERS ===

func get_gorvian_fuel_reduction() -> float:
	## Returns fuel reduction multiplier from Gorvian crew (5% per Gorvian, max 20%).
	var roster: Array[CrewMember] = get_crew_roster()
	var gorvian_count: int = 0
	for cm: CrewMember in roster:
		if cm.species == CrewMember.Species.GORVIAN:
			gorvian_count += 1
	var reduction: float = minf(float(gorvian_count) * 0.05, 0.20)
	return 1.0 - reduction


func get_species_food_cost() -> float:
	## Returns total food cost per jump accounting for species modifiers.
	## Captain eats 1.0. Vellani eat 0.7x. Krellvani eat 1.3x. Others eat 1.0x.
	var roster: Array[CrewMember] = get_crew_roster()
	var total: float = FOOD_PER_CAPTAIN_PER_JUMP
	for cm: CrewMember in roster:
		match cm.species:
			CrewMember.Species.VELLANI:
				total += FOOD_PER_CREW_PER_JUMP * 0.7
			CrewMember.Species.KRELLVANI:
				total += FOOD_PER_CREW_PER_JUMP * 1.3
			_:
				total += FOOD_PER_CREW_PER_JUMP
	return total


# === CREW SIMULATION HELPERS ===

func get_ship_morale() -> float:
	## Returns weighted average of all crew morale. Crisis crew weighted 1.5x.
	var roster: Array[CrewMember] = get_crew_roster()
	if roster.is_empty():
		return 100.0
	var total_weight: float = 0.0
	var weighted_sum: float = 0.0
	for cm: CrewMember in roster:
		var weight: float = 1.5 if cm.morale < 20.0 else 1.0
		weighted_sum += cm.morale * weight
		total_weight += weight
	return weighted_sum / total_weight


func get_ship_morale_word() -> String:
	## Returns a word descriptor for ship-wide morale.
	var m: float = get_ship_morale()
	if m > 80.0:
		return "Excellent"
	elif m > 60.0:
		return "Good"
	elif m > 40.0:
		return "Fair"
	elif m > 20.0:
		return "Poor"
	else:
		return "Critical"


func get_ship_morale_color() -> String:
	## Returns BBCode color for ship morale.
	var m: float = get_ship_morale()
	if m > 60.0:
		return "#27AE60"
	elif m > 40.0:
		return "#E67E22"
	else:
		return "#C0392B"


func record_event(event_type: String) -> void:
	## Adds an event type to the rolling window (max 10).
	recent_events.append(event_type)
	if recent_events.size() > 10:
		recent_events.pop_front()


func get_danger_ratio() -> float:
	## Returns ratio of dangerous events in the rolling window.
	if recent_events.is_empty():
		return 0.0
	var dangerous: int = 0
	for event: String in recent_events:
		if event in ["combat", "critical_failure", "hull_damage", "pirate_attack", "failure"]:
			dangerous += 1
	return float(dangerous) / float(recent_events.size())


func tick_nudge_cooldowns() -> void:
	## Decrements all nudge cooldowns by 1.
	var to_remove: Array[String] = []
	for key: String in nudge_cooldowns:
		nudge_cooldowns[key] -= 1
		if nudge_cooldowns[key] <= 0:
			to_remove.append(key)
	for key: String in to_remove:
		nudge_cooldowns.erase(key)


func tick_promises() -> Array[Dictionary]:
	## Decrements promise timers. Returns expired promises.
	var expired: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []
	for promise: Dictionary in pending_promises:
		promise.ticks_remaining -= 1
		if promise.ticks_remaining <= 0:
			expired.append(promise)
		else:
			remaining.append(promise)
	pending_promises = remaining
	return expired


func _get_stat(stat_name: String) -> int:
	match stat_name:
		"stamina":
			return stamina
		"cognition":
			return cognition
		"reflexes":
			return reflexes
		"social":
			return social
		"resourcefulness":
			return resourcefulness
		_:
			return resourcefulness
