# src/skill_effects/block_banish_effect.gd
class_name BlockBanishEffect
extends SkillEffect

## Blocks a guest from being banished.
## Sets banish_result.blocked = true on the TriggerContext.
## Used with on_pre_banish triggers.
##
## Effect data:
##   type: "block_banish"


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	context.banish_result["blocked"] = true

	var owner_name = skill.owner.definition.id if skill.owner and skill.owner.definition else "unknown"
	print("[BlockBanish] %s blocked banishment" % owner_name)

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("banish_blocked", false, true)
	return result
