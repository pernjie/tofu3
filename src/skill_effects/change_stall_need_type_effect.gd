# src/skill_effects/change_stall_need_type_effect.gd
class_name ChangeStallNeedTypeEffect
extends SkillEffect

## Changes the need type a stall serves at runtime.
## Sets need_type_override on the StallInstance.
##
## Effect data:
##   type: "change_stall_need_type"
##   need_type: string or "{parameter_name}" (the new need type to serve)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var stall = skill.owner as StallInstance
	if not stall:
		return SkillEffectResult.failed("Skill owner is not a stall")

	var new_need_type = resolve_string_parameter("need_type", skill, "")
	if new_need_type.is_empty():
		return SkillEffectResult.failed("No need_type specified")

	var old_need_type = stall.get_need_type()
	if old_need_type == new_need_type:
		return SkillEffectResult.succeeded()  # Already serving this type

	stall.need_type_override = new_need_type

	# Refresh entity display + queue floating text
	if BoardSystem.board_visual:
		var entity = BoardSystem.board_visual.get_stall_entity(stall.board_position)
		if entity:
			entity.update_labels()
			var anim = FloatingTextAnimation.new()
			anim.target = entity
			anim.text = "%s -> %s!" % [old_need_type.capitalize(), new_need_type.capitalize()]
			anim.color = Color.MEDIUM_PURPLE
			AnimationCoordinator.queue(anim)

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(stall)
	result.set_value_changed("need_type", old_need_type, new_need_type)
	return result
