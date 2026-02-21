# src/skill_conditions/stall_stock_check_condition.gd
class_name StallStockCheckCondition
extends SkillCondition

## Compares a stall's current stock against a threshold.
## Only passes for product stalls (service stalls don't use stock).
##
## Condition data:
##   type: "stall_stock_check"
##   comparison: "greater_than", "less_than", "equal", "greater_or_equal", "less_or_equal"
##   value: int or "{parameter_name}"


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var stall = context.stall
	if not stall:
		return false

	# Only product stalls have stock
	if stall.get_operation_model() != "product":
		return false

	var current_stock = stall.current_stock
	var threshold = resolve_int_parameter("value", skill, 0)
	var comparison = condition_data.get("comparison", "equal")

	match comparison:
		"greater_than":
			return current_stock > threshold
		"less_than":
			return current_stock < threshold
		"equal":
			return current_stock == threshold
		"greater_or_equal":
			return current_stock >= threshold
		"less_or_equal":
			return current_stock <= threshold
		_:
			push_warning("StallStockCheckCondition: unknown comparison '%s'" % comparison)
			return false
