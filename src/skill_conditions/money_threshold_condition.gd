# src/skill_conditions/money_threshold_condition.gd
class_name MoneyThresholdCondition
extends SkillCondition

## Compares a guest's current money against a threshold.
##
## Condition data:
##   type: "money_threshold"
##   target: "self", "target", "guest" (must be a guest)
##   comparison: "greater_than", "less_than", "equal", "greater_or_equal", "less_or_equal"
##   value: int or "{parameter_name}"


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var target_str = condition_data.get("target", "self")
	var target_entity = context.resolve_target_entity(target_str, skill)

	if not target_entity:
		return false

	if not target_entity is GuestInstance:
		push_warning("MoneyThresholdCondition: target is not a guest")
		return false

	var guest = target_entity as GuestInstance
	var current_money = guest.get_effective_money()
	var threshold = resolve_int_parameter("value", skill, 0)
	var comparison = condition_data.get("comparison", "greater_than")

	match comparison:
		"greater_than":
			return current_money > threshold
		"less_than":
			return current_money < threshold
		"equal":
			return current_money == threshold
		"greater_or_equal":
			return current_money >= threshold
		"less_or_equal":
			return current_money <= threshold
		_:
			push_warning("MoneyThresholdCondition: unknown comparison '%s'" % comparison)
			return false
