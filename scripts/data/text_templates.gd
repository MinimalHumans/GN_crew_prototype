class_name TextTemplates
## TextTemplates — Static text pools for atmospheric messages.
## Flavor text is now served from FlavorDB (res://data/flavor_text.db).
## This file retains game-logic constants and helper method signatures.


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


# === MISSION TEXT ===

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

const FACTION_HEX_COLORS: Dictionary = {
	"Human": "#4A90D9",
	"Gorvian": "#C73636",
	"Vellani": "#4CAF50",
	"Krellvani": "#BF8C33",
}


# === HELPER FUNCTIONS ===

static func get_arrival_text(planet_name: String) -> String:
	var pool_key: String = "arrival_" + planet_name.to_lower().replace(" ", "_")
	var text: String = FlavorDB.pick(pool_key)
	if text.is_empty():
		return "You arrive at %s." % planet_name
	text = text.replace("{bay}", str(randi_range(1, 42)))
	return text


static func get_travel_text() -> String:
	return FlavorDB.pick("travel_transit")


static func get_faction_color(faction: String) -> Color:
	if FACTION_COLORS.has(faction):
		return FACTION_COLORS[faction]
	return Color(0.443, 0.502, 0.588)


static func get_mission_primary_stat(mission_type: String) -> String:
	return MISSION_PRIMARY_STAT.get(mission_type, "resourcefulness")


static func get_mission_outcome_text(tier: String) -> String:
	var key: String = "mission_outcome_" + tier
	var result: String = FlavorDB.pick(key)
	return result if not result.is_empty() else "Mission resolved."


static func get_difficulty_flavor(difficulty: int) -> String:
	var key: String = "difficulty_%d" % clampi(difficulty, 1, 5)
	return FlavorDB.pick(key)


static func get_mission_type_display(mission_type: String) -> String:
	return MISSION_TYPE_DISPLAY.get(mission_type, mission_type.capitalize())


static func get_ship_purchase_text(ship_class: String) -> String:
	var result: String = FlavorDB.pick("ship_purchase_" + ship_class)
	return result if not result.is_empty() else "Your new %s is ready." % ship_class.capitalize()


static func get_level_up_text(level: int) -> String:
	var result: String = FlavorDB.pick("levelup_%d" % level)
	return result if not result.is_empty() else "You've reached level %d." % level


static func get_crew_name(species_key: String) -> String:
	var all_names: Array[String] = FlavorDB.get_all("names_" + species_key.to_lower())
	if all_names.is_empty():
		return "Unknown"
	return all_names[randi() % all_names.size()]


static func generate_personality() -> String:
	var temp: String = FlavorDB.pick("personality_temperament")
	var trait_phrase: String = FlavorDB.pick("personality_trait")
	return "%s, %s." % [temp, trait_phrase]


static func get_recruit_accept_text(crew_name: String, role_name: String) -> String:
	return FlavorDB.pick_with_replacements("recruit_accept",
		{"{name}": crew_name, "{role}": role_name})


static func get_recruit_reluctant_text(crew_name: String) -> String:
	return FlavorDB.pick_with_replacements("recruit_reluctant", {"{name}": crew_name})


static func get_recruit_decline_text(crew_name: String) -> String:
	return FlavorDB.pick_with_replacements("recruit_decline", {"{name}": crew_name})


static func get_dismiss_text(crew_name: String) -> String:
	return FlavorDB.pick_with_replacements("recruit_dismiss", {"{name}": crew_name})


static func get_faction_access_text(access_type: String, planet_name: String, faction: String) -> String:
	var result: String = FlavorDB.pick_with_replacements(
		"faction_access_" + access_type,
		{"{planet}": planet_name, "{faction}": faction})
	return result


static func get_faction_hex_color(faction: String) -> String:
	return FACTION_HEX_COLORS.get(faction, "#718096")
