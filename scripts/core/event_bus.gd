extends Node
## EventBus — Signal-based event system for decoupled communication.
## All game signals are defined here. Systems emit; UI and other systems connect.

# === GAME STATE ===
signal game_started(captain_name: String)
signal game_loaded(save_id: int)
signal game_saved(save_id: int)
signal day_advanced(new_day: int)

# === NAVIGATION ===
signal planet_arrived(planet_id: int, planet_name: String)
signal travel_started(from_id: int, to_id: int, jumps: int)
signal travel_jump_completed(current_jump: int, total_jumps: int)
signal travel_completed(planet_id: int)

# === ECONOMY ===
signal credits_changed(new_amount: int)
signal cargo_changed(commodity_id: int, new_quantity: int)
signal trade_completed(commodity_id: int, quantity: int, price: int, is_buy: bool)
signal fuel_changed(current: float, maximum: float)
signal food_changed(supply: float)

# === MISSIONS ===
signal mission_accepted(mission_id: int)
signal mission_completed(mission_id: int, success: bool)
signal mission_failed(mission_id: int)
signal mission_board_refreshed(planet_id: int)

# === CAPTAIN ===
signal xp_gained(amount: int, new_total: int)
signal level_up(new_level: int)
signal stats_changed()

# === SHIP ===
signal ship_purchased(ship_class: String)
signal hull_changed(current: int, maximum: int)
signal ship_repaired(amount: int)

# === CREW ===
signal crew_recruited(crew_id: int, crew_name: String)
signal crew_dismissed(crew_id: int, crew_name: String)
signal crew_changed()
signal pay_split_changed(new_split: float)

# === CREW SIMULATION ===
signal crew_simulation_ticked(tick_results: Dictionary)
signal background_event_fired(text: String)
signal nudge_event_fired(text: String)
signal decision_event_fired(event_data: Dictionary)
signal decision_event_resolved(event_id: String, choice: int)

# === ENCOUNTERS ===
signal encounter_started(encounter_type: String)
signal encounter_resolved(outcome: String)
signal challenge_presented(options: Array)
signal challenge_choice_made(choice_index: int)

# === CREW GROWTH (Phase 4) ===
signal crew_skill_gained(crew_id: int, crew_name: String, new_label: String)
signal crew_memory_formed(crew_id: int, crew_name: String, trigger_text: String)
signal crew_trait_acquired(crew_id: int, crew_name: String, trait_id: String, trait_name: String)
signal ship_memory_formed(event_description: String)

# === UI ===
signal message_logged(text: String, color: Color)
signal scene_change_requested(scene_path: String)
signal notification_shown(text: String)
