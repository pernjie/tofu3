# src/skill_effects/chance_reverse_movement_effect.gd
class_name ChanceReverseMovementEffect
extends SkillEffect

## Rolls a random chance to reverse movement direction.
## Sets movement_result.direction = -1 on the TriggerContext.
##
## Effect data:
##   type: "chance_reverse_movement"
##   chance: float or "{parameter_name}" (0.0 to 1.0)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var chance = resolve_float_parameter("chance", skill, 0.25)

	if randf() < chance:
		context.movement_result["direction"] = -1
		print("[Lost] Reversed movement! Guest: %s (chance: %.0f%%)" % [
			context.guest.definition.id if context.guest else "unknown",
			chance * 100.0
		])
		var result = SkillEffectResult.succeeded()
		result.set_value_changed("movement_reversed", false, true)
		return result

	return SkillEffectResult.succeeded()
