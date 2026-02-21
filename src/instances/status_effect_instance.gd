# src/instances/status_effect_instance.gd
class_name StatusEffectInstance
extends RefCounted

## Runtime instance of a status effect applied to an entity.
## Tracks stacks, duration, and manages stat modifiers.

var definition: StatusEffectDefinition
var target: BaseInstance  # Entity this effect is applied to
var stacks: int = 1
var source_aura = null  # Reference to aura that created this (if any)

var _applied_modifiers: Array[StatModifier] = []
var _granted_skill_instances: Array = []  # SkillInstances created by granted_skills


func _init(def: StatusEffectDefinition = null, effect_target: BaseInstance = null) -> void:
	if def:
		definition = def
		stacks = def.initial_stacks if def.initial_stacks > 0 else 1
	target = effect_target


func apply_modifiers() -> void:
	## Apply stat modifiers from this effect to the target.
	if not target or not definition:
		return

	_remove_existing_modifiers()

	for mod_data in definition.stat_modifiers:
		var modifier = _create_modifier_from_data(mod_data)
		if modifier:
			_applied_modifiers.append(modifier)
			target.modifier_stack.add_modifier(modifier)


func _remove_existing_modifiers() -> void:
	for modifier in _applied_modifiers:
		if target:
			target.modifier_stack.remove_modifier(modifier)
	_applied_modifiers.clear()


func _create_modifier_from_data(mod_data: Dictionary) -> StatModifier:
	var stat_name = mod_data.get("stat", "")
	var op_string = mod_data.get("operation", "add")
	var base_value = mod_data.get("value", 0)
	var value_per_stack = mod_data.get("value_per_stack", base_value)

	var operation: StatModifier.Operation
	match op_string:
		"add": operation = StatModifier.Operation.ADD
		"multiply": operation = StatModifier.Operation.MULTIPLY
		"set": operation = StatModifier.Operation.SET
		"add_final": operation = StatModifier.Operation.ADD_FINAL
		_: operation = StatModifier.Operation.ADD

	# Calculate value based on stacks
	var final_value = value_per_stack * stacks

	return StatModifier.new(stat_name, operation, final_value, self)


func add_stacks(amount: int) -> void:
	var old_stacks = stacks
	stacks = mini(stacks + amount, definition.max_stacks if definition else 99)
	if stacks != old_stacks:
		apply_modifiers()  # Recalculate with new stack count


func remove_stacks(amount: int) -> bool:
	## Remove stacks. Returns true if effect should be removed entirely.
	stacks = maxi(stacks - amount, 0)
	if stacks <= 0:
		_remove_existing_modifiers()
		return true
	apply_modifiers()  # Recalculate with new stack count
	return false


func on_remove(trigger_system = null) -> void:
	## Called when effect is fully removed from target.
	_remove_existing_modifiers()
	revoke_skills(trigger_system)


func grant_skills(trigger_system) -> void:
	## Create skill instances from definition's granted_skills and register them.
	## trigger_system: the TriggerSystem node (passed in to avoid autoload coupling)
	if not target or not definition:
		return

	for skill_data in definition.granted_skills:
		var skill_id = skill_data.get("skill_id", "")
		if skill_id.is_empty():
			continue

		var skill_def = ContentRegistry.get_definition("skills", skill_id)
		if not skill_def:
			push_warning("StatusEffectInstance: granted skill not found: %s" % skill_id)
			continue

		var skill_instance = SkillInstance.new(skill_def, target)

		# Apply parameter overrides at instance level (don't mutate shared definition)
		var param_overrides = skill_data.get("parameters", {})
		for param_name in param_overrides:
			skill_instance.parameter_overrides[param_name] = param_overrides[param_name]

		_granted_skill_instances.append(skill_instance)
		target.skill_instances.append(skill_instance)

		if trigger_system:
			trigger_system.register_skill(skill_instance)


func revoke_skills(trigger_system) -> void:
	## Remove all granted skill instances from target and trigger system.
	for skill_instance in _granted_skill_instances:
		if trigger_system:
			trigger_system.unregister_skill(skill_instance)
		if target:
			target.skill_instances.erase(skill_instance)

	_granted_skill_instances.clear()
