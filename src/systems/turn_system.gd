# src/systems/turn_system.gd
extends Node

## Turn flow and phase orchestration.
## Manages the sequence of phases within each turn.

enum Phase {
	IDLE,
	TURN_START,
	SERVICE_RESOLUTION,
	BEAST_MOVEMENT,
	GUEST_MOVEMENT,
	BEAST_INTERACTION,
	STALL_ENTRY,
	GUEST_SPAWN,
	PLAYER_ACTION,
	TURN_END
}

const BULK_WAIT_DURATION: int = 3

var current_turn: int = 0
var current_phase: Phase = Phase.IDLE
var is_running: bool = false
var waiting_for_player: bool = false

# Level completion tracking
var _level_complete_emitted: bool = false
var _midnight_emitted: bool = false
var midnight_threshold_fraction: float = 0.0
var _initial_core_guest_count: int = 0

# External references
var board_system = null  # Set via set_board_system()
var board_visual: BoardVisual = null  # Set via set_board_visual()
var status_effect_system: StatusEffectSystem = null  # Set via set_status_effect_system()
var trigger_system = null  # Set via set_trigger_system()


func _ready() -> void:
	EventBus.level_lost.connect(stop_level)


func set_board_system(system) -> void:
	board_system = system


func set_board_visual(visual: BoardVisual) -> void:
	board_visual = visual


func set_status_effect_system(system: StatusEffectSystem) -> void:
	status_effect_system = system


func set_trigger_system(system) -> void:
	trigger_system = system


func _queue_guest_animation(guest: GuestInstance, animation_method: String, args: Array = []) -> void:
	## Helper to queue an animation for a guest entity.
	if not board_visual:
		return
	var entity = board_visual.get_guest_entity(guest)
	if not entity:
		return
	var anim = entity.callv(animation_method, args)
	if anim:
		AnimationCoordinator.queue(anim)


func _resolve_pre_serve(guest: GuestInstance, stall: StallInstance) -> Dictionary:
	## Fire on_pre_serve triggers and return the full service_result dictionary.
	## Callers check service_result.get("blocked", false) and apply fulfillment modifiers.
	var context = TriggerContext.create("on_pre_serve")
	context.with_guest(guest)
	context.with_stall(stall)
	context.with_source(guest)
	context.with_target(guest)
	context.with_service_result()

	if trigger_system:
		trigger_system.trigger_entity_skills("on_pre_serve", context, [guest, stall])

	return context.service_result


func _apply_fulfillment_modifiers(base_value: int, service_result: Dictionary) -> int:
	## Apply fulfillment_multiplier and fulfillment_bonus from service_result to a base value.
	return int(base_value * service_result.get("fulfillment_multiplier", 1.0)) + service_result.get("fulfillment_bonus", 0)


func _resolve_pre_move(guest: GuestInstance) -> Dictionary:
	## Fire on_pre_move triggers and return the movement_result dictionary.
	## Callers read movement_result.get("direction", 1) for movement direction.
	var context = TriggerContext.create("on_pre_move")
	context.with_guest(guest)
	context.with_source(guest)
	context.with_target(guest)
	context.with_movement_result()

	if trigger_system:
		trigger_system.trigger_entity_skills("on_pre_move", context, [guest])

	return context.movement_result


func _resolve_pre_encounter(beast: GuestInstance, guest: GuestInstance) -> Dictionary:
	## Fire on_pre_encounter triggers and return the encounter_result dictionary.
	## Callers check encounter_result.get("blocked", false) and read benefit_multiplier.
	var context = TriggerContext.create("on_pre_encounter")
	context.with_guest(guest)
	context.with_source(beast)
	context.with_target(guest)
	context.with_encounter_result()

	if trigger_system:
		trigger_system.trigger_entity_skills("on_pre_encounter", context, [guest])

	return context.encounter_result


func _resolve_pre_enter_stall(guest: GuestInstance, stall: StallInstance) -> Dictionary:
	## Fire on_pre_enter_stall triggers and return the entry_result dictionary.
	## Callers check entry_result.get("blocked", false).
	var context = TriggerContext.create("on_pre_enter_stall")
	context.with_guest(guest)
	context.with_stall(stall)
	context.with_source(guest)
	context.with_target(guest)
	context.with_entry_result()

	if trigger_system:
		trigger_system.trigger_entity_skills("on_pre_enter_stall", context, [guest, stall])

	return context.entry_result


func _resolve_service_for_guest(guest: GuestInstance, stall: StallInstance) -> Dictionary:
	## Fire on_pre_serve, fulfill need, charge cost, queue animations.
	## Returns service event data dict (includes "blocked" key).
	var service_result = _resolve_pre_serve(guest, stall)

	var need_type = stall.resolve_need_type_for_guest(guest)

	if service_result.get("blocked", false):
		_queue_guest_animation(guest, "create_service_blocked_animation")
		return {
			"guest": guest,
			"stall": stall,
			"need_type": need_type,
			"fulfilled": 0,
			"blocked": true
		}

	var final_value = _apply_fulfillment_modifiers(stall.get_value(), service_result)
	var cost = stall.get_cost_to_guest()
	var fulfilled = board_system.fulfill_guest_need(guest, need_type, final_value, stall)
	guest.spend_money(cost)

	return {
		"guest": guest,
		"stall": stall,
		"need_type": need_type,
		"fulfilled": fulfilled
	}


func _flush_and_sweep() -> void:
	## Flush skill-effect animations, then process banished guests and ascend
	## any newly-satisfied guests.
	## Loops until no more pending banishments or ascensions remain.
	await AnimationCoordinator.play_batch()

	if not board_system:
		return

	while true:
		# Sweep banished guests (animation already played in the batch above)
		var newly_banished: Array[GuestInstance] = []
		for guest in board_system.active_guests:
			if guest.is_banished:
				newly_banished.append(guest)

		for guest in newly_banished:
			_handle_guest_banishment(guest)

		# Flush on_banish skill-effect animations
		if not newly_banished.is_empty():
			await AnimationCoordinator.play_batch()

		# Sweep ascending guests (need animation queued + played)
		var newly_ascending: Array[GuestInstance] = []
		for guest in board_system.active_guests:
			if not guest.is_exiting and (guest.are_all_needs_fulfilled() or guest.force_ascend):
				guest.is_exiting = true
				newly_ascending.append(guest)

		if newly_ascending.is_empty() and newly_banished.is_empty():
			break

		if not newly_ascending.is_empty():
			for guest in newly_ascending:
				_queue_guest_animation(guest, "create_ascend_animation")
			await AnimationCoordinator.play_batch()

			for guest in newly_ascending:
				_handle_guest_ascension(guest)

			# Flush animations from on_ascend skill effects, then loop to check
			# if those effects satisfied more guests or banished more guests
			await AnimationCoordinator.play_batch()


func _refresh_stall_entity(stall: StallInstance) -> void:
	## Refresh a stall entity's labels and visual state after state changes.
	if board_visual:
		var entity = board_visual.get_stall_entity(stall.board_position)
		if entity:
			entity.refresh()


func _handle_bulk_service_entry(guest: GuestInstance, stall: StallInstance) -> void:
	## Handle a guest entering a bulk_service stall. Sets wait timers and
	## checks if capacity is filled to transition to SERVING.
	stall.bulk_phase = StallInstance.BulkPhase.WAITING
	guest.wait_turns_remaining = BULK_WAIT_DURATION

	# Reset wait timers for all OTHER occupants
	for other in stall.current_occupants:
		if other != guest:
			other.wait_turns_remaining = BULK_WAIT_DURATION

	# Check if capacity is now filled → transition to SERVING
	if stall.current_occupants.size() == stall.get_capacity():
		stall.bulk_phase = StallInstance.BulkPhase.SERVING
		var total_multiplier: float = 0.0
		for occ in stall.current_occupants:
			total_multiplier += occ.get_stat("service_duration_multiplier", 1.0)
		var avg_multiplier = total_multiplier / stall.current_occupants.size()
		var base_duration = stall.get_service_duration()
		var duration = maxi(1, int(base_duration * avg_multiplier))
		for occ in stall.current_occupants:
			occ.service_turns_remaining = duration

	_refresh_stall_entity(stall)


func _tick_bulk_waiting(stall: StallInstance, timed_out_by_stall: Array) -> void:
	## Tick waiting countdown for guests in a bulk_service stall in WAITING phase.
	## Collects timed-out guests for removal in Phase 3.
	var timed_out: Array[GuestInstance] = []

	for guest in stall.current_occupants:
		guest.wait_turns_remaining -= 1
		_queue_guest_animation(guest, "create_wait_tick_animation", [guest.wait_turns_remaining])
		if guest.wait_turns_remaining <= 0:
			timed_out.append(guest)

	for guest in timed_out:
		timed_out_by_stall.append({"guest": guest, "stall": stall})


# =============================================================================
# Turn Control
# =============================================================================

func start_level() -> void:
	## Begin turn processing for a level.
	current_turn = 0
	current_phase = Phase.IDLE
	is_running = true
	waiting_for_player = false
	_level_complete_emitted = false
	_midnight_emitted = false
	midnight_threshold_fraction = 0.0
	_initial_core_guest_count = 0
	if board_system:
		for guest_def in board_system.guest_queue:
			if guest_def.is_core_guest:
				_initial_core_guest_count += 1

	EventBus.level_started.emit()
	advance_turn()


func stop_level() -> void:
	## Stop turn processing.
	is_running = false
	current_phase = Phase.IDLE


func advance_turn() -> void:
	## Start the next turn.
	if not is_running:
		return

	current_turn += 1
	_execute_turn()


func player_action_complete() -> void:
	## Called when the player has finished their action for the turn.
	if current_phase == Phase.PLAYER_ACTION and waiting_for_player:
		waiting_for_player = false
		_continue_after_player_action()


# =============================================================================
# Turn Execution
# =============================================================================

func _execute_turn() -> void:
	## Execute all phases of a turn in order.
	await _execute_turn_start()
	await _execute_service_resolution()
	await _execute_beast_movement()
	await _execute_guest_movement()
	await _execute_beast_interaction()
	await _execute_stall_entry()
	await _execute_guest_spawn()
	_execute_player_action()
	# Turn end happens after player action completes


func _continue_after_player_action() -> void:
	## Continue turn after player finishes their action.
	await _execute_turn_end()

	# Start next turn if level still running
	if is_running:
		advance_turn()


func _set_phase(phase: Phase) -> void:
	current_phase = phase
	var phase_name = Phase.keys()[phase].to_lower()
	EventBus.phase_changed.emit(phase_name)


# =============================================================================
# Phase Implementations
# =============================================================================

func _execute_turn_start() -> void:
	## TURN_START: Trigger on_turn_start skills, tick cooldowns.
	_set_phase(Phase.TURN_START)

	# Tick cooldowns on stalls
	var restocked_stalls: Array[StallInstance] = []
	if board_system:
		for stall in board_system.get_all_stalls():
			if stall.restock_cooldown > 0:
				stall.restock_cooldown -= 1
				if stall.restock_cooldown == 0:
					board_system.restock_stall(stall)
					restocked_stalls.append(stall)
				else:
					# Cooldown ticked but not yet restocked — update labels only
					if board_visual:
						var entity = board_visual.get_stall_entity(stall.board_position)
						if entity:
							entity.update_labels()

	await AnimationCoordinator.play_batch()

	# Emit events after animations
	EventBus.turn_started.emit(current_turn)
	for stall in restocked_stalls:
		EventBus.stall_restocked.emit(stall)

	# Flush & sweep: play skill-effect animations, ascend newly-satisfied guests
	await _flush_and_sweep()


func _execute_service_resolution() -> void:
	## SERVICE_RESOLUTION: Guests in stalls complete service.
	## Bulk service stalls have two phases: WAITING (tick wait countdown) and SERVING.
	_set_phase(Phase.SERVICE_RESOLUTION)

	if not board_system:
		return

	var service_events: Array = []
	var completed_by_stall: Array = []  # [{guest, stall}] — service-completed guests
	var timed_out_by_stall: Array = []  # [{guest, stall}] — bulk wait timeout guests
	var bulk_serve_events: Array = []  # [{stall, guests}] — on_bulk_serve data

	# Phase 1: Tick timers, resolve completions, queue fulfillment animations
	for stall in board_system.get_all_stalls():
		if stall.current_occupants.is_empty():
			continue

		var op_model = stall.get_operation_model()

		# Bulk service WAITING: tick wait countdown, collect timeouts
		if op_model == "bulk_service" and stall.bulk_phase == StallInstance.BulkPhase.WAITING:
			_tick_bulk_waiting(stall, timed_out_by_stall)
			continue

		# Service, bulk_service SERVING, and product: tick service timers
		var is_service = op_model == "service" or (op_model == "bulk_service" and stall.bulk_phase == StallInstance.BulkPhase.SERVING)
		var completed_guests: Array[GuestInstance] = []

		for guest in stall.current_occupants:
			guest.service_turns_remaining -= 1

			if guest.service_turns_remaining <= 0:
				if is_service:
					var event = _resolve_service_for_guest(guest, stall)
					service_events.append(event)
				completed_guests.append(guest)
			elif is_service:
				service_events.append({
					"type": "tick",
					"guest": guest,
					"stall": stall,
					"remaining": guest.service_turns_remaining
				})
				_queue_guest_animation(guest, "create_service_tick_animation", [guest.service_turns_remaining])

		for guest in completed_guests:
			completed_by_stall.append({"guest": guest, "stall": stall})

		# Collect bulk_serve data for completed bulk_service stalls
		if is_service and not completed_guests.is_empty() and op_model == "bulk_service":
			bulk_serve_events.append({"stall": stall, "guests": completed_guests})

	# Phase 2: Emit service events (guest still in stall for on_serve triggers)
	for event in service_events:
		if event.has("type") and event.type == "tick":
			EventBus.service_tick.emit(event.guest, event.stall, event.remaining)
		elif event.get("blocked", false):
			pass  # Blocked service — no events emitted
		else:
			if event.fulfilled > 0:
				EventBus.guest_need_fulfilled.emit(event.guest, event.need_type, event.fulfilled, event.stall)
			EventBus.guest_served.emit(event.guest, event.stall)

	# Phase 2b: Fire on_bulk_serve for completed bulk_service stalls
	for bulk_event in bulk_serve_events:
		var context = TriggerContext.create("on_bulk_serve")
		context.with_stall(bulk_event.stall).with_guests(bulk_event.guests).with_source(bulk_event.stall)
		if trigger_system:
			trigger_system.trigger_entity_skills("on_bulk_serve", context, [bulk_event.stall])

	# Phase 2c: Reset bulk_phase to IDLE for completed bulk stalls
	for bulk_event in bulk_serve_events:
		bulk_event.stall.bulk_phase = StallInstance.BulkPhase.IDLE
		_refresh_stall_entity(bulk_event.stall)

	# Phase 3: Remove completed/timed-out guests from stall
	var exiting_guests: Array[GuestInstance] = []
	var exit_events: Array = []

	for entry in completed_by_stall:
		var guest = entry.guest
		var stall = entry.stall
		if guest.are_all_needs_fulfilled() or guest.is_banished or guest.force_ascend:
			continue
		if guest not in board_system.active_guests:
			continue
		guest.is_in_stall = false
		guest.current_stall = null
		stall.remove_occupant(guest)
		exiting_guests.append(guest)
		exit_events.append({"guest": guest, "stall": stall})

	var stalls_with_timeout: Array[StallInstance] = []

	for entry in timed_out_by_stall:
		var guest = entry.guest
		var stall = entry.stall
		if guest.is_banished or guest.force_ascend:
			continue
		if guest not in board_system.active_guests:
			continue
		guest.is_in_stall = false
		guest.current_stall = null
		stall.remove_occupant(guest)
		exiting_guests.append(guest)
		exit_events.append({"guest": guest, "stall": stall})
		if stall not in stalls_with_timeout:
			stalls_with_timeout.append(stall)

	for stall in stalls_with_timeout:
		_refresh_stall_entity(stall)

	# Phase 4: Queue exit animations + repositioning
	for guest in exiting_guests:
		if board_visual and guest.current_tile:
			var entity = board_visual.get_guest_entity(guest)
			if entity:
				var target_pos = TileOccupancyManager.get_slot_position_for_guest(guest, guest.current_tile.position)
				entity.update_last_path_position(target_pos)
				AnimationCoordinator.queue(entity.create_move_animation(target_pos))

	TileOccupancyManager.queue_all_repositions(exiting_guests)

	# Phase 5: Play all animations
	await AnimationCoordinator.play_batch()

	# Phase 6: Emit exit events
	for event in exit_events:
		EventBus.guest_exited_stall.emit(event.guest, event.stall)

	# Phase 7: Flush & sweep
	await _flush_and_sweep()

	# Check level completion after ascensions
	_check_level_complete()


func _complete_service(guest: GuestInstance, stall: StallInstance, service_result: Dictionary = {}) -> Dictionary:
	## Complete service for a guest at a stall (used by product stalls for immediate service).
	## Returns service data: {need_type, fulfilled, guest, stall, stall_depleted}
	## Does NOT emit events — caller controls timing.
	var need_type = stall.resolve_need_type_for_guest(guest)
	var final_value = _apply_fulfillment_modifiers(stall.get_value(), service_result)
	var cost = stall.get_cost_to_guest()

	# Fulfill the need (state + animation)
	var fulfilled = board_system.fulfill_guest_need(guest, need_type, final_value, stall)

	# Charge the guest
	guest.spend_money(cost)

	# Product stalls consume stock
	var stall_depleted = false
	if stall.get_operation_model() == "product":
		stall_depleted = stall.use_stock()

	return {
		"guest": guest,
		"stall": stall,
		"need_type": need_type,
		"fulfilled": fulfilled,
		"stall_depleted": stall_depleted
	}


func _handle_guest_ascension(guest: GuestInstance) -> void:
	## Handle a guest completing all their needs.
	## Called after animations complete.
	if guest.is_core_guest():
		GameManager.record_guest_ascended()

	EventBus.guest_ascended.emit(guest)

	if board_system:
		board_system.remove_guest(guest)


func _handle_guest_descent(guest: GuestInstance) -> void:
	## Handle a guest leaving unsatisfied (reached path end without fulfilling needs).
	## Called after animations complete.
	if guest.is_core_guest():
		GameManager.record_guest_descended()

	EventBus.guest_descended.emit(guest)

	if board_system:
		if guest.is_core_guest():
			board_system.add_reputation(-1)
		board_system.remove_guest(guest)


func _handle_guest_banishment(guest: GuestInstance) -> void:
	## Handle a guest being banished (forced removal, no reputation penalty).
	## Called after banish animation completes.
	EventBus.guest_banished.emit(guest)

	if board_system:
		board_system.remove_guest(guest)


func _execute_beast_movement() -> void:
	## BEAST_MOVEMENT: Move mythical beasts and resolve interactions at destination.
	_set_phase(Phase.BEAST_MOVEMENT)

	if not board_system or not board_system.board:
		return

	# Reset interaction flags from previous turn
	for guest in board_system.active_guests:
		guest.interacted_this_turn = false

	# Collect beasts that will move
	var beasts: Array[GuestInstance] = []
	for guest in board_system.active_guests:
		if guest.is_mythical_beast() and not guest.is_in_stall and not guest.is_exiting:
			beasts.append(guest)

	if beasts.is_empty():
		return

	# FIRST PASS: Move all beasts (state changes only)
	var movement_results: Array = []
	var beasts_to_exit: Array[GuestInstance] = []

	for beast in beasts:
		var speed = beast.get_movement_speed()
		var direction = beast.get_move_direction()
		var path = _get_guest_path(beast)

		if path:
			var from_tile = beast.current_tile
			var reached_end = not board_system.advance_guest_on_path(beast, path, speed, direction)
			var to_tile = beast.current_tile

			movement_results.append({
				"beast": beast,
				"from": from_tile,
				"to": to_tile,
				"reached_end": reached_end
			})

			if reached_end:
				beasts_to_exit.append(beast)

	# SECOND PASS: Queue move animations
	var animated_beasts: Array[GuestInstance] = []
	for result in movement_results:
		var beast = result.beast
		if result.from != result.to:
			animated_beasts.append(beast)
			var target_pos = TileOccupancyManager.get_slot_position_for_guest(beast, beast.current_tile.position)
			if board_visual:
				var entity = board_visual.get_guest_entity(beast)
				if entity:
					entity.update_last_path_position(target_pos)
					AnimationCoordinator.queue(entity.create_move_animation(target_pos))

	TileOccupancyManager.queue_all_repositions(animated_beasts)
	await AnimationCoordinator.play_batch()

	# Emit movement events for beasts that moved (not exiting)
	for result in movement_results:
		if not result.reached_end:
			EventBus.guest_moved.emit(result.beast, result.from, result.to)

	await _flush_and_sweep()

	# Resolve interactions at beast destination tiles (beasts that didn't exit)
	var interaction_events: Array = []
	for result in movement_results:
		var beast = result.beast
		if result.reached_end or beast not in board_system.active_guests:
			continue
		var events = _resolve_beast_interactions(beast)
		interaction_events.append_array(events)

	if not interaction_events.is_empty():
		await AnimationCoordinator.play_batch()

		for event in interaction_events:
			EventBus.beast_interacted.emit(event.beast, event.guest)

		await _flush_and_sweep()

	# Handle beast exits
	for beast in beasts_to_exit:
		if beast not in board_system.active_guests:
			continue
		_handle_guest_exit(beast)

	if not beasts_to_exit.is_empty():
		await AnimationCoordinator.play_batch()

		for beast in beasts_to_exit:
			if beast not in board_system.active_guests:
				continue
			var exit_type = beast.get_meta("exit_type", "descended")
			if exit_type == "ascend":
				_handle_guest_ascension(beast)
			else:
				_handle_guest_descent(beast)

		await _flush_and_sweep()


func _execute_guest_movement() -> void:
	## GUEST_MOVEMENT: Move guests along paths.
	_set_phase(Phase.GUEST_MOVEMENT)

	if not board_system or not board_system.board:
		return

	# Collect guests that will move (skip beasts — they moved in BEAST_MOVEMENT,
	# and skip guests that interacted with a beast this turn)
	var moving_guests: Array[GuestInstance] = []
	for guest in board_system.active_guests:
		if guest.is_in_stall:
			continue
		if guest.is_mythical_beast():
			continue
		if guest.is_exiting:
			continue
		if guest.interacted_this_turn:
			continue
		moving_guests.append(guest)

	# Track movement results for events
	var movement_results: Array = []  # [{guest, from, to, reached_end}]
	var guests_to_exit: Array[GuestInstance] = []
	var guests_moved: Array[GuestInstance] = []  # Guests that moved (not exiting)

	# FIRST PASS: Execute all movement logic (state changes only, no animations)
	for guest in moving_guests:
		var speed = guest.get_movement_speed()
		var path = _get_guest_path(guest)

		if path:
			var move_result = _resolve_pre_move(guest)
			var direction = move_result.get("direction", 1)
			var from_tile = guest.current_tile
			var reached_end = not board_system.advance_guest_on_path(guest, path, speed, direction)
			var to_tile = guest.current_tile

			movement_results.append({
				"guest": guest,
				"from": from_tile,
				"to": to_tile,
				"reached_end": reached_end
			})

			if reached_end:
				guests_to_exit.append(guest)
			elif from_tile != to_tile:
				guests_moved.append(guest)

	# SECOND PASS: Queue move animations with correct slot positions
	# Now all state is settled, TileOccupancyManager can calculate proper slots
	# Include guests that reached the end - they still need to animate to the final tile
	var all_animated_guests: Array[GuestInstance] = []

	for result in movement_results:
		var guest = result.guest
		# Only animate if the guest actually moved (skip if already at end)
		if result.from != result.to:
			all_animated_guests.append(guest)
			var to_tile = guest.current_tile
			# Get slot position (accounts for other guests on same tile)
			var target_pos = TileOccupancyManager.get_slot_position_for_guest(guest, to_tile.position)
			if board_visual:
				var entity = board_visual.get_guest_entity(guest)
				if entity:
					entity.update_last_path_position(target_pos)
					AnimationCoordinator.queue(entity.create_move_animation(target_pos))

	# Queue repositioning for non-moving guests only
	TileOccupancyManager.queue_all_repositions(all_animated_guests)

	# Play all movement animations
	await AnimationCoordinator.play_batch()

	# Now emit movement events (for skill triggers)
	for result in movement_results:
		if not result.reached_end:
			EventBus.guest_moved.emit(result.guest, result.from, result.to)

	# Flush & sweep: play skill-effect animations, ascend newly-satisfied guests
	await _flush_and_sweep()

	# Handle exits (separate batch for ascend/despawn animations)
	# Skip guests already removed by the sweep (ascended mid-path)
	for guest in guests_to_exit:
		if guest not in board_system.active_guests:
			continue
		_handle_guest_exit(guest)

	if not guests_to_exit.is_empty():
		await AnimationCoordinator.play_batch()

		# Process exit events after animations complete
		for guest in guests_to_exit:
			if guest not in board_system.active_guests:
				continue
			var exit_type = guest.get_meta("exit_type", "descended")
			if exit_type == "ascend":
				_handle_guest_ascension(guest)
			else:
				_handle_guest_descent(guest)

		# Flush & sweep after exit event processing
		await _flush_and_sweep()

		# Check level completion after processing exits
		_check_level_complete()


func _execute_beast_interaction() -> void:
	## BEAST_INTERACTION: Beasts interact with guests that just moved onto their tiles.
	_set_phase(Phase.BEAST_INTERACTION)

	if not board_system or not board_system.board:
		return

	# Find active beasts that haven't ascended
	var beasts: Array[GuestInstance] = []
	for guest in board_system.active_guests:
		if guest.is_mythical_beast() and not guest.is_exiting and not guest.are_all_needs_fulfilled():
			beasts.append(guest)

	if beasts.is_empty():
		return

	var interaction_events: Array = []
	for beast in beasts:
		var events = _resolve_beast_interactions(beast)
		interaction_events.append_array(events)

	if interaction_events.is_empty():
		return

	await AnimationCoordinator.play_batch()

	for event in interaction_events:
		EventBus.beast_interacted.emit(event.beast, event.guest)

	await _flush_and_sweep()


func _get_guest_path(guest: GuestInstance) -> Path:
	## Get the path a guest is on.
	if not board_system or not board_system.board:
		return null

	# Find path containing guest's current tile
	if guest.current_tile:
		for path in board_system.board.paths:
			for tile in path.tiles:
				if tile.position == guest.current_tile.position:
					return path

	# Default to first path
	if board_system.board.paths.size() > 0:
		return board_system.board.paths[0]

	return null


func _handle_guest_exit(guest: GuestInstance) -> void:
	## Handle a guest reaching the end of their path.
	## Called during movement phase - queues animations only.
	guest.is_exiting = true
	if guest.are_all_needs_fulfilled():
		_queue_guest_animation(guest, "create_ascend_animation")
		guest.set_meta("exit_type", "ascend")
	else:
		_queue_guest_animation(guest, "create_descend_animation")
		guest.set_meta("exit_type", "descended")


func _resolve_beast_interactions(beast: GuestInstance) -> Array:
	## Resolve a beast's interactions with regular guests on the same tile.
	## Fires on_encounter skills on the beast for each eligible guest.
	## Returns array of interaction event dicts. Queues animations, does NOT emit events.
	var events: Array = []

	if not trigger_system:
		return events

	# Find eligible guests on the same tile
	var guests_on_tile = board_system.get_guests_at(beast.current_tile.position)

	for guest in guests_on_tile:
		# Skip self, other beasts, guests in stalls, already interacted guests
		if guest == beast:
			continue
		if guest.is_mythical_beast():
			continue
		if guest.is_in_stall:
			continue
		if guest.interacted_this_turn:
			continue

		# Fire on_pre_encounter (guest's skills can modify encounter)
		var encounter_result = _resolve_pre_encounter(beast, guest)
		if encounter_result.get("blocked", false):
			continue

		# Fire on_encounter skills (beast's skills, with guest as target)
		var context = TriggerContext.create("on_encounter")
		context.with_guest(guest)
		context.with_source(beast)
		context.with_target(guest)
		context.encounter_result = encounter_result

		var results = trigger_system.trigger_entity_skills("on_encounter", context, [beast])

		# Check if any effect succeeded (e.g. fulfill_need found a valid need)
		var any_succeeded = false
		for result in results:
			if result.success:
				any_succeeded = true
				break

		if any_succeeded:
			# Decrement beast's interact need
			beast.fulfill_need("interact", 1)

			# Mark guest as interacted
			guest.interacted_this_turn = true

			events.append({
				"beast": beast,
				"guest": guest,
			})

			# Beast satisfied — ascend will be handled by flush_and_sweep
			if beast.are_all_needs_fulfilled():
				break

	return events


func _execute_stall_entry() -> void:
	## STALL_ENTRY: Guests enter adjacent stalls.
	_set_phase(Phase.STALL_ENTRY)

	if not board_system:
		return

	var entries: Array = []  # [{guest, stall}]
	var entering_guests: Array[GuestInstance] = []  # For skip list

	# FIRST PASS: Determine which guests enter which stalls (state changes only)
	for guest in board_system.active_guests:
		if guest.is_in_stall:
			continue
		if guest.is_mythical_beast():
			continue
		if guest.interacted_this_turn:
			continue

		if not guest.current_tile:
			continue

		var adjacent_stalls = board_system.get_stalls_adjacent_to(guest.current_tile.position)

		for stall in adjacent_stalls:
			if stall.can_serve_guest(guest):
				var entry_result = _resolve_pre_enter_stall(guest, stall)
				if entry_result.get("blocked", false):
					_queue_guest_animation(guest, "create_entry_blocked_animation")
					continue

				# Update logical state
				guest.is_in_stall = true
				guest.current_stall = stall
				stall.add_occupant(guest)

				entries.append({"guest": guest, "stall": stall})
				entering_guests.append(guest)
				break

	# SECOND PASS: Queue entry animations with correct slot positions
	for entry in entries:
		var guest = entry.guest
		var stall = entry.stall
		if board_visual:
			var entity = board_visual.get_guest_entity(guest)
			if entity:
				# Use stall slot position (accounts for other guests in stall)
				var target_pos = TileOccupancyManager.get_stall_slot_position_for_guest(guest, stall)
				AnimationCoordinator.queue(entity.create_enter_stall_animation(target_pos))

	# Queue repositioning for vacated path tiles and other stall occupants (skip entering guests)
	TileOccupancyManager.queue_all_repositions(entering_guests)

	# Play entry animations
	await AnimationCoordinator.play_batch()

	# Emit entry events (on_enter_stall skills fire here, may queue animations)
	for entry in entries:
		EventBus.guest_entered_stall.emit(entry.guest, entry.stall)

	# Flush entry-skill animations
	await AnimationCoordinator.play_batch()

	# Process service for all entries (state + queue fulfillment animations)
	var service_events: Array = []

	for entry in entries:
		var guest = entry.guest
		var stall = entry.stall

		if stall.get_operation_model() == "product":
			var service_result = _resolve_pre_serve(guest, stall)

			if service_result.get("blocked", false):
				_queue_guest_animation(guest, "create_service_blocked_animation")
				service_events.append({
					"guest": guest,
					"stall": stall,
					"need_type": stall.resolve_need_type_for_guest(guest),
					"fulfilled": 0,
					"blocked": true
				})
			else:
				var service_data = _complete_service(guest, stall, service_result)
				service_events.append(service_data)

			if guest in board_system.active_guests:
				guest.service_turns_remaining = 1
		elif stall.get_operation_model() == "bulk_service":
			_handle_bulk_service_entry(guest, stall)
		else:
			BoardSystem.reset_guest_service(guest)

	# Play service animations
	await AnimationCoordinator.play_batch()

	# Emit service events after animations complete
	for event in service_events:
		if event.get("blocked", false):
			continue
		if event.fulfilled > 0:
			EventBus.guest_need_fulfilled.emit(event.guest, event.need_type, event.fulfilled, event.stall)
		EventBus.guest_served.emit(event.guest, event.stall)
		if event.get("stall_depleted", false):
			EventBus.stall_depleted.emit(event.stall)

	# Flush & sweep: play skill-effect animations, ascend newly-satisfied guests
	await _flush_and_sweep()

	# Check level completion after ascensions
	_check_level_complete()


func _execute_guest_spawn() -> void:
	## GUEST_SPAWN: Spawn next guest from queue.
	_set_phase(Phase.GUEST_SPAWN)

	if not board_system:
		return

	# Spawn regular guest from main queue
	var guest = board_system.spawn_next_from_queue()
	if guest:
		var skip: Array[GuestInstance] = [guest]
		TileOccupancyManager.queue_all_repositions(skip)
		await AnimationCoordinator.play_batch()

		# Emit event AFTER animations
		EventBus.guest_spawned.emit(guest)

		# Flush & sweep: play skill-effect animations, ascend newly-satisfied guests
		await _flush_and_sweep()

	# Check for midnight: core guests depleted past threshold
	if not _midnight_emitted:
		var core_remaining: int = 0
		for guest_def in board_system.guest_queue:
			if guest_def.is_core_guest:
				core_remaining += 1
		var threshold_count: int = int(floor(_initial_core_guest_count * midnight_threshold_fraction))
		if core_remaining <= threshold_count:
			_midnight_emitted = true
			EventBus.midnight_reached.emit()
			await _flush_and_sweep()

	# Spawn beast from beast queue (after midnight)
	if _midnight_emitted:
		var beast = board_system.spawn_next_beast_from_queue()
		if beast:
			var beast_skip: Array[GuestInstance] = [beast]
			TileOccupancyManager.queue_all_repositions(beast_skip)
			await AnimationCoordinator.play_batch()

			EventBus.guest_spawned.emit(beast)

			await _flush_and_sweep()


func _execute_player_action() -> void:
	## PLAYER_ACTION: Wait for player input.
	_set_phase(Phase.PLAYER_ACTION)
	waiting_for_player = true
	# Execution pauses here until player_action_complete() is called


func _execute_turn_end() -> void:
	## TURN_END: Trigger on_turn_end skills.
	_set_phase(Phase.TURN_END)
	EventBus.turn_ended.emit(current_turn)

	# Flush & sweep: play skill-effect animations, ascend newly-satisfied guests
	await _flush_and_sweep()



func _check_level_complete() -> void:
	## Check if level is complete (no core guests remaining on board or in queue).
	if _level_complete_emitted:
		return

	if not _has_core_guests_remaining():
		_level_complete_emitted = true
		if GameManager.reputation > 0:
			GameManager.record_level_completed()
			EventBus.level_won.emit()
		# Note: level_lost is emitted when reputation hits 0, not here


func _has_core_guests_remaining() -> bool:
	## Returns true if any core guests are still in the spawn queue or on the board.
	if not board_system:
		return false
	for guest_def in board_system.guest_queue:
		if guest_def.is_core_guest:
			return true
	for guest in board_system.active_guests:
		if guest.is_core_guest():
			return true
	return false


