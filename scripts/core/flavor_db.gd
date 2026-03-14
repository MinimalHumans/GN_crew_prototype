extends Node
## FlavorDB — Read-only autoload for flavor text stored in SQLite.
## Opens res://data/flavor_text.db and provides random text selection
## from named pools. Caches results to avoid repeated DB queries.

var _db: SQLite = null
var _cache: Dictionary = {}  # {pool_key: Array[String]}
var _weight_cache: Dictionary = {}  # {pool_key: Array[Dictionary]} — [{text, weight}]


func _ready() -> void:
	_db = SQLite.new()
	_db.path = "res://data/flavor_text.db"
	_db.read_only = true
	if not _db.open_db():
		push_error("FlavorDB: Failed to open flavor_text.db")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _db != null:
			_db.close_db()


func pick(pool_key: String) -> String:
	## Returns one random text entry from the pool.
	var pool: Array[String] = _get_pool(pool_key)
	if pool.is_empty():
		push_error("FlavorDB: pool '%s' is empty or missing" % pool_key)
		return ""
	return pool[randi() % pool.size()]


func pick_weighted(pool_key: String) -> String:
	## Like pick() but respects the weight column for weighted random selection.
	var entries: Array[Dictionary] = _get_weighted_pool(pool_key)
	if entries.is_empty():
		push_error("FlavorDB: pool '%s' is empty or missing" % pool_key)
		return ""

	var total_weight: float = 0.0
	for entry: Dictionary in entries:
		total_weight += entry.weight

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for entry: Dictionary in entries:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.text

	return entries[-1].text


func get_all(pool_key: String) -> Array[String]:
	## Returns all entries for a pool. Used for name pools where caller
	## wants to pick with deduplication logic.
	return _get_pool(pool_key)


func pick_with_replacements(pool_key: String, replacements: Dictionary) -> String:
	## Calls pick() then applies all key->value replacements in the dictionary.
	var text: String = pick(pool_key)
	for key: String in replacements:
		text = text.replace(key, replacements[key])
	return text


# === PRIVATE ===

func _get_pool(pool_key: String) -> Array[String]:
	if _cache.has(pool_key):
		return _cache[pool_key]

	var result: Array[String] = []
	if _db == null:
		push_error("FlavorDB: database not initialized")
		return result

	_db.query_with_bindings("SELECT text FROM flavor_text WHERE pool_key = ?", [pool_key])
	for row: Dictionary in _db.query_result:
		result.append(row.text)

	_cache[pool_key] = result
	_validate_pool(pool_key)
	return result


func _get_weighted_pool(pool_key: String) -> Array[Dictionary]:
	if _weight_cache.has(pool_key):
		return _weight_cache[pool_key]

	var result: Array[Dictionary] = []
	if _db == null:
		push_error("FlavorDB: database not initialized")
		return result

	_db.query_with_bindings(
		"SELECT text, weight FROM flavor_text WHERE pool_key = ?", [pool_key])
	for row: Dictionary in _db.query_result:
		result.append({"text": row.text, "weight": row.weight})

	_weight_cache[pool_key] = result
	_validate_pool(pool_key)
	return result


func _validate_pool(pool_key: String) -> void:
	var pool: Array[String] = _cache.get(pool_key, [])
	if pool.is_empty():
		push_warning("FlavorDB: pool '%s' is empty or missing — check flavor_text.db" % pool_key)
