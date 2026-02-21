# src/skill_conditions/always_condition.gd
class_name AlwaysCondition
extends SkillCondition

## A condition that always returns true.
## Used when effects should always trigger.
##
## Condition data:
##   type: "always"


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	return true
