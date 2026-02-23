# src/autoload/board_system.gd
extends Node

## Runtime state manager for the game board.
## Tracks active entities, tokens, and provides entity queries.

# Board state
var board: Board = null
var level_definition: LevelDefinition = null

# Entity tracking
var active_guests: Array[GuestInstance] = []
var stalls: Dictionary = {}  # Vector2i -> StallInstance
var relics: Dictionary = {}  # Vector2i -> RelicInstance (persists across levels)
var guest_queue: Array = []  # Array of GuestDefinition (remaining to spawn)
var beast_queue: Array = []  # Array of GuestDefinition (beasts waiting to spawn after midnight)

# Note: Economy (tokens, reputation) is managed by GameManager.
# BoardSystem provides convenience methods that delegate to GameManager.

# References to other systems
var trigger_system: TriggerSystem = null
var status_effect_system: StatusEffectSystem = null
var board_visual: BoardVisual = null
var aura_system = null
var deck_system: DeckSystem = null


func _ready() -> void:
	pass


func set_trigger_system(system: TriggerSystem) -> void:
	trigger_system = system


func set_status_effect_system(system: StatusEffectSystem) -> void:
	status_effect_system = system


func set_board_visual(visual: BoardVisual) -> void:
	board_visual = visual


func set_aura_system(system) -> void:
	aura_system = system


func set_deck_system(system: DeckSystem) -> void:
	deck_system = system


# =============================================================================
# Level Setup
# =============================================================================

func setup_level(level_def: LevelDefinition, initial_queue: Array = []) -> void:
	## Initialize board for a new level.
	clear_level()

	level_definition = level_def

	# Create board from level data
	if level_def.board:
		board = Board.from_dict(level_def.board)

	# Set up guest queue
	guest_queue = initial_queue.duplicate()

	# Restore persistent relics from previous levels
	restore_relics()


func clear_level() -> void:
	## Clear all level state. Relics persist across levels.
	# Unregister all entity skills
	if trigger_system:
		for guest in active_guests:
			trigger_system.unregister_entity_skills(guest)
		for stall in stalls.values():
			trigger_system.unregister_entity_skills(stall)
		for relic in relics.values():
			trigger_system.unregister_entity_skills(relic)

	# Clear all aura effects
	if aura_system:
		aura_system.clear_all()

	board = null
	level_definition = null
	active_guests.clear()
	stalls.clear()
	guest_queue.clear()
	beast_queue.clear()
	# Note: relics dict is NOT cleared — relics persist across levels


# =============================================================================
# Guest Management
# =============================================================================

func spawn_guest(guest_def: GuestDefinition, path_id: String = "", spawn_index: int = -1) -> GuestInstance:
	## Create and spawn a guest on the board.
	## Handles state + entity creation + spawn animation.
	## Does NOT emit guest_spawned or reposition — caller controls timing.
	## Most callers should use summon_guest() instead.
	## If spawn_index >= 0, guest spawns at that path index instead of index 0.
	var guest = GuestInstance.new(guest_def)

	# Find path to spawn on
	var path: Path = null
	if path_id.is_empty() and board and board.paths.size() > 0:
		path = board.paths[0]
	elif board:
		path = board.get_path_by_id(path_id)

	if path:
		if spawn_index >= 0:
			guest.path_index = spawn_index
			guest.current_tile = path.get_tile_at_index(spawn_index)
		elif guest_def.spawn_at_exit:
			guest.path_index = path.get_length() - 1
			guest.current_tile = path.get_exit_tile()
		else:
			guest.current_tile = path.get_spawn_tile()
			guest.path_index = 0

	active_guests.append(guest)

	# Register skills with trigger system
	if trigger_system:
		trigger_system.register_entity_skills(guest)

	# Entity creation + animation
	if board_visual:
		board_visual.add_guest_entity(guest)
		var entity = board_visual.get_guest_entity(guest)
		if entity and guest.current_tile:
			var target_pos = TileOccupancyManager.get_slot_position_for_guest(
				guest, guest.current_tile.position)
			AnimationCoordinator.queue(entity.create_spawn_animation(target_pos))

	return guest


func spawn_next_from_queue(path_id: String = "") -> GuestInstance:
	## Spawn the next guest from the queue.
	if guest_queue.is_empty():
		return null

	var guest_def = guest_queue.pop_front()
	return spawn_guest(guest_def, path_id)


func spawn_next_beast_from_queue(path_id: String = "") -> GuestInstance:
	## Spawn the next beast from the beast queue.
	if beast_queue.is_empty():
		return null

	var beast_def = beast_queue.pop_front()
	return spawn_guest(beast_def, path_id)


func summon_guest(guest_def: GuestDefinition, path_id: String = "", spawn_index: int = -1) -> GuestInstance:
	## Spawn a guest, reposition others, and emit guest_spawned.
	## For use by skill effects and debug console.
	## TurnSystem phases should NOT use this — they control animation timing directly.
	var guest = spawn_guest(guest_def, path_id, spawn_index)
	if not guest:
		return null
	var skip: Array[GuestInstance] = [guest]
	TileOccupancyManager.queue_all_repositions(skip)
	EventBus.guest_spawned.emit(guest)
	return guest


func summon_guest_with_overrides(guest_def: GuestDefinition, path_id: String, spawn_index: int,
		needs_override: Dictionary, money_override: int) -> GuestInstance:
	## Spawn a guest from a definition with overridden needs/money.
	## Creates instance from definition (preserving skills), then overrides stats.
	## Handles entity creation, reposition, and guest_spawned event.
	var guest = spawn_guest(guest_def, path_id, spawn_index)
	if not guest:
		return null

	# Override stats on the mutable instance
	guest.current_needs = needs_override.duplicate()
	guest.initial_needs = needs_override.duplicate()
	guest.current_money = money_override

	# Refresh entity display to show overridden stats
	if board_visual:
		var entity = board_visual.get_guest_entity(guest)
		if entity:
			entity.refresh()

	# Reposition + emit (same as summon_guest)
	var skip: Array[GuestInstance] = [guest]
	TileOccupancyManager.queue_all_repositions(skip)
	EventBus.guest_spawned.emit(guest)
	return guest


func remove_guest(guest: GuestInstance) -> void:
	## Remove a guest from the board.
	if trigger_system:
		trigger_system.unregister_entity_skills(guest)

	# Remove from stall if in one
	if guest.is_in_stall and guest.current_stall:
		guest.current_stall.remove_occupant(guest)

	active_guests.erase(guest)


func banish_guest(guest: GuestInstance) -> bool:
	## Mark a guest for banishment and queue the banish animation.
	## Returns false if the banishment was blocked or the guest is already exiting.
	## Does NOT emit events or play batch — _flush_and_sweep handles the lifecycle.
	## Stall cleanup is NOT done here — remove_guest() handles it when called by the sweep.
	## Fires on_pre_banish trigger — skills can block the banishment.
	if guest.is_exiting:
		return false

	# Fire pre-banish trigger to allow interception
	if trigger_system:
		var pre_context = TriggerContext.create("on_pre_banish")
		pre_context.with_guest(guest)
		pre_context.with_source(guest)
		pre_context.with_banish_result()
		trigger_system.trigger_entity_skills("on_pre_banish", pre_context, [guest])

		if pre_context.banish_result.get("blocked", false):
			if board_visual:
				var entity = board_visual.get_guest_entity(guest)
				if entity:
					AnimationCoordinator.queue(entity.create_banish_blocked_animation())
			return false

	guest.is_exiting = true
	guest.is_banished = true

	if board_visual:
		var entity = board_visual.get_guest_entity(guest)
		if entity:
			AnimationCoordinator.queue(entity.create_banish_animation())

	return true


func advance_guest_on_path(guest: GuestInstance, path: Path, steps: int = 1, direction: int = 1) -> bool:
	## Move guest along their path. Returns false if guest reached their end.
	## direction: 1 = forward (spawn->exit), -1 = reverse (exit->spawn).
	## Updates logical state only - no events emitted.
	## Note: Guest moves as far as possible, even if that's fewer steps than requested.
	var reached_end = false

	for i in range(steps):
		var next_index = path.get_next_index(guest.path_index, direction)
		if next_index == -1:
			# Can't move further - guest is at the end of the path
			reached_end = true
			break
		guest.path_index = next_index

	# Always update current_tile to match path_index
	var new_tile = path.get_tile_at_index(guest.path_index)
	if new_tile:
		guest.current_tile = new_tile

	return not reached_end


# =============================================================================
# Stall Management
# =============================================================================

func place_stall(stall_def: StallDefinition, pos: Vector2i) -> StallInstance:
	## Place a new stall: state + data display + animation.
	## Does NOT emit events or play batch — caller controls timing.
	## For place-or-upgrade with events, use deploy_stall().
	if stalls.has(pos):
		push_warning("Cannot place stall at %s - position occupied by stall" % pos)
		return null

	if relics.has(pos):
		push_warning("Cannot place stall at %s - position occupied by relic" % pos)
		return null

	if not board or not board.can_place_at(pos):
		push_warning("Cannot place stall at %s" % pos)
		return null

	var stall = StallInstance.new(stall_def)
	# Create a tile for the stall position (stalls are off-path)
	var stall_tile = Tile.new()
	stall_tile.position = pos
	stall.tile = stall_tile
	stall.board_position = pos

	stalls[pos] = stall

	# Register skills with trigger system
	if trigger_system:
		trigger_system.register_entity_skills(stall)

	# Data display: create entity
	if board_visual:
		board_visual.add_stall_entity(stall, pos)

	return stall


func upgrade_stall(stall: StallInstance) -> StallInstance:
	## Upgrade a stall to the next tier: state + data display + animation.
	## Does NOT emit events or play batch — caller controls timing.
	if not stall.can_upgrade():
		push_warning("Stall %s already at max tier" % stall.definition.id)
		return null

	stall.upgrade()

	# Data display: refresh entity
	if board_visual and stall.tile:
		board_visual.refresh_stall(stall.tile.position)

	return stall


func deploy_stall(stall_def: StallDefinition, pos: Vector2i) -> StallInstance:
	## Convenience: place or upgrade stall + emit appropriate event.
	## For game.gd and skill effects. Does NOT play batch.
	if stalls.has(pos):
		var existing = stalls[pos]
		if existing.definition.id == stall_def.id:
			var stall = upgrade_stall(existing)
			if stall:
				EventBus.stall_upgraded.emit(stall, stall.current_tier)
			return stall
		push_warning("Cannot place %s at %s - different stall type exists" % [stall_def.id, pos])
		return null

	var stall = place_stall(stall_def, pos)
	if stall:
		EventBus.stall_placed.emit(stall, stall.tile)
	return stall


# =============================================================================
# Relic Management
# =============================================================================

func place_relic(relic_def: RelicDefinition, pos: Vector2i) -> RelicInstance:
	## Place a new relic: state + visual. Does NOT emit events.
	if stalls.has(pos):
		push_warning("Cannot place relic at %s - position occupied by stall" % pos)
		return null

	if relics.has(pos):
		push_warning("Cannot place relic at %s - position occupied by relic" % pos)
		return null

	if not board or not board.can_place_at(pos):
		push_warning("Cannot place relic at %s" % pos)
		return null

	var relic = RelicInstance.new(relic_def)
	var relic_tile = Tile.new()
	relic_tile.position = pos
	relic.tile = relic_tile
	relic.board_position = pos

	relics[pos] = relic

	# Register skills with trigger system
	if trigger_system:
		trigger_system.register_entity_skills(relic)

	# Create visual entity
	if board_visual:
		board_visual.add_relic_entity(relic, pos)

	return relic


func deploy_relic(relic_def: RelicDefinition, pos: Vector2i) -> RelicInstance:
	## Place relic + emit relic_placed event.
	var relic = place_relic(relic_def, pos)
	if relic:
		EventBus.relic_placed.emit(relic, relic.tile)
	return relic


func restore_relics() -> void:
	## Re-register skills and recreate visuals for all persistent relics.
	## Called during setup_level() after board is created.
	for pos in relics:
		var relic = relics[pos]
		# Update tile reference to match new board
		var relic_tile = Tile.new()
		relic_tile.position = pos
		relic.tile = relic_tile

		# Restore persistent state from RunState
		if GameManager.current_run and GameManager.current_run.relics_on_board.has(pos):
			var saved = GameManager.current_run.relics_on_board[pos]
			if saved is Dictionary and saved.has("persistent_state"):
				relic.persistent_state = saved["persistent_state"].duplicate(true)

		# Reset skill state so per-level counters start fresh
		for skill in relic.skill_instances:
			skill.reset_state()

		if trigger_system:
			trigger_system.register_entity_skills(relic)
		if board_visual:
			board_visual.add_relic_entity(relic, pos)


func get_relic_at(pos: Vector2i) -> RelicInstance:
	## Get the relic at a position, or null.
	return relics.get(pos, null)


func get_all_relics() -> Array[RelicInstance]:
	## Get all placed relics.
	var result: Array[RelicInstance] = []
	for relic in relics.values():
		result.append(relic)
	return result


# =============================================================================
# Action Methods (state + data display + animation)
# =============================================================================

func reset_guest_service(guest: GuestInstance) -> bool:
	## Reset a guest's service timer to full duration.
	## Does NOT emit events or play batch — caller controls timing.
	if not guest.is_in_stall or not guest.current_stall:
		return false

	var stall = guest.current_stall
	var base_duration = stall.get_service_duration()
	var duration_multiplier = guest.get_stat("service_duration_multiplier", 1)
	guest.service_turns_remaining = int(base_duration * duration_multiplier)

	return true


func fulfill_guest_need(guest: GuestInstance, need_type: String, amount: int, source: BaseInstance = null) -> int:
	## Fulfill a guest's need: state mutation + data display + animation.
	## Fires on_pre_fulfill triggers for universal fulfillment interception.
	## Does NOT emit events or play batch — caller controls timing.
	## Returns the amount actually fulfilled.

	# Fire on_pre_fulfill triggers
	var context = TriggerContext.create("on_pre_fulfill")
	context.with_guest(guest)
	context.with_need_type(need_type)
	context.with_amount(amount)
	context.with_target(guest)
	context.with_fulfillment_result()
	if source:
		context.with_source(source)

	var entities: Array[BaseInstance] = [guest]
	if source and source != guest:
		entities.append(source)
	TriggerSystem.trigger_entity_skills("on_pre_fulfill", context, entities)

	# Check blocked
	if context.fulfillment_result.get("blocked", false):
		return 0

	# Apply modifiers to amount
	var modified = int(amount * context.fulfillment_result.get("fulfillment_multiplier", 1.0))
	modified += context.fulfillment_result.get("fulfillment_bonus", 0)
	modified = max(modified, 0)

	var fulfilled = guest.fulfill_need(need_type, modified)
	if fulfilled > 0 and board_visual:
		var entity = board_visual.get_guest_entity(guest)
		if entity:
			entity.refresh()
			AnimationCoordinator.queue(entity.create_need_fulfilled_animation(fulfilled, need_type))
	return fulfilled


func restock_stall(stall: StallInstance) -> bool:
	## Restock a stall: state mutation + data display + animation.
	## Does NOT emit events or play batch — caller controls timing.
	if stall.get_operation_model() != "product":
		return false
	stall.restock()
	stall.restock_cooldown = 0
	if board_visual:
		var entity = board_visual.get_stall_entity(stall.board_position)
		if entity:
			entity.update_labels()
			AnimationCoordinator.queue(entity.create_restock_animation())
	return true


func get_entity_for_target(target: BaseInstance) -> Node2D:
	## Get the visual entity for a guest, stall, or relic instance.
	if not board_visual:
		return null
	if target is GuestInstance:
		return board_visual.get_guest_entity(target)
	elif target is StallInstance:
		return board_visual.get_stall_entity(target.board_position)
	elif target is RelicInstance:
		return board_visual.get_relic_entity(target.board_position)
	return null


func apply_status_effect(target: BaseInstance, status_id: String, stacks: int = 1) -> StatusEffectInstance:
	## Apply a status effect: state + data display + animation.
	## Does NOT emit events or play batch — caller controls timing.
	if not status_effect_system:
		push_warning("BoardSystem: status_effect_system not set")
		return null

	var had_existing = target.has_status(status_id)
	var old_stacks = target.get_status(status_id).stacks if had_existing else 0

	var instance = status_effect_system.apply_status(target, status_id, stacks)
	if not instance:
		return null

	# Visual feedback
	var entity = get_entity_for_target(target)
	if entity:
		entity.refresh()
		if had_existing:
			var delta = instance.stacks - old_stacks
			if delta != 0:
				AnimationCoordinator.queue(entity.create_status_stacks_changed_animation(instance.definition, delta))
		else:
			AnimationCoordinator.queue(entity.create_status_applied_animation(instance.definition, instance.stacks))

	return instance


func remove_status_effect(target: BaseInstance, status_id: String) -> void:
	## Remove a status effect: state + data display + animation.
	## Does NOT emit events or play batch — caller controls timing.
	if not status_effect_system:
		push_warning("BoardSystem: status_effect_system not set")
		return

	var existing = target.get_status(status_id)
	if not existing:
		return

	var status_def = existing.definition

	status_effect_system.remove_status(target, status_id)

	# Visual feedback
	var entity = get_entity_for_target(target)
	if entity:
		entity.refresh()
		AnimationCoordinator.queue(entity.create_status_removed_animation(status_def))


func inflict_status(target: BaseInstance, status_id: String, stacks: int = 1) -> StatusEffectInstance:
	## Convenience: apply_status_effect + emit appropriate event.
	## For skill effects and debug console. Does NOT play batch.
	## Fires on_pre_status trigger — skills can block the application.

	# Fire pre-status trigger to allow interception
	var status_def = ContentRegistry.get_definition("status_effects", status_id)
	if status_def and trigger_system:
		var pre_context = TriggerContext.create("on_pre_status")
		pre_context.with_target(target)
		if target is GuestInstance:
			pre_context.with_guest(target)
		pre_context.with_extra("status_definition", status_def)
		pre_context.with_status_result()
		trigger_system.trigger_entity_skills("on_pre_status", pre_context, [target])

		if pre_context.status_result.get("blocked", false):
			if board_visual and target is GuestInstance:
				var entity = board_visual.get_guest_entity(target)
				if entity:
					AnimationCoordinator.queue(entity.create_status_blocked_animation(status_def))
			return null

	var existing = target.get_status(status_id)
	var old_stacks = existing.stacks if existing else 0

	var instance = apply_status_effect(target, status_id, stacks)
	if not instance:
		return null

	if existing:
		EventBus.status_stack_changed.emit(instance, old_stacks, instance.stacks)
	else:
		EventBus.status_applied.emit(target, instance)

	return instance


func revoke_status(target: BaseInstance, status_id: String) -> void:
	## Convenience: remove_status_effect + emit event.
	## For skill effects and debug console. Does NOT play batch.
	var existing = target.get_status(status_id)
	if not existing:
		return

	remove_status_effect(target, status_id)
	EventBus.status_removed.emit(target, existing)


func fulfill_and_notify(guest: GuestInstance, need_type: String, amount: int, source) -> int:
	## Convenience: fulfill_guest_need + emit guest_need_fulfilled.
	## For skill effects. Does NOT play batch.
	var fulfilled = fulfill_guest_need(guest, need_type, amount, source)
	if fulfilled > 0:
		EventBus.guest_need_fulfilled.emit(guest, need_type, fulfilled, source)
	return fulfilled


func restock_and_notify(stall: StallInstance) -> bool:
	## Convenience: restock_stall + emit stall_restocked.
	## For skill effects and debug console. Does NOT play batch.
	if not restock_stall(stall):
		return false
	EventBus.stall_restocked.emit(stall)
	return true


# =============================================================================
# Entity Queries
# =============================================================================

func get_guests_at(pos: Vector2i) -> Array[GuestInstance]:
	## Get all guests at a position.
	var result: Array[GuestInstance] = []
	for guest in active_guests:
		if guest.current_tile and guest.current_tile.position == pos:
			result.append(guest)
	return result


func get_stall_at(pos: Vector2i) -> StallInstance:
	## Get the stall at a position, or null.
	return stalls.get(pos, null)


func get_stalls_adjacent_to(pos: Vector2i) -> Array[StallInstance]:
	## Get stalls adjacent to a tile position.
	var result: Array[StallInstance] = []
	if not board:
		return result

	for adj_pos in board.get_adjacent_positions(pos):
		if stalls.has(adj_pos):
			result.append(stalls[adj_pos])

	return result


func get_stalls_in_range(center: Vector2i, range_val: int) -> Array[StallInstance]:
	## Get all stalls within Manhattan distance of center.
	var result: Array[StallInstance] = []
	for pos in stalls:
		var distance = abs(pos.x - center.x) + abs(pos.y - center.y)
		if distance <= range_val:
			result.append(stalls[pos])
	return result


func get_guests_in_range(center: Vector2i, range_val: int) -> Array[GuestInstance]:
	## Get all guests within Manhattan distance of center.
	var result: Array[GuestInstance] = []
	for guest in active_guests:
		if guest.current_tile:
			var distance = abs(guest.current_tile.position.x - center.x) + abs(guest.current_tile.position.y - center.y)
			if distance <= range_val:
				result.append(guest)
	return result


func get_all_stalls() -> Array[StallInstance]:
	## Get all placed stalls.
	var result: Array[StallInstance] = []
	for stall in stalls.values():
		result.append(stall)
	return result


func get_guests_needing(need_type: String) -> Array[GuestInstance]:
	## Get all guests that have the given need unfulfilled.
	var result: Array[GuestInstance] = []
	for guest in active_guests:
		if guest.get_remaining_need(need_type) > 0:
			result.append(guest)
	return result


# =============================================================================
# Economy (delegates to GameManager)
# =============================================================================

func add_tokens(amount: int) -> void:
	## Add tokens. Delegates to GameManager.
	GameManager.add_tokens(amount)


func spend_tokens(amount: int) -> bool:
	## Spend tokens. Delegates to GameManager.
	return GameManager.spend_tokens(amount)


func add_reputation(amount: int) -> void:
	## Change reputation. Delegates to GameManager.
	GameManager.change_reputation(amount)


func grant_bonus_plays(amount: int) -> void:
	## Increase the max plays per turn. Delegates to DeckSystem.
	if deck_system:
		deck_system.max_plays_per_turn += amount
	else:
		push_warning("BoardSystem: deck_system not set")
