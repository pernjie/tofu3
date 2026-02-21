# src/skill_effects/chance_block_service_effect.gd
class_name ChanceBlockServiceEffect
extends SkillEffect

## Rolls a random chance to block service fulfillment.
## Sets service_result.blocked = true on the TriggerContext.
##
## Effect data:
##   type: "chance_block_service"
##   chance: float or "{parameter_name}" (0.0 to 1.0)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var chance = resolve_float_parameter("chance", skill, 0.25)

	if randf() < chance:
		context.service_result["blocked"] = true
		print("[Charm] Blocked fulfillment! Guest: %s, Stall: %s (chance: %.0f%%)" % [
			context.guest.definition.id if context.guest else "unknown",
			context.stall.definition.id if context.stall else "unknown",
			chance * 100.0
		])
		var result = SkillEffectResult.succeeded()
		result.set_value_changed("service_blocked", false, true)
		return result

	return SkillEffectResult.succeeded()
