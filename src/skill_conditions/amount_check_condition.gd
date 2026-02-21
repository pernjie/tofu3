# src/skill_conditions/amount_check_condition.gd
class_name AmountCheckCondition
extends SkillCondition

## Compares the trigger context's amount against a threshold.
##
## Condition data:
##   type: "amount_check"
##   comparison: "greater_than", "less_than", "equal", "greater_or_equal", "less_or_equal"
##   value: int or "{parameter_name}"


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var threshold = resolve_int_parameter("value", skill, 0)
	var comparison = condition_data.get("comparison", "equal")

	match comparison:
		"greater_than":
			return context.amount > threshold
		"less_than":
			return context.amount < threshold
		"equal":
			return context.amount == threshold
		"greater_or_equal":
			return context.amount >= threshold
		"less_or_equal":
			return context.amount <= threshold
		_:
			push_warning("AmountCheckCondition: unknown comparison '%s'" % comparison)
			return false
