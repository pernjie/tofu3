# src/skill_conditions/need_type_check_condition.gd
class_name NeedTypeCheckCondition
extends SkillCondition

## Checks if context.need_type matches a specified value.
##
## Condition data:
##   type: "need_type_check"
##   need_type: string (the need type to match, e.g. "food", "joy")


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var required = resolve_string_parameter("need_type", skill, "")
	return context.need_type == required
