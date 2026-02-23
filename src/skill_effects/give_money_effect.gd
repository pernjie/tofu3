# src/skill_effects/give_money_effect.gd
class_name GiveMoneyEffect
extends SkillEffect

## Gives money to the target guest.
## Scales with benefit_multiplier from encounter_result when present.
##
## Effect data:
##   type: "give_money"
##   target: "target" (the guest receiving money)
##   amount: int or "{parameter_name}"


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var amount = resolve_int_parameter("amount", skill, 1)

	if amount <= 0:
		return SkillEffectResult.failed("Amount must be positive")

	var target_guest = resolve_target(context, skill)
	if not target_guest or not target_guest is GuestInstance:
		return SkillEffectResult.failed("No valid guest target")

	var guest: GuestInstance = target_guest

	# Scale with encounter benefit_multiplier
	var final_amount = amount
	if not context.encounter_result.is_empty():
		final_amount = int(amount * context.encounter_result.get("benefit_multiplier", 1.0))

	var old_money = guest.current_money
	guest.current_money += final_amount

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(guest)
	result.set_value_changed("money", old_money, guest.current_money)
	return result
