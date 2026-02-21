# src/systems/status_effect_system.gd
class_name StatusEffectSystem
extends Node

## Manages status effect lifecycle: apply, tick, remove.
## Processes on_turn_end_effects (stack decay) and handles cleanup.

var trigger_system = null  # Set externally
var board_visual: BoardVisual = null  # Set externally (for tick visuals)

# Entities with active status effects — avoids scanning BoardSystem
var _tracked_entities: Array[BaseInstance] = []


func set_trigger_system(system) -> void:
	trigger_system = system


func set_board_visual(visual: BoardVisual) -> void:
	board_visual = visual


func _ready() -> void:
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.guest_ascended.connect(_on_guest_exiting)
	EventBus.guest_descended.connect(_on_guest_exiting)
	EventBus.guest_banished.connect(_on_guest_exiting)


# =============================================================================
# Public API
# =============================================================================

func apply_status(target: BaseInstance, status_id: String, stacks: int = 1) -> StatusEffectInstance:
	## Apply a status effect to an entity. Handles stacking with existing effects.
	## State only: does NOT emit events or queue visuals. Caller handles both.
	## Returns the StatusEffectInstance (new or existing), or null on failure.
	var status_def = ContentRegistry.get_definition("status_effects", status_id)
	if not status_def:
		push_warning("StatusEffectSystem: status not found: %s" % status_id)
		return null

	# Validate applicability
	var entity_type = target.get_entity_type()
	if not status_def.applicable_to.is_empty() and entity_type not in status_def.applicable_to:
		push_warning("StatusEffectSystem: %s not applicable to %s" % [status_id, entity_type])
		return null

	# Check for existing
	var existing = target.get_status(status_id)
	if existing:
		existing.add_stacks(stacks)
		return existing

	# Create new
	var instance = StatusEffectInstance.new(status_def, target)
	if stacks > 1:
		instance.stacks = mini(stacks, status_def.max_stacks)
	instance.apply_modifiers()
	instance.grant_skills(trigger_system)
	target.add_status_effect(instance)

	# Track entity
	if target not in _tracked_entities:
		_tracked_entities.append(target)

	return instance


func remove_status(target: BaseInstance, status_id: String) -> void:
	## Fully remove a status effect from an entity.
	## State only: does NOT emit events or queue visuals. Caller handles both.
	var existing = target.get_status(status_id)
	if not existing:
		return

	existing.on_remove(trigger_system)
	target.remove_status_effect(existing)

	# Untrack entity if no effects remain
	if target.status_effects.is_empty():
		_tracked_entities.erase(target)


func remove_status_instance(target: BaseInstance, instance: StatusEffectInstance) -> void:
	## Remove a specific status effect instance.
	## State only: does NOT emit events or queue visuals. Caller handles both.
	instance.on_remove(trigger_system)
	target.remove_status_effect(instance)

	# Untrack entity if no effects remain
	if target.status_effects.is_empty():
		_tracked_entities.erase(target)


# =============================================================================
# Turn Tick
# =============================================================================

func _on_guest_exiting(guest) -> void:
	## Clean up all status effects when a guest leaves the board.
	## No visual needed — entity is being removed.
	var effects = guest.status_effects.duplicate()
	for effect in effects:
		remove_status_instance(guest, effect)
		EventBus.status_removed.emit(guest, effect)


func _on_turn_ended(_turn_number: int) -> void:
	_tick_all_status_effects()


func _tick_all_status_effects() -> void:
	## Process on_turn_end_effects for all active status effects.
	## Collects removals first, queues visuals for all changes, then processes removals.
	## Visual-only: no new events emitted for tick-based stack decay.
	var to_remove: Array = []

	for entity in _tracked_entities.duplicate():
		var effects = entity.status_effects.duplicate()
		for effect in effects:
			if not effect or not effect.definition:
				continue

			var old_stacks = effect.stacks
			var should_remove = _tick_effect(effect)

			if should_remove:
				to_remove.append({"target": entity, "instance": effect})
				var vis_entity = _get_visual_entity(entity)
				if vis_entity:
					AnimationCoordinator.queue(vis_entity.create_status_removed_animation(effect.definition))
			elif effect.stacks != old_stacks:
				var delta = effect.stacks - old_stacks
				var vis_entity = _get_visual_entity(entity)
				if vis_entity:
					AnimationCoordinator.queue(vis_entity.create_status_stacks_changed_animation(effect.definition, delta))

	# Process removals (state cleanup + events)
	for removal in to_remove:
		remove_status_instance(removal.target, removal.instance)
		EventBus.status_removed.emit(removal.target, removal.instance)


func _tick_effect(effect: StatusEffectInstance) -> bool:
	## Process one tick of a status effect. Returns true if it should be removed.
	if effect.definition.stack_type != "time":
		return false

	# Process on_turn_end_effects
	for effect_data in effect.definition.on_turn_end_effects:
		var effect_type = effect_data.get("type", "")
		match effect_type:
			"remove_stacks":
				var amount = effect_data.get("amount", 1)
				var should_remove = effect.remove_stacks(amount)
				if should_remove:
					return true

	return false


func _get_visual_entity(target: BaseInstance) -> Node2D:
	## Get the visual entity for a guest or stall instance.
	if not board_visual:
		return null
	if target is GuestInstance:
		return board_visual.get_guest_entity(target)
	elif target is StallInstance:
		return board_visual.get_stall_entity(target.board_position)
	return null
