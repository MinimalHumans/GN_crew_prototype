class_name CrewMember
## CrewMember — In-memory data class for a single crew member.
## Holds all properties and provides stat calculation methods.

# === ENUMS ===

enum Species { HUMAN, GORVIAN, VELLANI, KRELLVANI }
enum Role { GUNNER, ENGINEER, NAVIGATOR, MEDIC, COMMS_OFFICER, SCIENCE_OFFICER, SECURITY_CHIEF, GENERALIST }

# === PROPERTIES ===

var id: int = -1
var save_id: int = -1
var crew_name: String = ""
var species: Species = Species.HUMAN
var role: Role = Role.GENERALIST
var stamina: int = 45
var cognition: int = 45
var reflexes: int = 45
var social: int = 45
var resourcefulness: int = 45
var morale: float = 60.0
var fatigue: float = 0.0
var loyalty: float = 50.0
var is_active: bool = true
var hired_day: int = 1
var personality: String = ""
var ticks_since_role_used: int = 0
var comfort_food_ticks: int = 0
var injuries: Array = []  # [{stat_affected, reduction_amount, ticks_remaining, description}]
var fast_learner: bool = false
var morale_bonus: float = 0.0  # Permanent morale bonus (e.g., from bonding breakthrough)


# === SPECIES / ROLE DISPLAY ===

const SPECIES_NAMES: Dictionary = {
	Species.HUMAN: "Human",
	Species.GORVIAN: "Gorvian",
	Species.VELLANI: "Vellani",
	Species.KRELLVANI: "Krellvani",
}

const SPECIES_COLORS: Dictionary = {
	Species.HUMAN: "#6CB4EE",
	Species.GORVIAN: "#D4A843",
	Species.VELLANI: "#4CAF50",
	Species.KRELLVANI: "#CD4545",
}

const ROLE_NAMES: Dictionary = {
	Role.GUNNER: "Gunner",
	Role.ENGINEER: "Engineer",
	Role.NAVIGATOR: "Navigator",
	Role.MEDIC: "Medic",
	Role.COMMS_OFFICER: "Comms Officer",
	Role.SCIENCE_OFFICER: "Science Officer",
	Role.SECURITY_CHIEF: "Security Chief",
	Role.GENERALIST: "Generalist",
}

# Role primary stat mapping
const ROLE_PRIMARY_STAT: Dictionary = {
	Role.GUNNER: "reflexes",
	Role.ENGINEER: "cognition",
	Role.NAVIGATOR: "cognition",
	Role.MEDIC: "social",
	Role.COMMS_OFFICER: "social",
	Role.SCIENCE_OFFICER: "cognition",
	Role.SECURITY_CHIEF: "stamina",
	Role.GENERALIST: "resourcefulness",
}

# Species trait descriptions
const SPECIES_TRAITS: Dictionary = {
	Species.HUMAN: "Adaptable — no environmental bonuses or vulnerabilities.",
	Species.GORVIAN: "Fuel efficiency bonus. Cold sensitive.",
	Species.VELLANI: "0.7x food consumption. Fragile bones (longer injury recovery).",
	Species.KRELLVANI: "1.3x food consumption. 1.5 crew slots on small ships. Claustrophobia on small ships.",
}

# Cultural friction matrix — keyed by sorted species pair string
const CULTURAL_FRICTION: Dictionary = {
	"GORVIAN_KRELLVANI": -20,
	"GORVIAN_VELLANI": -10,
	"GORVIAN_HUMAN": 10,
	"HUMAN_VELLANI": 10,
	"KRELLVANI_VELLANI": 10,
	"HUMAN_KRELLVANI": 5,
}


# === STAT CALCULATION ===

func get_morale_modifier() -> float:
	## Returns 0.5 (crisis) to 1.2 (high morale) based on morale value.
	return 0.5 + (morale / 100.0) * 0.7


func get_fatigue_modifier() -> float:
	## Returns 0.4 (exhausted) to 1.0 (rested) based on fatigue value.
	return 1.0 - (fatigue / 100.0) * 0.6


func get_effective_stat(stat_name: String) -> float:
	## Returns base_stat * morale_modifier * fatigue_modifier - injury reductions.
	var base: int = get_base_stat(stat_name)
	var effective: float = float(base) * get_morale_modifier() * get_fatigue_modifier()
	# Subtract active injury reductions for this stat
	for injury: Dictionary in injuries:
		if injury.get("stat_affected", "") == stat_name:
			effective -= float(injury.get("reduction_amount", 0))
	return maxf(effective, 1.0)


func get_base_stat(stat_name: String) -> int:
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


func get_primary_stat() -> float:
	## Returns the effective value of this crew member's role primary stat.
	var stat_name: String = ROLE_PRIMARY_STAT.get(role, "resourcefulness")
	return get_effective_stat(stat_name)


func get_role_effectiveness() -> float:
	## Returns 0.0–1.0 rating of how well they perform their role.
	## Based on primary stat effective value relative to a max of 100.
	return clampf(get_primary_stat() / 100.0, 0.0, 1.0)


func get_average_stat() -> float:
	## Returns the average of all five base stats.
	return float(stamina + cognition + reflexes + social + resourcefulness) / 5.0


# === DISPLAY HELPERS ===

func get_species_name() -> String:
	return SPECIES_NAMES.get(species, "Unknown")


func get_species_color() -> String:
	return SPECIES_COLORS.get(species, "#F7FAFC")


func get_role_name() -> String:
	return ROLE_NAMES.get(role, "Unknown")


func get_species_trait_text() -> String:
	return SPECIES_TRAITS.get(species, "Unknown species traits.")


func get_status_color() -> String:
	## Returns green/yellow/red based on morale and fatigue.
	if morale > 60.0 and fatigue < 40.0:
		return "#27AE60"  # Green
	elif morale < 30.0 or fatigue > 70.0:
		return "#C0392B"  # Red
	else:
		return "#E67E22"  # Yellow


func get_crew_slot_cost(ship_class: String) -> float:
	## Krellvani take 1.5 slots on Corvette and Frigate.
	if species == Species.KRELLVANI and ship_class in ["corvette", "frigate"]:
		return 1.5
	return 1.0


# === CULTURAL FRICTION ===

static func get_friction_between(species_a: Species, species_b: Species) -> int:
	## Returns the cultural friction value between two species.
	if species_a == species_b:
		return 0
	# Create sorted key
	var name_a: String = SPECIES_NAMES.get(species_a, "").to_upper()
	var name_b: String = SPECIES_NAMES.get(species_b, "").to_upper()
	var key: String
	if name_a < name_b:
		key = "%s_%s" % [name_a, name_b]
	else:
		key = "%s_%s" % [name_b, name_a]
	return CULTURAL_FRICTION.get(key, 0)


# === INJURY HELPERS ===

func has_injuries() -> bool:
	return not injuries.is_empty()


func get_injury_text() -> Array[String]:
	## Returns display strings for each active injury.
	var texts: Array[String] = []
	for injury: Dictionary in injuries:
		var stat: String = injury.get("stat_affected", "").capitalize()
		var amount: int = injury.get("reduction_amount", 0)
		var ticks: int = injury.get("ticks_remaining", 0)
		var desc: String = injury.get("description", "Injury")
		texts.append("%s — %s -%d, recovering (%d days remaining)" % [desc, stat, amount, ticks])
	return texts


func tick_injuries() -> Array[String]:
	## Decrements injury timers. Returns text for recovered injuries.
	var recovered: Array[String] = []
	var remaining: Array = []
	for injury: Dictionary in injuries:
		injury.ticks_remaining -= 1
		if injury.ticks_remaining <= 0:
			recovered.append("%s has recovered from their %s." % [
				crew_name, injury.get("description", "injury").to_lower()])
		else:
			remaining.append(injury)
	injuries = remaining
	return recovered


# === SERIALIZATION ===

static func from_dict(data: Dictionary) -> CrewMember:
	## Creates a CrewMember from a database row dictionary.
	var cm: CrewMember = CrewMember.new()
	cm.id = data.get("id", -1)
	cm.save_id = data.get("save_id", -1)
	cm.crew_name = data.get("name", "")
	cm.species = _parse_species(data.get("species", "HUMAN"))
	cm.role = _parse_role(data.get("role", "GENERALIST"))
	cm.stamina = data.get("stamina", 45)
	cm.cognition = data.get("cognition", 45)
	cm.reflexes = data.get("reflexes", 45)
	cm.social = data.get("social", 45)
	cm.resourcefulness = data.get("resourcefulness", 45)
	cm.morale = data.get("morale", 60.0)
	cm.fatigue = data.get("fatigue", 0.0)
	cm.loyalty = data.get("loyalty", 50.0)
	cm.is_active = bool(data.get("is_active", 1))
	cm.hired_day = data.get("hired_day", 1)
	cm.personality = data.get("personality", "")
	cm.ticks_since_role_used = data.get("ticks_since_role_used", 0)
	cm.comfort_food_ticks = data.get("comfort_food_ticks", 0)
	cm.fast_learner = bool(data.get("fast_learner", 0))
	cm.morale_bonus = data.get("morale_bonus", 0.0)
	# Parse injuries from JSON string
	var injuries_str: String = data.get("injuries", "[]")
	if injuries_str != "" and injuries_str != "[]":
		var parsed: Variant = JSON.parse_string(injuries_str)
		if parsed is Array:
			cm.injuries = parsed
	return cm


func to_dict() -> Dictionary:
	return {
		"name": crew_name,
		"species": get_species_name().to_upper(),
		"role": _role_to_string(role),
		"stamina": stamina,
		"cognition": cognition,
		"reflexes": reflexes,
		"social": social,
		"resourcefulness": resourcefulness,
		"morale": morale,
		"fatigue": fatigue,
		"loyalty": loyalty,
		"is_active": 1 if is_active else 0,
		"hired_day": hired_day,
		"personality": personality,
		"ticks_since_role_used": ticks_since_role_used,
		"comfort_food_ticks": comfort_food_ticks,
		"injuries": JSON.stringify(injuries),
		"fast_learner": 1 if fast_learner else 0,
		"morale_bonus": morale_bonus,
	}


static func _parse_species(s: String) -> Species:
	match s.to_upper():
		"HUMAN": return Species.HUMAN
		"GORVIAN": return Species.GORVIAN
		"VELLANI": return Species.VELLANI
		"KRELLVANI": return Species.KRELLVANI
		_: return Species.HUMAN


static func _parse_role(r: String) -> Role:
	match r.to_upper():
		"GUNNER": return Role.GUNNER
		"ENGINEER": return Role.ENGINEER
		"NAVIGATOR": return Role.NAVIGATOR
		"MEDIC": return Role.MEDIC
		"COMMS_OFFICER": return Role.COMMS_OFFICER
		"SCIENCE_OFFICER": return Role.SCIENCE_OFFICER
		"SECURITY_CHIEF": return Role.SECURITY_CHIEF
		"GENERALIST": return Role.GENERALIST
		_: return Role.GENERALIST


static func _role_to_string(r: Role) -> String:
	match r:
		Role.GUNNER: return "GUNNER"
		Role.ENGINEER: return "ENGINEER"
		Role.NAVIGATOR: return "NAVIGATOR"
		Role.MEDIC: return "MEDIC"
		Role.COMMS_OFFICER: return "COMMS_OFFICER"
		Role.SCIENCE_OFFICER: return "SCIENCE_OFFICER"
		Role.SECURITY_CHIEF: return "SECURITY_CHIEF"
		Role.GENERALIST: return "GENERALIST"
		_: return "GENERALIST"
