#!/usr/bin/env python3
"""Build the flavor_text.db SQLite database from GDScript text pools.

Run from the project root:
    python build_flavor_db.py

Creates data/flavor_text.db with all flavor text entries.
"""

import os
import sqlite3
from collections import defaultdict

DB_PATH = os.path.join(os.path.dirname(__file__), "data", "flavor_text.db")

# ── Schema ──────────────────────────────────────────────────────────────────

SCHEMA = """
CREATE TABLE IF NOT EXISTS flavor_text (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pool_key TEXT NOT NULL,
    text TEXT NOT NULL,
    weight REAL DEFAULT 1.0
);
CREATE INDEX IF NOT EXISTS idx_pool ON flavor_text(pool_key);
"""


def build():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    conn.executescript(SCHEMA)
    cur = conn.cursor()
    counts = defaultdict(int)

    def add(pool_key: str, texts):
        if isinstance(texts, str):
            texts = [texts]
        for t in texts:
            cur.execute("INSERT INTO flavor_text (pool_key, text) VALUES (?, ?)", (pool_key, t))
            counts[pool_key] += 1

    # ════════════════════════════════════════════════════════════════════════
    # FROM text_templates.gd
    # ════════════════════════════════════════════════════════════════════════

    # --- ARRIVAL_TEXT ---
    add("arrival_haven", [
        "You dock at Haven. The station hums with commerce and the smell of cheap coffee.",
        "Haven's docking clamps lock on. The familiar bustle of the Commonwealth hub greets you.",
        "Home port. Haven's lights spread out below as your ship settles into bay {bay}.",
        "The dockmaster waves you through with barely a glance. Haven knows your transponder by now.",
    ])
    add("arrival_meridian", [
        "Meridian's crossroads station buzzes with traffic from three zones. Everyone's going somewhere.",
        "You slot into Meridian's crowded docking ring. Trade vessels from every faction jostle for position.",
        "The Meridian beacon pings your transponder. Commonwealth and Hexarchy flags fly side by side here.",
        "Meridian never sleeps. Cargo drones weave between ships as you find your assigned berth.",
    ])
    add("arrival_fallow", [
        "Fallow smells like grain and engine grease. A quiet world with cheap provisions.",
        "You set down at Fallow. Fields stretch to the horizon under pale skies. Simple and cheap.",
        "Fallow's small port has more cargo haulers than passenger ships. Food country.",
        "The air at Fallow tastes clean. A welcome change from recycled ship atmosphere.",
    ])
    add("arrival_korrath_prime", [
        "Korrath Prime's orbital docks are immaculate. Gorvian efficiency at its finest.",
        "The Hexarchy capital gleams with ordered precision. Your hull looks shabby by comparison.",
        "Korrath Prime. The dockmaster inspects your ship with clinical Gorvian thoroughness.",
        "Everything at Korrath Prime runs on schedule. Your docking window is exactly forty seconds.",
    ])
    add("arrival_dvarn", [
        "Dvarn's cold hits you through the hull. Mining rigs dot the frozen landscape below.",
        "You dock at Dvarn. Ice crystals coat the viewports. The ore haulers here are massive.",
        "The cold of Dvarn seeps into everything. Miners in heavy suits trudge past your berth.",
        "Dvarn's landing pad crunches with frost. The ore refineries belch steam into the grey sky.",
    ])
    add("arrival_sethi_orbital", [
        "Sethi Orbital rotates slowly against the stars. A research station at the edge of Hexarchy space.",
        "The orbital's sensors sweep your ship before you're cleared to dock. Science types are cautious.",
        "Sethi Orbital hums with instrument readings. Researchers hurry between labs.",
        "A strange energy reading pulses from Sethi's lower decks. The scientists don't seem concerned.",
    ])
    add("arrival_lirien", [
        "Lirien's port is alive with color and conversation. Vellani hospitality at its warmest.",
        "You dock at Lirien. Music drifts from somewhere. The air smells like spiced tea and flowers.",
        "Lirien welcomes you. The Vellani homeworld is the best place to find crew in the sector.",
        "Children wave from the observation deck as you dock. Lirien still believes in strangers.",
    ])
    add("arrival_tessara", [
        "Tessara's docks are decorated with murals and hanging textiles. Culture is the export here.",
        "Art and commerce blend seamlessly at Tessara. Even the dockworkers move with grace.",
        "You set down on Tessara. A Vellani artisan is selling hand-painted hull decals at the next berth.",
        "Tessara's markets overflow with luxuries. Silk, spice, and song at every turn.",
    ])
    add("arrival_windhollow", [
        "Windhollow is barely a settlement. A frontier outpost where the maps start getting vague.",
        "You dock at Windhollow. The wind howls across the landing pad. Not much here but cheap fuel and big sky.",
        "Windhollow. The frontier. Beyond here, the routes get interesting.",
        "A lone survey ship shares the landing field. Its pilot nods but doesn't speak.",
    ])
    add("arrival_ironmaw", [
        "Ironmaw's docks are built for warships. The Krellvani stronghold radiates menace.",
        "You dock at Ironmaw. Weapons dealers outnumber food vendors three to one.",
        "Ironmaw. Even the station smells like gunmetal. The Krellvani eye your ship appraisingly.",
        "Heavy turrets track your approach. Ironmaw doesn't trust anyone until they've docked.",
    ])
    add("arrival_char", [
        "Char has no real port — just a bombed-out landing field. Contested space at its worst.",
        "You set down on Char and hope your ship is still here when you get back.",
        "Char. The most dangerous rock in the sector. The pay is good if you survive.",
        "Scorch marks and debris litter Char's landing zone. Someone had a bad day recently.",
    ])
    add("arrival_nexus_station", [
        "Nexus Station operates outside every faction's rules. The prices here are anyone's guess.",
        "You dock at Nexus Station. The black market hub of the Outer Reach. Watch your cargo.",
        "Nexus Station. Neutral ground where anything can be bought if you don't ask too many questions.",
        "The station's neon reflects off your hull. Nexus never pretends to be anything it isn't.",
    ])

    # --- TRAVEL_TEXT ---
    add("travel_transit", [
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
        "Faint radiation echoes from a dead system nearby. You adjust course and move on.",
        "The jump leaves a metallic taste. Old spacer superstition says that's good luck.",
        "Between stars, the dark is absolute. Then the next system blooms ahead.",
        "Your nav computer chirps a course correction. Barely noticeable, but it matters.",
        "A ghost signal flickers on long-range — probably just stellar noise.",
        "The ship creaks as gravity shifts between jump lanes. Routine, but never comfortable.",
        "You pass through the remnants of an old shipping lane. Debris pings off the hull.",
        "The transition is rough this time. Coffee spills. Instruments recover quickly.",
        "A trade convoy passes on a parallel lane, lights blinking in sequence. You exchange no words.",
        "The void between systems feels longer this jump. Just perception, says the nav log.",
        "Your chronometer skips a beat during the jump. Recalibrates on the other side.",
    ])

    # --- RECRUIT TEXT ---
    add("recruit_accept", [
        "{name} looks over the terms and nods. 'When do I start, Captain?' Welcome aboard.",
        "{name} extends a hand. 'You've got yourself a crew member.' Welcome aboard.",
        "'Fair enough,' says {name}. 'I've served on worse ships.' They're in.",
        "{name} grins. 'I was hoping you'd ask.' Welcome aboard, {role}.",
    ])
    add("recruit_reluctant", [
        "{name} glances at the split and frowns. They'll take the job but they're not thrilled about it.",
        "'Could be better,' {name} mutters, but signs the contract anyway. Not the happiest start.",
        "{name} hesitates, then shrugs. 'I suppose it beats sitting on this dock.' Joins with reservations.",
    ])
    add("recruit_decline", [
        "They glance at your ship and politely pass. 'Not the right fit, Captain. No offense.'",
        "{name} shakes their head. 'I'll wait for a better offer.' They stay on the dock.",
        "'Appreciate the interest,' {name} says, 'but I'm looking for something different.'",
    ])
    add("recruit_dismiss", [
        "{name} gathers their belongings and walks off the ship without looking back.",
        "{name} salutes once and heads down the gangway. The crew watches them go.",
        "Without a word, {name} collects their kit and disappears into the station crowd.",
    ])

    # --- DIFFICULTY_FLAVOR ---
    add("difficulty_1", [
        "Routine run, should be straightforward.",
        "Simple job. Low risk.",
        "Easy money if you stay on course.",
    ])
    add("difficulty_2", [
        "Moderate difficulty. Stay alert.",
        "Could get interesting. Keep your wits about you.",
        "Not the easiest route, but manageable.",
    ])
    add("difficulty_3", [
        "Challenging assignment. Prepare well.",
        "High risk, decent pay. Watch yourself out there.",
        "Seasoned captains only.",
    ])
    add("difficulty_4", [
        "Dangerous mission. Not for the faint-hearted.",
        "Expect trouble. The pay reflects the risk.",
        "Veterans recommend against this one.",
    ])
    add("difficulty_5", [
        "Extremely dangerous. Survival not guaranteed.",
        "Only the desperate or the foolish take this job.",
        "Near-suicidal difficulty. The reward is enormous.",
    ])

    # --- MISSION_OUTCOME_TEXT ---
    add("mission_outcome_critical_success", [
        "Outstanding work. The mission was a resounding success.",
        "Flawless execution. Your reputation grows.",
        "Couldn't have gone better. The client is thrilled.",
    ])
    add("mission_outcome_success", [
        "Mission complete. Another job well done.",
        "Solid work. The pay is as promised.",
        "You've completed the mission successfully.",
    ])
    add("mission_outcome_marginal_success", [
        "The job is done, but it wasn't pretty. Your hull took some hits.",
        "Scraped through by the skin of your teeth. Could have gone worse.",
        "Mission complete, barely. You'll need repairs.",
    ])
    add("mission_outcome_failure", [
        "Things went sideways. You salvaged what you could.",
        "The mission didn't go as planned. Partial payment only.",
        "A rough outcome. You limped back with little to show for it.",
    ])
    add("mission_outcome_critical_failure", [
        "Disaster. The mission was a complete failure.",
        "Everything that could go wrong did. You're lucky to be alive.",
        "Total loss. No payment. Your ship is battered.",
    ])

    # --- MISSION_PAYLOADS ---
    add("mission_payload_cargo_delivery", [
        "medical supplies", "industrial parts", "food crates", "mining equipment",
        "electronics", "fuel cells", "agricultural machinery", "research samples",
    ])
    add("mission_payload_passenger_transport", [
        "diplomats", "researchers", "colonists", "refugees", "merchants", "engineers",
    ])
    add("mission_payload_retrieval", [
        "salvage", "lost cargo", "data cores", "prototype components",
        "ancient artifacts", "stranded equipment",
    ])

    # --- LEVEL_UP_TEXT ---
    add("levelup_2", [
        "You're learning the ropes. The void feels less foreign now.",
        "Your instincts are sharpening. Level 2 — still a long way to go.",
        "A few runs under your belt. You're starting to think like a captain.",
    ])
    add("levelup_3", [
        "Experience is the best teacher, and you've been paying attention. Level 3.",
        "Your reflexes are quicker, your decisions more confident. Growing into this.",
        "Dockworkers are starting to recognize your ship. You're building a name.",
    ])
    add("levelup_4", [
        "Level 4. You've earned enough respect to command a bigger ship.",
        "The Corvette-class is within reach now. Time to think bigger.",
        "Your skills have outgrown the Skiff. The stars are opening up.",
    ])
    add("levelup_5", [
        "Halfway to legend. Level 5. The sector is starting to know your name.",
        "Seasoned captain. The dangerous routes don't scare you like they used to.",
        "Level 5. Veteran captains nod when you pass. You've earned it.",
    ])
    add("levelup_6", [
        "Level 6. Fewer and fewer captains have made it this far.",
        "You read jump corridors like poetry now. Instinct and experience fused together.",
        "Level 6 — the missions that once seemed impossible are routine now.",
    ])
    add("levelup_7", [
        "Level 7. The Frigate-class beckons. Ready for a real crew?",
        "Seven levels deep and still flying. That's more than most can say.",
        "A Frigate could be yours now. The sector's toughest runs await.",
    ])
    add("levelup_8", [
        "Level 8. There aren't many captains left who can match your record.",
        "Your name carries weight now. Factions pay attention when you dock.",
        "Elite territory. Level 8. The void has tested you and found you worthy.",
    ])
    add("levelup_9", [
        "Level 9. One step from the top. Legends are written about captains like you.",
        "Near the peak. Your ship, your crew, your instincts — honed to perfection.",
        "Level 9. The most dangerous missions in the sector are yours for the taking.",
    ])
    add("levelup_10", [
        "Level 10 — MAXIMUM. You are the standard by which all captains are measured.",
        "The pinnacle. Level 10. There is nothing left to prove. Only legacy to build.",
        "Maximum level achieved. You are a legend of the Gravity Nexus.",
    ])

    # --- SHIP_PURCHASE_TEXT ---
    add("ship_purchase_corvette", [
        "The Corvette's engines thrum with barely contained power. She's yours now, Captain.",
        "You sign the transfer docs. The Corvette sits in the bay, gleaming and ready. A real ship at last.",
        "The yard boss hands you the access codes. Your new Corvette has room for crew. Time to grow.",
    ])
    add("ship_purchase_frigate", [
        "A Frigate. Twelve crew berths, heavy hull, deep cargo holds. This is a serious vessel.",
        "The Frigate dwarfs everything else in the bay. Your old ship looks like a toy beside her.",
        "The transfer is complete. You stand on the bridge of your Frigate and the sector feels smaller.",
    ])

    # --- FACTION_ACCESS_TEXT ---
    add("faction_access_outsider", [
        "The locals at {planet} eye your ship warily. No {faction} crew — you're clearly outsiders.",
        "Prices are steeper here without a {faction} contact. The dockmaster makes that clear.",
        "You feel the cold shoulder at {planet}. Outsiders pay a premium in {faction} space.",
    ])
    add("faction_access_insider", [
        "Your {faction} crew member exchanges nods with the dockworkers. You're among friends at {planet}.",
        "Having {faction} crew opens doors at {planet}. Better deals, better missions.",
        "The locals at {planet} warm up when they see your crew. {faction} connections matter here.",
    ])

    # --- NAMES ---
    add("names_human", [
        "Marcus", "Elena", "Jin", "Priya", "Osei", "Rosa", "Dmitri", "Fatima",
        "Carlos", "Anika", "Tomas", "Lena", "Yusuf", "Cora", "Ravi", "Sofia",
        "Henrik", "Amara", "Kenji", "Nadia", "Luis", "Ingrid", "Zane", "Mira",
        "Owen", "Adeline", "Felix", "Vera", "Samir", "Hana",
    ])
    add("names_gorvian", [
        "Dvarra", "Korrath", "Sethi", "Voss", "Thenn", "Irrik", "Maldrek",
        "Zolvar", "Fennoth", "Sarrek", "Kellun", "Brassen", "Vekkor", "Torenn",
        "Aldris", "Norrek", "Galveth", "Ossren", "Drevak", "Pellarn",
        "Krissov", "Fennald", "Dorrath", "Ullvek", "Grennoth", "Salvik",
        "Tessorn", "Vorrath", "Bennok", "Ardrek",
    ])
    add("names_vellani", [
        "Velindra", "Tessari", "Kael", "Wynna", "Aelith", "Sorenn", "Mellira",
        "Faelinn", "Thyra", "Ioleth", "Caelen", "Nivari", "Ellisande", "Pyriel",
        "Dael", "Miravel", "Solinne", "Kaethis", "Veradine", "Lyraeth",
        "Tessiel", "Wynael", "Corael", "Isenne", "Aelora", "Quilleth",
        "Fennara", "Silvael", "Thalien", "Orianna",
    ])
    add("names_krellvani", [
        "Grenn", "Rask", "Drokk", "Charn", "Brekk", "Vurr", "Kex", "Thull",
        "Mordak", "Skarn", "Tork", "Grunn", "Harsk", "Zull", "Brenn", "Dakk",
        "Vorsk", "Gharn", "Rekk", "Sturm", "Bolg", "Krath", "Fenn", "Rull",
        "Skoll", "Denn", "Vrax", "Torr", "Grist", "Krull",
    ])

    # --- PERSONALITY ---
    add("personality_temperament", [
        "Meticulous", "Reckless", "Calm", "Ambitious", "Quiet",
        "Methodical", "Impulsive", "Stoic", "Cheerful", "Brooding",
        "Sharp-tongued", "Patient", "Intense", "Easygoing", "Cautious",
        "Stubborn", "Perceptive",
    ])
    add("personality_trait", [
        "dislikes chaos", "restless temperament", "fiercely loyal",
        "easily bored", "natural problem-solver", "keeps to themselves",
        "always volunteering", "uncomfortable with authority",
        "surprisingly gentle", "competitive streak", "dry humor",
        "thrives under pressure", "needs routine", "respects strength",
        "curious about everything", "distrustful of strangers",
        "quick to forgive",
    ])

    # ════════════════════════════════════════════════════════════════════════
    # FROM crew_event_templates.gd
    # ════════════════════════════════════════════════════════════════════════

    # --- SLICE_OF_LIFE (original 37) ---
    add("slice_of_life", [
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
        "{a} fell asleep in the common room. {b} draped a blanket over them without a word.",
        "Someone scratched a good-luck symbol into the bulkhead near the airlock. Spacer tradition.",
        "{a} is teaching {b} a few words in their native language. Progress is slow but earnest.",
        "{a} found an old data chip wedged behind a panel. The music on it is centuries old.",
        "The galley smells like burned toast. {a} claims it was intentional. Nobody believes them.",
        "{b} rigged a small reading light above their bunk. {a} wants one too.",
        "{a} and {b} are arm-wrestling in the mess. The crew has picked sides.",
        "You notice {a} has started keeping a plant in a ration container. It's barely surviving, but so are they.",
        "{a} spent the quiet shift polishing their boots. Old military habit, they say.",
        "The crew voted on a name for the ship's resident pest — a persistent vent beetle.",
        "{a} left a small thank-you note on {b}'s workstation. No explanation needed.",
        "{b} has been sketching crew portraits during downtime. They're getting better.",
    ])

    # --- 63 additional SLICE_OF_LIFE entries ---
    add("slice_of_life", [
        "{a} is methodically refolding the same cloth for the third time. Some habits survive everything.",
        "You find a handwritten list on the common room table. Destinations. Some crossed out. {a}'s handwriting.",
        "{a} and {b} are arm-wrestling in the cargo bay. The crew has quietly gathered to watch.",
        "{a} is standing at the viewport for a long time. Not watching anything in particular. Just standing.",
        "Someone has arranged the ration packs by color. Nobody admits to it, but everyone suspects {a}.",
        "{a} asked {b} to teach them a few words in their language. The pronunciation attempts are causing genuine delight.",
        "{b} is humming something unfamiliar while running diagnostics. {a} has started humming it too without seeming to notice.",
        "You catch {a} talking quietly to the ship. Not to anyone on it. To it.",
        "{a} and {b} spent an hour arguing about the best route they've ever flown. Neither is backing down.",
        "Someone left a small smooth stone on the navigation console. You don't ask where it came from.",
        "{a} is doing stretches in the corridor with the focused expression of someone completing a sacred duty.",
        "{b} has been stress-testing every seal and hatch on the ship for two days. {a} says it started after a nightmare.",
        "{a} and {b} traded bunk assignments without explanation. The rest of the crew pretends not to notice.",
        "You hear quiet laughter from the engine room. {a} and {b} don't explain when they emerge.",
        "{a} has memorized every planet on the route map and started naming the unmarked ones. The crew is using the names.",
        "{b} brought out a pack of cards with unfamiliar symbols. {a} is pretending to understand the rules.",
        "{a} spent their off-hours building something small from scrap metal. They haven't said what it is.",
        "You find {a} asleep in the cargo bay again. They claim it's cooler. Nobody argues.",
        "{a} and {b} have been exchanging notes on paper instead of comms. Old habit from a posting neither talks about.",
        "{a} fixed the flickering light in the corridor that has annoyed everyone for two weeks. Didn't mention it.",
        "There's a small drawing of the ship taped inside the storage locker. Detailed and careful. Nobody saw {a} do it.",
        "{b} challenged {a} to a staring contest during the quiet shift. The rest of the crew waited seventeen minutes for a winner.",
        "{a} keeps a list of every planet they've set foot on. You see them add to it after each landing.",
        "Someone reorganized the medical kit by expiry date. {a} accepts the credit with suspicious calm.",
        "{a} and {b} have established an unspoken agreement about who gets the last cup of good coffee. The system seems fair.",
        "{a} is teaching themselves a new skill from a data pad they found in the cargo three jobs ago.",
        "You overhear {a} giving {b} very detailed advice about something neither of them will confirm when asked.",
        "{a} sat with {b} through the whole quiet shift without saying a word. Sometimes that's enough.",
        "{b} has started keeping a log of notable sunrises seen through the viewport. It's already eleven pages.",
        "{a} spent the better part of an hour trying to recreate a meal from memory. The result was debatable. The effort was not.",
        "There's a running scoreboard scratched into the mess table. {a} is winning whatever the game is.",
        "{a} gave {b} a heads-up about a rough approach vector an hour before it happened. Nobody asked how they knew.",
        "{b} is whistling something that sounds like a lullaby. It's oddly settling on the long stretches.",
        "{a} stopped in the corridor to listen to a sound in the hull. Stood there for almost a minute. Then walked on.",
        "You find {a} and {b} on opposite ends of the common room, reading. They've been there for hours. It looks comfortable.",
        "{a} repaired {b}'s worn boot strap without mentioning it. {b} noticed. Neither said anything.",
        "{a} has developed a ritual before every jump. The crew works around it without being asked.",
        "{b} is carving something into a small piece of cargo crate wood. Not quite a figure. Not quite abstract.",
        "{a} and {b} disagreed loudly about something trivial, then immediately agreed on something important. The crew found this reassuring.",
        "Someone has written a small word in an unfamiliar script above the airlock. {a} says it means safe return.",
        "{a} spent their downtime reading the technical manual for a system they don't operate. Old paranoia, they say.",
        "{b} found a frequency on the long-range scanner that sounds almost like music. {a} is convinced it's just noise. They keep listening anyway.",
        "{a} showed {b} a scar with a story attached. {b} showed one back. The exchange was brief and seemed complete.",
        "The crew has started leaving notes in the galley about who owes what for the coffee supply. {a} is managing the ledger with more seriousness than seems warranted.",
        "{a} and {b} worked through an entire shift back to back without coordinating it. It simply happened.",
        "{b} has started saying a quiet word before eating. {a} asked about it once, then never again, and started pausing too.",
        "{a} spent an hour mapping the corridor with their eyes closed. Training, they said. Old training.",
        "You notice {a} and {b} have synchronized their sleep schedules without discussing it.",
        "{a} left a book on {b}'s workstation. No note. {b} started reading it.",
        "Someone has been leaving small improvements throughout the ship. A padded edge here, a non-slip strip there. The crew suspects {a}.",
        "{a} is counting something quietly under their breath while staring at the ceiling. They stop when they notice you. That's fine, they say.",
        "{b} asked {a} something personal and {a} answered honestly. You could tell by how still it went.",
        "{a} found a way to squeeze two extra hours of range out of the fuel calculations. Mentioned it like it was nothing.",
        "The mess roster has been quietly reorganized so nobody has to cook on their own birthday. Nobody discussed this. It simply appeared.",
        "{a} is practicing signatures. Not their own. Someone who isn't aboard anymore.",
        "{b} taught {a} how to tie a knot from their home region. It took an embarrassing number of attempts.",
        "{a} spent their whole free shift listening to the same recording. Didn't react when you walked past.",
        "There's a constellation chart pinned up near the sleeping quarters. {b} has been adding labels. {a} added one that isn't a real star name. Nobody erased it.",
        "{a} stayed up to finish a repair that wasn't urgent. Said they couldn't sleep. The ship runs quieter for it.",
        "{b} and {a} are playing a game with rules only they know. The pieces are coins and ration wrappers and it looks completely serious.",
        "{a} stood at the back of the ship for a long moment before departure. You didn't ask. They came back looking settled.",
        "{b} is keeping a count of good days and bad days on the inside of their locker door. Today's mark is in the good column.",
        "{a} and {b} watched the same empty patch of space for almost an hour. Later, neither could explain what had held their attention.",
    ])

    # --- SOCIAL ---
    add("social_positive", [
        "{a} and {b} spent the evening playing cards.",
        "{a} and {b} shared a meal during the quiet shift.",
        "{a} and {b} were talking shop — seems they have more in common than they thought.",
        "{a} helped {b} with a repair. Good teamwork.",
        "{a} and {b} shared a laugh over something on the comms channel.",
    ])
    add("social_negative", [
        "{a} and {b} got into a disagreement about engine maintenance.",
        "{a} and {b} had words over shift schedules.",
        "There was a tense moment between {a} and {b} in the corridor.",
        "{a} made a comment that didn't sit well with {b}. Awkward silence.",
        "{a} and {b} are giving each other the cold shoulder.",
    ])

    # --- MORALE ---
    add("morale_high", [
        "{name} is in good spirits lately.",
        "{name} has been whistling between shifts. Morale seems high.",
        "{name} seems energized and confident. Good to see.",
    ])
    add("morale_low", [
        "{name} has been keeping to themselves. Something's bothering them.",
        "{name} is quieter than usual. The strain is showing.",
        "{name} barely touched their food today.",
    ])

    # --- FATIGUE ---
    add("fatigue_high", [
        "{name} looks exhausted. Dark circles under their eyes.",
        "{name} nearly fell asleep at their station.",
        "{name} is running on fumes. They need rest.",
    ])
    add("fatigue_recovered", [
        "{name} looks well-rested and sharp after the shore leave.",
        "{name} is back to full form after some proper rest.",
    ])

    # --- PURPOSE ---
    add("purpose_bored", [
        "{name} has been recalibrating the same scanner for a week. They look bored.",
        "{name}'s skills are going unused. You can see the restlessness building.",
        "{name} is sharpening tools that don't need sharpening. They need real work.",
    ])

    # --- FOOD ---
    add("food_low", [
        "Rations are getting thin. The crew eyes the food storage nervously.",
        "The crew is stretching meals. Nobody says anything, but everyone notices.",
    ])

    # --- COMFORT FOOD ---
    add("comfort_food_human", [
        "{name} smiles at the familiar taste of Commonwealth rations. Feels like home.",
        "{name} savors the proper Human food. Nothing beats comfort cooking.",
    ])
    add("comfort_food_gorvian", [
        "{name} grins at the sight of proper Gorvian provisions. Spiced and precise.",
        "{name}'s mood brightens with authentic Hexarchy cuisine.",
    ])
    add("comfort_food_vellani", [
        "{name}'s eyes light up. Real Vellani spiced provisions at last.",
        "{name} hums contentedly over a bowl of proper FPU food.",
    ])
    add("comfort_food_krellvani", [
        "{name} tears into the Outer Reach rations with obvious satisfaction.",
        "{name} grins. Nothing like proper Krellvani grub to lift the spirits.",
    ])

    # --- NUDGE ---
    add("nudge_morale", [
        "The mood on the ship is grim. The crew could use some good news — or at least a break.",
        "Ship-wide morale is low. Tension hangs in the air like engine exhaust.",
    ])
    add("nudge_relationship", [
        "The tension between {a} and {b} is becoming hard to ignore. The rest of the crew is walking on eggshells.",
    ])
    add("nudge_food", [
        "Food supplies are running low. You should resupply soon.",
        "The galley is nearly bare. The crew is counting meals.",
    ])
    add("nudge_fatigue", [
        "The crew is running ragged. They need downtime.",
        "Exhaustion is spreading through the crew. Performance will suffer.",
    ])
    add("nudge_pay", [
        "The crew has been grumbling about the pay split. It might be worth reconsidering.",
    ])

    # --- TRAVEL CREW ---
    add("travel_crew_good", [
        "The crew is resting between shifts.",
        "Quiet conversation drifts from the crew quarters.",
        "The crew seems settled. Routine has a comfort of its own.",
    ])
    add("travel_crew_bad", [
        "Tension on the bridge. The crew is quiet.",
        "You can feel the strain. Nobody's smiling.",
        "The silence on the ship feels heavy.",
    ])

    # --- SPECIES FRICTION ---
    add("species_friction_gorvian_krellvani", [
        "{a} and {b} argue over trade routes. Old rivalries die hard between Gorvian and Krellvani.",
        "{a} mutters something about Krellvani stubbornness. {b} pretends not to hear.",
        "A cold exchange between {a} and {b}. The Gorvian-Krellvani divide runs deep.",
    ])
    add("species_friction_gorvian_vellani", [
        "{a} and {b} disagree about how to organize the supply locker. Hierarchy versus communalism.",
        "{a} finds {b}'s approach inefficient. The feeling seems mutual.",
    ])

    # --- SPECIES BONDING ---
    add("species_bonding_gorvian_krellvani", [
        "{a} and {b} found common ground over engine diagnostics. Surprising, given their species' history.",
        "Against all odds, {a} and {b} are actually getting along. Something shifted between them.",
    ])
    add("species_bonding_krellvani_vellani", [
        "{a} and {b} share stories of their respective frontiers. Independence resonates with both.",
        "{a} and {b} discovered a mutual love of open spaces. Their bond is growing.",
    ])
    add("species_bonding_gorvian_human", [
        "{a} and {b} share a professional respect. Gorvians appreciate Commonwealth structure.",
        "{a} is impressed by {b}'s work ethic. The institutional respect runs both ways.",
    ])
    add("species_bonding_human_vellani", [
        "{a} and {b} swap exploration stories over evening tea. An easy friendship.",
        "{a} and {b} bond over a shared curiosity about what's beyond the next jump.",
    ])

    # --- MEMORY DIALOGUE ---
    add("memory_dialogue_hardened", [
        "{name} glances at the old scar. Their jaw tightens, but their hands are steady.",
        "{name}'s eyes go distant for a moment. They've been here before. They know the cost.",
        "{name} doesn't flinch. Not anymore. The memory has become armor.",
    ])
    add("memory_dialogue_shaken", [
        "{name} freezes for a heartbeat. The memory surfaces uninvited. They push through.",
        "{name}'s hands tremble slightly. The last time something like this happened...",
        "{name} takes a sharp breath. Old fears don't die — they just learn to be quiet.",
    ])
    add("memory_dialogue_proud", [
        "{name} stands a little taller. They've proven themselves before, and they'll do it again.",
        "A flicker of confidence crosses {name}'s face. They remember what they're capable of.",
    ])
    add("memory_dialogue_bitter", [
        "{name}'s expression hardens. Some wounds don't heal with time.",
        "{name} mutters something under their breath. The resentment runs deep.",
    ])
    add("memory_dialogue_grateful", [
        "{name} looks around with quiet appreciation. They remember what it means to belong.",
        "Something softens in {name}'s expression. They haven't forgotten the kindness.",
    ])
    add("memory_dialogue_cautious", [
        "{name} checks the instruments twice. After what happened, they take nothing for granted.",
        "{name} scans the horizon carefully. Caution born from experience.",
    ])
    add("memory_dialogue_reckless", [
        "{name} grins at the danger. After everything, fear feels like a suggestion.",
        "{name} pushes forward without hesitation. Caution was never their strong suit.",
    ])
    add("memory_dialogue_inspired", [
        "{name}'s eyes light up. They've seen what's possible, and it drives them forward.",
        "There's a spark in {name}. The memory of triumph is fuel for the next challenge.",
    ])

    # --- ROMANCE ---
    add("romance_formation", [
        "You've noticed {a} and {b} spending their off-hours together. Not just as crewmates. Something's shifted between them.",
        "It's the worst-kept secret on the ship. {a} and {b} are together. The crew pretends not to notice, but there are a lot of knowing smiles on the bridge.",
        "You catch {a} and {b} in the corridor, standing closer than duty requires. They step apart when they see you, but the look between them says everything.",
        "{a} brought {b} something from the last port. Nobody buys gifts for 'just a friend.' The crew exchanges glances.",
        "The way {a} looks at {b} during briefings hasn't gone unnoticed. Something quiet and real has grown between them.",
    ])
    add("romance_positive", [
        "{a} brought {b} breakfast from the galley. Small gestures, noticed by everyone.",
        "You catch {a} and {b} sharing a quiet moment on the observation deck between jumps.",
        "{a} patched up {b}'s console without being asked. {b} caught their eye and smiled.",
        "The crew has started referring to {a} and {b} as a unit. They don't seem to mind.",
        "You notice {a} saved the last cup of good coffee for {b}. Partnership in small things.",
    ])
    add("romance_stressed", [
        "{a} and {b} are barely speaking. The warmth between them has gone cold.",
        "You overhear {a} snap at {b} over something trivial. {b} walks away without responding.",
        "{a} and {b} sit on opposite sides of the mess. The distance between them is louder than any argument.",
    ])
    add("romance_breakup", [
        "It's over between {a} and {b}. The ship feels different. Conversations stop when one of them enters a room. The crew is navigating around them like debris in a shipping lane.",
    ])
    add("romance_injury_concern", [
        "{a} hasn't left {b}'s side since the injury. It's affecting their focus.",
        "{a} keeps checking on {b} between duties. The worry is written all over their face.",
    ])

    # --- LOYALTY VALUE REACTIONS ---
    add("loyalty_reaction_cautious_positive", [
        "{name} nods approvingly at the cautious approach. They respect a captain who thinks before acting.",
    ])
    add("loyalty_reaction_cautious_negative", [
        "{name}'s expression tightens. They would have preferred a safer course.",
    ])
    add("loyalty_reaction_bold_positive", [
        "{name} grins as you choose the bold path. They respect a captain with nerve.",
    ])
    add("loyalty_reaction_bold_negative", [
        "{name} seems frustrated at the cautious choice. They wanted action.",
    ])
    add("loyalty_reaction_compassionate_positive", [
        "{name}'s face softens. They're glad you chose the compassionate path.",
    ])
    add("loyalty_reaction_compassionate_negative", [
        "{name}'s expression tightens as you ignore those in need. They don't say anything, but you notice.",
    ])
    add("loyalty_reaction_pragmatic_positive", [
        "{name} appreciates the practical decision. Efficiency matters to them.",
    ])
    add("loyalty_reaction_pragmatic_negative", [
        "{name} winces at the unnecessary expense. They value practicality.",
    ])
    add("loyalty_reaction_exploratory_positive", [
        "{name}'s eyes light up at the chance to explore. This is why they're out here.",
    ])
    add("loyalty_reaction_exploratory_negative", [
        "{name} looks disappointed at the missed opportunity to discover something new.",
    ])

    # --- LOYALTY STAGES ---
    add("loyalty_withdrawal", [
        "{name} ate alone again today. They've been pulling away from the group.",
        "{name} has been spending more time in their quarters. The distance is noticeable.",
    ])
    add("loyalty_vocal", [
        "{name} has been openly critical of your decisions. The rest of the crew has noticed.",
        "{name} challenged your judgment in front of the crew. The tension was palpable.",
    ])
    add("loyalty_departure", [
        "{name} is packed and waiting at the airlock when you dock. 'No hard feelings, Captain. I just can't anymore.' They walk down the ramp without looking back.",
    ])

    # --- GRIEF ---
    add("grief_event", [
        "{name} was staring at {deceased}'s empty station again.",
        "{name} hasn't said more than three words today.",
        "{name} flinched when someone accidentally used {deceased}'s call sign.",
        "{name} sits alone in the mess during meals. Nobody pushes them.",
        "{name} was found holding {deceased}'s old data pad. Just holding it.",
        "You caught {name} standing outside {deceased}'s old quarters again.",
    ])
    add("grief_resolved",
        "{name} is different now. The grief isn't gone — it never will be. But there's steel underneath it. They've decided that {deceased}'s death will mean something. And they'll make sure of it.")
    add("grief_broken",
        "{name} packs their bag slowly. They leave {deceased}'s favorite belonging on the bridge console before they go. They don't say goodbye to anyone.")
    add("grief_broken_request",
        "{name} comes to you quietly. 'I can't be on this ship anymore, Captain. Everything here reminds me of them. I need to go somewhere they never were.'")

    # --- MOURNING ---
    add("mourning_crew", [
        "The ship is quieter since {name} died. Nobody says much.",
        "Someone left {name}'s favorite mug in its usual spot. Nobody moves it.",
        "The crew moves through their duties mechanically. The loss hangs over everything.",
    ])

    conn.commit()

    # ── Summary ─────────────────────────────────────────────────────────────
    total = 0
    print("\n=== Flavor Text DB Build Summary ===\n")
    for key in sorted(counts.keys()):
        print(f"  {key}: {counts[key]}")
        total += counts[key]
    print(f"\n  TOTAL: {total} rows")
    print(f"  Database: {DB_PATH}")

    # Verify with a query
    row_count = conn.execute("SELECT COUNT(*) FROM flavor_text").fetchone()[0]
    print(f"  Verified row count: {row_count}")
    assert row_count == total, f"Mismatch! Expected {total}, got {row_count}"

    conn.close()
    print("\nDone.")


if __name__ == "__main__":
    build()
