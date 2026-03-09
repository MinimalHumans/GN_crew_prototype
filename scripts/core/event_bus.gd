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

# === ENCOUNTERS ===
signal encounter_started(encounter_type: String)
signal encounter_resolved(outcome: String)
signal challenge_presented(options: Array)
signal challenge_choice_made(choice_index: int)

# === UI ===
signal message_logged(text: String, color: Color)
signal scene_change_requested(scene_path: String)
signal notification_shown(text: String)
