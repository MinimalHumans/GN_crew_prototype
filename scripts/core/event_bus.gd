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

# === ROMANCE (Phase 5.1) ===
signal romance_formed(crew_a_id: int, crew_b_id: int)
signal romance_ended(crew_a_id: int, crew_b_id: int, reason: String)
signal romance_warning(crew_a_id: int, crew_b_id: int)

# === LOYALTY (Phase 5.2) ===
signal loyalty_changed(crew_id: int, new_loyalty: float, old_loyalty: float)
signal loyalty_stage_changed(crew_id: int, crew_name: String, stage: String)
signal crew_departed(crew_id: int, crew_name: String)

# === INJURY / DISEASE (Phase 5.3) ===
signal crew_diseased(crew_id: int, disease_name: String)
signal disease_spread(crew_id: int, disease_name: String)
signal quarantine_started()
signal permanent_impairment(crew_id: int, crew_name: String, stat: String, amount: int)

# === CREW-GENERATED MISSIONS (Phase 5.4) ===
signal crew_mission_triggered(crew_id: int, crew_name: String, template_type: String)
signal crew_mission_completed(crew_id: int, template_type: String, success: bool)
signal crew_mission_declined(crew_id: int)

# === LEGACY SYSTEM (Phase 5.5) ===
signal crew_retired(crew_id: int, crew_name: String)
signal crew_died(crew_id: int, crew_name: String, cause: String)
signal legacy_created(crew_name: String, departure_type: String)
signal grief_resolved(crew_id: int, crew_name: String, outcome: String)

# === ECONOMY (Phase 4) ===
signal payout_completed(total_crew_share: int, per_crew: int)
signal payout_crisis(shortfall: int)
signal prosperity_departure(crew_id: int, crew_name: String)
signal underpaid_departure(crew_id: int, crew_name: String)

# === WIN STATE (Phase 6) ===
signal win_condition_reached(total_earned: int)

# === LOSE STATES (Phase 9) ===
signal ship_destroyed()
signal crewless_state_entered()

# === UI ===
signal message_logged(text: String, color: Color)
signal scene_change_requested(scene_path: String)
signal notification_shown(text: String)
