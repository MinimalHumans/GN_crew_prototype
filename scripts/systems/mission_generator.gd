class_name MissionGenerator
## MissionGenerator — Procedurally generates missions for planet mission boards.
## Assembles missions from type, destination, difficulty, reward, and complications.

# === MISSION TYPES ===

const MISSION_TYPES: Array[String] = [
	"cargo_delivery", "passenger_transport", "trade_run", "survey",
	"retrieval", "escort", "patrol", "distress_signal",
]

# Weights per planet type — higher weight = more likely to appear
const TYPE_WEIGHTS: Dictionary = {
	"hub":          {"cargo_delivery": 15, "passenger_transport": 15, "trade_run": 15, "survey": 10, "retrieval": 10, "escort": 10, "patrol": 10, "distress_signal": 15},
	"trade_hub":    {"cargo_delivery": 25, "passenger_transport": 10, "trade_run": 25, "survey": 5,  "retrieval": 5,  "escort": 10, "patrol": 10, "distress_signal": 10},
	"agricultural": {"cargo_delivery": 25, "passenger_transport": 15, "trade_run": 20, "survey": 10, "retrieval": 10, "escort": 5,  "patrol": 5,  "distress_signal": 10},
	"capital":      {"cargo_delivery": 15, "passenger_transport": 10, "trade_run": 15, "survey": 10, "retrieval": 10, "escort": 15, "patrol": 15, "distress_signal": 10},
	"mining":       {"cargo_delivery": 20, "passenger_transport": 5,  "trade_run": 15, "survey": 15, "retrieval": 15, "escort": 10, "patrol": 10, "distress_signal": 10},
	"research":     {"cargo_delivery": 10, "passenger_transport": 5,  "trade_run": 5,  "survey": 30, "retrieval": 20, "escort": 5,  "patrol": 5,  "distress_signal": 20},
	"homeworld":    {"cargo_delivery": 15, "passenger_transport": 20, "trade_run": 10, "survey": 10, "retrieval": 10, "escort": 10, "patrol": 10, "distress_signal": 15},
	"cultural":     {"cargo_delivery": 15, "passenger_transport": 25, "trade_run": 20, "survey": 5,  "retrieval": 5,  "escort": 5,  "patrol": 10, "distress_signal": 15},
	"frontier":     {"cargo_delivery": 10, "passenger_transport": 5,  "trade_run": 5,  "survey": 30, "retrieval": 15, "escort": 10, "patrol": 10, "distress_signal": 15},
	"stronghold":   {"cargo_delivery": 10, "passenger_transport": 5,  "trade_run": 10, "survey": 5,  "retrieval": 10, "escort": 20, "patrol": 25, "distress_signal": 15},
	"contested":    {"cargo_delivery": 5,  "passenger_transport": 5,  "trade_run": 5,  "survey": 5,  "retrieval": 10, "escort": 20, "patrol": 30, "distress_signal": 20},
	"black_market": {"cargo_delivery": 15, "passenger_transport": 10, "trade_run": 20, "survey": 10, "retrieval": 15, "escort": 10, "patrol": 10, "distress_signal": 10},
}

# Reward multipliers per difficulty star
const REWARD_MULTIPLIERS: Array[float] = [0.0, 1.0, 1.5, 2.5, 4.0, 6.0]  # Index 0 unused
const BASE_REWARD_MIN: int = 50
const BASE_REWARD_MAX: int = 80

# Possible complications for higher difficulty missions
const COMPLICATIONS: Array[String] = [
	"pirate_ambush", "customs_inspection", "equipment_failure",
	"navigation_hazard", "cargo_damage", "hostile_wildlife",
	"communication_blackout", "fuel_shortage",
]


# === GENERATION ===

static func generate_missions(planet_id: int, player_level: int, count: int = 4) -> Array[Dictionary]:
	## Generates a batch of missions for a planet's mission board.
	var planet: Dictionary = DatabaseManager.get_planet(planet_id)
	if planet.is_empty():
		return []

	var destinations: Array[int] = _get_reachable_planets(planet_id)
	if destinations.is_empty():
		return []

	var missions: Array[Dictionary] = []
	for i: int in range(count):
		var mission: Dictionary = _generate_one(planet, destinations, player_level)
		missions.append(mission)

	return missions


static func generate_and_store(planet_id: int, player_level: int, count: int = 4) -> void:
	## Generates missions and stores them in the database.
	DatabaseManager.clear_missions_available(planet_id)
	var missions: Array[Dictionary] = generate_missions(planet_id, player_level, count)
	for m: Dictionary in missions:
		DatabaseManager.insert_mission_available(m)


static func _generate_one(planet: Dictionary, destinations: Array[int], player_level: int) -> Dictionary:
	var mission_type: String = _pick_type(planet.type)
	var destination_id: int = destinations[randi() % destinations.size()]
	var difficulty: int = _pick_difficulty(player_level)
	var reward: int = _calculate_reward(difficulty)
	var complications: Array = _pick_complications(difficulty)
	var roles: Array = _get_roles_tested(mission_type)

	var dest_planet: Dictionary = DatabaseManager.get_planet(destination_id)
	var dest_name: String = dest_planet.get("name", "Unknown")

	var title: String = _build_title(mission_type, dest_name)
	var description: String = _build_description(mission_type, dest_name, difficulty, complications)

	return {
		"planet_id": planet.id,
		"type": mission_type,
		"destination_id": destination_id,
		"difficulty": difficulty,
		"reward": reward,
		"title": title,
		"description": description,
		"complications": JSON.stringify(complications),
		"roles_tested": JSON.stringify(roles),
	}


# === COMPONENT PICKERS ===

static func _pick_type(planet_type: String) -> String:
	var weights: Dictionary = TYPE_WEIGHTS.get(planet_type, TYPE_WEIGHTS["hub"])
	var total: int = 0
	for w: int in weights.values():
		total += w

	var roll: int = randi() % total
	var cumulative: int = 0
	for mtype: String in weights:
		cumulative += weights[mtype]
		if roll < cumulative:
			return mtype
	return "cargo_delivery"


static func _pick_difficulty(player_level: int) -> int:
	## Weighted by player level. Low levels get mostly 1-2 star, higher levels get 3-5.
	var weights: Array[int]
	if player_level <= 2:
		weights = [40, 35, 20, 5, 0]
	elif player_level <= 4:
		weights = [20, 30, 30, 15, 5]
	elif player_level <= 6:
		weights = [10, 20, 30, 25, 15]
	else:
		weights = [5, 10, 25, 35, 25]

	var total: int = 0
	for w: int in weights:
		total += w

	var roll: int = randi() % total
	var cumulative: int = 0
	for i: int in range(weights.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return i + 1  # 1-5 stars
	return 1


static func _calculate_reward(difficulty: int) -> int:
	var base: int = randi_range(BASE_REWARD_MIN, BASE_REWARD_MAX)
	var multiplier: float = REWARD_MULTIPLIERS[clampi(difficulty, 1, 5)]
	return int(base * multiplier)


static func _pick_complications(difficulty: int) -> Array:
	if difficulty <= 1:
		return []
	var count: int = 0
	if difficulty == 2:
		count = 1 if randf() < 0.3 else 0
	elif difficulty == 3:
		count = 1
	elif difficulty == 4:
		count = randi_range(1, 2)
	else:
		count = 2

	var available: Array = COMPLICATIONS.duplicate()
	available.shuffle()
	return available.slice(0, count)


static func _get_roles_tested(mission_type: String) -> Array:
	return TextTemplates.MISSION_ROLES.get(mission_type, ["Generalist"])


# === TEXT GENERATION ===

static func _build_title(mission_type: String, dest_name: String) -> String:
	var type_display: String = TextTemplates.get_mission_type_display(mission_type)
	return "%s — %s" % [type_display, dest_name]


static func _build_description(mission_type: String, dest_name: String, difficulty: int, complications: Array) -> String:
	var verb: String = TextTemplates.MISSION_TYPE_VERB.get(mission_type, "Complete mission at")

	# Build payload for types that have them
	var payload: String = ""
	if TextTemplates.MISSION_PAYLOADS.has(mission_type):
		var payloads: Array = TextTemplates.MISSION_PAYLOADS[mission_type]
		payload = " " + payloads[randi() % payloads.size()]

	var line1: String = "%s%s %s." % [verb, payload, dest_name]
	var line2: String = TextTemplates.get_difficulty_flavor(difficulty)

	var complication_hint: String = ""
	for c: String in complications:
		if TextTemplates.COMPLICATION_DISPLAY.has(c):
			complication_hint += " " + TextTemplates.COMPLICATION_DISPLAY[c]

	var desc: String = "%s %s" % [line1, line2]
	if not complication_hint.is_empty():
		desc += complication_hint
	return desc


# === DESTINATION HELPERS ===

static func _get_reachable_planets(planet_id: int) -> Array[int]:
	## Returns planet IDs reachable within 2 hops (not including current planet).
	var routes: Array = DatabaseManager.get_routes_from(planet_id)
	var direct: Array[int] = []

	for route: Dictionary in routes:
		var other: int = route.planet_b_id if route.planet_a_id == planet_id else route.planet_a_id
		if other != planet_id and other not in direct:
			direct.append(other)

	# Add 2-hop destinations
	var reachable: Array[int] = direct.duplicate()
	for d_id: int in direct:
		var secondary: Array = DatabaseManager.get_routes_from(d_id)
		for route: Dictionary in secondary:
			var other: int = route.planet_b_id if route.planet_a_id == d_id else route.planet_a_id
			if other != planet_id and other not in reachable:
				reachable.append(other)

	return reachable
