class_name BaseInstance
extends RefCounted

## Base class for all runtime instances.
## Instances hold mutable state and reference immutable definitions.

var definition: BaseDefinition
var instance_id: String
var modifier_stack: ModifierStack
var status_effects: Array  # Array of StatusEffectInstance
var skill_instances: Array  # Array of SkillInstance
var persistent_state: Dictionary  # General-purpose persistent key-value store


func _init(def: BaseDefinition = null) -> void:
	if def:
		definition = def
	instance_id = _generate_instance_id()
	modifier_stack = ModifierStack.new()
	status_effects = []
	skill_instances = []
	persistent_state = {}


func get_stat(stat_name: String, base_value: Variant) -> Variant:
	## Calculate a stat value with all modifiers applied.
	return modifier_stack.calculate_stat(stat_name, base_value)


func add_status_effect(effect) -> void:  # StatusEffectInstance
	status_effects.append(effect)


func remove_status_effect(effect) -> void:  # StatusEffectInstance
	status_effects.erase(effect)
	modifier_stack.remove_modifiers_from_source(effect)


func has_status(status_id: String) -> bool:
	for effect in status_effects:
		if effect and effect.definition and effect.definition.id == status_id:
			return true
	return false


func get_status(status_id: String):  # -> StatusEffectInstance or null
	for effect in status_effects:
		if effect and effect.definition and effect.definition.id == status_id:
			return effect
	return null


func get_entity_type() -> String:
	## Override in subclasses
	return "base"


func _generate_instance_id() -> String:
	return "%s_%d_%d" % [get_entity_type(), Time.get_ticks_msec(), randi()]
