# src/skill_conditions/has_debuff_condition.gd
class_name HasDebuffCondition
extends SkillCondition

## Checks if a target has any debuff (or buff, if inverted) status effect.
##
## Condition data:
##   type: "has_debuff"
##   target: "self", "target", "guest", "stall"
##   invert: bool (optional, if true checks for buffs instead)


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var target_str = condition_data.get("target", "self")
	var target_entity = context.resolve_target_entity(target_str, skill)

	if not target_entity:
		return false

	var looking_for = "debuff"
	var invert = condition_data.get("invert", false)
	if invert:
		looking_for = "buff"

	for effect in target_entity.status_effects:
		if effect and effect.definition and effect.definition.effect_type == looking_for:
			return true

	return false
