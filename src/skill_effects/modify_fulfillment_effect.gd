# src/skill_effects/modify_fulfillment_effect.gd
class_name ModifyFulfillmentEffect
extends SkillEffect

## Modifies service fulfillment by adding a bonus or multiplier.
## Accumulates onto context.service_result for the TurnSystem to apply.
##
## Effect data:
##   type: "modify_fulfillment"
##   bonus: int or "{parameter_name}" (added to fulfillment)
##   multiplier: float or "{parameter_name}" (optional, multiplies fulfillment)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var bonus = resolve_int_parameter("bonus", skill, 0)
	var multiplier = resolve_float_parameter("multiplier", skill, 1.0)

	# Pick the active result dict (fulfillment_result for on_pre_fulfill, service_result for on_pre_serve)
	var result_dict: Dictionary
	if not context.fulfillment_result.is_empty():
		result_dict = context.fulfillment_result
	elif not context.service_result.is_empty():
		result_dict = context.service_result
	else:
		return SkillEffectResult.failed("No result dict available")

	if bonus != 0:
		result_dict["fulfillment_bonus"] = result_dict.get("fulfillment_bonus", 0) + bonus

	if multiplier != 1.0:
		var current = result_dict.get("fulfillment_multiplier", 1.0)
		result_dict["fulfillment_multiplier"] = current * multiplier

	print("[ModifyFulfillment] Guest: %s, Stall: %s | bonus: %d, multiplier: %.2f" % [
		context.guest.definition.id if context.guest else "unknown",
		context.stall.definition.id if context.stall else "unknown",
		bonus, multiplier
	])

	var result = SkillEffectResult.succeeded()
	if bonus != 0:
		result.set_value_changed("fulfillment_bonus", bonus - bonus, bonus)
	return result
