# src/skill_conditions/state_greater_than_condition.gd
class_name StateGreaterThanCondition
extends SkillCondition

## Checks if a skill state value is greater than a threshold.
##
## Condition data:
##   type: "state_greater_than"
##   state_key: string (key in skill.state)
##   value: int or "{parameter_name}" (threshold to compare against)


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var state_key = condition_data.get("state_key", "")
	if state_key.is_empty():
		push_warning("StateGreaterThanCondition: missing state_key")
		return false

	var threshold = resolve_int_parameter("value", skill, 0)
	var current_value = skill.get_state(state_key, 0)

	return current_value > threshold
