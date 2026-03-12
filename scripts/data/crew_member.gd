class_name CrewMember
## CrewMember — In-memory data class for a single crew member.
## Holds all properties and provides stat calculation methods.

# === ENUMS ===

enum Species { HUMAN, GORVIAN, VELLANI, KRELLVANI }
enum Role { GUNNER, ENGINEER, NAVIGATOR, MEDIC, COMMS_OFFICER, SCIENCE_OFFICER, SECURITY_CHIEF, GENERALIST }
enum EmotionalTag { HARDENED, SHAKEN, PROUD, BITTER, GRATEFUL, CAUTIOUS, RECKLESS, INSPIRED }
enum MemoryModifierType { COMBAT_PERFORMANCE, NAVIGATION_PERFORMANCE, FACTION_REACTION, MORALE_IN_CONTEXT, SCAN_PERFORMANCE, SOCIAL_PERFORMANCE }
enum ValuePreference { CAUTIOUS, BOLD, COMPASSIONATE, PRAGMATIC, EXPLORATORY }
enum InjuryLocation { HEAD, TORSO, ARMS, LEGS }
enum InjurySeverity { MINOR, MODERATE, SEVERE }

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

# Phase 4: Skill progression
var role_experience: float = 0.0
var pinch_hit_experience: Dictionary = {}  # {role_string: float}

# Phase 4: Traits and tracking counters
var traits: Array = []  # Array of trait ID strings
var combat_encounter_count: int = 0
var total_jumps: int = 0
var low_food_ticks: int = 0
var conflicts_mediated: int = 0
var total_injuries_sustained: int = 0
var docked_ticks: int = 0

# Phase 4: In-memory cache (loaded separately)
var memories: Array = []  # Loaded from crew_memories table when needed

# Phase 5.2: Loyalty system
var value_preference: String = ""  # CAUTIOUS, BOLD, COMPASSIONATE, PRAGMATIC, EXPLORATORY
var value_evidence_count: int = 0  # Number of observed decision reactions
var loyalty_departure_stage: int = 0  # 0=none, 1=withdrawal, 2=vocal, 3=ultimatum

# Phase 5.3: Disease and impairment
var diseases: Array = []  # [{name, stat_affected, reduction, ticks_remaining, contagious, species_specific}]
var permanent_impairments: Array = []  # [{stat, amount, source}]
var is_quarantined: bool = false
var quarantine_ticks: int = 0

# Phase 5.4: Origin tracking
var origin: String = "recruited"  # recruited, rescue, stowaway

# Phase 5.5: Death, grief, legacy
var death_day: int = 0
var grief_state: String = ""  # "", GRIEVING, RESOLVED, BROKEN
var grief_ticks_remaining: int = 0
var stat_bonus_all: int = 0  # Permanent all-stat modifier (positive or negative)

# Phase 6: Hospital checkup
var checkup_bonus_ticks: int = 0  # Ticks remaining of +5 fatigue recovery bonus


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


# === TRAIT DEFINITIONS (Phase 4.3) ===

const TRAIT_DEFINITIONS: Dictionary = {
	"battle_tested": {
		"name": "Battle-Tested",
		"description": "Veteran of many fights.",
		"positive": {"stats": {"reflexes": 5, "stamina": 5}, "context": "combat"},
		"negative": {"stats": {"social": -3}},
		"acquisition_text": "{name} carries themselves differently now. Ten fights and counting. They've earned something that can't be taught.",
	},
	"spacers_instinct": {
		"name": "Spacer's Instinct",
		"description": "Born to the void.",
		"positive": {"stats": {"cognition": 5}, "context": "navigation"},
		"negative": {"docked_restless": -2},
		"acquisition_text": "{name} knows the feel of jump transit in their bones now. They get twitchy if the ship sits still too long.",
	},
	"trusted_by_faction": {
		"name": "Trusted by Faction",
		"description": "Known face in faction space.",
		"positive": {"faction_bonus": 1.5},
		"negative": {"rival_suspicion": true},
		"acquisition_text": "{name} has become something of a known face in faction space. Doors open for them — but rival factions have noticed.",
	},
	"iron_stomach": {
		"name": "Iron Stomach",
		"description": "Can function on nothing.",
		"positive": {"food_penalty_reduction": 0.5},
		"negative": {"stats": {"social": -2}},
		"acquisition_text": "{name} has learned to function on nothing. Rations don't faze them anymore.",
	},
	"peacemaker": {
		"name": "Peacemaker",
		"description": "The crew's emotional anchor.",
		"positive": {"relationship_drift_bonus": 2},
		"negative": {"conflict_morale_penalty": -2},
		"acquisition_text": "{name} has become the person everyone talks to. They carry the weight of the crew's feelings — and it shows.",
	},
	"scarred": {
		"name": "Scarred",
		"description": "Marked by a serious injury.",
		"positive": {"stats": {"cognition": 5}},
		"negative": {"stat_penalty_key": "scarred_stat"},
		"acquisition_text": "{name} is healed, mostly. The injury left its mark — but so did the weeks of recovery. They see things differently now.",
	},
	"grudge_bearer": {
		"name": "Grudge-Bearer",
		"description": "Carries an old hatred.",
		"positive": {"combat_vs_grudge": 8},
		"negative": {"social_vs_grudge": -10},
		"acquisition_text": "{name} hasn't forgiven them. Maybe they never will. But cross them in a fight and that grudge burns like fuel.",
	},
	"haunted": {
		"name": "Haunted",
		"description": "Driven by ghosts.",
		"positive": {"purpose_always_satisfied": true},
		"negative": {"periodic_morale_dip": -3, "dip_interval": 15},
		"acquisition_text": "{name} doesn't sleep well. But they're the first one at their station every morning. Whatever they're running from, it keeps them moving.",
	},
	"reckless": {
		"name": "Reckless",
		"description": "Doesn't flinch anymore.",
		"positive": {"combat_aggressive_bonus": 8},
		"negative": {"evasion_penalty": -5},
		"acquisition_text": "{name} doesn't flinch anymore. That's not always a good thing — but when the guns are hot, there's nobody you'd rather have on the trigger.",
	},
	"bonded_pair": {
		"name": "Bonded Pair",
		"description": "Deep professional trust.",
		"positive": {"paired_bonus": 5},
		"negative": {"separation_penalty": -10, "separation_duration": 30},
		"acquisition_text": "{a} and {b} don't need words anymore. A glance is enough. They've become something more than crewmates.",
	},
	# Phase 5.4: Crew-generated mission replacement traits
	"settled": {
		"name": "Settled",
		"description": "Found peace with old grudges.",
		"positive": {"stats": {"social": 3}},
		"negative": {},
		"acquisition_text": "{name} came back from the meeting different. Quieter. The anger is still there, but it's not running the show anymore.",
	},
	"at_peace": {
		"name": "At Peace",
		"description": "Processed old trauma.",
		"positive": {"stats": {"cognition": 3}, "purpose_always_satisfied": true},
		"negative": {},
		"acquisition_text": "{name} stood at the viewport and exhaled — a breath they'd been holding for weeks. 'Okay,' they said. 'Okay.'",
	},
	"proven": {
		"name": "Proven",
		"description": "Earned their place on the crew.",
		"positive": {"stats": {"stamina": 3, "cognition": 3, "reflexes": 3, "social": 3, "resourcefulness": 3}},
		"negative": {},
		"acquisition_text": "{name} walks off the bridge and the crew parts for them — not in fear, but respect. The desperate stowaway is gone.",
	},
	# Phase 5.5: Grief resolution traits
	"resolved": {
		"name": "Resolved",
		"description": "Emerged stronger through grief.",
		"positive": {"stats": {"stamina": 5, "cognition": 5, "reflexes": 5, "social": 5, "resourcefulness": 5}},
		"negative": {},
		"acquisition_text": "{name} is different now. The grief isn't gone — it never will be. But there's steel underneath it.",
	},
	"broken_spirit": {
		"name": "Broken",
		"description": "Shattered by loss.",
		"positive": {},
		"negative": {"stats": {"stamina": -5, "cognition": -5, "reflexes": -5, "social": -5, "resourcefulness": -5}},
		"acquisition_text": "{name} packs their bag slowly. They don't say goodbye to anyone.",
	},
}

# Phase 5.2: Value preference display
const VALUE_PREFERENCE_DISPLAY: Dictionary = {
	"CAUTIOUS": "Values caution and careful planning",
	"BOLD": "Respects bold, decisive action",
	"COMPASSIONATE": "Driven by compassion and empathy",
	"PRAGMATIC": "Prefers practical, efficient solutions",
	"EXPLORATORY": "Curious and eager to explore the unknown",
}

# Phase 5.2: Loyalty word descriptors
const LOYALTY_WORDS: Array[Array] = [
	[85.0, "Devoted"],
	[65.0, "Loyal"],
	[40.0, "Steady"],
	[25.0, "Wavering"],
	[10.0, "Disaffected"],
	[0.0, "Ready to leave"],
]

# Phase 5.3: Injury location → affected stats
const INJURY_LOCATION_STATS: Dictionary = {
	"HEAD": ["cognition", "social"],
	"TORSO": ["stamina", "resourcefulness"],
	"ARMS": ["reflexes", "cognition"],
	"LEGS": ["stamina", "reflexes"],
}

const INJURY_LOCATIONS: Array[String] = ["HEAD", "TORSO", "ARMS", "LEGS"]

const INJURY_DESCRIPTIONS: Dictionary = {
	"HEAD_MINOR": "Minor head laceration",
	"HEAD_MODERATE": "Moderate concussion",
	"HEAD_SEVERE": "Severe cranial trauma",
	"TORSO_MINOR": "Bruised ribs",
	"TORSO_MODERATE": "Cracked ribs",
	"TORSO_SEVERE": "Severe torso trauma",
	"ARMS_MINOR": "Sprained wrist",
	"ARMS_MODERATE": "Moderate arm fracture",
	"ARMS_SEVERE": "Severe compound fracture",
	"LEGS_MINOR": "Twisted ankle",
	"LEGS_MODERATE": "Knee injury",
	"LEGS_SEVERE": "Severe leg trauma",
}

# Emotional tag names for display
const EMOTIONAL_TAG_NAMES: Dictionary = {
	"HARDENED": "Hardened",
	"SHAKEN": "Shaken",
	"PROUD": "Proud",
	"BITTER": "Bitter",
	"GRATEFUL": "Grateful",
	"CAUTIOUS": "Cautious",
	"RECKLESS": "Reckless",
	"INSPIRED": "Inspired",
}

const EMOTIONAL_TAG_COLORS: Dictionary = {
	"HARDENED": "#E67E22",
	"SHAKEN": "#C0392B",
	"PROUD": "#27AE60",
	"BITTER": "#CD4545",
	"GRATEFUL": "#4CAF50",
	"CAUTIOUS": "#4A90D9",
	"RECKLESS": "#E67E22",
	"INSPIRED": "#E6D159",
}


# === STAT CALCULATION ===

func get_morale_modifier() -> float:
	## Returns 0.5 (crisis) to 1.2 (high morale) based on morale value.
	return 0.5 + (morale / 100.0) * 0.7


func get_fatigue_modifier() -> float:
	## Returns 0.4 (exhausted) to 1.0 (rested) based on fatigue value.
	return 1.0 - (fatigue / 100.0) * 0.6


func get_experience_multiplier() -> float:
	## Returns 0.75 (green) to 1.10 (expert) based on role experience.
	var base_mult: float = 0.75 + 0.25 * (1.0 - exp(-role_experience / 50.0))
	var veteran_bonus: float = 0.0
	if role_experience > 200.0:
		veteran_bonus = clampf((role_experience - 200.0) / 500.0, 0.0, 0.10)
	return base_mult + veteran_bonus


func get_stat_total() -> int:
	## Returns the sum of all 5 base stats.
	return stamina + cognition + reflexes + social + resourcefulness


func get_effective_stat(stat_name: String) -> float:
	## Full stat chain: base * experience * morale * fatigue + trait_bonuses - injuries - impairments - diseases.
	var base: int = get_base_stat(stat_name)
	var effective: float = float(base) * get_experience_multiplier() * get_morale_modifier() * get_fatigue_modifier()
	# Phase 5.5: Grief performance penalty (-30% all stats while grieving)
	if grief_state == "GRIEVING":
		effective *= 0.70
	# Add trait bonuses
	effective += get_trait_stat_bonus(stat_name)
	# Phase 5.5: Apply permanent all-stat bonus/penalty
	effective += float(stat_bonus_all)
	# Subtract active injury reductions for this stat
	for injury: Dictionary in injuries:
		if injury.get("stat_affected", "") == stat_name:
			effective -= float(injury.get("reduction_amount", 0))
	# Phase 5.3: Subtract permanent impairments
	for imp: Dictionary in permanent_impairments:
		if imp.get("stat", "") == stat_name:
			effective -= float(imp.get("amount", 0))
	# Phase 5.3: Subtract disease reductions
	for disease: Dictionary in diseases:
		if disease.get("stat_affected", "") == stat_name:
			effective -= float(disease.get("reduction", 0))
		elif disease.get("all_stats", false):
			effective -= float(disease.get("reduction", 0))
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


# === SKILL PROGRESSION (Phase 4.1) ===

func get_growth_label() -> String:
	## Returns descriptive label based on experience multiplier.
	var mult: float = get_experience_multiplier()
	if mult >= 1.05:
		return "Expert"
	elif mult >= 1.0:
		return "Veteran"
	elif mult >= 0.95:
		return "Skilled"
	elif mult >= 0.85:
		return "Capable"
	else:
		return "Green"


func get_growth_color() -> String:
	var label: String = get_growth_label()
	match label:
		"Expert": return "#CD4545"
		"Veteran": return "#E6D159"
		"Skilled": return "#27AE60"
		"Capable": return "#4A90D9"
		_: return "#718096"


func add_role_experience(amount: float) -> void:
	if fast_learner:
		amount *= 1.25
	role_experience += amount


func add_pinch_hit_experience(role_name: String, amount: float) -> void:
	var current: float = pinch_hit_experience.get(role_name, 0.0)
	pinch_hit_experience[role_name] = current + amount


func get_pinch_hit_effectiveness(role_name: String) -> float:
	## Returns effectiveness multiplier for pinch-hitting a role.
	## Generalists: base 0.65, ceiling 0.75. Others: base 0.60, ceiling 0.55 (yes, inverted — improves toward higher value).
	var exp_val: float = pinch_hit_experience.get(role_name, 0.0)
	if role == Role.GENERALIST:
		# Generalists start at 0.65 and can reach 0.75
		return 0.65 + 0.10 * (1.0 - exp(-exp_val / 30.0))
	else:
		# Non-generalists start at 0.60 and can reach 0.70
		return 0.60 + 0.10 * (1.0 - exp(-exp_val / 40.0))


# === MEMORY HELPERS (Phase 4.2) ===

func load_memories() -> void:
	## Loads memories from database into in-memory cache.
	if id > 0:
		memories = DatabaseManager.get_crew_memories(id)


func get_memory_bonus(context: String) -> float:
	## Returns sum of memory modifier values matching the given context.
	var total: float = 0.0
	for mem: Dictionary in memories:
		if mem.get("context_match", "") == context:
			if mem.get("modifier_type", "") != "MORALE_IN_CONTEXT":
				total += mem.get("modifier_value", 0.0)
	return total


func get_memory_morale_modifier(context: String) -> float:
	## Returns sum of MORALE_IN_CONTEXT modifiers matching context.
	var total: float = 0.0
	for mem: Dictionary in memories:
		if mem.get("context_match", "") == context and mem.get("modifier_type", "") == "MORALE_IN_CONTEXT":
			total += mem.get("modifier_value", 0.0)
	return total


func count_memories_with_tag(tag: String) -> int:
	var count: int = 0
	for mem: Dictionary in memories:
		if mem.get("emotional_tag", "") == tag:
			count += 1
	return count


# === TRAIT HELPERS (Phase 4.3) ===

func has_trait(trait_id: String) -> bool:
	return trait_id in traits


func get_trait_stat_bonus(stat_name: String) -> float:
	## Returns cumulative stat bonus from all traits for the given stat.
	var total: float = 0.0
	for trait_id: String in traits:
		var tdef: Dictionary = TRAIT_DEFINITIONS.get(trait_id, {})
		var pos: Dictionary = tdef.get("positive", {})
		var neg: Dictionary = tdef.get("negative", {})
		# Positive stat bonuses
		var pos_stats: Dictionary = pos.get("stats", {})
		if pos_stats.has(stat_name):
			total += float(pos_stats[stat_name])
		# Negative stat penalties
		var neg_stats: Dictionary = neg.get("stats", {})
		if neg_stats.has(stat_name):
			total += float(neg_stats[stat_name])
	return total


func get_trait_morale_modifier() -> float:
	## Returns morale modifier from traits that apply every tick.
	var total: float = 0.0
	# Haunted: periodic dip handled externally via tick counter
	# Spacer's Instinct: docked restlessness handled externally
	# Peacemaker: conflict morale penalty handled externally
	return total


func get_trait_display_info() -> Array[Dictionary]:
	## Returns formatted trait data for UI display.
	var info: Array[Dictionary] = []
	for trait_id: String in traits:
		var tdef: Dictionary = TRAIT_DEFINITIONS.get(trait_id, {})
		if tdef.is_empty():
			continue
		var pos_text: String = _format_trait_effects(tdef.get("positive", {}), true)
		var neg_text: String = _format_trait_effects(tdef.get("negative", {}), false)
		info.append({
			"id": trait_id,
			"name": tdef.get("name", trait_id),
			"description": tdef.get("description", ""),
			"positive_text": pos_text,
			"negative_text": neg_text,
		})
	return info


func _format_trait_effects(effects: Dictionary, is_positive: bool) -> String:
	var parts: Array[String] = []
	if effects.has("stats"):
		for stat_name: String in effects.stats:
			var val: int = effects.stats[stat_name]
			parts.append("%+d %s" % [val, stat_name.capitalize()])
	if effects.has("food_penalty_reduction"):
		parts.append("50%% less food morale penalty")
	if effects.has("relationship_drift_bonus"):
		parts.append("+%d relationship drift" % effects.relationship_drift_bonus)
	if effects.has("purpose_always_satisfied"):
		parts.append("+5 purpose")
	if effects.has("combat_aggressive_bonus"):
		parts.append("+%d aggressive combat" % effects.combat_aggressive_bonus)
	if effects.has("paired_bonus"):
		parts.append("+%d when paired" % effects.paired_bonus)
	if effects.has("docked_restless"):
		parts.append("%d morale when docked" % effects.docked_restless)
	if effects.has("evasion_penalty"):
		parts.append("%d evasion" % effects.evasion_penalty)
	if effects.has("periodic_morale_dip"):
		parts.append("%d morale every %d days" % [effects.periodic_morale_dip, effects.get("dip_interval", 15)])
	if effects.has("conflict_morale_penalty"):
		parts.append("%d morale on conflict" % effects.conflict_morale_penalty)
	return ", ".join(parts)


# === ROMANCE HELPERS (Phase 5.1) ===

func get_top_stats(count: int = 3) -> Array[String]:
	## Returns the top N stat names sorted by value descending.
	var stat_pairs: Array[Array] = [
		[stamina, "stamina"], [cognition, "cognition"], [reflexes, "reflexes"],
		[social, "social"], [resourcefulness, "resourcefulness"],
	]
	stat_pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var result: Array[String] = []
	for i: int in range(mini(count, stat_pairs.size())):
		result.append(stat_pairs[i][1])
	return result


func is_romance_compatible(other: CrewMember) -> bool:
	## Returns true if stat profiles allow romantic attraction.
	## Top 2 must not be identical. Must share at least 1 in top 3.
	var my_top2: Array[String] = get_top_stats(2)
	var other_top2: Array[String] = other.get_top_stats(2)
	# Check: top 2 are not identical
	if my_top2[0] == other_top2[0] and my_top2[1] == other_top2[1]:
		return false
	# Check: share at least 1 in top 3
	var my_top3: Array[String] = get_top_stats(3)
	var other_top3: Array[String] = other.get_top_stats(3)
	for stat: String in my_top3:
		if stat in other_top3:
			return true
	return false


# === LOYALTY HELPERS (Phase 5.2) ===

func get_loyalty_word() -> String:
	## Returns a word descriptor for loyalty level.
	for threshold: Array in LOYALTY_WORDS:
		if loyalty >= threshold[0]:
			return threshold[1]
	return "Ready to leave"


func get_loyalty_color() -> String:
	var word: String = get_loyalty_word()
	match word:
		"Devoted": return "#27AE60"
		"Loyal": return "#4CAF50"
		"Steady": return "#4A90D9"
		"Wavering": return "#E67E22"
		"Disaffected": return "#C0392B"
		"Ready to leave": return "#C0392B"
		_: return "#718096"


func get_value_display() -> String:
	## Returns the value preference display text if enough evidence.
	if value_evidence_count < 3:
		return ""
	return VALUE_PREFERENCE_DISPLAY.get(value_preference, "")


static func assign_value_preference(cm: CrewMember) -> String:
	## Assigns a value preference based on stat profile.
	var highest_stat: String = cm.get_top_stats(1)[0]
	if highest_stat in ["stamina", "reflexes"] and cm.social < 45:
		return "BOLD"
	elif highest_stat == "social":
		return "COMPASSIONATE"
	elif highest_stat == "cognition":
		if randf() < 0.5:
			return "CAUTIOUS"
		else:
			return "EXPLORATORY"
	else:
		return "PRAGMATIC"


# === DISEASE HELPERS (Phase 5.3) ===

func has_diseases() -> bool:
	return not diseases.is_empty()


func get_disease_text() -> Array[String]:
	## Returns display strings for each active disease.
	var texts: Array[String] = []
	for disease: Dictionary in diseases:
		var name_str: String = disease.get("name", "Unknown")
		var stat: String = disease.get("stat_affected", "").capitalize()
		var reduction: int = disease.get("reduction", 0)
		var ticks: int = disease.get("ticks_remaining", 0)
		var contagious_tag: String = " Contagious." if disease.get("contagious", false) else ""
		if disease.get("all_stats", false):
			texts.append("%s — All stats -%d. Recovering (%d days).%s" % [name_str, reduction, ticks, contagious_tag])
		else:
			texts.append("%s — %s -%d. Recovering (%d days).%s" % [name_str, stat, reduction, ticks, contagious_tag])
	return texts


func tick_diseases() -> Array[String]:
	## Decrements disease timers. Returns text for cured diseases.
	var cured: Array[String] = []
	var remaining: Array = []
	for disease: Dictionary in diseases:
		disease.ticks_remaining -= 1
		if disease.ticks_remaining <= 0:
			cured.append("%s has recovered from %s." % [crew_name, disease.get("name", "disease")])
		else:
			remaining.append(disease)
	diseases = remaining
	return cured


func get_injury_text_structured() -> Array[String]:
	## Returns display strings for structured injuries (Phase 5.3).
	var texts: Array[String] = []
	for injury: Dictionary in injuries:
		var location: String = injury.get("location", "").capitalize()
		var severity: String = injury.get("severity", "").capitalize()
		var desc: String = injury.get("description", "Injury")
		var ticks: int = injury.get("ticks_remaining", 0)
		var stats_text: String = ""
		var stats_list: Array = injury.get("stats_affected", [])
		for i: int in range(stats_list.size()):
			var sa: Dictionary = stats_list[i]
			if i > 0:
				stats_text += ", "
			stats_text += "%s -%d" % [sa.get("stat", "").capitalize(), sa.get("reduction", 0)]
		var perm_text: String = " [PERMANENT RISK]" if injury.get("can_become_permanent", false) else ""
		texts.append("%s — %s. Recovering (%d days).%s" % [desc, stats_text, ticks, perm_text])
	return texts


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
	# Phase 4 fields
	cm.role_experience = data.get("role_experience", 0.0)
	cm.combat_encounter_count = data.get("combat_encounter_count", 0)
	cm.total_jumps = data.get("total_jumps", 0)
	cm.low_food_ticks = data.get("low_food_ticks", 0)
	cm.conflicts_mediated = data.get("conflicts_mediated", 0)
	cm.total_injuries_sustained = data.get("total_injuries_sustained", 0)
	cm.docked_ticks = data.get("docked_ticks", 0)
	# Phase 5.2 fields
	cm.value_preference = data.get("value_preference", "")
	cm.value_evidence_count = data.get("value_evidence_count", 0)
	cm.loyalty_departure_stage = data.get("loyalty_departure_stage", 0)
	# Phase 5.3 fields
	cm.is_quarantined = bool(data.get("is_quarantined", 0))
	cm.quarantine_ticks = data.get("quarantine_ticks", 0)
	# Phase 5.4/5.5 fields
	cm.origin = data.get("origin", "recruited")
	cm.death_day = data.get("death_day", 0)
	cm.grief_state = data.get("grief_state", "")
	cm.grief_ticks_remaining = data.get("grief_ticks_remaining", 0)
	cm.stat_bonus_all = data.get("stat_bonus_all", 0)
	cm.checkup_bonus_ticks = data.get("checkup_bonus_ticks", 0)
	# Parse JSON fields
	var injuries_str: String = data.get("injuries", "[]")
	if injuries_str != "" and injuries_str != "[]":
		var parsed: Variant = JSON.parse_string(injuries_str)
		if parsed is Array:
			cm.injuries = parsed
	var phe_str: String = data.get("pinch_hit_experience", "{}")
	if phe_str != "" and phe_str != "{}":
		var parsed: Variant = JSON.parse_string(phe_str)
		if parsed is Dictionary:
			cm.pinch_hit_experience = parsed
	var traits_str: String = data.get("traits", "[]")
	if traits_str != "" and traits_str != "[]":
		var parsed: Variant = JSON.parse_string(traits_str)
		if parsed is Array:
			cm.traits = parsed
	var diseases_str: String = data.get("diseases", "[]")
	if diseases_str != "" and diseases_str != "[]":
		var parsed: Variant = JSON.parse_string(diseases_str)
		if parsed is Array:
			cm.diseases = parsed
	var impairments_str: String = data.get("permanent_impairments", "[]")
	if impairments_str != "" and impairments_str != "[]":
		var parsed: Variant = JSON.parse_string(impairments_str)
		if parsed is Array:
			cm.permanent_impairments = parsed
	# Assign value preference if missing
	if cm.value_preference == "":
		cm.value_preference = assign_value_preference(cm)
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
		"role_experience": role_experience,
		"pinch_hit_experience": JSON.stringify(pinch_hit_experience),
		"traits": JSON.stringify(traits),
		"combat_encounter_count": combat_encounter_count,
		"total_jumps": total_jumps,
		"low_food_ticks": low_food_ticks,
		"conflicts_mediated": conflicts_mediated,
		"total_injuries_sustained": total_injuries_sustained,
		"docked_ticks": docked_ticks,
		"value_preference": value_preference,
		"value_evidence_count": value_evidence_count,
		"loyalty_departure_stage": loyalty_departure_stage,
		"diseases": JSON.stringify(diseases),
		"permanent_impairments": JSON.stringify(permanent_impairments),
		"is_quarantined": 1 if is_quarantined else 0,
		"quarantine_ticks": quarantine_ticks,
		"origin": origin,
		"death_day": death_day,
		"grief_state": grief_state,
		"grief_ticks_remaining": grief_ticks_remaining,
		"stat_bonus_all": stat_bonus_all,
		"checkup_bonus_ticks": checkup_bonus_ticks,
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
