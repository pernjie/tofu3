# src/skill_effects/upgrade_stall_effect.gd
class_name UpgradeStallEffect
extends SkillEffect

## Upgrades a stall to its next tier.
##
## Effect data:
##   type: "upgrade_stall"
##   target: "stall" — uses context.stall (for spells targeting a stall)
##           "self" — uses the skill's owner stall (for stall skills)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var stall = resolve_target(context, skill) as StallInstance
	if not stall:
		return SkillEffectResult.failed("No stall target")

	if not stall.can_upgrade():
		return SkillEffectResult.failed("Stall cannot be upgraded")

	var old_tier = stall.current_tier
	BoardSystem.upgrade_and_notify(stall)

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("tier", old_tier, stall.current_tier)
	return result
