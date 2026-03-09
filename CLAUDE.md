# Captain's Ledger — Crew System Prototype

## Project Overview

A text-adventure prototype for testing the Gravity Nexus crew system in isolation. The player progresses through three ship classes (solo → 3 crew → 12 crew), running missions, trading goods across a 12-planet node graph, and managing an emergent crew that develops relationships, memories, and history through play.

**Engine:** Godot 4.5+ with GDScript
**Database:** SQLite via godot-sqlite (GDSQLite) plugin
**Target:** Desktop, 2–3 hour playthrough
**Design docs:** See `/docs/crew-system-gdd.docx` and `/docs/prototype-gdd.docx`

This is a development prototype, not a shipping product. Prioritize testability and iteration speed over polish. Debug tools are first-class features.

## Architecture

### Folder Structure

```
project/
├── addons/godot-sqlite/          # SQLite plugin
├── database/
│   └── captains_ledger.db        # Runtime database (generated, gitignored)
├── docs/                         # GDD documents for reference
├── resources/
│   ├── themes/                   # UI themes
│   └── data/                     # Static data (name lists, text templates)
├── scenes/
│   ├── ui/                       # Main menu, new game, win screen
│   ├── planet/                   # Planet view, shop, recruitment, shipyard, mission board
│   ├── travel/                   # Node map, travel view, encounter/challenge view
│   └── ship/                     # Ship view, crew profiles
├── scripts/
│   ├── core/                     # Autoloads: GameManager, DatabaseManager, EventBus
│   ├── systems/                  # Game systems: CrewSimulation, MissionGenerator, TradeSystem, TravelSystem, ChallengeResolver
│   ├── data/                     # Data classes: CrewMember, Planet, Ship, Mission, etc.
│   └── ui/                       # UI controller scripts
└── CLAUDE.md
```

### Autoload Singletons

Three autoloads, registered in Project Settings:

- **GameManager** (`scripts/core/game_manager.gd`) — Holds current game state in memory (captain, ship, current planet, active missions, day counter). Handles new game initialization, save/load orchestration, and game phase transitions. Does NOT query the database directly — calls DatabaseManager.
- **DatabaseManager** (`scripts/core/database_manager.gd`) — Wraps all SQLite operations. Every database read/write goes through this singleton. Provides a clean GDScript API (`get_planet(id)`, `get_crew_roster()`, `save_game()`, etc.). Other scripts never construct SQL directly.
- **EventBus** (`scripts/core/event_bus.gd`) — Signal-based event system for decoupled communication. Define all signals here as typed signals. Systems emit events; UI and other systems connect to them. Keeps scene tree coupling minimal.

### Data Flow

```
UI scenes → GameManager (state) → DatabaseManager (persistence) → SQLite
                ↕
         EventBus (signals)
                ↕
      Systems (CrewSimulation, MissionGenerator, etc.)
```

State lives in memory during play via GameManager. SQLite is the persistence layer — save on planet departure, mission completion, and manual save. Load reconstructs GameManager state from database on game start.

### Scene Management

- Scenes transition through GameManager calls, never directly.
- Use `call_deferred("change_scene_to_file", path)` for scene switches.
- The Planet View is the primary hub — most systems present their UI as sub-panels within Planet View, not as separate scenes.
- Ship View is accessible from any screen via a persistent UI element (tab or button).

## Coding Standards

### GDScript Conventions

- **Type hints everywhere:** `var morale: float = 50.0`, `func get_crew(id: int) -> CrewMember:`
- **@onready for node refs:** `@onready var message_log: RichTextLabel = $MessageLog`
- **@export for tunable values:** `@export var morale_decay_rate: float = 0.5`
- **Section comments for organization:**

```gdscript
# === INITIALIZATION ===

# === CREW SIMULATION ===

# === EVENT GENERATION ===
```

- **Scripts under 500 lines.** If a script grows beyond this, split into focused components.
- **Prefer composition over inheritance.** Use child nodes and signals over deep class hierarchies.
- **Enums for fixed sets** — roles, species, mission types, event types. Never compare raw strings.

```gdscript
enum Role { GUNNER, ENGINEER, NAVIGATOR, MEDIC, COMMS_OFFICER, SCIENCE_OFFICER, SECURITY_CHIEF, GENERALIST }
enum Species { HUMAN, GORVIAN, VELLANI, KRELLVANI }
enum MissionType { CARGO_DELIVERY, PASSENGER_TRANSPORT, TRADE_RUN, SURVEY, RETRIEVAL, ESCORT, PATROL, DISTRESS_SIGNAL }
```

- **Signal naming:** past tense for events that happened (`crew_member_recruited`, `mission_completed`, `morale_changed`), present tense for requests (`request_save`, `request_travel`).
- **No magic numbers.** Use constants or @export vars.

### Database Conventions

- All table and column names use `snake_case`.
- Every table has `id INTEGER PRIMARY KEY`, `created_at TEXT DEFAULT CURRENT_TIMESTAMP`, `updated_at TEXT`.
- JSON columns (e.g., `complications`, `services`) store structured data that doesn't need individual querying.
- Use parameterized queries exclusively — never string-interpolate values into SQL.
- DatabaseManager methods return typed dictionaries or arrays of dictionaries, never raw query results.

### UI Conventions

- Dark sci-fi theme: dark background (#1A1A2E), light text (#F7FAFC), blue accent (#4A90D9), muted text (#718096).
- Use Godot's built-in Control nodes with theme overrides. No custom rendering for UI.
- Planet shader square is a `TextureRect` or `ColorRect` with a `ShaderMaterial` — parameters set per-planet.
- Message log is a `RichTextLabel` with `bbcode_enabled = true` and `scroll_following = true`.
- Color code trade prices: green (#27AE60) = cheap, red (#C0392B) = expensive, white = average.
- Status indicators: green (#27AE60) = good, yellow (#E67E22) = attention needed, red (#C0392B) = crisis.

## Game Systems Reference

### The Reactive Principle

The crew system is **reactive, not interactive.** The player does not micromanage crew. They recruit, set a pay split, buy food, and choose missions. Everything else — morale, relationships, events, growth — is the system responding to player actions. Design every system with this in mind: if it requires the player to open a menu and make a crew-specific decision, it's probably wrong. The exceptions are rare decision events (~10% of crew events) that feel significant precisely because they're uncommon.

### Four Species

| Species | Faction | Stat Bias | Environmental Trait | Vulnerability |
|---------|---------|-----------|-------------------|---------------|
| Human | Commonwealth | Balanced | Adaptable (none) | None |
| Gorvian | Hexarchy | Cognition, Stamina | Fuel efficiency bonus | Cold sensitivity |
| Vellani | FPU | Social, Reflexes | 0.7x food consumption | Fragile bones (longer injury recovery) |
| Krellvani | Outer Reach | Stamina, Reflexes | 1.3x food, 1.5 crew slots on small ships | Claustrophobia (morale penalty on small ships) |

### Eight Roles

Gunner, Engineer, Navigator, Medic, Comms Officer, Science Officer, Security Chief, Generalist. Crew arrive pre-roled. No player assignment.

### Five Stats

Stamina, Cognition, Reflexes, Social, Resourcefulness. Range 0–100. Captain starts all at 45, gains +2/level.

### Performance Formula

```
effective_stat = base_stat * morale_modifier * fatigue_modifier
morale_modifier: 0.5 (crisis) to 1.2 (high morale)
fatigue_modifier: 0.4 (exhausted) to 1.0 (rested)
```

### Challenge Resolution

```
roll = effective_stat + randi_range(0, effective_stat)
if roll > 2 * difficulty: critical_success
elif roll > difficulty: success
elif roll > 0.75 * difficulty: marginal_success
elif roll > 0.5 * difficulty: failure
else: critical_failure
```

### Three Ships

| Class | Name | Crew | Cargo | Fuel | Hull | Unlock |
|-------|------|------|-------|------|------|--------|
| Starter | Skiff | 0 | 10 | 30 | 50 | Level 1 (start) |
| Medium | Corvette | 3 | 25 | 60 | 120 | Level 4 |
| Large | Frigate | 12 | 50 | 100 | 250 | Level 7 |

### 12 Planets

**Commonwealth:** Haven (hub, all services, starter), Meridian (trade hub, crossroads), Fallow (agricultural, cheapest food)
**Hexarchy:** Korrath Prime (capital, best repairs), Dvarn (mining, cheapest ore, cold), Sethi Orbital (research outpost)
**FPU:** Lirien (homeworld, best recruitment), Tessara (cultural, cheap luxury), Windhollow (frontier, exploration)
**Outer Reach:** Ironmaw (stronghold, best weapons), Char (contested, most dangerous, highest pay), Nexus Station (black market, unpredictable prices)

### Cultural Friction Matrix

```
Gorvian ↔ Krellvani: -20 (trade rivalry, hierarchy vs independence)
Gorvian ↔ Vellani:   -10 (hierarchy vs communalism)
Gorvian ↔ Human:     +10 (institutional respect)
Vellani ↔ Krellvani: +10 (shared independence)
Vellani ↔ Human:     +10 (exploratory kinship)
Krellvani ↔ Human:    +5 (mild respect)
```

### Crew Event Distribution

- 80% background flavor (no player input, message log only)
- 10% mild nudges (morale warnings via dialogue cues)
- 10% decision points (modal popup, 2–3 choices, real consequences)

## Development Phases

The prototype is built in 6 sequential phases. Each produces a playable build. Never skip ahead — each phase depends on the last being complete and tested.

1. **Foundation** — Project setup, SQLite, main menu, planet view, node map, travel, shop, basic missions, captain leveling, shipyard
2. **Tier 0–1** — Crew data model, recruitment, ship view, crew simulation (morale/needs/fatigue), relationships, crew events, crew in combat
3. **Tier 2** — Faction access, species environmental traits, cultural friction/synergy, species food
4. **Tier 3** — Skill progression, event memory, trait acquisition, ship memories
5. **Tier 4** — Romance, loyalty, injury/disease depth, crew-generated missions, legacy system
6. **Polish** — Economy balance, win state, debug tools, QoL, narrative text variety pass

Full checklists and asset lists for each phase are in the Prototype GDD.

## Common Patterns

### Adding a New System

1. Create a system script in `scripts/systems/` (e.g., `crew_simulation.gd`)
2. Define relevant signals in EventBus
3. Add any new database tables via DatabaseManager
4. System reads state from GameManager, writes through DatabaseManager, communicates via EventBus
5. UI scenes connect to EventBus signals to update display

### Adding a Crew Event Type

1. Define the event condition check in CrewSimulation
2. Add text templates to the text template resource
3. If it's a decision event: create the choice data structure with options and consequences
4. Fire through EventBus — UI picks it up and displays appropriately

### Database Queries

Always go through DatabaseManager:

```gdscript
# Good
var crew = DatabaseManager.get_crew_for_ship(ship_id)

# Bad — never do this in game scripts
var result = db.query("SELECT * FROM crew_members WHERE ship_id = ?", [ship_id])
```

### Text Templates

Atmospheric text uses a simple template system with placeholders:

```
"The dockmaster at {planet_name} sizes up your {ship_class}. {faction_reaction}"
"{crew_name} stretches their legs on the docks. {mood_text}"
```

Store templates in resource files or a SQLite table. The text system fills placeholders from current game state.

## Debugging

The debug panel (accessible from New Game screen and optionally in-game) supports:

- Start with any ship class
- Set starting credits and level
- Pre-built crew compositions
- Enable/disable individual crew system tiers (for isolated testing)
- Time acceleration (speed up simulation ticks)
- Force-fire specific event types
- Export event log to file for analysis

These are development tools, not player features. Keep them functional but don't spend time polishing them.

## Known Constraints

- SQLite plugin (GDSQLite) must be in `addons/godot-sqlite/`. Verify the plugin works on your Godot version before starting.
- No multiplayer, no networking, no cloud saves. Single local save file.
- No 3D rendering. This is a 2D UI-driven game. The only visual element beyond standard UI controls is the planet shader square.
- Text templates will need significant expansion in Phase 6 to avoid noticeable repetition across a full playthrough. During earlier phases, repetition is acceptable.
- Economy values (mission rewards, ship prices, trade margins, crew costs) are placeholders until Phase 6 balance pass. Use the suggested values from the GDD as starting points and expect to tune them.
