# src/skill_effects/modify_need_effect.gd
class_name ModifyNeedEffect
extends SkillEffect

## Adds or subtracts from a guest's needs.
## Modifies both current_needs and initial_needs so the UI denominator stays correct.
##
## Effect data:
##   type: "modify_need"
##   target: "self", "target", "guest" (must resolve to a GuestInstance)
##   need_type: string (e.g. "interact", "food", "joy")
##   amount: int or "{parameter_name}" (positive = add need, negative = reduce)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var target_entity = resolve_target(context, skill)

	if not target_entity:
		return SkillEffectResult.failed("No valid target")

	if not target_entity is GuestInstance:
		return SkillEffectResult.failed("Target is not a guest")

	var guest = target_entity as GuestInstance
	var need_type = resolve_string_parameter("need_type", skill, "")
	var amount = resolve_int_parameter("amount", skill, 0)

	if need_type.is_empty():
		return SkillEffectResult.failed("No need_type specified")

	var old_current = guest.current_needs.get(need_type, 0)
	var old_initial = guest.initial_needs.get(need_type, 0)

	guest.current_needs[need_type] = old_current + amount
	guest.initial_needs[need_type] = old_initial + amount

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(guest)
	result.set_value_changed(need_type, old_current, guest.current_needs[need_type])
	return result
