class_name TextTemplates
## TextTemplates — Static text pools for atmospheric messages.
## Templates use {placeholder} syntax filled by the caller.

# === PLANET ARRIVAL TEXT ===
# Keyed by planet name. Each planet has 2-3 variants picked at random.

const ARRIVAL_TEXT: Dictionary = {
	"Haven": [
		"You dock at Haven. The station hums with commerce and the smell of cheap coffee.",
		"Haven's docking clamps lock on. The familiar bustle of the Commonwealth hub greets you.",
		"Home port. Haven's lights spread out below as your ship settles into bay {bay}.",
	],
	"Meridian": [
		"Meridian's crossroads station buzzes with traffic from three zones. Everyone's going somewhere.",
		"You slot into Meridian's crowded docking ring. Trade vessels from every faction jostle for position.",
		"The Meridian beacon pings your transponder. Commonwealth and Hexarchy flags fly side by side here.",
	],
	"Fallow": [
		"Fallow smells like grain and engine grease. A quiet world with cheap provisions.",
		"You set down at Fallow. Fields stretch to the horizon under pale skies. Simple and cheap.",
		"Fallow's small port has more cargo haulers than passenger ships. Food country.",
	],
	"Korrath Prime": [
		"Korrath Prime's orbital docks are immaculate. Gorvian efficiency at its finest.",
		"The Hexarchy capital gleams with ordered precision. Your hull looks shabby by comparison.",
		"Korrath Prime. The dockmaster inspects your ship with clinical Gorvian thoroughness.",
	],
	"Dvarn": [
		"Dvarn's cold hits you through the hull. Mining rigs dot the frozen landscape below.",
		"You dock at Dvarn. Ice crystals coat the viewports. The ore haulers here are massive.",
		"The cold of Dvarn seeps into everything. Miners in heavy suits trudge past your berth.",
	],
	"Sethi Orbital": [
		"Sethi Orbital rotates slowly against the stars. A research station at the edge of Hexarchy space.",
		"The orbital's sensors sweep your ship before you're cleared to dock. Science types are cautious.",
		"Sethi Orbital hums with instrument readings. Researchers hurry between labs.",
	],
	"Lirien": [
		"Lirien's port is alive with color and conversation. Vellani hospitality at its warmest.",
		"You dock at Lirien. Music drifts from somewhere. The air smells like spiced tea and flowers.",
		"Lirien welcomes you. The Vellani homeworld is the best place to find crew in the sector.",
	],
	"Tessara": [
		"Tessara's docks are decorated with murals and hanging textiles. Culture is the export here.",
		"Art and commerce blend seamlessly at Tessara. Even the dockworkers move with grace.",
		"You set down on Tessara. A Vellani artisan is selling hand-painted hull decals at the next berth.",
	],
	"Windhollow": [
		"Windhollow is barely a settlement. A frontier outpost where the maps start getting vague.",
		"You dock at Windhollow. The wind howls across the landing pad. Not much here but cheap fuel and big sky.",
		"Windhollow. The frontier. Beyond here, the routes get interesting.",
	],
	"Ironmaw": [
		"Ironmaw's docks are built for warships. The Krellvani stronghold radiates menace.",
		"You dock at Ironmaw. Weapons dealers outnumber food vendors three to one.",
		"Ironmaw. Even the station smells like gunmetal. The Krellvani eye your ship appraisingly.",
	],
	"Char": [
		"Char has no real port — just a bombed-out landing field. Contested space at its worst.",
		"You set down on Char and hope your ship is still here when you get back.",
		"Char. The most dangerous rock in the sector. The pay is good if you survive.",
	],
	"Nexus Station": [
		"Nexus Station operates outside every faction's rules. The prices here are anyone's guess.",
		"You dock at Nexus Station. The black market hub of the Outer Reach. Watch your cargo.",
		"Nexus Station. Neutral ground where anything can be bought if you don't ask too many questions.",
	],
}

# === TRAVEL TEXT ===
# Generic lines for jump-by-jump travel. Picked at random.

const TRAVEL_TEXT: Array[String] = [
	"Stars blur and reform. Quiet transit.",
	"The hull groans through the jump. Nothing on scanners.",
	"A smooth jump. Your instruments hold steady.",
	"The void stretches between stars. Silence and distance.",
	"Jump complete. The new starfield is unfamiliar but calm.",
	"Your ship shudders slightly as reality reasserts itself. All clear.",
	"Space is vast and indifferent. The jump passes without incident.",
	"The drive spools down. Another jump behind you.",
	"Starlight shifts as you emerge. The route ahead is clear.",
	"A brief flicker of static on the comms. Probably nothing.",
	"The jump corridor narrows and releases. Smooth transition.",
	"Your instruments ping — just a stray asteroid. Moving on.",
	"The silence between jumps has its own weight. You press on.",
	"Navigation holds. The stars rearrange themselves around you.",
	"Jump complete. The ship settles into the new void with a low hum.",
	"A distant nebula catches your eye between jumps. Beautiful and empty.",
	"The drive harmonics sound good today. Clean transit.",
]

# === FACTION COLORS ===
# Used for planet visuals and faction indicators.

const FACTION_COLORS: Dictionary = {
	"Human": Color(0.29, 0.565, 0.851),      # Blue — Commonwealth
	"Gorvian": Color(0.78, 0.22, 0.22),       # Red — Hexarchy
	"Vellani": Color(0.22, 0.78, 0.45),        # Green — FPU
	"Krellvani": Color(0.75, 0.55, 0.20),      # Amber — Outer Reach
}

# === NODE MAP POSITIONS ===
# Normalized positions (0-1) for the 12 planets on the node map.
# Arranged in a roughly circular galaxy layout by faction zone.

const PLANET_POSITIONS: Dictionary = {
	# Commonwealth (top-center)
	1: Vector2(0.45, 0.18),   # Haven
	2: Vector2(0.55, 0.32),   # Meridian
	3: Vector2(0.35, 0.32),   # Fallow
	# Hexarchy (right)
	4: Vector2(0.75, 0.35),   # Korrath Prime
	5: Vector2(0.88, 0.50),   # Dvarn
	6: Vector2(0.72, 0.55),   # Sethi Orbital
	# FPU (left)
	7: Vector2(0.25, 0.45),   # Lirien
	8: Vector2(0.15, 0.60),   # Tessara
	9: Vector2(0.35, 0.65),   # Windhollow
	# Outer Reach (bottom)
	10: Vector2(0.30, 0.82),  # Ironmaw
	11: Vector2(0.50, 0.90),  # Char
	12: Vector2(0.65, 0.75),  # Nexus Station
}


# === CREW NAME POOLS ===
# 28–30 names per species.

const HUMAN_NAMES: Array[String] = [
	"Marcus", "Elena", "Jin", "Priya", "Osei", "Rosa", "Dmitri", "Fatima",
	"Carlos", "Anika", "Tomas", "Lena", "Yusuf", "Cora", "Ravi", "Sofia",
	"Henrik", "Amara", "Kenji", "Nadia", "Luis", "Ingrid", "Zane", "Mira",
	"Owen", "Adeline", "Felix", "Vera", "Samir", "Hana",
]

const GORVIAN_NAMES: Array[String] = [
	"Dvarra", "Korrath", "Sethi", "Voss", "Thenn", "Irrik", "Maldrek",
	"Zolvar", "Fennoth", "Sarrek", "Kellun", "Brassen", "Vekkor", "Torenn",
	"Aldris", "Norrek", "Galveth", "Ossren", "Drevak", "Pellarn",
	"Krissov", "Fennald", "Dorrath", "Ullvek", "Grennoth", "Salvik",
	"Tessorn", "Vorrath", "Bennok", "Ardrek",
]

const VELLANI_NAMES: Array[String] = [
	"Lirien", "Tessari", "Kael", "Wynna", "Aelith", "Sorenn", "Mellira",
	"Faelinn", "Thyra", "Ioleth", "Caelen", "Nivari", "Ellisande", "Pyriel",
	"Dael", "Miravel", "Solinne", "Kaethis", "Veradine", "Lyraeth",
	"Tessiel", "Wynael", "Corael", "Isenne", "Aelora", "Quilleth",
	"Fennara", "Silvael", "Thalien", "Orianna",
]

const KRELLVANI_NAMES: Array[String] = [
	"Grenn", "Rask", "Drokk", "Char", "Brekk", "Vurr", "Kex", "Thull",
	"Mordak", "Skarn", "Tork", "Grunn", "Harsk", "Zull", "Brenn", "Dakk",
	"Vorsk", "Gharn", "Rekk", "Sturm", "Bolg", "Krath", "Fenn", "Rull",
	"Skoll", "Denn", "Vrax", "Torr", "Grist", "Krull",
]

const CREW_NAME_POOLS: Dictionary = {
	"HUMAN": HUMAN_NAMES,
	"GORVIAN": GORVIAN_NAMES,
	"VELLANI": VELLANI_NAMES,
	"KRELLVANI": KRELLVANI_NAMES,
}

# === PERSONALITY GENERATORS ===

const TEMPERAMENT_WORDS: Array[String] = [
	"Meticulous", "Reckless", "Calm", "Ambitious", "Quiet",
	"Methodical", "Impulsive", "Stoic", "Cheerful", "Brooding",
	"Sharp-tongued", "Patient", "Intense", "Easygoing", "Cautious",
	"Stubborn", "Perceptive",
]

const TRAIT_PHRASES: Array[String] = [
	"dislikes chaos", "restless temperament", "fiercely loyal",
	"easily bored", "natural problem-solver", "keeps to themselves",
	"always volunteering", "uncomfortable with authority",
	"surprisingly gentle", "competitive streak", "dry humor",
	"thrives under pressure", "needs routine", "respects strength",
	"curious about everything", "distrustful of strangers",
	"quick to forgive",
]

# === RECRUITMENT TEXT ===

const RECRUIT_ACCEPT_TEXT: Array[String] = [
	"{name} looks over the terms and nods. 'When do I start, Captain?' Welcome aboard.",
	"{name} extends a hand. 'You've got yourself a crew member.' Welcome aboard.",
	"'Fair enough,' says {name}. 'I've served on worse ships.' They're in.",
	"{name} grins. 'I was hoping you'd ask.' Welcome aboard, {role}.",
]

const RECRUIT_RELUCTANT_TEXT: Array[String] = [
	"{name} glances at the split and frowns. They'll take the job but they're not thrilled about it.",
	"'Could be better,' {name} mutters, but signs the contract anyway. Not the happiest start.",
	"{name} hesitates, then shrugs. 'I suppose it beats sitting on this dock.' Joins with reservations.",
]

const RECRUIT_DECLINE_TEXT: Array[String] = [
	"They glance at your ship and politely pass. 'Not the right fit, Captain. No offense.'",
	"{name} shakes their head. 'I'll wait for a better offer.' They stay on the dock.",
	"'Appreciate the interest,' {name} says, 'but I'm looking for something different.'",
]

const RECRUIT_DISMISS_TEXT: Array[String] = [
	"{name} gathers their belongings and walks off the ship without looking back.",
	"{name} salutes once and heads down the gangway. The crew watches them go.",
	"Without a word, {name} collects their kit and disappears into the station crowd.",
]


# === MISSION TEXT ===

# === SHIPYARD TEXT ===

const SHIP_PURCHASE_TEXT: Dictionary = {
	"corvette": [
		"The Corvette's engines thrum with barely contained power. She's yours now, Captain.",
		"You sign the transfer docs. The Corvette sits in the bay, gleaming and ready. A real ship at last.",
		"The yard boss hands you the access codes. Your new Corvette has room for crew. Time to grow.",
	],
	"frigate": [
		"A Frigate. Twelve crew berths, heavy hull, deep cargo holds. This is a serious vessel.",
		"The Frigate dwarfs everything else in the bay. Your old ship looks like a toy beside her.",
		"The transfer is complete. You stand on the bridge of your Frigate and the sector feels smaller.",
	],
}


const MISSION_TYPE_DISPLAY: Dictionary = {
	"cargo_delivery": "Cargo Delivery",
	"passenger_transport": "Passenger Transport",
	"trade_run": "Trade Run",
	"survey": "Survey",
	"retrieval": "Retrieval",
	"escort": "Escort",
	"patrol": "Patrol",
	"distress_signal": "Distress Signal",
	# Faction-exclusive mission types
	"diplomatic_courier": "Diplomatic Courier",
	"trade_regulation": "Trade Regulation Audit",
	"census_survey": "Census Survey",
	"technical_recovery": "Technical Recovery",
	"deep_mining": "Deep Mining Op",
	"research_transport": "Research Data Transport",
	"cultural_exchange": "Cultural Exchange",
	"refugee_relocation": "Refugee Relocation",
	"frontier_medical": "Frontier Medical Aid",
	"bounty_hunting": "Bounty Hunt",
	"contested_salvage": "Contested Salvage",
	"security_escort": "Security Escort",
}

const MISSION_TYPE_VERB: Dictionary = {
	"cargo_delivery": "Deliver",
	"passenger_transport": "Transport passengers to",
	"trade_run": "Trade run to",
	"survey": "Survey sector near",
	"retrieval": "Retrieve cargo from",
	"escort": "Escort convoy to",
	"patrol": "Patrol route to",
	"distress_signal": "Respond to distress signal near",
}

const MISSION_PAYLOADS: Dictionary = {
	"cargo_delivery": ["medical supplies", "industrial parts", "food crates", "mining equipment", "electronics", "fuel cells", "agricultural machinery", "research samples"],
	"passenger_transport": ["diplomats", "researchers", "colonists", "refugees", "merchants", "engineers"],
	"retrieval": ["salvage", "lost cargo", "data cores", "prototype components", "ancient artifacts", "stranded equipment"],
}

const DIFFICULTY_FLAVOR: Dictionary = {
	1: ["Routine run, should be straightforward.", "Simple job. Low risk.", "Easy money if you stay on course."],
	2: ["Moderate difficulty. Stay alert.", "Could get interesting. Keep your wits about you.", "Not the easiest route, but manageable."],
	3: ["Challenging assignment. Prepare well.", "High risk, decent pay. Watch yourself out there.", "Seasoned captains only."],
	4: ["Dangerous mission. Not for the faint-hearted.", "Expect trouble. The pay reflects the risk.", "Veterans recommend against this one."],
	5: ["Extremely dangerous. Survival not guaranteed.", "Only the desperate or the foolish take this job.", "Near-suicidal difficulty. The reward is enormous."],
}

const COMPLICATION_DISPLAY: Dictionary = {
	"pirate_ambush": "Watch for ambushes.",
	"customs_inspection": "Expect customs delays.",
	"equipment_failure": "Reports of equipment malfunctions on this route.",
	"navigation_hazard": "Navigation hazards reported.",
	"cargo_damage": "Fragile cargo — handle with care.",
	"hostile_wildlife": "Local wildlife is aggressive.",
	"communication_blackout": "Comms dead zone along the route.",
	"fuel_shortage": "Fuel stations limited on this route.",
}

const MISSION_PRIMARY_STAT: Dictionary = {
	"cargo_delivery": "cognition",
	"passenger_transport": "social",
	"trade_run": "social",
	"survey": "cognition",
	"retrieval": "resourcefulness",
	"escort": "reflexes",
	"patrol": "stamina",
	"distress_signal": "resourcefulness",
	# Faction-exclusive mission types
	"diplomatic_courier": "social",
	"trade_regulation": "cognition",
	"census_survey": "cognition",
	"technical_recovery": "cognition",
	"deep_mining": "stamina",
	"research_transport": "cognition",
	"cultural_exchange": "social",
	"refugee_relocation": "social",
	"frontier_medical": "social",
	"bounty_hunting": "reflexes",
	"contested_salvage": "stamina",
	"security_escort": "reflexes",
}

const MISSION_ROLES: Dictionary = {
	"cargo_delivery": ["Engineer", "Navigator"],
	"passenger_transport": ["Medic", "Comms Officer"],
	"trade_run": ["Comms Officer", "Navigator"],
	"survey": ["Science Officer", "Navigator"],
	"retrieval": ["Security Chief", "Engineer"],
	"escort": ["Gunner", "Navigator"],
	"patrol": ["Security Chief", "Gunner"],
	"distress_signal": ["Medic", "Engineer", "Security Chief"],
	# Faction-exclusive mission types
	"diplomatic_courier": ["Comms Officer", "Navigator"],
	"trade_regulation": ["Comms Officer", "Science Officer"],
	"census_survey": ["Science Officer", "Navigator"],
	"technical_recovery": ["Engineer", "Security Chief"],
	"deep_mining": ["Engineer", "Navigator"],
	"research_transport": ["Science Officer", "Navigator"],
	"cultural_exchange": ["Comms Officer", "Medic"],
	"refugee_relocation": ["Medic", "Navigator"],
	"frontier_medical": ["Medic", "Science Officer"],
	"bounty_hunting": ["Security Chief", "Gunner"],
	"contested_salvage": ["Engineer", "Security Chief"],
	"security_escort": ["Gunner", "Navigator"],
}

# === LEVEL-UP TEXT ===

const LEVEL_UP_TEXT: Dictionary = {
	2: [
		"You're learning the ropes. The void feels less foreign now.",
		"Your instincts are sharpening. Level 2 — still a long way to go.",
		"A few runs under your belt. You're starting to think like a captain.",
	],
	3: [
		"Experience is the best teacher, and you've been paying attention. Level 3.",
		"Your reflexes are quicker, your decisions more confident. Growing into this.",
		"Dockworkers are starting to recognize your ship. You're building a name.",
	],
	4: [
		"Level 4. You've earned enough respect to command a bigger ship.",
		"The Corvette-class is within reach now. Time to think bigger.",
		"Your skills have outgrown the Skiff. The stars are opening up.",
	],
	5: [
		"Halfway to legend. Level 5. The sector is starting to know your name.",
		"Seasoned captain. The dangerous routes don't scare you like they used to.",
		"Level 5. Veteran captains nod when you pass. You've earned it.",
	],
	6: [
		"Level 6. Fewer and fewer captains have made it this far.",
		"You read jump corridors like poetry now. Instinct and experience fused together.",
		"Level 6 — the missions that once seemed impossible are routine now.",
	],
	7: [
		"Level 7. The Frigate-class beckons. Ready for a real crew?",
		"Seven levels deep and still flying. That's more than most can say.",
		"A Frigate could be yours now. The sector's toughest runs await.",
	],
	8: [
		"Level 8. There aren't many captains left who can match your record.",
		"Your name carries weight now. Factions pay attention when you dock.",
		"Elite territory. Level 8. The void has tested you and found you worthy.",
	],
	9: [
		"Level 9. One step from the top. Legends are written about captains like you.",
		"Near the peak. Your ship, your crew, your instincts — honed to perfection.",
		"Level 9. The most dangerous missions in the sector are yours for the taking.",
	],
	10: [
		"Level 10 — MAXIMUM. You are the standard by which all captains are measured.",
		"The pinnacle. Level 10. There is nothing left to prove. Only legacy to build.",
		"Maximum level achieved. You are a legend of the Gravity Nexus.",
	],
}

const MISSION_OUTCOME_TEXT: Dictionary = {
	"critical_success": [
		"Outstanding work. The mission was a resounding success.",
		"Flawless execution. Your reputation grows.",
		"Couldn't have gone better. The client is thrilled.",
	],
	"success": [
		"Mission complete. Another job well done.",
		"Solid work. The pay is as promised.",
		"You've completed the mission successfully.",
	],
	"marginal_success": [
		"The job is done, but it wasn't pretty. Your hull took some hits.",
		"Scraped through by the skin of your teeth. Could have gone worse.",
		"Mission complete, barely. You'll need repairs.",
	],
	"failure": [
		"Things went sideways. You salvaged what you could.",
		"The mission didn't go as planned. Partial payment only.",
		"A rough outcome. You limped back with little to show for it.",
	],
	"critical_failure": [
		"Disaster. The mission was a complete failure.",
		"Everything that could go wrong did. You're lucky to be alive.",
		"Total loss. No payment. Your ship is battered.",
	],
}


# === FACTION ACCESS TEXT ===

const FACTION_ACCESS_TEXT: Dictionary = {
	"outsider": [
		"The locals at {planet} eye your ship warily. No {faction} crew — you're clearly outsiders.",
		"Prices are steeper here without a {faction} contact. The dockmaster makes that clear.",
		"You feel the cold shoulder at {planet}. Outsiders pay a premium in {faction} space.",
	],
	"insider": [
		"Your {faction} crew member exchanges nods with the dockworkers. You're among friends at {planet}.",
		"Having {faction} crew opens doors at {planet}. Better deals, better missions.",
		"The locals at {planet} warm up when they see your crew. {faction} connections matter here.",
	],
}

const FACTION_HEX_COLORS: Dictionary = {
	"Human": "#4A90D9",
	"Gorvian": "#C73636",
	"Vellani": "#4CAF50",
	"Krellvani": "#BF8C33",
}


# === HELPER FUNCTIONS ===

static func get_arrival_text(planet_name: String) -> String:
	## Returns a random arrival line for the given planet.
	if ARRIVAL_TEXT.has(planet_name):
		var variants: Array = ARRIVAL_TEXT[planet_name]
		var text: String = variants[randi() % variants.size()]
		# Fill simple placeholders
		text = text.replace("{bay}", str(randi_range(1, 42)))
		return text
	return "You arrive at %s." % planet_name


static func get_travel_text() -> String:
	## Returns a random travel line.
	return TRAVEL_TEXT[randi() % TRAVEL_TEXT.size()]


static func get_faction_color(faction: String) -> Color:
	if FACTION_COLORS.has(faction):
		return FACTION_COLORS[faction]
	return Color(0.443, 0.502, 0.588)


static func get_mission_primary_stat(mission_type: String) -> String:
	return MISSION_PRIMARY_STAT.get(mission_type, "resourcefulness")


static func get_mission_outcome_text(tier: String) -> String:
	if MISSION_OUTCOME_TEXT.has(tier):
		var variants: Array = MISSION_OUTCOME_TEXT[tier]
		return variants[randi() % variants.size()]
	return "Mission resolved."


static func get_difficulty_flavor(difficulty: int) -> String:
	var clamped: int = clampi(difficulty, 1, 5)
	var variants: Array = DIFFICULTY_FLAVOR[clamped]
	return variants[randi() % variants.size()]


static func get_mission_type_display(mission_type: String) -> String:
	return MISSION_TYPE_DISPLAY.get(mission_type, mission_type.capitalize())


static func get_ship_purchase_text(ship_class: String) -> String:
	if SHIP_PURCHASE_TEXT.has(ship_class):
		var variants: Array = SHIP_PURCHASE_TEXT[ship_class]
		return variants[randi() % variants.size()]
	return "Your new %s is ready." % ship_class.capitalize()


static func get_level_up_text(level: int) -> String:
	if LEVEL_UP_TEXT.has(level):
		var variants: Array = LEVEL_UP_TEXT[level]
		return variants[randi() % variants.size()]
	return "You've reached level %d." % level


static func get_crew_name(species_key: String) -> String:
	## Returns a random name from the species name pool.
	if CREW_NAME_POOLS.has(species_key):
		var pool: Array = CREW_NAME_POOLS[species_key]
		return pool[randi() % pool.size()]
	return HUMAN_NAMES[randi() % HUMAN_NAMES.size()]


static func generate_personality() -> String:
	## Returns a random personality descriptor combining temperament + trait.
	var temp: String = TEMPERAMENT_WORDS[randi() % TEMPERAMENT_WORDS.size()]
	var trait_phrase: String = TRAIT_PHRASES[randi() % TRAIT_PHRASES.size()]
	return "%s, %s." % [temp, trait_phrase]


static func get_recruit_accept_text(crew_name: String, role_name: String) -> String:
	var variants: Array = RECRUIT_ACCEPT_TEXT
	var text: String = variants[randi() % variants.size()]
	return text.replace("{name}", crew_name).replace("{role}", role_name)


static func get_recruit_reluctant_text(crew_name: String) -> String:
	var variants: Array = RECRUIT_RELUCTANT_TEXT
	var text: String = variants[randi() % variants.size()]
	return text.replace("{name}", crew_name)


static func get_recruit_decline_text(crew_name: String) -> String:
	var variants: Array = RECRUIT_DECLINE_TEXT
	var text: String = variants[randi() % variants.size()]
	return text.replace("{name}", crew_name)


static func get_dismiss_text(crew_name: String) -> String:
	var variants: Array = RECRUIT_DISMISS_TEXT
	var text: String = variants[randi() % variants.size()]
	return text.replace("{name}", crew_name)


static func get_faction_access_text(access_type: String, planet_name: String, faction: String) -> String:
	## Returns faction access arrival text (outsider or insider).
	if FACTION_ACCESS_TEXT.has(access_type):
		var variants: Array = FACTION_ACCESS_TEXT[access_type]
		var text: String = variants[randi() % variants.size()]
		return text.replace("{planet}", planet_name).replace("{faction}", faction)
	return ""


static func get_faction_hex_color(faction: String) -> String:
	return FACTION_HEX_COLORS.get(faction, "#718096")
