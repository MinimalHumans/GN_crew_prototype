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
	ship_class = ship.class
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


func get_fuel_cost_per_jump() -> float:
	## Returns fuel cost per jump based on ship class.
	match ship_class:
		"skiff":
			return 5.0
		"corvette":
			return 10.0
		"frigate":
			return 20.0
		_:
			return 5.0


func can_afford_ship(target_class: String) -> bool:
	match target_class:
		"corvette":
			return captain_level >= CORVETTE_UNLOCK_LEVEL and credits >= CORVETTE_PRICE
		"frigate":
			return captain_level >= FRIGATE_UNLOCK_LEVEL and credits >= FRIGATE_PRICE
		_:
			return false
