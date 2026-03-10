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
