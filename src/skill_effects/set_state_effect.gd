# src/skill_effects/set_state_effect.gd
class_name SetStateEffect
extends SkillEffect

## Sets a value in the skill's state dictionary.
## Unlike increment_state, this overwrites the existing value.
##
## Effect data:
##   type: "set_state"
##   state_key: string (key in skill.state to set)
##   value: int or "{parameter_name}" (default 0)
##   target_skill_id: string (optional — target a sibling skill on the same owner)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var state_key = effect_data.get("state_key", "")
	if state_key.is_empty():
		return SkillEffectResult.failed("No state_key specified")

	var value = resolve_int_parameter("value", skill, 0)

	var target_skill = _resolve_target_skill(skill)
	if not target_skill:
		return SkillEffectResult.failed("Target skill not found")

	var old_value = target_skill.get_state(state_key, 0)
	target_skill.set_state(state_key, value)

	var result = SkillEffectResult.succeeded()
	result.set_value_changed(state_key, old_value, value)
	return result


func _resolve_target_skill(skill: SkillInstance) -> SkillInstance:
	## If target_skill_id is specified, find the sibling skill on the same owner.
	## Otherwise, target the executing skill itself.
	var target_id = effect_data.get("target_skill_id", "")
	if target_id.is_empty():
		return skill

	if not skill.owner:
		return null

	for sibling in skill.owner.skill_instances:
		if sibling.definition.id == target_id:
			return sibling

	push_warning("SetStateEffect: target_skill_id '%s' not found on owner" % target_id)
	return null
