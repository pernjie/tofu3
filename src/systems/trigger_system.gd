# src/systems/trigger_system.gd
extends Node

## Central orchestrator connecting EventBus signals to skill execution.
## Maintains a registry of all active skills and triggers them on relevant events.

const MAX_TRIGGER_DEPTH: int = 10

# Registry of skills by trigger type
var _skills_by_trigger: Dictionary = {}  # trigger_type -> Array[SkillInstance]
var _trigger_depth: int = 0
var pending_deferred_requests: Array = []  # Deferred effect requests awaiting UI resolution


func _ready() -> void:
	_connect_event_bus_signals()


func _connect_event_bus_signals() -> void:
	## Connect to all relevant EventBus signals.
	# Game flow
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.phase_changed.connect(_on_phase_changed)

	# Guest events
	EventBus.guest_spawned.connect(_on_guest_spawned)
	EventBus.guest_moved.connect(_on_guest_moved)
	EventBus.guest_served.connect(_on_guest_served)
	EventBus.guest_need_fulfilled.connect(_on_guest_need_fulfilled)
	EventBus.guest_ascended.connect(_on_guest_ascended)
	EventBus.guest_descended.connect(_on_guest_descended)
	EventBus.guest_banished.connect(_on_guest_banished)

	# Stall events
	EventBus.stall_placed.connect(_on_stall_placed)
	EventBus.stall_upgraded.connect(_on_stall_upgraded)
	EventBus.stall_restocked.connect(_on_stall_restocked)

	# Relic events
	EventBus.relic_placed.connect(_on_relic_placed)

	# Card events
	EventBus.card_played.connect(_on_card_played)
	EventBus.spell_cast.connect(_on_spell_cast)

	# Status events
	EventBus.status_applied.connect(_on_status_applied)
	EventBus.status_removed.connect(_on_status_removed)

	EventBus.guest_entered_stall.connect(_on_guest_entered_stall)

	# Beast events
	EventBus.beast_interacted.connect(_on_beast_interacted)

	# Midnight
	EventBus.midnight_reached.connect(_on_midnight_reached)

	# Level flow
	EventBus.level_started.connect(_on_level_started)


# =============================================================================
# Skill Registration
# =============================================================================

func register_skill(skill: SkillInstance) -> void:
	## Register a skill to be triggered on relevant events.
	if not skill or not skill.definition:
		return

	var trigger_type = skill.definition.trigger_type
	# Aura skills are managed by AuraSystem, not TriggerSystem
	if trigger_type == "aura":
		return

	if not _skills_by_trigger.has(trigger_type):
		_skills_by_trigger[trigger_type] = []

	if skill not in _skills_by_trigger[trigger_type]:
		_skills_by_trigger[trigger_type].append(skill)


func unregister_skill(skill: SkillInstance) -> void:
	## Remove a skill from the registry.
	if not skill or not skill.definition:
		return

	var trigger_type = skill.definition.trigger_type
	if _skills_by_trigger.has(trigger_type):
		_skills_by_trigger[trigger_type].erase(skill)


func register_entity_skills(entity: BaseInstance) -> void:
	## Register all skills from an entity.
	for skill in entity.skill_instances:
		register_skill(skill)


func unregister_entity_skills(entity: BaseInstance) -> void:
	## Unregister all skills from an entity.
	for skill in entity.skill_instances:
		unregister_skill(skill)


func clear_all() -> void:
	## Clear all registered skills and reset state.
	_skills_by_trigger.clear()
	_trigger_depth = 0
	pending_deferred_requests.clear()


# =============================================================================
# Skill Triggering
# =============================================================================

func trigger_skills(trigger_type: String, context: TriggerContext) -> Array[SkillEffectResult]:
	## Trigger all skills of the given type with the context.
	## Returns array of results from executed effects.
	var results: Array[SkillEffectResult] = []

	if _trigger_depth >= MAX_TRIGGER_DEPTH:
		push_warning("TriggerSystem: max recursion depth (%d) reached for '%s', skipping" % [MAX_TRIGGER_DEPTH, trigger_type])
		return results

	if not _skills_by_trigger.has(trigger_type):
		return results

	# Auto-clear deferred requests at the start of a top-level trigger call
	if _trigger_depth == 0:
		pending_deferred_requests.clear()

	_trigger_depth += 1
	for skill in _skills_by_trigger[trigger_type]:
		if not skill.is_active:
			continue

		var skill_results = _execute_skill(skill, context)
		results.append_array(skill_results)

	_trigger_depth -= 1
	return results


func trigger_entity_skills(trigger_type: String, context: TriggerContext, entities: Array) -> Array[SkillEffectResult]:
	## Trigger skills of the given type, but only those owned by the specified entities.
	## Use this for entity-specific events (spawn, move, serve) to avoid firing
	## unrelated entities' skills.
	var results: Array[SkillEffectResult] = []

	if _trigger_depth >= MAX_TRIGGER_DEPTH:
		push_warning("TriggerSystem: max recursion depth (%d) reached for '%s', skipping" % [MAX_TRIGGER_DEPTH, trigger_type])
		return results

	if not _skills_by_trigger.has(trigger_type):
		return results

	# Auto-clear deferred requests at the start of a top-level trigger call
	if _trigger_depth == 0:
		pending_deferred_requests.clear()

	_trigger_depth += 1
	for skill in _skills_by_trigger[trigger_type]:
		if not skill.is_active:
			continue

		if skill.owner not in entities and not skill.definition.global:
			continue

		var skill_results = _execute_skill(skill, context)
		results.append_array(skill_results)

	_trigger_depth -= 1
	return results


func _execute_skill(skill: SkillInstance, context: TriggerContext) -> Array[SkillEffectResult]:
	## Execute a skill if its conditions are met.
	var results: Array[SkillEffectResult] = []

	# Create condition instances and evaluate
	var conditions = SkillConditionFactory.create_all(skill.definition.conditions)
	if not SkillConditionFactory.evaluate_all(conditions, context, skill):
		return results

	# Create effect instances and execute
	var effects = SkillEffectFactory.create_all(skill.definition.effects)
	for effect in effects:
		var result = effect.execute(context, skill)
		if not result.deferred_request.is_empty():
			result.deferred_request["owner"] = skill.owner
			pending_deferred_requests.append(result.deferred_request)
		results.append(result)

	return results


# =============================================================================
# Event Handlers
# =============================================================================

func _on_turn_started(turn_number: int) -> void:
	var context = TriggerContext.create("on_turn_start")
	context.with_amount(turn_number)
	trigger_skills("on_turn_start", context)


func _on_turn_ended(turn_number: int) -> void:
	var context = TriggerContext.create("on_turn_end")
	context.with_amount(turn_number)
	trigger_skills("on_turn_end", context)


func _on_phase_changed(phase: String) -> void:
	var context = TriggerContext.create("on_phase_" + phase)
	context.with_extra("phase", phase)
	trigger_skills("on_phase_" + phase, context)


func _on_guest_spawned(guest) -> void:
	var context = TriggerContext.create("on_spawn")
	context.with_guest(guest)
	context.with_source(guest)
	trigger_entity_skills("on_spawn", context, [guest])


func _on_guest_moved(guest, from_tile, to_tile) -> void:
	var context = TriggerContext.create("on_move")
	context.with_guest(guest)
	context.with_source(guest)
	context.with_movement(from_tile, to_tile)
	trigger_entity_skills("on_move", context, [guest])


func _on_guest_served(guest, stall) -> void:
	var context = TriggerContext.create("on_serve")
	context.with_guest(guest)
	context.with_stall(stall)
	context.with_source(stall)
	context.with_target(guest)
	trigger_entity_skills("on_serve", context, [guest, stall])


func _on_guest_need_fulfilled(guest, need_type, amount, source) -> void:
	var context = TriggerContext.create("on_need_fulfilled")
	context.with_guest(guest)
	context.with_need_type(need_type)
	context.with_amount(amount)
	var entities: Array = [guest]
	if source is BaseInstance:
		context.with_source(source)
		entities.append(source)
	trigger_entity_skills("on_need_fulfilled", context, entities)


func _on_guest_ascended(guest) -> void:
	var context = TriggerContext.create("on_ascend")
	context.with_guest(guest)
	context.with_source(guest)
	trigger_entity_skills("on_ascend", context, [guest])


func _on_guest_descended(guest) -> void:
	var context = TriggerContext.create("on_descended")
	context.with_guest(guest)
	context.with_source(guest)
	trigger_entity_skills("on_descended", context, [guest])


func _on_guest_banished(guest) -> void:
	var context = TriggerContext.create("on_banish")
	context.with_guest(guest)
	context.with_source(guest)
	trigger_entity_skills("on_banish", context, [guest])


func _on_stall_placed(stall, tile) -> void:
	var context = TriggerContext.create("on_place")
	context.with_stall(stall)
	context.with_tile(tile)
	context.with_source(stall)
	trigger_entity_skills("on_place", context, [stall])


func _on_stall_upgraded(stall, new_tier) -> void:
	var context = TriggerContext.create("on_upgrade")
	context.with_stall(stall)
	context.with_source(stall)
	context.with_amount(new_tier)
	trigger_entity_skills("on_upgrade", context, [stall])


func _on_stall_restocked(stall) -> void:
	var context = TriggerContext.create("on_restock")
	context.with_stall(stall)
	context.with_source(stall)
	trigger_entity_skills("on_restock", context, [stall])


func _on_card_played(card) -> void:
	var context = TriggerContext.create("on_play")
	context.with_extra("card", card)
	trigger_skills("on_play", context)


func _on_status_applied(target, status) -> void:
	var context = TriggerContext.create("on_status_applied")
	context.with_target(target)
	context.with_extra("status", status)
	trigger_entity_skills("on_status_applied", context, [target])


func _on_status_removed(target, status) -> void:
	var context = TriggerContext.create("on_status_removed")
	context.with_target(target)
	context.with_extra("status", status)
	trigger_entity_skills("on_status_removed", context, [target])


func _on_guest_entered_stall(guest, stall) -> void:
	var context = TriggerContext.create("on_enter_stall")
	context.with_guest(guest)
	context.with_stall(stall)
	context.with_source(guest)
	trigger_entity_skills("on_enter_stall", context, [guest, stall])


func _on_relic_placed(relic, tile) -> void:
	var context = TriggerContext.create("on_place")
	context.with_tile(tile)
	context.with_source(relic)
	trigger_entity_skills("on_place", context, [relic])


func _on_beast_interacted(beast, guest) -> void:
	var context = TriggerContext.create("on_interact")
	context.with_guest(guest)
	context.with_source(beast)
	context.with_target(guest)
	trigger_entity_skills("on_interact", context, [beast, guest])


func _on_midnight_reached() -> void:
	var context = TriggerContext.create("on_midnight")
	trigger_skills("on_midnight", context)


func _on_spell_cast(spell_def: SpellDefinition, target_pos: Variant, target_entity: Variant) -> void:
	var context = TriggerContext.create("on_cast")
	context.with_extra("spell_definition", spell_def)
	context.with_extra("target_pos", target_pos)
	if target_entity is GuestInstance:
		context.with_guest(target_entity)
	elif target_entity is StallInstance:
		context.with_stall(target_entity)
	trigger_skills("on_cast", context)


func _on_level_started() -> void:
	var context = TriggerContext.create("on_level_start")
	trigger_skills("on_level_start", context)
