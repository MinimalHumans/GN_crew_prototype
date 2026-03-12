class_name CrewEventTemplates
## CrewEventTemplates — Text pools for crew simulation events.
## Background flavor, nudge warnings, and decision event text.


# === SLICE-OF-LIFE EVENTS ===
# Random positive crew moments unrelated to any specific state.

const SLICE_OF_LIFE: Array[String] = [
	"{a} taught {b} a card game from their homeworld.",
	"You overhear {a} humming a folk song in the corridor.",
	"{a} made a pot of something that smells surprisingly good. The crew gathers.",
	"{a} and {b} are comparing scars in the mess hall. Laughter echoes down the corridor.",
	"Someone left a sketch of the ship on the common room wall. It's not bad.",
	"{a} is telling stories from their last posting. {b} seems genuinely interested.",
	"The crew is unusually quiet tonight. A comfortable silence.",
	"{a} fixed a rattling panel that's been bothering everyone for days.",
	"You find {a} stargazing through the viewport during the quiet hours.",
	"{a} and {b} are debating which station has the best street food.",
	"Someone started a running tally of jumps on the corridor wall. Everyone's adding to it.",
	"{a} is doing maintenance on their personal kit. Methodical, practiced movements.",
	"You catch {a} reading an old letter. They tuck it away when they notice you.",
	"{b} found a way to coax better coffee out of the galley machine. The crew is grateful.",
	"{a} is exercising in the cargo bay during the quiet shift.",
	"The crew shares a meal together. For a moment, things feel almost normal.",
	"{a} and {b} discovered a shared taste in music. The ship has a soundtrack now.",
	"You hear laughter from the crew quarters. A rare sound out here.",
	"{a} organized the tool locker. It's never looked this good.",
	"Someone hung a small flag from their homeworld near their bunk. Nobody minds.",
	"{a} offered to take an extra watch so {b} could rest. Small kindnesses.",
	"The view from the bridge during this jump was particularly beautiful. Even {a} paused to look.",
	"{b} has been whistling the same tune for three jumps. It's oddly comforting.",
	"{a} is cataloging star formations in a personal journal. Old habit, they say.",
	"{a} shared some dried fruit from their home planet. It tastes strange but the gesture matters.",
]

# === SOCIAL INTERACTION TEXT ===

const POSITIVE_SOCIAL: Array[String] = [
	"{a} and {b} spent the evening playing cards.",
	"{a} and {b} shared a meal during the quiet shift.",
	"{a} and {b} were talking shop — seems they have more in common than they thought.",
	"{a} helped {b} with a repair. Good teamwork.",
	"{a} and {b} shared a laugh over something on the comms channel.",
]

const NEGATIVE_SOCIAL: Array[String] = [
	"{a} and {b} got into a disagreement about engine maintenance.",
	"{a} and {b} had words over shift schedules.",
	"There was a tense moment between {a} and {b} in the corridor.",
	"{a} made a comment that didn't sit well with {b}. Awkward silence.",
	"{a} and {b} are giving each other the cold shoulder.",
]

# === MORALE STATE TEXT ===

const MORALE_HIGH: Array[String] = [
	"{name} is in good spirits lately.",
	"{name} has been whistling between shifts. Morale seems high.",
	"{name} seems energized and confident. Good to see.",
]

const MORALE_LOW: Array[String] = [
	"{name} has been keeping to themselves. Something's bothering them.",
	"{name} is quieter than usual. The strain is showing.",
	"{name} barely touched their food today.",
]

# === FATIGUE STATE TEXT ===

const FATIGUE_HIGH: Array[String] = [
	"{name} looks exhausted. Dark circles under their eyes.",
	"{name} nearly fell asleep at their station.",
	"{name} is running on fumes. They need rest.",
]

const FATIGUE_RECOVERED: Array[String] = [
	"{name} looks well-rested and sharp after the shore leave.",
	"{name} is back to full form after some proper rest.",
]

# === FOOD EVENT TEXT ===

const FOOD_LOW: Array[String] = [
	"Rations are getting thin. The crew eyes the food storage nervously.",
	"The crew is stretching meals. Nobody says anything, but everyone notices.",
]

const FOOD_COMFORT: Dictionary = {
	"Human": ["{name} smiles at the familiar taste of Commonwealth rations."],
	"Gorvian": ["{name} grins at the sight of proper Gorvian street food."],
	"Vellani": ["{name}'s eyes light up. Real Vellani spiced provisions."],
	"Krellvani": ["{name} tears into the Outer Reach rations with obvious satisfaction."],
}

# === PURPOSE EVENT TEXT ===

const PURPOSE_BORED: Array[String] = [
	"{name} has been recalibrating the same scanner for a week. They look bored.",
	"{name}'s skills are going unused. You can see the restlessness building.",
	"{name} is sharpening tools that don't need sharpening. They need real work.",
]

# === NUDGE EVENT TEXT ===

const NUDGE_MORALE: Array[String] = [
	"The mood on the ship is grim. The crew could use some good news — or at least a break.",
	"Ship-wide morale is low. Tension hangs in the air like engine exhaust.",
]

const NUDGE_RELATIONSHIP: Array[String] = [
	"The tension between {a} and {b} is becoming hard to ignore. The rest of the crew is walking on eggshells.",
]

const NUDGE_FOOD: Array[String] = [
	"Food supplies are running low. You should resupply soon.",
	"The galley is nearly bare. The crew is counting meals.",
]

const NUDGE_FATIGUE: Array[String] = [
	"The crew is running ragged. They need downtime.",
	"Exhaustion is spreading through the crew. Performance will suffer.",
]

const NUDGE_PAY: Array[String] = [
	"The crew has been grumbling about the pay split. It might be worth reconsidering.",
]

# === TRAVEL CREW FLAVOR TEXT ===

const TRAVEL_CREW_GOOD: Array[String] = [
	"The crew is resting between shifts.",
	"Quiet conversation drifts from the crew quarters.",
	"The crew seems settled. Routine has a comfort of its own.",
]

const TRAVEL_CREW_BAD: Array[String] = [
	"Tension on the bridge. The crew is quiet.",
	"You can feel the strain. Nobody's smiling.",
	"The silence on the ship feels heavy.",
]


# === SPECIES-SPECIFIC RELATIONSHIP TEXT (Phase 3.3) ===

const SPECIES_FRICTION_TEXT: Dictionary = {
	"GORVIAN_KRELLVANI": [
		"{a} and {b} argue over trade routes. Old rivalries die hard between Gorvian and Krellvani.",
		"{a} mutters something about Krellvani stubbornness. {b} pretends not to hear.",
		"A cold exchange between {a} and {b}. The Gorvian-Krellvani divide runs deep.",
	],
	"GORVIAN_VELLANI": [
		"{a} and {b} disagree about how to organize the supply locker. Hierarchy versus communalism.",
		"{a} finds {b}'s approach inefficient. The feeling seems mutual.",
	],
}

const SPECIES_BONDING_TEXT: Dictionary = {
	"GORVIAN_KRELLVANI": [
		"{a} and {b} found common ground over engine diagnostics. Surprising, given their species' history.",
		"Against all odds, {a} and {b} are actually getting along. Something shifted between them.",
	],
	"KRELLVANI_VELLANI": [
		"{a} and {b} share stories of their respective frontiers. Independence resonates with both.",
		"{a} and {b} discovered a mutual love of open spaces. Their bond is growing.",
	],
	"GORVIAN_HUMAN": [
		"{a} and {b} share a professional respect. Gorvians appreciate Commonwealth structure.",
		"{a} is impressed by {b}'s work ethic. The institutional respect runs both ways.",
	],
	"HUMAN_VELLANI": [
		"{a} and {b} swap exploration stories over evening tea. An easy friendship.",
		"{a} and {b} bond over a shared curiosity about what's beyond the next jump.",
	],
}

# === COMFORT FOOD TEXT (Phase 3.4) ===

const COMFORT_FOOD_TEXT: Dictionary = {
	"Human": [
		"{name} smiles at the familiar taste of Commonwealth rations. Feels like home.",
		"{name} savors the proper Human food. Nothing beats comfort cooking.",
	],
	"Gorvian": [
		"{name} grins at the sight of proper Gorvian provisions. Spiced and precise.",
		"{name}'s mood brightens with authentic Hexarchy cuisine.",
	],
	"Vellani": [
		"{name}'s eyes light up. Real Vellani spiced provisions at last.",
		"{name} hums contentedly over a bowl of proper FPU food.",
	],
	"Krellvani": [
		"{name} tears into the Outer Reach rations with obvious satisfaction.",
		"{name} grins. Nothing like proper Krellvani grub to lift the spirits.",
	],
}


# === DECISION EVENT DEFINITIONS ===

static func get_decision_events() -> Dictionary:
	## Returns definitions for all decision events.
	## Each has: id, title, conditions check (done externally), description, options.
	return {
		"crew_conflict": {
			"id": "crew_conflict",
			"title": "Crew Conflict",
			"min_ticks_between": 15,
		},
		"medical_request": {
			"id": "medical_request",
			"title": "Medical Request",
			"min_ticks_between": 15,
		},
		"pay_dispute": {
			"id": "pay_dispute",
			"title": "Pay Dispute",
			"min_ticks_between": 15,
		},
		"homesick": {
			"id": "homesick",
			"title": "Homesick Crew Member",
			"min_ticks_between": 15,
		},
		"shared_discovery": {
			"id": "shared_discovery",
			"title": "Shared Discovery",
			"min_ticks_between": 15,
		},
		"stowaway": {
			"id": "stowaway",
			"title": "Stowaway Found",
			"min_ticks_between": 999,  # Once per playthrough
		},
	}


# === HELPER FUNCTIONS ===

static func _pick(pool: Array) -> String:
	return pool[randi() % pool.size()]


static func get_slice_of_life(name_a: String, name_b: String) -> String:
	var text: String = _pick(SLICE_OF_LIFE)
	return text.replace("{a}", name_a).replace("{b}", name_b)


static func get_positive_social_text(name_a: String, name_b: String) -> String:
	var text: String = _pick(POSITIVE_SOCIAL)
	return text.replace("{a}", name_a).replace("{b}", name_b)


static func get_negative_social_text(name_a: String, name_b: String) -> String:
	var text: String = _pick(NEGATIVE_SOCIAL)
	return text.replace("{a}", name_a).replace("{b}", name_b)


static func get_morale_high_text(crew_name: String) -> String:
	return _pick(MORALE_HIGH).replace("{name}", crew_name)


static func get_morale_low_text(crew_name: String) -> String:
	return _pick(MORALE_LOW).replace("{name}", crew_name)


static func get_fatigue_high_text(crew_name: String) -> String:
	return _pick(FATIGUE_HIGH).replace("{name}", crew_name)


static func get_purpose_bored_text(crew_name: String) -> String:
	return _pick(PURPOSE_BORED).replace("{name}", crew_name)


static func get_travel_crew_text(ship_morale: float) -> String:
	if ship_morale > 50.0:
		return _pick(TRAVEL_CREW_GOOD)
	return _pick(TRAVEL_CREW_BAD)


static func get_nudge_text(nudge_type: String, name_a: String = "", name_b: String = "") -> String:
	var pool: Array
	match nudge_type:
		"morale":
			pool = NUDGE_MORALE
		"relationship":
			pool = NUDGE_RELATIONSHIP
		"food":
			pool = NUDGE_FOOD
		"fatigue":
			pool = NUDGE_FATIGUE
		"pay":
			pool = NUDGE_PAY
		_:
			return ""
	var text: String = _pick(pool)
	return text.replace("{a}", name_a).replace("{b}", name_b)


static func get_species_friction_text(name_a: String, name_b: String, pair_key: String) -> String:
	## Returns species-specific friction event text.
	if SPECIES_FRICTION_TEXT.has(pair_key):
		var text: String = _pick(SPECIES_FRICTION_TEXT[pair_key])
		return text.replace("{a}", name_a).replace("{b}", name_b)
	return "%s and %s had a tense moment." % [name_a, name_b]


static func get_species_bonding_text(name_a: String, name_b: String, pair_key: String) -> String:
	## Returns species-specific bonding event text.
	if SPECIES_BONDING_TEXT.has(pair_key):
		var text: String = _pick(SPECIES_BONDING_TEXT[pair_key])
		return text.replace("{a}", name_a).replace("{b}", name_b)
	return "%s and %s are getting along surprisingly well." % [name_a, name_b]


static func get_comfort_food_text(crew_name: String, species_name: String) -> String:
	## Returns species-specific comfort food text.
	if COMFORT_FOOD_TEXT.has(species_name):
		return _pick(COMFORT_FOOD_TEXT[species_name]).replace("{name}", crew_name)
	return "%s enjoys the familiar food." % crew_name


# === MEMORY-REFERENCED DIALOGUE (Phase 4.2) ===

const MEMORY_DIALOGUE: Dictionary = {
	"HARDENED": [
		"{name} glances at the old scar. Their jaw tightens, but their hands are steady.",
		"{name}'s eyes go distant for a moment. They've been here before. They know the cost.",
		"{name} doesn't flinch. Not anymore. The memory has become armor.",
	],
	"SHAKEN": [
		"{name} freezes for a heartbeat. The memory surfaces uninvited. They push through.",
		"{name}'s hands tremble slightly. The last time something like this happened...",
		"{name} takes a sharp breath. Old fears don't die — they just learn to be quiet.",
	],
	"PROUD": [
		"{name} stands a little taller. They've proven themselves before, and they'll do it again.",
		"A flicker of confidence crosses {name}'s face. They remember what they're capable of.",
	],
	"BITTER": [
		"{name}'s expression hardens. Some wounds don't heal with time.",
		"{name} mutters something under their breath. The resentment runs deep.",
	],
	"GRATEFUL": [
		"{name} looks around with quiet appreciation. They remember what it means to belong.",
		"Something softens in {name}'s expression. They haven't forgotten the kindness.",
	],
	"CAUTIOUS": [
		"{name} checks the instruments twice. After what happened, they take nothing for granted.",
		"{name} scans the horizon carefully. Caution born from experience.",
	],
	"RECKLESS": [
		"{name} grins at the danger. After everything, fear feels like a suggestion.",
		"{name} pushes forward without hesitation. Caution was never their strong suit.",
	],
	"INSPIRED": [
		"{name}'s eyes light up. They've seen what's possible, and it drives them forward.",
		"There's a spark in {name}. The memory of triumph is fuel for the next challenge.",
	],
}


static func get_memory_dialogue(crew_name: String, emotional_tag: String) -> String:
	## Returns a memory-referenced dialogue line.
	if MEMORY_DIALOGUE.has(emotional_tag):
		return _pick(MEMORY_DIALOGUE[emotional_tag]).replace("{name}", crew_name)
	return "%s is lost in thought for a moment." % crew_name


# === ROMANCE TEXT (Phase 5.1) ===

const ROMANCE_FORMATION: Array[String] = [
	"You've noticed {a} and {b} spending their off-hours together. Not just as crewmates. Something's shifted between them.",
	"It's the worst-kept secret on the ship. {a} and {b} are together. The crew pretends not to notice, but there are a lot of knowing smiles on the bridge.",
	"You catch {a} and {b} in the corridor, standing closer than duty requires. They step apart when they see you, but the look between them says everything.",
	"{a} brought {b} something from the last port. Nobody buys gifts for 'just a friend.' The crew exchanges glances.",
	"The way {a} looks at {b} during briefings hasn't gone unnoticed. Something quiet and real has grown between them.",
]

const ROMANCE_POSITIVE: Array[String] = [
	"{a} brought {b} breakfast from the galley. Small gestures, noticed by everyone.",
	"You catch {a} and {b} sharing a quiet moment on the observation deck between jumps.",
	"{a} patched up {b}'s console without being asked. {b} caught their eye and smiled.",
	"The crew has started referring to {a} and {b} as a unit. They don't seem to mind.",
	"You notice {a} saved the last cup of good coffee for {b}. Partnership in small things.",
]

const ROMANCE_STRESSED: Array[String] = [
	"{a} and {b} are barely speaking. The warmth between them has gone cold.",
	"You overhear {a} snap at {b} over something trivial. {b} walks away without responding.",
	"{a} and {b} sit on opposite sides of the mess. The distance between them is louder than any argument.",
]

const ROMANCE_BREAKUP: Array[String] = [
	"It's over between {a} and {b}. The ship feels different. Conversations stop when one of them enters a room. The crew is navigating around them like debris in a shipping lane.",
]

const ROMANCE_INJURY_CONCERN: Array[String] = [
	"{a} hasn't left {b}'s side since the injury. It's affecting their focus.",
	"{a} keeps checking on {b} between duties. The worry is written all over their face.",
]


static func get_romance_formation_text(name_a: String, name_b: String) -> String:
	return _pick(ROMANCE_FORMATION).replace("{a}", name_a).replace("{b}", name_b)


static func get_romance_event_text(name_a: String, name_b: String, morale_avg: float) -> String:
	if morale_avg < 40.0:
		return _pick(ROMANCE_STRESSED).replace("{a}", name_a).replace("{b}", name_b)
	return _pick(ROMANCE_POSITIVE).replace("{a}", name_a).replace("{b}", name_b)


# === LOYALTY TEXT (Phase 5.2) ===

const LOYALTY_VALUE_REACTIONS: Dictionary = {
	"CAUTIOUS_positive": [
		"{name} nods approvingly at the cautious approach. They respect a captain who thinks before acting.",
	],
	"CAUTIOUS_negative": [
		"{name}'s expression tightens. They would have preferred a safer course.",
	],
	"BOLD_positive": [
		"{name} grins as you choose the bold path. They respect a captain with nerve.",
	],
	"BOLD_negative": [
		"{name} seems frustrated at the cautious choice. They wanted action.",
	],
	"COMPASSIONATE_positive": [
		"{name}'s face softens. They're glad you chose the compassionate path.",
	],
	"COMPASSIONATE_negative": [
		"{name}'s expression tightens as you ignore those in need. They don't say anything, but you notice.",
	],
	"PRAGMATIC_positive": [
		"{name} appreciates the practical decision. Efficiency matters to them.",
	],
	"PRAGMATIC_negative": [
		"{name} winces at the unnecessary expense. They value practicality.",
	],
	"EXPLORATORY_positive": [
		"{name}'s eyes light up at the chance to explore. This is why they're out here.",
	],
	"EXPLORATORY_negative": [
		"{name} looks disappointed at the missed opportunity to discover something new.",
	],
}

const LOYALTY_WITHDRAWAL: Array[String] = [
	"{name} ate alone again today. They've been pulling away from the group.",
	"{name} has been spending more time in their quarters. The distance is noticeable.",
]

const LOYALTY_VOCAL: Array[String] = [
	"{name} has been openly critical of your decisions. The rest of the crew has noticed.",
	"{name} challenged your judgment in front of the crew. The tension was palpable.",
]

const LOYALTY_DEPARTURE: Array[String] = [
	"{name} is packed and waiting at the airlock when you dock. 'No hard feelings, Captain. I just can't anymore.' They walk down the ramp without looking back.",
]

const LOYALTY_VOLUNTEER: Array[String] = [
	"{name} steps up to the console. 'I've watched enough to have a go, Captain.'",
]


static func get_loyalty_reaction_text(crew_name: String, value: String, is_positive: bool) -> String:
	var key: String = "%s_%s" % [value, "positive" if is_positive else "negative"]
	if LOYALTY_VALUE_REACTIONS.has(key):
		return _pick(LOYALTY_VALUE_REACTIONS[key]).replace("{name}", crew_name)
	return ""


# === DISEASE TEXT (Phase 5.3) ===

const DISEASE_NAMES: Dictionary = {
	"GORVIAN": "Korrath Fever",
	"VELLANI": "Bone Brittling",
	"KRELLVANI": "Confinement Psychosis",
	"HUMAN": "Common Spacer's Flu",
}

const DISEASE_THERMAL_SHOCK: String = "Thermal Shock Syndrome"

const MEDIC_INTERVENTION: Array[String] = [
	"Medic {medic} stabilizes {patient}'s condition. Without them, it could have been much worse.",
	"Medic {medic} treats {patient} with practiced hands. Recovery will be faster with proper care.",
]

const NO_MEDIC_WARNING: Array[String] = [
	"Without a medic on board, {name}'s injury is healing slowly. A proper medical facility would help.",
]
