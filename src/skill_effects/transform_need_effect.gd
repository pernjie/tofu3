# src/skill_effects/transform_need_effect.gd
class_name TransformNeedEffect
extends SkillEffect

## Transforms remaining needs of one type into another type on the skill owner.
## Only transforms REMAINING (unfulfilled) needs — already-served needs stay as-is.
## Updates both current_needs and initial_needs so the display is correct.
##
## Effect data:
##   type: "transform_need"
##   from_need_type: string (the need type to convert FROM, e.g. "joy")
##   to_need_type: string (the need type to convert TO, e.g. "food")


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var from_type = resolve_string_parameter("from_need_type", skill, "")
	var to_type = resolve_string_parameter("to_need_type", skill, "")

	if from_type.is_empty() or to_type.is_empty():
		return SkillEffectResult.failed("Missing from_need_type or to_need_type")

	if from_type == to_type:
		return SkillEffectResult.failed("from_need_type and to_need_type are the same")

	var guest = skill.owner as GuestInstance
	if not guest:
		return SkillEffectResult.failed("Skill owner is not a guest")

	var remaining = guest.current_needs.get(from_type, 0)
	if remaining <= 0:
		return SkillEffectResult.succeeded()  # Nothing to transform — no-op

	# Transfer remaining needs to the new type
	guest.current_needs[to_type] = guest.current_needs.get(to_type, 0) + remaining
	guest.current_needs[from_type] = 0

	# Update initial_needs so the display denominator is correct
	guest.initial_needs[to_type] = guest.initial_needs.get(to_type, 0) + remaining
	guest.initial_needs[from_type] = guest.initial_needs.get(from_type, 0) - remaining

	# Refresh entity display + queue floating text
	if BoardSystem.board_visual:
		var entity = BoardSystem.board_visual.get_guest_entity(guest)
		if entity:
			entity.refresh()
			var anim = FloatingTextAnimation.new()
			anim.target = entity
			anim.text = "%s -> %s!" % [from_type.capitalize(), to_type.capitalize()]
			anim.color = Color.ORANGE_RED
			AnimationCoordinator.queue(anim)

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(guest)
	result.set_value_changed(from_type, remaining, 0)
	return result
