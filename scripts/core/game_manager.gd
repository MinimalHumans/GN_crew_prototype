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
	EventBus.credits_changed.emit(credits)


func spend_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
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
	## Returns fuel cost per jump based on ship class.
	match ship_class:
		"skiff":
			return FUEL_PER_JUMP_SKIFF
		"corvette":
			return FUEL_PER_JUMP_CORVETTE
		"frigate":
			return FUEL_PER_JUMP_FRIGATE
		_:
			return FUEL_PER_JUMP_SKIFF


func get_food_cost_per_jump() -> float:
	## Returns food consumed per jump. Captain always eats 1 unit.
	## In Phase 2, crew will add to this cost.
	return FOOD_PER_CAPTAIN_PER_JUMP


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
	var current_qty: int = DatabaseManager.get_cargo_quantity(save_id, commodity_id)
	if current_qty < quantity:
		return false
	var revenue: int = price_per_unit * quantity
	DatabaseManager.update_cargo(save_id, commodity_id, current_qty - quantity)
	add_credits(revenue)
	EventBus.cargo_changed.emit(commodity_id, current_qty - quantity)
	EventBus.trade_completed.emit(commodity_id, quantity, revenue, false)
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
	DatabaseManager.update_ship(current_ship_id, {"food_supply": food_supply})
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
	## Runs the stat check and calculates rewards for a completed mission.
	var primary_stat: String = TextTemplates.get_mission_primary_stat(mission.mission_type)
	var stat_value: int = _get_stat(primary_stat)
	var scaled_difficulty: int = DIFFICULTY_SCALE_BASE + mission.difficulty * DIFFICULTY_SCALE_PER_STAR
	var outcome: Dictionary = resolve_challenge(stat_value, scaled_difficulty)

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

	return {
		"mission": mission,
		"outcome_tier": outcome.tier,
		"roll": outcome.roll,
		"credit_reward": credit_reward,
		"xp_reward": xp_reward,
		"hull_damage": hull_damage,
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
