# src/skill_effects/modify_persistent_state_effect.gd
class_name ModifyPersistentStateEffect
extends SkillEffect

## Modifies a value in GameManager.persistent_data for cross-level persistence.
##
## Effect data:
##   type: "modify_persistent_state"
##   store_id: string (top-level key, defaults to owner's definition ID)
##   key: string (field to modify within the store)
##   amount: int or "{parameter_name}" (value to add, default 1)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var store_id: String = resolve_string_parameter("store_id", skill, skill.owner.definition.id)
	var key: String = resolve_string_parameter("key", skill, "")
	var amount: int = resolve_int_parameter("amount", skill, 1)

	if key.is_empty():
		return SkillEffectResult.failed("Missing key parameter")

	# Ensure store exists
	if not GameManager.persistent_data.has(store_id):
		GameManager.persistent_data[store_id] = {}

	var store: Dictionary = GameManager.persistent_data[store_id]
	var old_value: int = store.get(key, 0)
	var new_value: int = old_value + amount
	store[key] = new_value

	print("[ModifyPersistentState] %s.%s: %d -> %d" % [store_id, key, old_value, new_value])

	var result = SkillEffectResult.succeeded()
	result.set_value_changed(key, old_value, new_value)
	return result
