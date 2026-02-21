# src/skill_conditions/status_is_debuff_condition.gd
class_name StatusIsDebuffCondition
extends SkillCondition

## Checks if the status effect in the trigger context is a debuff (or buff if inverted).
## Designed for on_pre_status triggers where context.extra["status_definition"] is set.
##
## Condition data:
##   type: "status_is_debuff"
##   invert: bool (optional, if true checks for buff instead)


func evaluate(context: TriggerContext, _skill: SkillInstance) -> bool:
	var status_def = context.get_extra("status_definition")
	if not status_def:
		return false

	var looking_for = "debuff"
	var invert = condition_data.get("invert", false)
	if invert:
		looking_for = "buff"

	return status_def.effect_type == looking_for
