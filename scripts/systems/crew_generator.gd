class_name CrewGenerator
## CrewGenerator — Generates crew member candidates for recruitment.
## Species, role, stats, and personality are procedurally generated
## with biases based on planet faction and species aptitudes.

# === SPECIES WEIGHTS BY PLANET ID ===
# {planet_id: {species_key: weight}}

const SPECIES_WEIGHTS: Dictionary = {
	# Haven (1) — balanced
	1: {"HUMAN": 25, "GORVIAN": 25, "VELLANI": 25, "KRELLVANI": 25},
	# Korrath Prime (4) — Gorvian capital
	4: {"HUMAN": 15, "GORVIAN": 60, "VELLANI": 15, "KRELLVANI": 10},
	# Sethi Orbital (6) — Gorvian research
	6: {"HUMAN": 20, "GORVIAN": 50, "VELLANI": 20, "KRELLVANI": 10},
	# Lirien (7) — most diverse
	7: {"HUMAN": 25, "GORVIAN": 25, "VELLANI": 30, "KRELLVANI": 20},
	# Ironmaw (10) — Krellvani stronghold
	10: {"HUMAN": 15, "GORVIAN": 10, "VELLANI": 15, "KRELLVANI": 60},
}

# Default weights for planets without specific data
const DEFAULT_WEIGHTS: Dictionary = {"HUMAN": 25, "GORVIAN": 25, "VELLANI": 25, "KRELLVANI": 25}

# === ROLE WEIGHTS BY SPECIES ===
# Higher weight = more likely. Generalist is uncommon (~10%) for all.

const ROLE_WEIGHTS: Dictionary = {
	"HUMAN": {
		"GUNNER": 12, "ENGINEER": 12, "NAVIGATOR": 12, "MEDIC": 12,
		"COMMS_OFFICER": 12, "SCIENCE_OFFICER": 12, "SECURITY_CHIEF": 12, "GENERALIST": 10,
	},
	"GORVIAN": {
		"GUNNER": 8, "ENGINEER": 18, "NAVIGATOR": 18, "MEDIC": 8,
		"COMMS_OFFICER": 8, "SCIENCE_OFFICER": 18, "SECURITY_CHIEF": 8, "GENERALIST": 10,
	},
	"VELLANI": {
		"GUNNER": 16, "ENGINEER": 8, "NAVIGATOR": 10, "MEDIC": 12,
		"COMMS_OFFICER": 18, "SCIENCE_OFFICER": 10, "SECURITY_CHIEF": 8, "GENERALIST": 10,
	},
	"KRELLVANI": {
		"GUNNER": 18, "ENGINEER": 8, "NAVIGATOR": 8, "MEDIC": 8,
		"COMMS_OFFICER": 8, "SCIENCE_OFFICER": 8, "SECURITY_CHIEF": 20, "GENERALIST": 10,
	},
}

# === STAT MODIFIERS BY SPECIES ===

const SPECIES_STAT_MODS: Dictionary = {
	"HUMAN": {"stamina": 3, "cognition": 3, "reflexes": 3, "social": 3, "resourcefulness": 3},
	"GORVIAN": {"stamina": 8, "cognition": 10, "reflexes": 0, "social": 0, "resourcefulness": 0},
	"VELLANI": {"stamina": 0, "cognition": 0, "reflexes": 8, "social": 10, "resourcefulness": 0},
	"KRELLVANI": {"stamina": 10, "cognition": 0, "reflexes": 8, "social": 0, "resourcefulness": 0},
}


# === GENERATION ===

static func generate_candidates(planet_id: int, count: int, player_level: int = 1) -> Array[CrewMember]:
	## Generates a list of crew member candidates.
	var candidates: Array[CrewMember] = []
	var used_names: Array[String] = []

	for i: int in range(count):
		var cm: CrewMember = _generate_one(planet_id, player_level, used_names)
		used_names.append(cm.crew_name)
		candidates.append(cm)

	return candidates


static func _generate_one(planet_id: int, player_level: int, used_names: Array[String]) -> CrewMember:
	var cm: CrewMember = CrewMember.new()

	# Pick species
	var species_key: String = _pick_species(planet_id)
	cm.species = CrewMember._parse_species(species_key)

	# Pick name (avoid duplicates within this batch)
	cm.crew_name = _pick_unique_name(species_key, used_names)

	# Pick role
	var role_key: String = _pick_role(species_key)
	cm.role = CrewMember._parse_role(role_key)

	# Generate stats
	_generate_stats(cm, species_key, player_level)

	# Generate personality
	cm.personality = TextTemplates.generate_personality()

	# Defaults
	cm.morale = 60.0
	cm.fatigue = 0.0
	cm.loyalty = 50.0
	cm.is_active = true

	return cm


static func _pick_species(planet_id: int) -> String:
	var weights: Dictionary = SPECIES_WEIGHTS.get(planet_id, DEFAULT_WEIGHTS)
	return _weighted_pick(weights)


static func _pick_role(species_key: String) -> String:
	var weights: Dictionary = ROLE_WEIGHTS.get(species_key, ROLE_WEIGHTS["HUMAN"])
	return _weighted_pick(weights)


static func _pick_unique_name(species_key: String, used_names: Array[String]) -> String:
	var pool: Array[String] = FlavorDB.get_all("names_" + species_key.to_lower())
	if pool.is_empty():
		pool = ["Crewmember"]
	for attempt: int in range(20):
		var name: String = pool[randi() % pool.size()]
		if name not in used_names:
			return name
	var base: String = pool[randi() % pool.size()]
	return "%s-%d" % [base, randi_range(1, 99)]


static func _generate_stats(cm: CrewMember, species_key: String, player_level: int) -> void:
	# Base quality influenced by player level (higher level = better candidates)
	var quality_bonus: int = player_level * 2
	var base_min: int = 30 + quality_bonus / 2
	var base_max: int = 75 + quality_bonus

	# Clamp ranges
	base_min = clampi(base_min, 30, 60)
	base_max = clampi(base_max, 55, 95)

	# Roll base stats
	cm.stamina = randi_range(base_min, base_max)
	cm.cognition = randi_range(base_min, base_max)
	cm.reflexes = randi_range(base_min, base_max)
	cm.social = randi_range(base_min, base_max)
	cm.resourcefulness = randi_range(base_min, base_max)

	# Apply species modifiers
	var mods: Dictionary = SPECIES_STAT_MODS.get(species_key, {})
	cm.stamina = clampi(cm.stamina + mods.get("stamina", 0), 0, 100)
	cm.cognition = clampi(cm.cognition + mods.get("cognition", 0), 0, 100)
	cm.reflexes = clampi(cm.reflexes + mods.get("reflexes", 0), 0, 100)
	cm.social = clampi(cm.social + mods.get("social", 0), 0, 100)
	cm.resourcefulness = clampi(cm.resourcefulness + mods.get("resourcefulness", 0), 0, 100)

	# Prosperity reputation bonus: +2 per prosperity departure on record (cap +10)
	var ship_mems: Array = DatabaseManager.get_ship_memories(GameManager.save_id)
	var prosperity_count: int = 0
	for smem: Dictionary in ship_mems:
		if smem.get("modifier_type", "") == "RECRUITMENT_REPUTATION":
			prosperity_count += 1
	if prosperity_count > 0:
		var rep_bonus: int = mini(prosperity_count * 2, 10)
		cm.stamina = clampi(cm.stamina + rep_bonus, 0, 100)
		cm.cognition = clampi(cm.cognition + rep_bonus, 0, 100)
		cm.reflexes = clampi(cm.reflexes + rep_bonus, 0, 100)
		cm.social = clampi(cm.social + rep_bonus, 0, 100)
		cm.resourcefulness = clampi(cm.resourcefulness + rep_bonus, 0, 100)


static func _weighted_pick(weights: Dictionary) -> String:
	## Given {"key": weight, ...}, returns a random key weighted by value.
	var total: int = 0
	for w: int in weights.values():
		total += w
	var roll: int = randi() % total
	var cumulative: int = 0
	for key: String in weights:
		cumulative += weights[key]
		if roll < cumulative:
			return key
	# Fallback
	return weights.keys()[0]
