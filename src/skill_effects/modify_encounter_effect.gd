# src/skill_effects/modify_encounter_effect.gd
class_name ModifyEncounterEffect
extends SkillEffect

## Modifies beast encounter benefits by setting a multiplier on encounter_result.
## Accumulates onto context.encounter_result for the TurnSystem to apply.
##
## Effect data:
##   type: "modify_encounter"
##   benefit_multiplier: float or "{parameter_name}" (multiplies beneficial effects)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	if context.encounter_result.is_empty():
		return SkillEffectResult.failed("No encounter_result available")

	var multiplier = resolve_float_parameter("benefit_multiplier", skill, 1.0)

	if multiplier != 1.0:
		var current = context.encounter_result.get("benefit_multiplier", 1.0)
		context.encounter_result["benefit_multiplier"] = current * multiplier

	var owner_name = skill.owner.definition.id if skill.owner and skill.owner.definition else "unknown"
	print("[ModifyEncounter] Owner: %s | benefit_multiplier: %.2f" % [owner_name, multiplier])

	var result = SkillEffectResult.succeeded()
	return result
