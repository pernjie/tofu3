# src/skill_conditions/turn_number_check_condition.gd
class_name TurnNumberCheckCondition
extends SkillCondition

## Checks the current turn number against a value.
##
## Condition data:
##   type: "turn_number_check"
##   operator: "eq", "lt", "gt", "lte", "gte" (default "eq")
##   value: int or "{parameter_name}"


func evaluate(_context: TriggerContext, skill: SkillInstance) -> bool:
	var target_value = resolve_int_parameter("value", skill, 1)
	var operator = condition_data.get("operator", "eq")
	var current = TurnSystem.current_turn

	match operator:
		"eq":
			return current == target_value
		"lt":
			return current < target_value
		"gt":
			return current > target_value
		"lte":
			return current <= target_value
		"gte":
			return current >= target_value
		_:
			push_warning("TurnNumberCheckCondition: unknown operator '%s'" % operator)
			return false
