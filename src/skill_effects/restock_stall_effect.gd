# src/skill_effects/restock_stall_effect.gd
class_name RestockStallEffect
extends SkillEffect

## Immediately restocks a stall to its tier's restock_amount, resets cooldown,
## and emits stall_restocked so on_restock triggers fire.
##
## Effect data:
##   type: "restock_stall"
##   target: "stall" — uses context.stall (for spells and on_serve skills)
##           "self" — uses the skill's owner stall (for global observer skills)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var stall = resolve_target(context, skill) as StallInstance
	if not stall:
		return SkillEffectResult.failed("No stall target")

	var old_stock = stall.current_stock
	if not BoardSystem.restock_and_notify(stall):
		return SkillEffectResult.failed("Stall is not a product stall")
	var new_stock = stall.current_stock

	# Animation is queued by BoardSystem.restock_stall().
	# Event emission is handled by BoardSystem.restock_and_notify().

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("stock", old_stock, new_stock)
	return result
