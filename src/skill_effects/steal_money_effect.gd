# src/skill_effects/steal_money_effect.gd
class_name StealMoneyEffect
extends SkillEffect

## Steals a flat amount of money from the target guest and gives it to the skill owner.
##
## Effect data:
##   type: "steal_money"
##   target: "target" (the guest being stolen from)
##   amount: int or "{parameter_name}" (flat amount to steal, clamped to available money)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var amount = resolve_int_parameter("amount", skill, 1)

	if amount <= 0:
		return SkillEffectResult.failed("Amount must be positive")

	var target_guest = resolve_target(context, skill)
	if not target_guest or not target_guest is GuestInstance:
		return SkillEffectResult.failed("No valid guest target")

	var guest: GuestInstance = target_guest
	var available = guest.get_effective_money()
	var stolen = mini(amount, available)

	if stolen <= 0:
		return SkillEffectResult.failed("Target has no money to steal")

	# Deduct from guest, add to beast (skill owner)
	guest.current_money -= stolen

	var owner = skill.owner
	if owner and owner is GuestInstance:
		(owner as GuestInstance).current_money += stolen

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("money_stolen", available, guest.current_money)
	return result
