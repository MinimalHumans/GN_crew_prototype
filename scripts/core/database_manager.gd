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
			progress TEXT DEFAULT 'accepted',
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (save_id) REFERENCES save_state(id),
			FOREIGN KEY (destination_id) REFERENCES planets(id)
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
		 ship_data.fuel_max, ship_data.fuel_max, ship_data.cargo_max, ship_data.crew_max, 0.0]
	)


func get_ship_template(ship_class: String) -> Dictionary:
	match ship_class:
		"skiff":
			return {"class": "skiff", "name": "Skiff", "hull_max": 50, "fuel_max": 30, "cargo_max": 10, "crew_max": 0}
		"corvette":
			return {"class": "corvette", "name": "Corvette", "hull_max": 120, "fuel_max": 60, "cargo_max": 25, "crew_max": 3}
		"frigate":
			return {"class": "frigate", "name": "Frigate", "hull_max": 250, "fuel_max": 100, "cargo_max": 50, "crew_max": 12}
		_:
			return {"class": "skiff", "name": "Skiff", "hull_max": 50, "fuel_max": 30, "cargo_max": 10, "crew_max": 0}


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
	for table: String in ["cargo", "missions_active", "visited_planets", "ships", "captain_stats"]:
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
