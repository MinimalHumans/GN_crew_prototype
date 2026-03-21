extends Node
## DatabaseManager — Wraps all SQLite operations.
## Every database read/write goes through this singleton.
## Other scripts never construct SQL directly.

const DB_PATH: String = "user://captains_ledger.db"

var db: SQLite = null


# === INITIALIZATION ===

func _ready() -> void:
	db = SQLite.new()
	db.path = DB_PATH
	db.open_db()
	_create_tables()
	_migrate_schema()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if db:
			db.close_db()


# === SCHEMA CREATION ===

func _create_tables() -> void:
	# Phase 1 core tables
	db.query("""
		CREATE TABLE IF NOT EXISTS save_state (
			id INTEGER PRIMARY KEY,
			captain_name TEXT NOT NULL,
			captain_level INTEGER DEFAULT 1,
			captain_xp INTEGER DEFAULT 0,
			credits INTEGER DEFAULT 500,
			current_planet_id INTEGER DEFAULT 1,
			current_ship_id INTEGER,
			day_count INTEGER DEFAULT 1,
			pay_split REAL DEFAULT 0.5,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS captain_stats (
			id INTEGER PRIMARY KEY,
			save_id INTEGER NOT NULL,
			stamina INTEGER DEFAULT 45,
			cognition INTEGER DEFAULT 45,
			reflexes INTEGER DEFAULT 45,
			social INTEGER DEFAULT 45,
			resourcefulness INTEGER DEFAULT 45,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (save_id) REFERENCES save_state(id)
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS ships (
			id INTEGER PRIMARY KEY,
			save_id INTEGER NOT NULL,
			class TEXT NOT NULL,
			name TEXT NOT NULL,
			hull_current INTEGER NOT NULL,
			hull_max INTEGER NOT NULL,
			fuel_current REAL NOT NULL,
			fuel_max REAL NOT NULL,
			cargo_max INTEGER NOT NULL,
			crew_max INTEGER DEFAULT 0,
			food_supply REAL DEFAULT 0.0,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (save_id) REFERENCES save_state(id)
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS planets (
			id INTEGER PRIMARY KEY,
			name TEXT NOT NULL,
			zone TEXT NOT NULL,
			faction TEXT NOT NULL,
			type TEXT NOT NULL,
			services TEXT NOT NULL,
			description TEXT DEFAULT '',
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS routes (
			id INTEGER PRIMARY KEY,
			planet_a_id INTEGER NOT NULL,
			planet_b_id INTEGER NOT NULL,
			jumps INTEGER NOT NULL,
			danger_level TEXT NOT NULL,
			notes TEXT DEFAULT '',
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (planet_a_id) REFERENCES planets(id),
			FOREIGN KEY (planet_b_id) REFERENCES planets(id)
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS commodities (
			id INTEGER PRIMARY KEY,
			name TEXT NOT NULL,
			description TEXT DEFAULT '',
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS planet_prices (
			id INTEGER PRIMARY KEY,
			planet_id INTEGER NOT NULL,
			commodity_id INTEGER NOT NULL,
			base_buy INTEGER NOT NULL,
			base_sell INTEGER NOT NULL,
			current_buy INTEGER NOT NULL,
			current_sell INTEGER NOT NULL,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (planet_id) REFERENCES planets(id),
			FOREIGN KEY (commodity_id) REFERENCES commodities(id)
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS cargo (
			id INTEGER PRIMARY KEY,
			save_id INTEGER NOT NULL,
			commodity_id INTEGER NOT NULL,
			quantity INTEGER DEFAULT 0,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (save_id) REFERENCES save_state(id),
			FOREIGN KEY (commodity_id) REFERENCES commodities(id)
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS missions_available (
			id INTEGER PRIMARY KEY,
			planet_id INTEGER NOT NULL,
			type TEXT NOT NULL,
			destination_id INTEGER NOT NULL,
			difficulty INTEGER NOT NULL,
			reward INTEGER NOT NULL,
			title TEXT DEFAULT '',
			description TEXT DEFAULT '',
			complications TEXT DEFAULT '[]',
			roles_tested TEXT DEFAULT '[]',
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (planet_id) REFERENCES planets(id),
			FOREIGN KEY (destination_id) REFERENCES planets(id)
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS missions_active (
			id INTEGER PRIMARY KEY,
			save_id INTEGER NOT NULL,
			mission_type TEXT NOT NULL,
			destination_id INTEGER NOT NULL,
			difficulty INTEGER NOT NULL,
			reward INTEGER NOT NULL,
			title TEXT DEFAULT '',
			description TEXT DEFAULT '',
			complications TEXT DEFAULT '[]',
			roles_tested TEXT DEFAULT '[]',
			progress TEXT DEFAULT 'accepted',
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (save_id) REFERENCES save_state(id),
			FOREIGN KEY (destination_id) REFERENCES planets(id)
		)
	""")

	# Phase 2 crew tables
	db.query("""
		CREATE TABLE IF NOT EXISTS crew_members (
			id INTEGER PRIMARY KEY,
			save_id INTEGER NOT NULL,
			name TEXT NOT NULL,
			species TEXT NOT NULL,
			role TEXT NOT NULL,
			stamina INTEGER DEFAULT 45,
			cognition INTEGER DEFAULT 45,
			reflexes INTEGER DEFAULT 45,
			social INTEGER DEFAULT 45,
			resourcefulness INTEGER DEFAULT 45,
			morale REAL DEFAULT 60.0,
			fatigue REAL DEFAULT 0.0,
			loyalty REAL DEFAULT 50.0,
			is_active INTEGER DEFAULT 1,
			hired_day INTEGER DEFAULT 1,
			personality TEXT DEFAULT '',
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (save_id) REFERENCES save_state(id)
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS crew_relationships (
			id INTEGER PRIMARY KEY,
			crew_a_id INTEGER NOT NULL,
			crew_b_id INTEGER NOT NULL,
			value REAL DEFAULT 0.0,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (crew_a_id) REFERENCES crew_members(id),
			FOREIGN KEY (crew_b_id) REFERENCES crew_members(id)
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS visited_planets (
			id INTEGER PRIMARY KEY,
			save_id INTEGER NOT NULL,
			planet_id INTEGER NOT NULL,
			first_visited_day INTEGER DEFAULT 1,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (save_id) REFERENCES save_state(id),
			FOREIGN KEY (planet_id) REFERENCES planets(id),
			UNIQUE(save_id, planet_id)
		)
	""")

	# Phase 4 tables
	db.query("""
		CREATE TABLE IF NOT EXISTS crew_memories (
			id INTEGER PRIMARY KEY,
			crew_id INTEGER NOT NULL,
			trigger_text TEXT NOT NULL,
			emotional_tag TEXT NOT NULL,
			modifier_type TEXT NOT NULL,
			modifier_value REAL DEFAULT 0.0,
			context_match TEXT DEFAULT '',
			day_acquired INTEGER DEFAULT 1,
			significance REAL DEFAULT 1.0,
			is_ship_culture INTEGER DEFAULT 0,
			culture_scaled INTEGER DEFAULT 0,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (crew_id) REFERENCES crew_members(id)
		)
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS ship_memories (
			id INTEGER PRIMARY KEY,
			save_id INTEGER NOT NULL,
			event_description TEXT NOT NULL,
			modifier_type TEXT NOT NULL,
			modifier_value REAL DEFAULT 0.0,
			context_match TEXT DEFAULT '',
			day_acquired INTEGER DEFAULT 1,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (save_id) REFERENCES save_state(id)
		)
	""")

	# Phase 5.4: Crew-generated missions table
	db.query("""
		CREATE TABLE IF NOT EXISTS crew_generated_missions (
			id INTEGER PRIMARY KEY,
			save_id INTEGER NOT NULL,
			crew_id INTEGER NOT NULL,
			template_type TEXT NOT NULL,
			destination_id INTEGER NOT NULL,
			setup_text TEXT DEFAULT '',
			objective_text TEXT DEFAULT '',
			time_limit INTEGER DEFAULT 15,
			ticks_remaining INTEGER DEFAULT 15,
			status TEXT DEFAULT 'ACTIVE',
			extra_data TEXT DEFAULT '{}',
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (save_id) REFERENCES save_state(id),
			FOREIGN KEY (crew_id) REFERENCES crew_members(id),
			FOREIGN KEY (destination_id) REFERENCES planets(id)
		)
	""")

	# Phase 5.5: Crew legacy table
	db.query("""
		CREATE TABLE IF NOT EXISTS crew_legacy (
			id INTEGER PRIMARY KEY,
			save_id INTEGER NOT NULL,
			crew_name TEXT NOT NULL,
			crew_role TEXT NOT NULL,
			departure_type TEXT NOT NULL,
			legacy_text TEXT DEFAULT '',
			effect_type TEXT DEFAULT '',
			effect_value REAL DEFAULT 0.0,
			effect_context TEXT DEFAULT '',
			effect_ticks_remaining INTEGER DEFAULT -1,
			day_departed INTEGER DEFAULT 0,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (save_id) REFERENCES save_state(id)
		)
	""")

	# Phase 5.1: Romance table
	db.query("""
		CREATE TABLE IF NOT EXISTS crew_romances (
			id INTEGER PRIMARY KEY,
			save_id INTEGER NOT NULL,
			crew_a_id INTEGER NOT NULL,
			crew_b_id INTEGER NOT NULL,
			status TEXT DEFAULT 'ACTIVE',
			formed_day INTEGER DEFAULT 1,
			ended_day INTEGER DEFAULT 0,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (save_id) REFERENCES save_state(id),
			FOREIGN KEY (crew_a_id) REFERENCES crew_members(id),
			FOREIGN KEY (crew_b_id) REFERENCES crew_members(id)
		)
	""")


# === SEED DATA ===

func seed_universe() -> void:
	## Seeds the 12 planets, routes, 6 commodities, and base prices.
	## Called once on new game. Checks if data already exists.
	var result: Array = db.select_rows("planets", "", ["id"])
	if result.size() > 0:
		return  # Already seeded

	_seed_planets()
	_seed_routes()
	_seed_commodities()
	_seed_prices()


func _seed_planets() -> void:
	var planets: Array[Dictionary] = [
		# Commonwealth Zone (Human)
		{"name": "Haven", "zone": "Commonwealth", "faction": "Human", "type": "hub",
		 "services": '["mission_board","shop","recruitment","hospital","shipyard"]',
		 "description": "Starter planet. Safe, all services. Home base."},
		{"name": "Meridian", "zone": "Commonwealth", "faction": "Human", "type": "trade_hub",
		 "services": '["mission_board","shop"]',
		 "description": "Crossroads — connects to Hexarchy and FPU zones."},
		{"name": "Fallow", "zone": "Commonwealth", "faction": "Human", "type": "agricultural",
		 "services": '["mission_board","shop"]',
		 "description": "Quiet resupply stop. Cheapest food in the game."},
		# Hexarchy Zone (Gorvian)
		{"name": "Korrath Prime", "zone": "Hexarchy", "faction": "Gorvian", "type": "capital",
		 "services": '["mission_board","shop","recruitment","hospital","shipyard"]',
		 "description": "Best ship repairs. Outsiders pay premium without Gorvian crew."},
		{"name": "Dvarn", "zone": "Hexarchy", "faction": "Gorvian", "type": "mining",
		 "services": '["mission_board","shop"]',
		 "description": "Cold environment. Cheapest ore and metals."},
		{"name": "Sethi Orbital", "zone": "Hexarchy", "faction": "Gorvian", "type": "research",
		 "services": '["mission_board","recruitment"]',
		 "description": "Science/survey missions. Good science/engineer recruitment."},
		# FPU Zone (Vellani)
		{"name": "Lirien", "zone": "FPU", "faction": "Vellani", "type": "homeworld",
		 "services": '["mission_board","shop","recruitment","hospital"]',
		 "description": "Best recruitment pool in the game."},
		{"name": "Tessara", "zone": "FPU", "faction": "Vellani", "type": "cultural",
		 "services": '["mission_board","shop"]',
		 "description": "Diplomatic/social missions. Cheap luxury goods."},
		{"name": "Windhollow", "zone": "FPU", "faction": "Vellani", "type": "frontier",
		 "services": '["mission_board"]',
		 "description": "Exploration missions. Cheap fuel, sparse everything else."},
		# Outer Reach Zone (Krellvani)
		{"name": "Ironmaw", "zone": "Outer Reach", "faction": "Krellvani", "type": "stronghold",
		 "services": '["mission_board","shop","recruitment","shipyard"]',
		 "description": "Best weapons/upgrades. High-risk missions."},
		{"name": "Char", "zone": "Outer Reach", "faction": "Krellvani", "type": "contested",
		 "services": '["mission_board"]',
		 "description": "Most dangerous planet. Highest-paying missions."},
		{"name": "Nexus Station", "zone": "Outer Reach", "faction": "Krellvani", "type": "black_market",
		 "services": '["mission_board","shop"]',
		 "description": "Neutral hub. Unpredictable prices. Connects to multiple zones."},
	]

	for planet: Dictionary in planets:
		db.query_with_bindings(
			"INSERT INTO planets (name, zone, faction, type, services, description) VALUES (?, ?, ?, ?, ?, ?)",
			[planet.name, planet.zone, planet.faction, planet.type, planet.services, planet.description]
		)


func _seed_routes() -> void:
	# Planet IDs: Haven=1, Meridian=2, Fallow=3, Korrath Prime=4, Dvarn=5,
	# Sethi Orbital=6, Lirien=7, Tessara=8, Windhollow=9, Ironmaw=10, Char=11, Nexus Station=12

	var routes: Array[Dictionary] = [
		# Intra-zone: Commonwealth
		{"a": 1, "b": 2, "jumps": 2, "danger": "low", "notes": "Main Commonwealth artery"},
		{"a": 1, "b": 3, "jumps": 2, "danger": "low", "notes": "Resupply run"},
		{"a": 2, "b": 3, "jumps": 1, "danger": "low", "notes": "Short trade hop"},
		# Intra-zone: Hexarchy
		{"a": 4, "b": 5, "jumps": 2, "danger": "low", "notes": "Hexarchy mining route"},
		{"a": 4, "b": 6, "jumps": 2, "danger": "low", "notes": "Hexarchy research corridor"},
		# Intra-zone: FPU
		{"a": 7, "b": 8, "jumps": 2, "danger": "low", "notes": "FPU cultural route"},
		{"a": 7, "b": 9, "jumps": 3, "danger": "low_medium", "notes": "Frontier exploration path"},
		# Intra-zone: Outer Reach
		{"a": 10, "b": 11, "jumps": 2, "danger": "medium", "notes": "Outer Reach combat zone"},
		{"a": 10, "b": 12, "jumps": 2, "danger": "medium", "notes": "Syndicate supply line"},
		# Cross-zone routes
		{"a": 2, "b": 4, "jumps": 3, "danger": "medium", "notes": "Commonwealth-Hexarchy bridge"},
		{"a": 2, "b": 7, "jumps": 2, "danger": "low", "notes": "Commonwealth-FPU bridge"},
		{"a": 3, "b": 8, "jumps": 2, "danger": "low", "notes": "Agricultural-cultural quiet route"},
		{"a": 6, "b": 9, "jumps": 3, "danger": "medium", "notes": "Research frontier"},
		{"a": 6, "b": 12, "jumps": 3, "danger": "high", "notes": "Hexarchy-Outer Reach back channel"},
		{"a": 8, "b": 10, "jumps": 3, "danger": "high", "notes": "FPU-Outer Reach. Dangerous but profitable"},
		{"a": 12, "b": 1, "jumps": 3, "danger": "medium", "notes": "Smuggler's shortcut"},
	]

	for route: Dictionary in routes:
		db.query_with_bindings(
			"INSERT INTO routes (planet_a_id, planet_b_id, jumps, danger_level, notes) VALUES (?, ?, ?, ?, ?)",
			[route.a, route.b, route.jumps, route.danger, route.notes]
		)


func _seed_commodities() -> void:
	var commodities: Array[Array] = [
		["Food", "Crew sustenance. Also a trade good."],
		["Fuel", "Ship fuel. Also tradeable in bulk."],
		["Ore", "Raw extracted minerals."],
		["Metals", "Refined processed materials."],
		["Tech", "Components and electronics."],
		["Luxury", "Art, textiles, cultural goods."],
	]

	for c: Array in commodities:
		db.query_with_bindings(
			"INSERT INTO commodities (name, description) VALUES (?, ?)",
			[c[0], c[1]]
		)


func _seed_prices() -> void:
	# Commodity IDs: Food=1, Fuel=2, Ore=3, Metals=4, Tech=5, Luxury=6
	# Prices: [base_buy, base_sell] — buy is what the player pays, sell is what they receive
	# "Cheap" planets have low buy prices; "Expensive" planets have high buy prices
	# Sell price is typically 80-90% of buy price at same planet

	# Per-planet price profiles based on GDD economic descriptions
	# Format: {commodity_id: [base_buy, base_sell]}
	var price_data: Dictionary = {
		# Haven (1) — Average prices across all goods
		1: {1: [10, 8], 2: [12, 10], 3: [15, 12], 4: [20, 16], 5: [25, 20], 6: [22, 18]},
		# Meridian (2) — Cheap luxury and tech, good variety
		2: {1: [10, 8], 2: [12, 10], 3: [15, 12], 4: [20, 16], 5: [18, 15], 6: [14, 11]},
		# Fallow (3) — Cheapest food, moderate fuel
		3: {1: [5, 4], 2: [10, 8], 3: [16, 13], 4: [22, 18], 5: [30, 24], 6: [24, 19]},
		# Korrath Prime (4) — Cheap metals and tech, expensive food
		4: {1: [18, 14], 2: [12, 10], 3: [12, 10], 4: [12, 10], 5: [16, 13], 6: [22, 18]},
		# Dvarn (5) — Cheapest ore and metals, expensive food
		5: {1: [20, 16], 2: [8, 6], 3: [6, 5], 4: [10, 8], 5: [28, 22], 6: [28, 22]},
		# Sethi Orbital (6) — No trade goods (research outpost), high prices
		6: {1: [16, 13], 2: [14, 11], 3: [18, 14], 4: [24, 19], 5: [22, 18], 6: [26, 21]},
		# Lirien (7) — Good food variety, moderate prices
		7: {1: [8, 6], 2: [12, 10], 3: [16, 13], 4: [22, 18], 5: [24, 19], 6: [16, 13]},
		# Tessara (8) — Cheap luxury goods, cultural hub
		8: {1: [12, 10], 2: [16, 13], 3: [18, 14], 4: [22, 18], 5: [24, 19], 6: [8, 6]},
		# Windhollow (9) — Cheap fuel, sparse everything else
		9: {1: [14, 11], 2: [6, 5], 3: [16, 13], 4: [24, 19], 5: [30, 24], 6: [20, 16]},
		# Ironmaw (10) — Best weapons/upgrades, expensive tech
		10: {1: [14, 11], 2: [10, 8], 3: [8, 6], 4: [14, 11], 5: [30, 24], 6: [28, 22]},
		# Char (11) — No shop (contested), but high reference prices
		11: {1: [22, 18], 2: [14, 11], 3: [14, 11], 4: [20, 16], 5: [28, 22], 6: [30, 24]},
		# Nexus Station (12) — Everything available, unpredictable (medium base)
		12: {1: [12, 10], 2: [14, 11], 3: [12, 10], 4: [18, 14], 5: [20, 16], 6: [18, 14]},
	}

	for planet_id: int in price_data:
		var commodities: Dictionary = price_data[planet_id]
		for commodity_id: int in commodities:
			var prices: Array = commodities[commodity_id]
			db.query_with_bindings(
				"INSERT INTO planet_prices (planet_id, commodity_id, base_buy, base_sell, current_buy, current_sell) VALUES (?, ?, ?, ?, ?, ?)",
				[planet_id, commodity_id, prices[0], prices[1], prices[0], prices[1]]
			)


# === SAVE/LOAD ===

func create_new_save(captain_name: String, starting_credits: int = 500, starting_level: int = 1) -> int:
	## Creates a new save and returns the save_id.
	db.query_with_bindings(
		"INSERT INTO save_state (captain_name, captain_level, credits) VALUES (?, ?, ?)",
		[captain_name, starting_level, starting_credits]
	)
	var result: Array = db.select_rows("save_state", "captain_name = '%s'" % captain_name, ["id"])
	if result.is_empty():
		return -1
	var save_id: int = result.back().id

	# Create captain stats — apply level bonus if starting above 1
	var base_stat: int = 45 + (starting_level - 1) * 2
	db.query_with_bindings(
		"INSERT INTO captain_stats (save_id, stamina, cognition, reflexes, social, resourcefulness) VALUES (?, ?, ?, ?, ?, ?)",
		[save_id, base_stat, base_stat, base_stat, base_stat, base_stat]
	)

	# Create starting ship (Skiff)
	_create_ship(save_id, "skiff")

	# Set the current ship
	var ships: Array = db.select_rows("ships", "save_id = %d" % save_id, ["id"])
	if not ships.is_empty():
		db.query_with_bindings(
			"UPDATE save_state SET current_ship_id = ? WHERE id = ?",
			[ships[0].id, save_id]
		)

	# Initialize empty cargo slots
	for commodity_id: int in range(1, 7):
		db.query_with_bindings(
			"INSERT INTO cargo (save_id, commodity_id, quantity) VALUES (?, ?, 0)",
			[save_id, commodity_id]
		)

	return save_id


func _create_ship(save_id: int, ship_class: String) -> void:
	var ship_data: Dictionary = get_ship_template(ship_class)
	db.query_with_bindings(
		"INSERT INTO ships (save_id, class, name, hull_current, hull_max, fuel_current, fuel_max, cargo_max, crew_max, food_supply) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
		[save_id, ship_data["class"], ship_data.name, ship_data.hull_max, ship_data.hull_max,
		 ship_data.fuel_max, ship_data.fuel_max, ship_data.cargo_max, ship_data.crew_max, ship_data.starting_food]
	)


func get_ship_template(ship_class: String) -> Dictionary:
	match ship_class:
		"skiff":
			return {"class": "skiff", "name": "Skiff", "hull_max": 50, "fuel_max": 30, "cargo_max": 10, "crew_max": 0, "starting_food": 10.0}
		"corvette":
			return {"class": "corvette", "name": "Corvette", "hull_max": 120, "fuel_max": 60, "cargo_max": 25, "crew_max": 3, "starting_food": 20.0}
		"frigate":
			return {"class": "frigate", "name": "Frigate", "hull_max": 250, "fuel_max": 100, "cargo_max": 50, "crew_max": 12, "starting_food": 40.0}
		_:
			return {"class": "skiff", "name": "Skiff", "hull_max": 50, "fuel_max": 30, "cargo_max": 10, "crew_max": 0, "starting_food": 10.0}


func create_ship_for_save(save_id: int, ship_class: String) -> void:
	## Creates a new ship record for the given save.
	_create_ship(save_id, ship_class)


func get_latest_ship_id(save_id: int) -> int:
	## Returns the id of the most recently created ship for a save.
	var result: Array = db.select_rows("ships", "save_id = %d" % save_id, ["id"])
	if result.is_empty():
		return -1
	return result.back().id


func has_save() -> bool:
	var result: Array = db.select_rows("save_state", "", ["id"])
	return not result.is_empty()


func load_save() -> Dictionary:
	## Returns the most recent save state as a dictionary.
	var saves: Array = db.select_rows("save_state", "", ["*"])
	if saves.is_empty():
		return {}
	return saves.back()


func get_captain_stats(save_id: int) -> Dictionary:
	var result: Array = db.select_rows("captain_stats", "save_id = %d" % save_id, ["*"])
	if result.is_empty():
		return {}
	return result[0]


func get_ship(ship_id: int) -> Dictionary:
	var result: Array = db.select_rows("ships", "id = %d" % ship_id, ["*"])
	if result.is_empty():
		return {}
	return result[0]


func get_current_ship(save_id: int) -> Dictionary:
	var save: Dictionary = load_save()
	if save.is_empty() or not save.has("current_ship_id"):
		return {}
	return get_ship(save.current_ship_id)


func get_planet(planet_id: int) -> Dictionary:
	var result: Array = db.select_rows("planets", "id = %d" % planet_id, ["*"])
	if result.is_empty():
		return {}
	return result[0]


func get_all_planets() -> Array:
	return db.select_rows("planets", "", ["*"])


func get_routes_from(planet_id: int) -> Array:
	var results: Array = []
	# Routes are bidirectional
	var from_a: Array = db.select_rows("routes", "planet_a_id = %d" % planet_id, ["*"])
	var from_b: Array = db.select_rows("routes", "planet_b_id = %d" % planet_id, ["*"])
	results.append_array(from_a)
	results.append_array(from_b)
	return results


func get_route_between(planet_a: int, planet_b: int) -> Dictionary:
	var result: Array = db.select_rows(
		"routes",
		"(planet_a_id = %d AND planet_b_id = %d) OR (planet_a_id = %d AND planet_b_id = %d)" % [planet_a, planet_b, planet_b, planet_a],
		["*"]
	)
	if result.is_empty():
		return {}
	return result[0]


func get_planet_prices(planet_id: int) -> Array:
	return db.select_rows("planet_prices", "planet_id = %d" % planet_id, ["*"])


func get_cargo(save_id: int) -> Array:
	return db.select_rows("cargo", "save_id = %d" % save_id, ["*"])


func get_commodity(commodity_id: int) -> Dictionary:
	var result: Array = db.select_rows("commodities", "id = %d" % commodity_id, ["*"])
	if result.is_empty():
		return {}
	return result[0]


func get_all_commodities() -> Array:
	return db.select_rows("commodities", "", ["*"])


# === UPDATE OPERATIONS ===

func update_save_state(save_id: int, data: Dictionary) -> void:
	var sets: PackedStringArray = []
	var values: Array = []
	for key: String in data:
		sets.append("%s = ?" % key)
		values.append(data[key])
	values.append(save_id)
	db.query_with_bindings(
		"UPDATE save_state SET %s, updated_at = CURRENT_TIMESTAMP WHERE id = ?" % ", ".join(sets),
		values
	)


func update_ship(ship_id: int, data: Dictionary) -> void:
	var sets: PackedStringArray = []
	var values: Array = []
	for key: String in data:
		sets.append("%s = ?" % key)
		values.append(data[key])
	values.append(ship_id)
	db.query_with_bindings(
		"UPDATE ships SET %s, updated_at = CURRENT_TIMESTAMP WHERE id = ?" % ", ".join(sets),
		values
	)


func update_captain_stats(save_id: int, data: Dictionary) -> void:
	var sets: PackedStringArray = []
	var values: Array = []
	for key: String in data:
		sets.append("%s = ?" % key)
		values.append(data[key])
	values.append(save_id)
	db.query_with_bindings(
		"UPDATE captain_stats SET %s, updated_at = CURRENT_TIMESTAMP WHERE save_id = ?" % ", ".join(sets),
		values
	)


func update_cargo(save_id: int, commodity_id: int, quantity: int) -> void:
	db.query_with_bindings(
		"UPDATE cargo SET quantity = ?, updated_at = CURRENT_TIMESTAMP WHERE save_id = ? AND commodity_id = ?",
		[quantity, save_id, commodity_id]
	)


func delete_save(save_id: int) -> void:
	## Deletes a save and all associated data.
	# Delete crew memories and relationships first (they reference crew_members)
	var crew_ids: Array = db.select_rows("crew_members", "save_id = %d" % save_id, ["id"])
	for crew: Dictionary in crew_ids:
		db.query_with_bindings("DELETE FROM crew_relationships WHERE crew_a_id = ? OR crew_b_id = ?", [crew.id, crew.id])
		db.query_with_bindings("DELETE FROM crew_memories WHERE crew_id = ?", [crew.id])
	# Delete ship memories, romances, crew-gen missions, and legacies
	db.query_with_bindings("DELETE FROM ship_memories WHERE save_id = ?", [save_id])
	db.query_with_bindings("DELETE FROM crew_romances WHERE save_id = ?", [save_id])
	db.query_with_bindings("DELETE FROM crew_generated_missions WHERE save_id = ?", [save_id])
	db.query_with_bindings("DELETE FROM crew_legacy WHERE save_id = ?", [save_id])
	for table: String in ["crew_members", "cargo", "missions_active", "visited_planets", "ships", "captain_stats"]:
		db.query_with_bindings("DELETE FROM %s WHERE save_id = ?" % table, [save_id])
	db.query_with_bindings("DELETE FROM save_state WHERE id = ?", [save_id])


# === VISITED PLANETS ===

func mark_planet_visited(save_id: int, planet_id: int, day: int) -> void:
	db.query_with_bindings(
		"INSERT OR IGNORE INTO visited_planets (save_id, planet_id, first_visited_day) VALUES (?, ?, ?)",
		[save_id, planet_id, day]
	)


func is_planet_visited(save_id: int, planet_id: int) -> bool:
	var result: Array = db.select_rows(
		"visited_planets",
		"save_id = %d AND planet_id = %d" % [save_id, planet_id],
		["id"]
	)
	return not result.is_empty()


func get_visited_planet_ids(save_id: int) -> Array[int]:
	var result: Array = db.select_rows("visited_planets", "save_id = %d" % save_id, ["planet_id"])
	var ids: Array[int] = []
	for row: Dictionary in result:
		ids.append(row.planet_id)
	return ids


# === CARGO HELPERS ===

func get_total_cargo(save_id: int) -> int:
	## Returns total units of cargo currently held.
	var cargo_rows: Array = get_cargo(save_id)
	var total: int = 0
	for row: Dictionary in cargo_rows:
		total += row.quantity
	return total


func get_all_routes() -> Array:
	return db.select_rows("routes", "", ["*"])


# === SCHEMA MIGRATION ===

func _migrate_schema() -> void:
	## Adds columns that may be missing from older databases.
	## Uses PRAGMA table_info to check before altering, since SQLite
	## does not support ALTER TABLE ADD COLUMN IF NOT EXISTS.
	_add_column_if_missing("missions_available", "roles_tested", "TEXT DEFAULT '[]'")
	_add_column_if_missing("missions_active", "roles_tested", "TEXT DEFAULT '[]'")
	# Phase 2.4 crew simulation tracking
	_add_column_if_missing("crew_members", "ticks_since_role_used", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_members", "comfort_food_ticks", "INTEGER DEFAULT 0")
	_add_column_if_missing("save_state", "last_food_planet_id", "INTEGER DEFAULT -1")
	# Phase 2.7 injury tracking and fast learner flag
	_add_column_if_missing("crew_members", "injuries", "TEXT DEFAULT '[]'")
	_add_column_if_missing("crew_members", "fast_learner", "INTEGER DEFAULT 0")
	# Phase 3 species & faction identity
	_add_column_if_missing("crew_members", "morale_bonus", "REAL DEFAULT 0.0")
	_add_column_if_missing("planets", "cold_environment", "INTEGER DEFAULT 0")
	_add_column_if_missing("planets", "is_neutral", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_relationships", "bonding_breakthrough", "INTEGER DEFAULT 0")
	# Phase 4: Skill progression
	_add_column_if_missing("crew_members", "role_experience", "REAL DEFAULT 0.0")
	_add_column_if_missing("crew_members", "pinch_hit_experience", "TEXT DEFAULT '{}'")
	# Phase 4: Trait tracking
	_add_column_if_missing("crew_members", "traits", "TEXT DEFAULT '[]'")
	_add_column_if_missing("crew_members", "combat_encounter_count", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_members", "total_jumps", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_members", "low_food_ticks", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_members", "conflicts_mediated", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_members", "total_injuries_sustained", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_members", "docked_ticks", "INTEGER DEFAULT 0")
	# Phase 5.2: Loyalty system
	_add_column_if_missing("crew_members", "value_preference", "TEXT DEFAULT ''")
	_add_column_if_missing("crew_members", "value_evidence_count", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_members", "loyalty_departure_stage", "INTEGER DEFAULT 0")
	# Phase 5.3: Disease tracking
	_add_column_if_missing("crew_members", "diseases", "TEXT DEFAULT '[]'")
	_add_column_if_missing("crew_members", "permanent_impairments", "TEXT DEFAULT '[]'")
	_add_column_if_missing("crew_members", "is_quarantined", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_members", "quarantine_ticks", "INTEGER DEFAULT 0")
	# Phase 5.3: Hospital service flag
	_add_column_if_missing("planets", "has_hospital", "INTEGER DEFAULT 0")
	# Phase 5.4: Crew-generated mission tracking
	_add_column_if_missing("crew_members", "origin", "TEXT DEFAULT 'recruited'")
	_add_column_if_missing("save_state", "last_crew_gen_mission_tick", "INTEGER DEFAULT 0")
	# Phase 5.5: Death, grief, legacy
	_add_column_if_missing("crew_members", "death_day", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_members", "grief_state", "TEXT DEFAULT ''")
	_add_column_if_missing("crew_members", "grief_ticks_remaining", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_members", "stat_bonus_all", "INTEGER DEFAULT 0")
	_add_column_if_missing("save_state", "morale_floor", "REAL DEFAULT 0.0")
	_add_column_if_missing("save_state", "combat_morale_resistance", "REAL DEFAULT 0.0")
	# Phase 6: Hospital checkup bonus
	_add_column_if_missing("crew_members", "checkup_bonus_ticks", "INTEGER DEFAULT 0")
	# Phase 6: Economy tracking
	_add_column_if_missing("save_state", "total_credits_earned", "INTEGER DEFAULT 0")
	_add_column_if_missing("save_state", "total_credits_spent", "INTEGER DEFAULT 0")
	_add_column_if_missing("save_state", "win_triggered", "INTEGER DEFAULT 0")
	_add_column_if_missing("crew_members", "faction_zones_visited", "TEXT DEFAULT '[]'")
	# Seed Phase 3 planet flags
	_seed_phase3_planet_flags()
	# Seed Phase 5.3 hospital flags
	_seed_phase5_hospital_flags()


func _seed_phase3_planet_flags() -> void:
	## Sets cold_environment on Dvarn (id=5) and is_neutral on Nexus Station (id=12).
	## Safe to call multiple times — just updates existing rows.
	db.query_with_bindings("UPDATE planets SET cold_environment = 1 WHERE id = ?", [5])
	db.query_with_bindings("UPDATE planets SET is_neutral = 1 WHERE id = ?", [12])


func _seed_phase5_hospital_flags() -> void:
	## Sets has_hospital on Haven (id=1), Korrath Prime (id=4), Lirien (id=7).
	for pid: int in [1, 4, 7]:
		db.query_with_bindings("UPDATE planets SET has_hospital = 1 WHERE id = ?", [pid])


func _add_column_if_missing(table_name: String, column_name: String, column_def: String) -> void:
	var columns: Array = db.select_rows("pragma_table_info('%s')" % table_name, "", ["name"])
	for col: Dictionary in columns:
		if col.name == column_name:
			return
	db.query("ALTER TABLE %s ADD COLUMN %s %s" % [table_name, column_name, column_def])


# === GALAXY AVERAGES ===

func get_galaxy_averages() -> Dictionary:
	## Returns {commodity_id: {"avg_buy": float, "avg_sell": float}} averaged across all planets.
	var all_prices: Array = db.select_rows("planet_prices", "", ["*"])
	var sums: Dictionary = {}  # {commodity_id: {"buy_sum": int, "sell_sum": int, "count": int}}
	for row: Dictionary in all_prices:
		var cid: int = row.commodity_id
		if not sums.has(cid):
			sums[cid] = {"buy_sum": 0, "sell_sum": 0, "count": 0}
		sums[cid].buy_sum += row.current_buy
		sums[cid].sell_sum += row.current_sell
		sums[cid].count += 1
	var averages: Dictionary = {}
	for cid: int in sums:
		var s: Dictionary = sums[cid]
		averages[cid] = {
			"avg_buy": float(s.buy_sum) / float(s.count),
			"avg_sell": float(s.sell_sum) / float(s.count),
		}
	return averages


func get_cargo_quantity(save_id: int, commodity_id: int) -> int:
	## Returns the quantity of a specific commodity in cargo.
	var rows: Array = db.select_rows(
		"cargo",
		"save_id = %d AND commodity_id = %d" % [save_id, commodity_id],
		["quantity"]
	)
	if rows.is_empty():
		return 0
	return rows[0].quantity


# === MISSION OPERATIONS ===

func get_missions_available(planet_id: int) -> Array:
	return db.select_rows("missions_available", "planet_id = %d" % planet_id, ["*"])


func clear_missions_available(planet_id: int) -> void:
	db.query_with_bindings("DELETE FROM missions_available WHERE planet_id = ?", [planet_id])


func insert_mission_available(data: Dictionary) -> void:
	db.query_with_bindings(
		"INSERT INTO missions_available (planet_id, type, destination_id, difficulty, reward, title, description, complications, roles_tested) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
		[data.planet_id, data.type, data.destination_id, data.difficulty, data.reward,
		 data.title, data.description, data.complications, data.roles_tested]
	)


func get_missions_active(save_id: int) -> Array:
	return db.select_rows("missions_active", "save_id = %d" % save_id, ["*"])


func get_active_mission_count(save_id: int) -> int:
	var rows: Array = db.select_rows("missions_active", "save_id = %d" % save_id, ["id"])
	return rows.size()


func accept_mission(save_id: int, mission_data: Dictionary) -> int:
	## Inserts a mission into missions_active. Returns the new id.
	db.query_with_bindings(
		"INSERT INTO missions_active (save_id, mission_type, destination_id, difficulty, reward, title, description, complications, roles_tested) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
		[save_id, mission_data.type, mission_data.destination_id, mission_data.difficulty,
		 mission_data.reward, mission_data.title, mission_data.description,
		 mission_data.get("complications", "[]"), mission_data.get("roles_tested", "[]")]
	)
	var result: Array = db.select_rows("missions_active", "save_id = %d" % save_id, ["id"])
	if result.is_empty():
		return -1
	return result.back().id


func get_missions_at_destination(save_id: int, planet_id: int) -> Array:
	## Returns active missions whose destination matches the given planet.
	return db.select_rows(
		"missions_active",
		"save_id = %d AND destination_id = %d" % [save_id, planet_id],
		["*"]
	)


func remove_active_mission(mission_id: int) -> void:
	db.query_with_bindings("DELETE FROM missions_active WHERE id = ?", [mission_id])


func remove_mission_available(mission_id: int) -> void:
	db.query_with_bindings("DELETE FROM missions_available WHERE id = ?", [mission_id])


# === CREW OPERATIONS ===

func insert_crew_member(save_id: int, data: Dictionary) -> int:
	## Inserts a new crew member and returns the new id.
	db.query_with_bindings(
		"INSERT INTO crew_members (save_id, name, species, role, stamina, cognition, reflexes, social, resourcefulness, morale, fatigue, loyalty, is_active, hired_day, personality) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
		[save_id, data.name, data.species, data.role, data.stamina, data.cognition,
		 data.reflexes, data.social, data.resourcefulness,
		 data.get("morale", 60.0), data.get("fatigue", 0.0), data.get("loyalty", 50.0),
		 data.get("is_active", 1), data.get("hired_day", 1), data.get("personality", "")]
	)
	var result: Array = db.select_rows("crew_members", "save_id = %d" % save_id, ["id"])
	if result.is_empty():
		return -1
	return result.back().id


func get_active_crew(save_id: int) -> Array:
	## Returns all active crew members for a save.
	return db.select_rows("crew_members", "save_id = %d AND is_active = 1" % save_id, ["*"])


func get_crew_member(crew_id: int) -> Dictionary:
	var result: Array = db.select_rows("crew_members", "id = %d" % crew_id, ["*"])
	if result.is_empty():
		return {}
	return result[0]


func get_active_crew_count(save_id: int) -> int:
	var rows: Array = db.select_rows("crew_members", "save_id = %d AND is_active = 1" % save_id, ["id"])
	return rows.size()


func deactivate_crew_member(crew_id: int) -> void:
	## Sets is_active = 0 (dismissed but kept for history).
	db.query_with_bindings(
		"UPDATE crew_members SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
		[crew_id]
	)


func update_crew_member(crew_id: int, data: Dictionary) -> void:
	var sets: PackedStringArray = []
	var values: Array = []
	for key: String in data:
		sets.append("%s = ?" % key)
		values.append(data[key])
	values.append(crew_id)
	db.query_with_bindings(
		"UPDATE crew_members SET %s, updated_at = CURRENT_TIMESTAMP WHERE id = ?" % ", ".join(sets),
		values
	)


# === CREW RELATIONSHIPS ===

func insert_crew_relationship(crew_a_id: int, crew_b_id: int, value: float) -> void:
	## Always store with lower id as crew_a_id.
	var a: int = mini(crew_a_id, crew_b_id)
	var b: int = maxi(crew_a_id, crew_b_id)
	db.query_with_bindings(
		"INSERT INTO crew_relationships (crew_a_id, crew_b_id, value) VALUES (?, ?, ?)",
		[a, b, value]
	)


func get_crew_relationships(crew_id: int) -> Array:
	## Returns all relationships involving this crew member.
	var from_a: Array = db.select_rows("crew_relationships", "crew_a_id = %d" % crew_id, ["*"])
	var from_b: Array = db.select_rows("crew_relationships", "crew_b_id = %d" % crew_id, ["*"])
	var all: Array = []
	all.append_array(from_a)
	all.append_array(from_b)
	return all


func get_relationship_value(crew_a_id: int, crew_b_id: int) -> float:
	## Returns the relationship value between two crew members.
	var a: int = mini(crew_a_id, crew_b_id)
	var b: int = maxi(crew_a_id, crew_b_id)
	var result: Array = db.select_rows(
		"crew_relationships",
		"crew_a_id = %d AND crew_b_id = %d" % [a, b],
		["value"]
	)
	if result.is_empty():
		return 0.0
	return result[0].value


func update_relationship(crew_a_id: int, crew_b_id: int, new_value: float) -> void:
	## Updates the relationship value between two crew members.
	var a: int = mini(crew_a_id, crew_b_id)
	var b: int = maxi(crew_a_id, crew_b_id)
	db.query_with_bindings(
		"UPDATE crew_relationships SET value = ?, updated_at = CURRENT_TIMESTAMP WHERE crew_a_id = ? AND crew_b_id = ?",
		[new_value, a, b]
	)


func get_all_crew_relationships(save_id: int) -> Array:
	## Returns all relationship rows for active crew in a save.
	var crew_ids: Array = db.select_rows("crew_members", "save_id = %d AND is_active = 1" % save_id, ["id"])
	if crew_ids.is_empty():
		return []
	var all_rels: Array = []
	for crew: Dictionary in crew_ids:
		var rels: Array = get_crew_relationships(crew.id)
		for rel: Dictionary in rels:
			# Avoid duplicates — only add if crew_a_id matches
			if rel.crew_a_id == crew.id:
				all_rels.append(rel)
	return all_rels


func update_bonding_breakthrough(crew_a_id: int, crew_b_id: int) -> void:
	## Marks a bonding breakthrough as complete between two crew members.
	var a: int = mini(crew_a_id, crew_b_id)
	var b: int = maxi(crew_a_id, crew_b_id)
	db.query_with_bindings(
		"UPDATE crew_relationships SET bonding_breakthrough = 1, updated_at = CURRENT_TIMESTAMP WHERE crew_a_id = ? AND crew_b_id = ?",
		[a, b]
	)


func delete_crew_relationships(crew_id: int) -> void:
	## Removes all relationship rows involving this crew member.
	db.query_with_bindings("DELETE FROM crew_relationships WHERE crew_a_id = ? OR crew_b_id = ?", [crew_id, crew_id])


# === CREW MEMORIES (Phase 4) ===

func insert_crew_memory(crew_id: int, data: Dictionary) -> void:
	db.query_with_bindings(
		"INSERT INTO crew_memories (crew_id, trigger_text, emotional_tag, modifier_type, modifier_value, context_match, day_acquired, significance, is_ship_culture, culture_scaled) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
		[crew_id, data.get("trigger_text", ""), data.get("emotional_tag", ""),
		 data.get("modifier_type", ""), data.get("modifier_value", 0.0),
		 data.get("context_match", ""), data.get("day_acquired", 1),
		 data.get("significance", 1.0), data.get("is_ship_culture", 0),
		 data.get("culture_scaled", 0)]
	)


func get_crew_memories(crew_id: int) -> Array:
	return db.select_rows("crew_memories", "crew_id = %d" % crew_id, ["*"])


func get_crew_memory_count(crew_id: int) -> int:
	var rows: Array = db.select_rows("crew_memories", "crew_id = %d" % crew_id, ["id"])
	return rows.size()


func delete_crew_memory(memory_id: int) -> void:
	db.query_with_bindings("DELETE FROM crew_memories WHERE id = ?", [memory_id])


func delete_all_crew_memories(crew_id: int) -> void:
	db.query_with_bindings("DELETE FROM crew_memories WHERE crew_id = ?", [crew_id])


# === SHIP MEMORIES (Phase 4) ===

func insert_ship_memory(save_id: int, data: Dictionary) -> void:
	db.query_with_bindings(
		"INSERT INTO ship_memories (save_id, event_description, modifier_type, modifier_value, context_match, day_acquired) VALUES (?, ?, ?, ?, ?, ?)",
		[save_id, data.get("event_description", ""), data.get("modifier_type", ""),
		 data.get("modifier_value", 0.0), data.get("context_match", ""),
		 data.get("day_acquired", 1)]
	)


func get_ship_memories(save_id: int) -> Array:
	return db.select_rows("ship_memories", "save_id = %d" % save_id, ["*"])


func get_ship_memory_count(save_id: int) -> int:
	var rows: Array = db.select_rows("ship_memories", "save_id = %d" % save_id, ["id"])
	return rows.size()


# === CREW ROMANCES (Phase 5.1) ===

func insert_crew_romance(save_id: int, crew_a_id: int, crew_b_id: int, day: int) -> void:
	var a: int = mini(crew_a_id, crew_b_id)
	var b: int = maxi(crew_a_id, crew_b_id)
	db.query_with_bindings(
		"INSERT INTO crew_romances (save_id, crew_a_id, crew_b_id, status, formed_day) VALUES (?, ?, ?, 'ACTIVE', ?)",
		[save_id, a, b, day]
	)


func get_active_romances(save_id: int) -> Array:
	return db.select_rows("crew_romances", "save_id = %d AND status = 'ACTIVE'" % save_id, ["*"])


func get_romance_for_crew(crew_id: int) -> Dictionary:
	## Returns the active romance involving this crew member, or empty dict.
	var rows: Array = db.select_rows(
		"crew_romances",
		"(crew_a_id = %d OR crew_b_id = %d) AND status = 'ACTIVE'" % [crew_id, crew_id],
		["*"]
	)
	if rows.is_empty():
		return {}
	return rows[0]


func end_romance(romance_id: int, day: int) -> void:
	db.query_with_bindings(
		"UPDATE crew_romances SET status = 'ENDED', ended_day = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
		[day, romance_id]
	)


func is_in_romance(crew_id: int) -> bool:
	var rom: Dictionary = get_romance_for_crew(crew_id)
	return not rom.is_empty()


func get_partner_id(crew_id: int) -> int:
	## Returns the partner's crew_id if in an active romance, or -1.
	var rom: Dictionary = get_romance_for_crew(crew_id)
	if rom.is_empty():
		return -1
	if rom.crew_a_id == crew_id:
		return rom.crew_b_id
	return rom.crew_a_id


# === CREW-GENERATED MISSIONS (Phase 5.4) ===

func insert_crew_generated_mission(save_id: int, data: Dictionary) -> int:
	## Inserts a crew-generated mission. Returns the new id.
	db.query_with_bindings(
		"INSERT INTO crew_generated_missions (save_id, crew_id, template_type, destination_id, setup_text, objective_text, time_limit, ticks_remaining, status, extra_data) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
		[save_id, data.get("crew_id", -1), data.get("template_type", ""),
		 data.get("destination_id", -1), data.get("setup_text", ""),
		 data.get("objective_text", ""), data.get("time_limit", 15),
		 data.get("ticks_remaining", 15), data.get("status", "ACTIVE"),
		 data.get("extra_data", "{}")]
	)
	var result: Array = db.select_rows("crew_generated_missions", "save_id = %d" % save_id, ["id"])
	if result.is_empty():
		return -1
	return result.back().id


func get_active_crew_generated_mission(save_id: int) -> Dictionary:
	## Returns the currently active crew-generated mission, or empty dict.
	var result: Array = db.select_rows(
		"crew_generated_missions",
		"save_id = %d AND status = 'ACTIVE'" % save_id,
		["*"]
	)
	if result.is_empty():
		return {}
	return result[0]


func get_crew_generated_mission_count(save_id: int) -> int:
	var rows: Array = db.select_rows("crew_generated_missions", "save_id = %d AND status = 'ACTIVE'" % save_id, ["id"])
	return rows.size()


func update_crew_generated_mission(mission_id: int, data: Dictionary) -> void:
	var sets: PackedStringArray = []
	var values: Array = []
	for key: String in data:
		sets.append("%s = ?" % key)
		values.append(data[key])
	values.append(mission_id)
	db.query_with_bindings(
		"UPDATE crew_generated_missions SET %s WHERE id = ?" % ", ".join(sets),
		values
	)


# === CREW LEGACY (Phase 5.5) ===

func insert_crew_legacy(save_id: int, data: Dictionary) -> void:
	db.query_with_bindings(
		"INSERT INTO crew_legacy (save_id, crew_name, crew_role, departure_type, legacy_text, effect_type, effect_value, effect_context, effect_ticks_remaining, day_departed) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
		[save_id, data.get("crew_name", ""), data.get("crew_role", ""),
		 data.get("departure_type", ""), data.get("legacy_text", ""),
		 data.get("effect_type", ""), data.get("effect_value", 0.0),
		 data.get("effect_context", ""), data.get("effect_ticks_remaining", -1),
		 data.get("day_departed", 0)]
	)


func get_crew_legacies(save_id: int) -> Array:
	return db.select_rows("crew_legacy", "save_id = %d" % save_id, ["*"])


func get_active_legacy_effects(save_id: int) -> Array:
	## Returns all legacies with active effects (permanent or ticks remaining > 0).
	return db.select_rows(
		"crew_legacy",
		"save_id = %d AND (effect_ticks_remaining = -1 OR effect_ticks_remaining > 0)" % save_id,
		["*"]
	)


func tick_legacy_effects(save_id: int) -> void:
	## Decrements ticks_remaining on temporary legacy effects.
	db.query_with_bindings(
		"UPDATE crew_legacy SET effect_ticks_remaining = effect_ticks_remaining - 1 WHERE save_id = ? AND effect_ticks_remaining > 0",
		[save_id]
	)


func delete_crew_legacies(save_id: int) -> void:
	db.query_with_bindings("DELETE FROM crew_legacy WHERE save_id = ?", [save_id])


func delete_crew_generated_missions(save_id: int) -> void:
	db.query_with_bindings("DELETE FROM crew_generated_missions WHERE save_id = ?", [save_id])
