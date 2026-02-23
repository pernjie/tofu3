# src/skill_conditions/after_midnight_condition.gd
class_name AfterMidnightCondition
extends SkillCondition

## Checks whether midnight has been reached in the current level.
##
## Condition data:
##   type: "after_midnight"


func evaluate(_context: TriggerContext, _skill: SkillInstance) -> bool:
	return TurnSystem.is_after_midnight()
