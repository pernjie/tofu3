# src/skill_conditions/need_threshold_condition.gd
class_name NeedThresholdCondition
extends SkillCondition

## Compares a guest's need value against a threshold.
##
## Condition data:
##   type: "need_threshold"
##   target: "self", "target", "guest" (must be a guest)
##   need_type: string (food, joy)
##   comparison: "greater_than", "less_than", "equal", "greater_or_equal", "less_or_equal"
##   value: int or "{parameter_name}"


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var target_str = condition_data.get("target", "self")
	var target_entity = context.resolve_target_entity(target_str, skill)

	if not target_entity:
		return false

	if not target_entity is GuestInstance:
		push_warning("NeedThresholdCondition: target is not a guest")
		return false

	var guest = target_entity as GuestInstance
	var need_type = resolve_string_parameter("need_type", skill, "")
	if need_type.is_empty():
		push_warning("NeedThresholdCondition: missing need_type")
		return false

	var current_need = guest.get_remaining_need(need_type)
	var threshold = resolve_int_parameter("value", skill, 0)
	var comparison = condition_data.get("comparison", "greater_than")

	match comparison:
		"greater_than":
			return current_need > threshold
		"less_than":
			return current_need < threshold
		"equal":
			return current_need == threshold
		"greater_or_equal":
			return current_need >= threshold
		"less_or_equal":
			return current_need <= threshold
		_:
			push_warning("NeedThresholdCondition: unknown comparison '%s'" % comparison)
			return false
