# src/skill_effects/modify_reputation_effect.gd
class_name ModifyReputationEffect
extends SkillEffect

## Modifies the player's reputation.
## Optionally scales by the stack count of a status effect on the context guest.
##
## Effect data:
##   type: "modify_reputation"
##   amount: int or "{parameter_name}" (reputation change per stack, or flat if no per_stack_of)
##   per_stack_of: string or "{parameter_name}" (optional status_id to read stacks from)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var amount = resolve_int_parameter("amount", skill, 0)

	if amount == 0:
		return SkillEffectResult.failed("Amount is zero")

	var final_amount = amount

	# Optionally scale by status stacks on the context guest
	var per_stack_of = resolve_string_parameter("per_stack_of", skill, "")
	if not per_stack_of.is_empty() and context.guest:
		var status = context.guest.get_status(per_stack_of)
		var stacks = status.stacks if status else 0
		if stacks <= 0:
			return SkillEffectResult.failed("No stacks of %s" % per_stack_of)
		final_amount = amount * stacks

	var old_rep = GameManager.reputation
	BoardSystem.add_reputation(final_amount)

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("reputation", old_rep, GameManager.reputation)
	return result
