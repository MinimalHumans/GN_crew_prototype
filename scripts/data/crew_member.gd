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
	## Returns base_stat * morale_modifier * fatigue_modifier.
	var base: int = get_base_stat(stat_name)
	return float(base) * get_morale_modifier() * get_fatigue_modifier()


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
	## Krellvani take 1.5 slots on Corvette.
	if species == Species.KRELLVANI and ship_class == "corvette":
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
