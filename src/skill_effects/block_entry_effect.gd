# src/skill_effects/block_entry_effect.gd
class_name BlockEntryEffect
extends SkillEffect

## Blocks a guest from entering a stall.
## Sets entry_result.blocked = true on the TriggerContext.
## Used with on_pre_enter_stall triggers.
##
## Effect data:
##   type: "block_entry"


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	context.entry_result["blocked"] = true

	var owner_name = skill.owner.definition.id if skill.owner and skill.owner.definition else "unknown"
	print("[BlockEntry] %s blocked stall entry" % owner_name)

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("entry_blocked", false, true)
	return result
