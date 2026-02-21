# src/skill_effects/banish_effect.gd
class_name BanishEffect
extends SkillEffect

## Banishes a guest from the board (forced removal, no reputation penalty).
## The guest is marked for banishment; _flush_and_sweep handles the rest.
##
## Effect data:
##   type: "banish"
##   target: "guest" (resolved from trigger context)


func execute(context: TriggerContext, _skill: SkillInstance) -> SkillEffectResult:
	var guest = context.guest
	if not guest:
		return SkillEffectResult.failed("No guest in context")

	if guest.is_exiting:
		return SkillEffectResult.failed("Guest already exiting")

	if not BoardSystem.banish_guest(guest):
		return SkillEffectResult.failed("Banishment was blocked")

	print("[Banish] Guest: %s" % guest.definition.id)

	return SkillEffectResult.succeeded()
