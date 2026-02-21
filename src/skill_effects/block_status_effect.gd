# src/skill_effects/block_status_effect.gd
class_name BlockStatusEffect
extends SkillEffect

## Blocks a status effect from being applied.
## Sets status_result.blocked = true on the TriggerContext.
## Used with on_pre_status triggers.
##
## Effect data:
##   type: "block_status"


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	context.status_result["blocked"] = true

	var status_def = context.get_extra("status_definition")
	var status_name = status_def.id if status_def else "unknown"
	var owner_name = skill.owner.definition.id if skill.owner and skill.owner.definition else "unknown"
	print("[BlockStatus] %s blocked status: %s" % [owner_name, status_name])

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("status_blocked", false, true)
	return result
