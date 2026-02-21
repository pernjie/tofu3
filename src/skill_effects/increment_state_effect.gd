# src/skill_effects/increment_state_effect.gd
class_name IncrementStateEffect
extends SkillEffect

## Increments a counter in the skill's state.
## Useful for tracking counts, stacks, or triggers.
##
## Effect data:
##   type: "increment_state"
##   state_key: string (key in skill.state to increment)
##   amount: int or "{parameter_name}" (default 1)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var state_key = effect_data.get("state_key", "")
	if state_key.is_empty():
		return SkillEffectResult.failed("No state_key specified")

	var amount = resolve_int_parameter("amount", skill, 1)
	var old_value = skill.get_state(state_key, 0)
	var new_value = skill.increment_state(state_key, amount)

	var result = SkillEffectResult.succeeded()
	result.set_value_changed(state_key, old_value, new_value)
	return result
