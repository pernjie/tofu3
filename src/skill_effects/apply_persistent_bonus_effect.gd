# src/skill_effects/apply_persistent_bonus_effect.gd
class_name ApplyPersistentBonusEffect
extends SkillEffect

## Reads a value from GameManager.persistent_data and applies it as fulfillment bonus.
## Must be used with on_pre_serve trigger.
##
## Effect data:
##   type: "apply_persistent_bonus"
##   store_id: string (top-level key, defaults to owner's definition ID)
##   key: string (field to read)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var store_id: String = resolve_string_parameter("store_id", skill, skill.owner.definition.id)
	var key: String = resolve_string_parameter("key", skill, "")

	if key.is_empty():
		return SkillEffectResult.failed("Missing key parameter")

	if context.service_result.is_empty():
		return SkillEffectResult.failed("No service_result available (must use on_pre_serve trigger)")

	var store: Dictionary = GameManager.persistent_data.get(store_id, {})
	var bonus: int = store.get(key, 0)

	if bonus <= 0:
		return SkillEffectResult.succeeded()

	context.service_result["fulfillment_bonus"] = context.service_result.get("fulfillment_bonus", 0) + bonus

	print("[ApplyPersistentBonus] %s.%s = %d applied to fulfillment_bonus" % [store_id, key, bonus])

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("fulfillment_bonus", 0, bonus)
	return result
