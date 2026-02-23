# src/skill_conditions/need_fulfillment_ratio_condition.gd
class_name NeedFulfillmentRatioCondition
extends SkillCondition

## Checks what fraction of a guest's need has been fulfilled.
## Compares (initial - remaining) / initial against a ratio threshold.
##
## Condition data:
##   type: "need_fulfillment_ratio"
##   target: "self", "target", "guest" (must be a guest)
##   need_type: string (food, joy)
##   comparison: "greater_than", "less_than", "equal", "greater_or_equal", "less_or_equal"
##   ratio: float or "{parameter_name}" (0.0 to 1.0)


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var target_str = condition_data.get("target", "self")
	var target_entity = context.resolve_target_entity(target_str, skill)

	if not target_entity:
		return false

	if not target_entity is GuestInstance:
		push_warning("NeedFulfillmentRatioCondition: target is not a guest")
		return false

	var guest = target_entity as GuestInstance
	var need_type = resolve_string_parameter("need_type", skill, "")
	if need_type.is_empty():
		push_warning("NeedFulfillmentRatioCondition: missing need_type")
		return false

	var initial = guest.initial_needs.get(need_type, 0)
	if initial <= 0:
		return false  # No such need — can't compute ratio

	var remaining = guest.get_remaining_need(need_type)
	var fulfilled_ratio = float(initial - remaining) / float(initial)

	var threshold = resolve_float_parameter("ratio", skill, 0.0)
	var comparison = condition_data.get("comparison", "greater_or_equal")

	match comparison:
		"greater_than":
			return fulfilled_ratio > threshold
		"less_than":
			return fulfilled_ratio < threshold
		"equal":
			return is_equal_approx(fulfilled_ratio, threshold)
		"greater_or_equal":
			return fulfilled_ratio >= threshold or is_equal_approx(fulfilled_ratio, threshold)
		"less_or_equal":
			return fulfilled_ratio <= threshold or is_equal_approx(fulfilled_ratio, threshold)
		_:
			push_warning("NeedFulfillmentRatioCondition: unknown comparison '%s'" % comparison)
			return false
