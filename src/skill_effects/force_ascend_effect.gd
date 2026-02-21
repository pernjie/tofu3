# src/skill_effects/force_ascend_effect.gd
class_name ForceAscendEffect
extends SkillEffect

## Forces a guest to ascend regardless of remaining needs.
## Sets the force_ascend flag; _flush_and_sweep handles the animation and lifecycle.
##
## Effect data:
##   type: "force_ascend"
##   target: "self", "guest" (resolved from trigger context)


func execute(context: TriggerContext, _skill: SkillInstance) -> SkillEffectResult:
	var guest = context.guest
	if not guest:
		return SkillEffectResult.failed("No guest in context")

	if guest.is_exiting:
		return SkillEffectResult.failed("Guest already exiting")

	guest.force_ascend = true

	print("[ForceAscend] Guest: %s" % guest.definition.id)

	return SkillEffectResult.succeeded()
