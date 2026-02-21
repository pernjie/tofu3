# src/skill_effects/modify_stat_effect.gd
class_name ModifyStatEffect
extends SkillEffect

## Modifies a stat on the target entity.
##
## Effect data:
##   type: "modify_stat"
##   target: "self", "target", "guest", "stall"
##   stat: string (stat name)
##   operation: "add", "multiply", "set", "add_final"
##   value: int/float or "{parameter_name}"


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var target_entity = resolve_target(context, skill)

	if not target_entity:
		return SkillEffectResult.failed("No valid target")

	var stat_name = effect_data.get("stat", "")
	if stat_name.is_empty():
		return SkillEffectResult.failed("No stat specified")

	var value = resolve_int_parameter("value", skill, 0)
	var op_string = effect_data.get("operation", "add")

	var operation: StatModifier.Operation
	match op_string:
		"add": operation = StatModifier.Operation.ADD
		"multiply": operation = StatModifier.Operation.MULTIPLY
		"set": operation = StatModifier.Operation.SET
		"add_final": operation = StatModifier.Operation.ADD_FINAL
		_: operation = StatModifier.Operation.ADD

	# Create and apply the modifier
	var modifier = StatModifier.new(stat_name, operation, value, skill)
	target_entity.modifier_stack.add_modifier(modifier)

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(target_entity)
	result.set_value_changed(stat_name, "base", "modified by %s %s" % [op_string, value])
	return result
