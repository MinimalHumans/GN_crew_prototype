class_name CrewEventTemplates
## CrewEventTemplates — Text pools for crew simulation events.
## Flavor text is now served from FlavorDB (res://data/flavor_text.db).
## This file retains game-logic constants and helper method signatures.


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


# === FORMATTING HELPERS ===

static func format_mechanical_summary(changes: Dictionary) -> String:
	## Generates a muted follow-up line summarizing mechanical changes.
	## Returns empty string if no changes worth reporting.
	var parts: Array[String] = []

	if changes.has("morale"):
		var val: float = changes.morale
		if val > 0:
			parts.append("Morale improved")
		elif val < 0:
			parts.append("Morale dropped")

	if changes.has("fatigue"):
		var val: float = changes.fatigue
		if val > 0:
			parts.append("Fatigue increased")
		elif val < 0:
			parts.append("Fatigue reduced")

	if changes.has("loyalty"):
		var val: float = changes.loyalty
		if val > 0:
			parts.append("Loyalty strengthened")
		elif val < 0:
			parts.append("Loyalty weakened")

	if changes.has("relationship"):
		var val: float = changes.relationship
		if val > 0:
			parts.append("Relationship improved")
		elif val < 0:
			parts.append("Relationship worsened")

	if changes.has("xp"):
		parts.append("+%d XP" % changes.xp)

	if changes.has("credits"):
		var val: int = changes.credits
		if val > 0:
			parts.append("+%d credits" % val)
		elif val < 0:
			parts.append("%d credits" % val)

	if changes.has("hull"):
		parts.append("Hull %+d" % changes.hull)

	if changes.has("fuel"):
		parts.append("Fuel %+.0f" % changes.fuel)

	if changes.has("injury"):
		parts.append(changes.injury)

	if changes.has("disease"):
		parts.append(changes.disease)

	if changes.has("trait"):
		parts.append("Trait acquired: %s" % changes.trait)

	if changes.has("memory"):
		parts.append("Formative memory")

	if parts.is_empty():
		return ""

	return "[color=#555B66]  ↳ %s.[/color]" % ", ".join(parts)


static func format_nudge(text: String) -> String:
	## Formats an actionable nudge warning — something the player can respond to.
	return "[color=#E67E22]⚠ %s[/color]" % text


static func format_observation(text: String) -> String:
	## Formats a neutral observation — atmospheric, no action needed.
	return "[color=#718096]%s[/color]" % text


static func format_positive(text: String) -> String:
	## Formats a positive event.
	return "[color=#27AE60]%s[/color]" % text


static func format_negative(text: String) -> String:
	## Formats a negative event.
	return "[color=#C0392B]%s[/color]" % text


# === SERVICE SUGGESTIONS ===

static func get_service_suggestion(trigger_type: String) -> String:
	## Returns a suggestion line for the given trigger, or empty string.
	match trigger_type:
		"fatigue_high":
			return "[color=#555B66]  ↳ A port with hospital services could help with recovery.[/color]"
		"morale_low":
			return "[color=#555B66]  ↳ Shore leave at a developed port might lift spirits.[/color]"
		"injury_no_medic":
			return "[color=#555B66]  ↳ A hospital could treat the injury properly.[/color]"
		"disease_active":
			return "[color=#555B66]  ↳ A hospital planet could cure the disease.[/color]"
		"purpose_bored":
			return "[color=#555B66]  ↳ A mission using their skills would help.[/color]"
		"food_low":
			return "[color=#555B66]  ↳ Restock at the nearest shop.[/color]"
		"hull_damaged":
			return "[color=#555B66]  ↳ A shipyard or shop can handle repairs.[/color]"
		"crew_conflict":
			return "[color=#555B66]  ↳ Docking for shore leave might ease tensions.[/color]"
	return ""


# === HELPER FUNCTIONS ===

static func _pick(pool: Array) -> String:
	return pool[randi() % pool.size()]


static func get_slice_of_life(name_a: String, name_b: String) -> String:
	return FlavorDB.pick_with_replacements("slice_of_life", {"{a}": name_a, "{b}": name_b})


static func get_positive_social_text(name_a: String, name_b: String) -> String:
	return FlavorDB.pick_with_replacements("social_positive", {"{a}": name_a, "{b}": name_b})


static func get_negative_social_text(name_a: String, name_b: String) -> String:
	return FlavorDB.pick_with_replacements("social_negative", {"{a}": name_a, "{b}": name_b})


static func get_morale_high_text(crew_name: String) -> String:
	return FlavorDB.pick_with_replacements("morale_high", {"{name}": crew_name})


static func get_morale_low_text(crew_name: String) -> String:
	return FlavorDB.pick_with_replacements("morale_low", {"{name}": crew_name})


static func get_fatigue_high_text(crew_name: String) -> String:
	return FlavorDB.pick_with_replacements("fatigue_high", {"{name}": crew_name})


static func get_purpose_bored_text(crew_name: String) -> String:
	return FlavorDB.pick_with_replacements("purpose_bored", {"{name}": crew_name})


static func get_food_low_text() -> String:
	return FlavorDB.pick("food_low")


static func get_travel_crew_text(ship_morale: float) -> String:
	if ship_morale > 50.0:
		return FlavorDB.pick("travel_crew_good")
	return FlavorDB.pick("travel_crew_bad")


static func get_nudge_text(nudge_type: String, name_a: String = "", name_b: String = "") -> String:
	var key: String = "nudge_" + nudge_type
	return FlavorDB.pick_with_replacements(key, {"{a}": name_a, "{b}": name_b})


static func get_species_friction_text(name_a: String, name_b: String, pair_key: String) -> String:
	var db_key: String = "species_friction_" + pair_key.to_lower()
	var result: String = FlavorDB.pick_with_replacements(db_key,
		{"{a}": name_a, "{b}": name_b})
	if result.is_empty():
		return "%s and %s had a tense moment." % [name_a, name_b]
	return result


static func get_species_bonding_text(name_a: String, name_b: String, pair_key: String) -> String:
	var db_key: String = "species_bonding_" + pair_key.to_lower()
	var result: String = FlavorDB.pick_with_replacements(db_key,
		{"{a}": name_a, "{b}": name_b})
	if result.is_empty():
		return "%s and %s are getting along surprisingly well." % [name_a, name_b]
	return result


static func get_comfort_food_text(crew_name: String, species_name: String) -> String:
	var key: String = "comfort_food_" + species_name.to_lower()
	var result: String = FlavorDB.pick_with_replacements(key, {"{name}": crew_name})
	if result.is_empty():
		return "%s enjoys the familiar food." % crew_name
	return result


static func get_memory_dialogue(crew_name: String, emotional_tag: String) -> String:
	var key: String = "memory_dialogue_" + emotional_tag.to_lower()
	var result: String = FlavorDB.pick_with_replacements(key, {"{name}": crew_name})
	if result.is_empty():
		return "%s is lost in thought for a moment." % crew_name
	return result


static func get_romance_formation_text(name_a: String, name_b: String) -> String:
	return FlavorDB.pick_with_replacements("romance_formation",
		{"{a}": name_a, "{b}": name_b})


static func get_romance_event_text(name_a: String, name_b: String, morale_avg: float) -> String:
	if morale_avg < 40.0:
		return FlavorDB.pick_with_replacements("romance_stressed",
			{"{a}": name_a, "{b}": name_b})
	return FlavorDB.pick_with_replacements("romance_positive",
		{"{a}": name_a, "{b}": name_b})


static func get_romance_breakup_text(name_a: String, name_b: String) -> String:
	return FlavorDB.pick_with_replacements("romance_breakup",
		{"{a}": name_a, "{b}": name_b})


static func get_romance_injury_concern_text(name_a: String, name_b: String) -> String:
	return FlavorDB.pick_with_replacements("romance_injury_concern",
		{"{a}": name_a, "{b}": name_b})


static func get_loyalty_reaction_text(crew_name: String, value: String, is_positive: bool) -> String:
	var key: String = "loyalty_reaction_%s_%s" % [
		value.to_lower(), "positive" if is_positive else "negative"]
	return FlavorDB.pick_with_replacements(key, {"{name}": crew_name})


static func get_loyalty_withdrawal_text(crew_name: String) -> String:
	return FlavorDB.pick_with_replacements("loyalty_withdrawal", {"{name}": crew_name})


static func get_loyalty_vocal_text(crew_name: String) -> String:
	return FlavorDB.pick_with_replacements("loyalty_vocal", {"{name}": crew_name})


static func get_loyalty_departure_text(crew_name: String) -> String:
	return FlavorDB.pick_with_replacements("loyalty_departure", {"{name}": crew_name})


static func get_grief_event_text(crew_name: String, deceased_name: String) -> String:
	return FlavorDB.pick_with_replacements("grief_event",
		{"{name}": crew_name, "{deceased}": deceased_name})


static func get_grief_resolved_text(crew_name: String, deceased_name: String) -> String:
	return FlavorDB.pick_with_replacements("grief_resolved",
		{"{name}": crew_name, "{deceased}": deceased_name})


static func get_grief_broken_text(crew_name: String, deceased_name: String) -> String:
	return FlavorDB.pick_with_replacements("grief_broken",
		{"{name}": crew_name, "{deceased}": deceased_name})


static func get_grief_broken_request_text(crew_name: String, deceased_name: String) -> String:
	return FlavorDB.pick_with_replacements("grief_broken_request",
		{"{name}": crew_name, "{deceased}": deceased_name})


static func get_mourning_crew_text(crew_name: String) -> String:
	return FlavorDB.pick_with_replacements("mourning_crew", {"{name}": crew_name})


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


# === CREW-GENERATED MISSIONS (Phase 5.4) ===

# Species → homeworld planet name mapping
const SPECIES_HOMEWORLD: Dictionary = {
	"GORVIAN": "Korrath Prime",
	"VELLANI": "Lirien",
	"KRELLVANI": "Ironmaw",
	"HUMAN": "Haven",
}

# Species → homeworld planet ID mapping
const SPECIES_HOMEWORLD_ID: Dictionary = {
	"GORVIAN": 4,
	"VELLANI": 7,
	"KRELLVANI": 10,
	"HUMAN": 1,
}

# Faction → rival faction zone planets
const FACTION_RIVAL_PLANETS: Dictionary = {
	"GORVIAN": [10, 11, 12],  # Outer Reach (Krellvani)
	"VELLANI": [4, 5, 6],     # Hexarchy (Gorvian)
	"KRELLVANI": [4, 5, 6],   # Hexarchy (Gorvian)
	"HUMAN": [10, 11, 12],    # Outer Reach
}

static func get_crew_gen_mission_setup(template_type: String, crew_name: String,
		species: String, extra: Dictionary) -> String:
	match template_type:
		"homeworld":
			var homeworld: String = SPECIES_HOMEWORLD.get(species, "home")
			return "%s catches you after a shift change. 'Captain, I know we go where the work takes us. But I haven't been home in a long time. %s isn't far from our usual runs. Could we make a stop?' They're not demanding — just asking." % [crew_name, homeworld]
		"confrontation":
			var planet_name: String = extra.get("planet_name", "a nearby planet")
			return "%s has been brooding since we passed through rival space. Finally they come to you. 'Captain, there's someone at %s. Someone I need to face. I'm not asking for a fight — I just need to look them in the eye.' The grudge has been eating at them." % [crew_name, planet_name]
		"closure":
			var planet_name: String = extra.get("planet_name", "that place")
			return "%s hasn't slept well in a while. They come to you quietly. 'Captain, I need to go back to where it happened. %s. I know it sounds crazy. But I need to see it again — maybe then I can put it down.'" % [crew_name, planet_name]
		"shared_adventure":
			var partner_name: String = extra.get("partner_name", "their partner")
			var planet_name: String = extra.get("planet_name", "somewhere new")
			return "%s and %s approach you together — that's unusual. %s speaks: 'Captain, there's a place %s has been telling me about for months. %s. We'd like to go there. Together. Call it a morale expedition.' %s adds: 'It's not far. And we've earned it.'" % [crew_name, partner_name, crew_name, partner_name, planet_name, partner_name]
		"proving":
			return "%s has been on board long enough to stop flinching at loud noises. They find you alone and speak with quiet intensity. 'Captain, you gave me a chance when no one else would. I want to earn it — really earn it. Let me lead the next tough mission we take on.'" % crew_name
	return "%s approaches you with a personal request." % crew_name


static func get_crew_gen_mission_completion(template_type: String, crew_name: String,
		success: bool, extra: Dictionary) -> String:
	match template_type:
		"homeworld":
			var homeworld: String = extra.get("homeworld", "home")
			return "%s steps off the ship at %s and breathes deep. For a moment, the weight they carry lifts. They come back looking ten years younger." % [crew_name, homeworld]
		"confrontation":
			if success:
				return "%s came back from the meeting different. Quieter. The anger is still there, but it's not running the show anymore." % crew_name
			else:
				return "%s came back from the meeting with a harder look in their eyes. Whatever happened, it didn't give them what they needed." % crew_name
		"closure":
			if success:
				var location: String = extra.get("planet_name", "that place")
				return "%s stood at the viewport as we passed through %s. For a long time, they didn't move. Then they exhaled — a breath they'd been holding for weeks. 'Okay,' they said. 'Okay.' They slept through the night for the first time since it happened." % [crew_name, location]
			else:
				return "%s came back from the viewport looking no different. 'It didn't work,' they said. But there was no regret. 'At least I tried, Captain. That counts for something.'" % crew_name
		"shared_adventure":
			var partner_name: String = extra.get("partner_name", "their partner")
			var planet_name: String = extra.get("planet_name", "that planet")
			return "%s and %s came back from their shore leave with matching grins and a story they refuse to tell anyone. Whatever happened on %s, it's theirs. The ship feels a little warmer for it." % [crew_name, partner_name, planet_name]
		"proving":
			if success:
				return "%s walks off the bridge after the mission and the crew parts for them — not in fear, but respect. The desperate stowaway is gone. In their place is someone who belongs here. They always did." % crew_name
			else:
				return "%s takes the failure hard, but they don't break. 'Next time, Captain. I'll be ready.' You believe them." % crew_name
	return ""


# === RETIREMENT (Phase 5.5) ===

static func get_retirement_text(crew_name: String, planet_name: String) -> String:
	return "%s finds you on the observation deck, which is unusual — they usually avoid sentimentality. 'Captain, it's been a hell of a run. But I think my time on this ship has come to an end. I want to settle down here on %s. Start something quieter.' They smile. 'I'll miss this crew. But I won't miss getting shot at.'" % [crew_name, planet_name]


# === CREW DEATH (Phase 5.5) ===

static func get_death_text(crew_name: String, cause: String, medic_name: String) -> String:
	match cause:
		"combat":
			if medic_name != "":
				return "%s is gone. The blast caught %s before anyone could react. %s tried. It wasn't enough. The bridge is silent." % [crew_name, crew_name, medic_name]
			return "%s is gone. The blast caught %s before anyone could react. There was nothing anyone could do. The bridge is silent." % [crew_name, crew_name]
		"disease":
			if medic_name != "":
				return "%s didn't wake up this morning. %s had been fighting it for days, but the disease was too far along. The crew gathers outside their quarters, unable to speak." % [crew_name, medic_name]
			return "%s didn't wake up this morning. Without a medic to fight it, the disease took them in their sleep. The crew gathers outside their quarters, unable to speak." % crew_name
		"hull_breach":
			return "%s is gone. When the hull gave way, they were in the wrong place at the wrong time. No amount of skill could have saved them." % crew_name
	return "%s is gone." % crew_name


# === LEGACY DISPLAY TEXT (Phase 5.5) ===

static func get_legacy_display_text(crew_name: String, departure_type: String,
		effect_text: String) -> String:
	match departure_type:
		"retirement":
			return "%s's modifications still hum in the walls. %s" % [crew_name, effect_text]
		"death":
			return "We fight for those we've lost. %s" % effect_text
		"voluntary":
			return "Not everyone stays. The crew remembers."
		"prosperity":
			return "%s made their fortune here. Future crew take notice." % crew_name
		"underpaid":
			return "Not everyone can afford to stay."
		"dismissal_positive":
			return "Nobody's said it out loud, but the ship breathes easier."
		"dismissal_negative":
			return "The crew hasn't forgotten how %s left." % crew_name
		"leave_expired":
			return "We never went back. That's on us."
		"leave_stayed":
			return "They found what they were looking for."
		"leave_replaced":
			return "The crew remembers how %s was treated." % crew_name
		"trouble_ashore":
			return "Port life claimed another one."
	return ""
