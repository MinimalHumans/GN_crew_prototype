  
**GRAVITY NEXUS**

**CREW SYSTEM**

Game Design Document

Minimal Humans

Version 1.0 — March 2026

*Inspirations: Star Trek Strange New Worlds • Farscape • Firefly • Rimworld*

# **Table of Contents**

# **Design Philosophy**

## **Core Vision**

The crew system transforms a solo piloting experience into a captaincy simulation. The player’s ship becomes a living vessel staffed by characters who bring capability, personality, and vulnerability. Crew are not passive stat bonuses; they are the primary source of emergent narrative in Gravity Nexus.

The player expresses themselves through recruitment, risk tolerance, and the missions they choose. The crew responds to these choices and evolves accordingly. No two playthroughs produce the same crew, even with identical recruitment decisions.

## **The Reactive Principle**

The crew system is reactive, not interactive. The player does not micromanage crew assignments, morale sliders, or relationship graphs. Instead, the player plays the game — takes missions, fights battles, explores, trades — and the crew system runs underneath, shaping crew behavior and performance in response to the player’s actions.

The player is a captain, not an HR department. Direct crew management is limited to three actions: setting the pay split, buying food when docked, and choosing who to recruit. Everything else is the system telling the player a story about how their crew is doing.

## **Design Pillars**

**Crew composition is strategy.** Who you recruit defines your ship’s capabilities, diplomatic access, and social dynamics. The recruitment decision is the primary strategic lever.

**No micromanagement.** The player cannot and should not optimize individual crew behavior. Crew are autonomous adults who respond to circumstances the player creates.

**Conflict builds character.** Players should not be motivated to avoid conflict to maintain a pristine crew. Hardship produces growth, trauma produces resilience, and every crew becomes uniquely shaped by its journey.

**Weird crews are valid.** No composition restrictions. A ship full of medics, a crew of all one species, a skeleton crew on a capital ship — all are permitted. The game communicates consequences through natural feedback, never through gates.

**Emergent narrative.** The crew system generates stories through interlocking mechanical systems, not through scripted events. The goal is Rimworld’s story generation in a tighter, more personal scope.

## **Tiered Implementation**

The system is designed in five tiers (0–4), each building on the last. Each tier is independently playable — Tier 0 alone should function as a complete, lean crew system. Higher tiers add depth and narrative richness without restructuring lower tiers. This supports incremental development and playtesting.

# **Tier 0 — Mechanical Skeleton**

**TIER 0  Ship Classes, Roles & Stats**

The minimum viable crew system. Functional bodies in seats that unlock ship capabilities. No personality, no drama — just the mechanical foundation that makes crew matter to gameplay.

## **Ship Classes**

Three ship classes define crew capacity. Crew slots are a hard cap per hull; upgrading your ship is the path to a larger crew.

| Class | Crew Capacity | Character | Strategic Identity |
| :---- | :---- | :---- | :---- |
| Small | 1–3 | Nimble, personal, Firefly-class | One specialist covers your biggest weakness. At 3, a skeleton crew enables basic multitasking. |
| Medium | 4–7 | Versatile, real tradeoffs emerge | Crew composition becomes a genuine strategic puzzle. Can’t fill every role, so tradeoffs matter. |
| Large | 8–12 | Full operational capability | Double up on critical roles. Running without full crew is possible but noticeably painful. |

*Companion ships are separate from this system. They fly alongside you with their own autonomous crews that the player never directly manages. Total group crew can far exceed 12 — you just never manage more than your own ship’s roster.*

## **Introduction Narrative**

The crew system is introduced through the ship seller when the player purchases a crew-capable vessel. The seller explains: “You can run this alone, Captain, but you’ll be choosing between shooting and steering. Get yourself a crew and a lot more becomes possible.” This frames crew as capability expansion, not obligation.

## **Core Roles**

Eight roles define what a crew member does. Each crew member arrives with their role as part of their identity — the player does not assign roles. This means recruitment is about choosing the right people, not solving an assignment puzzle.

| Role | Function | Primary Stat | Secondary Stats |
| :---- | :---- | :---- | :---- |
| Gunner | Operates weapon systems. Multiple gunners enable multiple simultaneous weapons. | Reflexes | Cognition |
| Engineer | Ship repair, fuel efficiency, system tuning. Universally useful. | Cognition | Stamina, Resourcefulness |
| Navigator | Jump accuracy, route optimization, scan range, hazard detection. | Cognition | Reflexes |
| Medic | Injury treatment, disease management, recovery speed. | Resourcefulness | Social, Cognition |
| Comms Officer | Hailing, diplomacy modifiers, trade negotiation, intel gathering. | Social | Cognition |
| Science Officer | Scanning, anomaly analysis, data collection, research. | Cognition | Resourcefulness |
| Security Chief | Boarding defense/offense, internal threat response. | Stamina | Reflexes |
| Generalist | Covers any gap at 60–70% specialist effectiveness. Never the best, never useless. | Resourcefulness | Varies by task |

A small ship with 3 crew covers three of eight roles, giving the ship a clear identity: “combat runner” (Gunner, Engineer, Security) versus “explorer” (Navigator, Science Officer, Medic). This identity emerges from recruitment, not configuration.

## **The Weird Crew Rule**

No composition restrictions exist. The player may recruit any crew member regardless of current roster. The game never gates recruitment by saying “you need an engineer.” Instead, natural feedback loops communicate consequences: a ship with no engineer degrades over time, a ship with no medic has longer injury recovery, a ship with no navigator takes worse routes. The player learns through play.

A ship full of medics performs poorly in most areas but excels at medical situations. A ship stacked with gunners is a glass cannon with no one to patch the hull. These compositions should be viable but lopsided — never hard-blocked.

## **Crew Stats**

Five core attributes define each crew member’s capabilities. Since crew arrive pre-roled, stats represent how good they are at their role rather than which role they should fill.

| Stat | Description | Primary For | Gameplay Impact |
| :---- | :---- | :---- | :---- |
| Stamina | Physical endurance, injury resistance, sustained performance under pressure. | Security Chief | Determines how long crew can operate in crisis, injury resistance. |
| Cognition | Problem-solving, learning speed, technical skill ceiling. | Engineer, Navigator, Science Officer | Affects skill quality, adaptation speed, technical task ceiling. |
| Reflexes | Reaction time, coordination, performance under sudden stress. | Gunner | Combat responsiveness, split-second decision quality. |
| Social | Communication, persuasion, empathy, reading people. | Comms Officer | Diplomacy effectiveness, crew relationship influence. |
| Resourcefulness | Improvisation, efficiency, making do with less. | Generalist, Cargo tasks, Medic | Gap-filling effectiveness, creative problem solving. |

A gunner with high Reflexes and low Social is a crackshot who irritates everyone. A gunner with moderate Reflexes but high Social is decent in a fight but great for crew cohesion. Both are gunners, but they’re different people with different tradeoffs.

## **Capability Model**

The fundamental rule: an empty role slot means the pilot handles that function manually, and the pilot can only do one thing at a time. Filling a role with any crew member enables autonomous operation of that system. The crew member’s stats determine how well it operates, but the key unlock is simply having someone in the seat.

Multiple crew in the same role provide redundancy and combined output: two gunners operate two weapon systems, two engineers repair faster. Generalists contribute partial coverage to the biggest current gap, with the game auto-assigning them.

## **Pinch-Hitting**

When a role is uncovered during a crisis, crew members can temporarily fill in. Effectiveness is based on their stats but modulated heavily downward (roughly 30–40% of a specialist). The generalist’s defining trait is a much smaller penalty when covering other roles. All pinch-hitting is automatic — no player assignment required.

# **Tier 1 — Living Crew**

**TIER 1  Morale, Needs & Relationships**

Crew stop being stat blocks and start being people. This tier introduces morale, needs, and basic interpersonal relationships — the minimum required for emergent crew stories.

## **Morale**

Every crew member has a personal morale value on a 0–100 scale. Ship-wide morale is the aggregate, weighted so that a single crew member in crisis drags the group down disproportionately — bad moods are contagious.

| Morale Range | Effect on Performance | Behavioral Impact |
| :---- | :---- | :---- |
| 80–100 (High) | Up to 1.2x performance multiplier | Positive social events, willingness to pinch-hit, hardship tolerance. |
| 40–79 (Neutral) | 1.0x baseline performance | Normal operation. No special effects. |
| 20–39 (Low) | 0.7x performance multiplier | Friction with others, reduced initiative, grumbling. |
| 0–19 (Crisis) | 0.5x performance multiplier | Refuses orders, picks fights, demands to leave at next port. |

Morale is not directly manageable. There is no “boost morale” button. It is an emergent output of needs fulfillment, relationships, and recent events. The player manages morale by managing circumstances.

## **Needs System**

Four needs tick over time. Unmet needs drain morale, met needs sustain it, and well-met needs provide a small boost. All are designed as set-and-forget systems that only demand attention when something goes wrong.

### **Pay — The Split Ratio**

A single ship-wide slider sets the captain-to-crew income split. This is not individual salaries — it’s one ratio applied to all earnings.

| Split | Captain’s Take | Crew Effect |
| :---- | :---- | :---- |
| 70/30 (Captain-heavy) | High personal income | Crew knows they’re underpaid. Morale penalty, harder to recruit top talent. |
| 50/50 (Equitable) | Moderate income | Fair deal. Attracts and retains good crew. Baseline expectation. |
| 40/60 (Crew-heavy) | Low personal income | Generous captain. Strong recruitment draw, high morale bonus, but player is always short on credits. |

*Set once, forget unless finances change. The simplest possible economic relationship between captain and crew.*

### **Food**

Buy food when docked. It depletes over time. Better stations offer better quality. Running out is a crisis; basic rations are neutral; good food is a cheap morale booster. No meal planning, no individual preferences at this tier. Crew are adults who feed themselves — you just stock the pantry.

### **Rest**

Entirely automatic. Crew accumulate fatigue during active operations and recover during downtime. Long quiet voyages are restful; back-to-back combat is exhausting. The player never tells anyone to sleep — they just notice sluggish performance after a hard stretch and choose easier missions to let the crew recover.

### **Safety**

A background assessment of “how likely am I to die on this ship.” Purely emergent, never directly visible as a number. Frequent dangerous encounters without adequate crew coverage erode it; successful battles and competent captaincy build it. The player manages safety by being a good captain.

### **Purpose**

Crew want to feel useful in their role. A gunner on a combat-heavy ship is fulfilled; a science officer who hasn’t scanned anything in twenty jumps is bored. Fully automatic — the system tracks role utilization. This naturally discourages hoarding specialists you don’t need and rewards matching crew to playstyle.

## **Interpersonal Relationships**

Each crew pair has a relationship score from −100 to \+100, starting near zero. Positive relationships mean better cooperation and positive crew events. Negative relationships mean friction, arguments, and eventually forcing the player to choose sides.

Relationships shift through shared experience and personality compatibility. Shared positive experiences build bonds; shared negative experiences can bond or fracture depending on the outcome. Stat profile similarity creates baseline compatibility — two high-Social crew tend to get along, high-Social/low-Social pairings create friction.

The player does not manage relationships directly. There is no “make them talk it out” action. The player influences relationships by managing proximity and circumstance — recruiting a high-Social generalist as a social buffer, or keeping hostile pairs busy.

## **Crew Events**

Small narrative moments generated by crew state, following an 80/10/10 distribution:

**80% Background flavor.** No player input. “Torres and Kex bonded over a shared meal, relationship \+10.” “The crew is in good spirits after shore leave.”

**10% Mild nudges.** Conveyed through dialogue or visual cues, not alerts. “Crew morale is dipping, might want an easy run.”

**10% Decision points.** Rare moments requiring a captain’s choice. “Medic Fenn refuses to treat Security Chief Denn after their feud. Order compliance or find another solution?”

## **Performance Formula**

A crew member’s actual effectiveness at any moment:

**Effective Performance \= Base Skill × Morale Modifier (0.5–1.2) × Fatigue Modifier (0.4–1.0)**

A neglected crew member operates at roughly 20–25% of theoretical best. A well-maintained one can slightly exceed baseline. This makes crew management mechanically real without requiring direct intervention.

# **Tier 2 — Species & Faction Identity**

**TIER 2  Diversity as Strategy**

Crew composition becomes a diplomatic passport. Who’s on your ship determines how the galaxy treats you.

## **Species Trait Framework**

Each species has a distinct mechanical fingerprint across three dimensions. These are baked into the crew member at recruitment and require no ongoing management.

### **Aptitude Bias**

Natural stat tendencies per species. Not hard caps, just bell curves. Most Gorvians skew toward Cognition and Stamina, making them natural engineers. A Gorvian gunner is unusual but possible, bringing unexpected tactical thinking to a role typically dominated by reflexes.

### **Environmental Trait**

A passive biological effect on ship operations. Examples: a species that runs hot and slightly increases engine efficiency; a small-framed species that consumes less food; a large species that needs more space and effectively costs 1.5 crew slots on small ships. Simple, non-manageable traits that make species feel physically distinct.

### **Vulnerability**

One clear weakness per species. Cold sensitivity, fragile bones, psychological need for open spaces, dietary restrictions. These create soft constraints on crew composition — you can put a claustrophobic species on a small ship, but they won’t be happy.

## **Species Design Template**

*The following is a template. Final species should map 1:1 to major factions (Hexarchy, Free People’s Union, Commonwealth of Systems, etc.). Recommend 5–7 total species including humans.*

| Trait | Species A (example) | Species B (example) | Humans |
| :---- | :---- | :---- | :---- |
| Aptitude Bias | High Cognition, high Stamina | High Reflexes, high Social | Balanced, no strong bias |
| Environmental Trait | Run hot (+engine efficiency) | Small frame (−food consumption) | Adaptable (no special trait, no penalty) |
| Vulnerability | Cold sensitivity (−performance in cold environments) | Fragile bones (longer injury recovery) | None specific (but no special resistances) |
| Faction | Gorvian Hexarchy | Vellani Free Peoples | Commonwealth of Systems |

## **Faction Access System**

Having crew from a faction provides access to that faction’s controlled space, stations, and services on a spectrum, not as a binary gate.

| Crew from Faction | Access Level | Effects |
| :---- | :---- | :---- |
| None | Outsider | Worse trade prices, restricted station areas, hostile patrols, no faction missions. |
| One crew member | Baseline acceptance | Normal prices, basic access, neutral treatment. |
| Multiple, or one in Comms Officer role | Insider | Better prices, restricted areas open, faction-specific missions available. |

This makes crew diversity strategically valuable. A player who trades across many territories wants a diverse crew for universal access. A player who operates in one faction’s space might stack that species for deep insider status. Both are valid.

## **Cultural Friction & Synergy**

Species pairings carry baseline relationship modifiers that feed into the Tier 1 system. Historical tensions (e.g., a trade rivalry) start a pair at −15 to −25. Natural affinity (shared cultural values) starts at \+10 to \+15. These are visible at recruitment time through dialogue or recruiter hints, allowing informed decisions. Individual compatibility can override cultural defaults over time.

## **Species-Specific Food**

Folds into the existing “buy food when docked” loop with zero additional management. Stations sell food appropriate to the local species. If you have Gorvians aboard and stock up at a Gorvian station, they get a small morale boost from comfort food. The player develops natural intuition: “I’ve got Gorvians and Vellani on board, let me stock up here since we won’t see another Vellani station for a while.” This is captaincy, not inventory management.

# **Tier 3 — History & Growth**

**TIER 3  The Crew as Living Record**

Every crew member accumulates experience that shapes who they become. The crew becomes a record of the player’s journey.

## **Skill Progression**

Crew improve at their role through doing it. The curve is steep early and flattens over time — a fresh recruit improves noticeably in the first few engagements while a veteran improves slowly. No XP bars or skill trees for the player to manage.

The stat block serves as both starting point and ceiling. A gunner with Reflexes 60 might start performing at effective 45 (green, unproven) and grow toward their cap through experience. Exceptional sustained performance can push 5–10% beyond the cap, representing experience transcending natural talent. Recruitment still matters — you cannot grind a mediocre hire into a prodigy.

Pinch-hitting also generates growth, very slowly. A security chief who repeatedly covers navigation develops a minor competency over time. Never as good as a specialist, but the penalty shrinks from brutal to merely noticeable.

## **Event Memory**

Each crew member maintains up to 5–8 formative memories. Newer significant events push out older minor ones. These are not journal entries — they’re mechanical modifiers that manifest through behavior and occasional dialogue.

A formative event has three components:

| Component | Description | Example |
| :---- | :---- | :---- |
| Trigger | What happened | Near-death pirate ambush |
| Emotional Tag | How they processed it (influenced by stats and morale) | Hardened (high Stamina) or Shaken (low Stamina) |
| Behavioral Modifier | How it affects future behavior | \+10% performance in ambush scenarios, or −10% when pirates detected but \+10% scan range |

The same event can be processed differently by different crew members. The player does not choose how crew process events. They see the results: the science officer flinches when pirates appear on scanners, the security chief grins. Over time the crew becomes a constellation of reactions shaped by shared experience.

## **Trait Acquisition**

Permanent binary traits acquired through significant events or sustained conditions. The critical design rule: every negative trait has a compensating edge, and every positive trait has a subtle cost.

### **Positive Traits**

| Trait | Acquisition | Benefit | Subtle Cost |
| :---- | :---- | :---- | :---- |
| Battle-Tested | Survived 10+ combat encounters | Baseline stress resistance in all combat | May be overly aggressive when diplomacy would serve better |
| Spacer’s Instinct | 500+ jumps completed | Passive navigation bonus regardless of role | Slightly restless when stationary too long |
| Trusted by \[Faction\] | Multiple successful faction missions | Personal faction access bonus | May be viewed with suspicion by rival factions |

### **Negative Traits**

| Trait | Acquisition | Penalty | Compensating Edge |
| :---- | :---- | :---- | :---- |
| Scarred | Suffered critical injury | Permanent slight Stamina reduction | Increased Cognition from recovery period |
| Grudge-Bearer | Relationship with a species dropped below −80 | Permanent hostility toward that species | Heightened alertness and combat readiness against them |
| Haunted | Witnessed crew death | Periodic morale dips that can’t be fully resolved | Increased Purpose — they’re driven now |

This design prevents players from viewing crew damage as purely negative and supports the principle that players should embrace conflict rather than avoid it. There is no pristine crew — only your crew, shaped by your journey.

## **Crew-Wide History (Ship Memories)**

Events significant enough to mark the entire crew generate a ship memory: a persistent modifier applied to all current crew. “The Incident at Nexon-7” might give the whole crew −15% in Plutonian space but \+10% cohesion from shared trauma.

New crew hired after the event don’t carry the memory directly, but the crew culture it created affects them through the Tier 1 relationship system. They join a crew that’s tight-knit and wary of Plutonians, and that rubs off. The ship develops a reputation and personality entirely from gameplay.

## **The Growth Arc**

Combining skill progression, event memory, and trait acquisition, each crew member follows a natural arc from recruit to veteran. A freshly hired gunner is nervous and performs below their stat ceiling. After extended service, they’re performing at full capability with memories of shared history and earned traits. They’re a character now — not because they were scripted, but because the systems generated a story through play.

This creates meaningful loss. Losing a veteran isn’t just losing stats; it’s losing a history that cannot be replaced.

# **Tier 4 — Deep Dynamics**

**TIER 4  The Crew as Family**

Everything here is optional seasoning on an already functional system. If Tiers 0–3 are the ship, Tier 4 is the soul.

## **Romantic Relationships**

Romance emerges from the Tier 1 relationship system, never from player intervention. When a pairwise relationship exceeds \+70 and personality profiles are compatible, a probability window opens — roughly 5% chance per event cycle, increasing as the relationship climbs. Some pairs never connect at \+90; some click quickly.

### **Effects of Couplehood**

| Effect | Description |
| :---- | :---- |
| Synergy bonus | Coordinated performance when both are active during the same event. |
| Linked morale | One partner’s happiness or distress partially transfers to the other. |
| Enhanced pinch-hitting | Willingness to cover for each other increases. |
| Injury vulnerability | If one is hurt, the other takes a morale and performance hit beyond normal crew concern. |
| Death consequence | Survivor enters grief state: deep morale collapse, erratic performance. Resolves into Resolved (stronger) or Broken (diminished, may leave). |
| Breakup fallout | Both take a morale hit proportional to relationship duration. The crew takes sides, fracturing existing relationships. |

*The player never manages romance. They witness it. A couple forming is a crew event; a breakup is a crisis that colors the ship for a long time.*

## **Loyalty**

Distinct from morale. Morale is “am I happy right now?” Loyalty is “would I follow this captain into the dark?” Morale fluctuates constantly; loyalty moves slowly and rarely reverses.

Loyalty builds through sustained competent captaincy, shared hardship that ends well, and choices that align with the crew member’s values. A cautious crew member gains loyalty from safe routes; a glory-seeker gains loyalty from bold victories. The player learns what builds loyalty for each crew member through observation.

### **High Loyalty Effects**

Subtle, never displayed in a stat screen. Loyal crew volunteer for dangerous tasks, perform slightly above their cap in crises, defend the captain’s decisions to grumpy crewmates (buffering morale dips), and stay when things get bad.

### **Low Loyalty — Departure Arc**

A crew member with low loyalty and low morale follows a visible arc toward departure: withdrawal from crew life, vocal unhappiness through organic dialogue, and eventually an ultimatum — they want something to change or they’re leaving at the next port. The player can meet the demand, negotiate, or accept their departure. Forcing someone to stay is never an option.

## **Injury & Disease Depth**

Injuries gain location and severity. A hand injury affects a gunner differently than an engineer. Severe injuries can become permanent impairments that feed into the Tier 3 trait system.

Disease is species-specific. Certain environments or cargo expose crew to pathogens affecting some species and not others. A diverse crew is more resilient on average (a species-specific plague only hits part of the roster) but vulnerable to a wider range of threats. A monospecies crew is either immune or devastated.

The medic becomes dramatically more important: a skilled medic reduces severity, speeds recovery, catches diseases early, and prevents complications. Outbreaks create tense non-combat scenarios: quarantine decisions, diverting for medical supplies, docking risks.

## **Crew-Generated Missions**

Crew with high loyalty and sufficient history occasionally surface personal requests that become optional side missions. These are generated from the crew member’s species, faction, history, and relationships — not random fetch quests.

Examples: a Gorvian engineer with the Grudge-Bearer trait asks to confront someone from their past. A long-serving crew member requests shore leave on their homeworld. Two close friends want to visit a place one keeps mentioning. A crew member who survived a near-death event wants to return for closure.

These reward the player with loyalty gains, trait resolutions (Haunted becomes At Peace), unique items, and story moments that feel earned. They are entirely optional — declining causes a small loyalty dip, not a crisis. Frequency should be conservative: roughly one per 30–40 hours of play, scaling slightly with crew size.

## **Crew Legacy**

When a crew member departs — by choice, death, or retirement — they leave a permanent mark. Remaining crew with strong relationships to the departed gain a Legacy Memory, a mild persistent version of the departed’s influence.

| Departure Type | Legacy Effect Example |
| :---- | :---- |
| Retirement (positive) | A beloved engineer’s modifications persist: slight efficiency bonus for future engineers on this ship. |
| Death in battle | Memorial effect: combat morale resistance. “We fight for those we’ve lost.” |
| Bitter departure | Negative legacy: suspicion toward their species, a cautionary tale that new crew hear about. |

The ship accumulates identity over an entire playthrough. Two players comparing ships aren’t comparing loadouts — they’re comparing histories written in legacy effects and the ghosts of crew who aren’t there anymore.

# **System Interactions**

## **Crew System × Social DNA**

The existing Social DNA dialogue system connects naturally to crew. The Comms Officer role bridges crew and the external world — they are the player’s interface with NPCs. A Comms Officer’s Social stat and species modifiers could influence dialogue options available and NPC disposition during encounters.

Crew members themselves are NPCs with standard dialogue options, but dialogue is not the primary management method. Conversations are windows into crew state — a way to notice morale problems, learn personal history, and feel the texture of interpersonal dynamics — not levers for controlling outcomes.

## **Crew System × Economy**

The pay split creates a constant soft drain on income, making crew an operational cost that scales with ambition. More crew means more capability but less personal profit. Better crew expect fairer splits. Food is a recurring expense tied to crew size and species composition. This economic pressure creates meaningful tension between expansion and solvency.

## **Crew System × Combat**

Combat is where crew capability is most immediately felt. Unfilled roles mean the pilot handles everything sequentially; filled roles enable simultaneous operations. Multiple specialists in the same role provide combined output. Injuries during combat have mechanical and narrative consequences that ripple through Tiers 1–4.

## **Crew System × Companion Ships**

Companion ships are autonomous black boxes with their own crews. The player never directly manages companion crews. This creates implicit leadership layers: the player is captain of their ship and fleet commander of their companion captains. Interesting cross-ship moments emerge: a companion’s engineer dies in battle and their ship is limping — does the player transfer one of their own?

# **Implementation Roadmap**

## **Priority Sequence**

Each tier should be fully implemented and playtested before beginning the next. Each tier is independently shippable.

| Phase | Tier | Core Deliverables | Playtesting Focus |
| :---- | :---- | :---- | :---- |
| 1 | Tier 0 | Ship classes, 8 roles, 5 stats, capability model, pinch-hitting, recruitment UI | Does crew composition feel like a strategic choice? Is the ship seller intro compelling? |
| 2 | Tier 1 | Morale system, 4 needs, pay split, food economy, relationships, crew events, performance formula | Does the crew feel alive? Is management light-touch? Do events generate stories? |
| 3 | Tier 2 | Species traits, faction access spectrum, cultural friction/synergy, species food | Does diversity feel strategically rewarding? Do faction access levels work? |
| 4 | Tier 3 | Skill progression, event memory, trait acquisition, ship memories | Do veterans feel different from recruits? Do traits feel fair? Is loss meaningful? |
| 5 | Tier 4 | Romance, loyalty, injury/disease depth, crew missions, legacy system | Does the crew feel like family? Are departure moments emotionally resonant? |

## **Solo Dev Considerations**

The reactive design philosophy directly benefits solo development. Fewer player-facing controls means fewer UI elements, fewer edge cases, and fewer ways to break the system. Complexity lives in the background simulation; the player sees narrative output, not mechanical input surfaces.

Each tier can be scoped to a development sprint. Tier 0 is mostly data structures and UI. Tier 1 is the simulation core. Tier 2 is content authoring (species/factions). Tier 3 is event system expansion. Tier 4 is narrative polish.

# **Appendix**

## **Quick Reference — Player Actions by Tier**

| Tier | What the Player Actively Does | What the System Does |
| :---- | :---- | :---- |
| 0 | Recruits crew members when docked | Maps crew roles to ship capabilities, handles pinch-hitting |
| 1 | Sets pay split once; buys food when docked | Tracks morale, needs, relationships; generates crew events |
| 2 | Considers species during recruitment | Applies faction access, cultural modifiers, species traits |
| 3 | Plays the game (nothing new) | Tracks skill growth, builds event memories, awards traits |
| 4 | Responds to rare crew decisions | Generates romance, loyalty arcs, crew missions, legacy effects |

## **Quick Reference — Morale Inputs**

| Input | Positive Effect | Negative Effect |
| :---- | :---- | :---- |
| Pay split | Equitable or generous split | Captain-heavy split |
| Food | Good quality, species-appropriate | Low stock, poor quality, no variety |
| Rest | Downtime between operations | Sustained high-intensity operations |
| Safety | Winning battles, competent captaincy | Frequent danger, hull damage, crew injuries |
| Purpose | Role being actively utilized | Extended periods of role irrelevance |
| Relationships | Positive bonds with crewmates | Feuds, cultural friction, isolation |

## **Open Design Questions**

The following questions should be resolved during playtesting of each tier:

* Should generalists be able to “specialize” over time if they repeatedly pinch-hit the same role? (Potential Tier 3 feature.)

* How visible should morale and relationship numbers be to the player? Exact values, general indicators, or only through behavioral cues?

* Can crew be transferred between the player’s ship and companion ships? If so, under what conditions?

* Should the player be able to dismiss crew, or only accept voluntary departures?

* What is the respawn/recruitment cadence? Should available recruits be procedurally generated or drawn from a curated pool per station?

* How do crew interact with the existing faction reputation system beyond the Tier 2 access spectrum?

*End of document. This GDD is a living document and should be revised as playtesting reveals what works.*