# src/skill_effects/set_midnight_threshold_effect.gd
class_name SetMidnightThresholdEffect
extends SkillEffect

## Sets the midnight threshold fraction, allowing midnight to trigger earlier.
## The fraction represents what portion of initial core guests can still remain
## in the queue when midnight fires.
##
## Effect data:
##   type: "set_midnight_threshold"
##   threshold: float (0.0 = all must be gone [default], 0.5 = half can remain)


func execute(_context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var threshold: float = resolve_float_parameter("threshold", skill, 0.0)
	TurnSystem.midnight_threshold_fraction = threshold
	return SkillEffectResult.succeeded()
