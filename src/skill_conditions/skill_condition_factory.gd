# src/skill_conditions/skill_condition_factory.gd
class_name SkillConditionFactory
extends RefCounted

## Factory for creating SkillCondition instances from condition data dictionaries.
## Maps condition type strings to their implementing classes.


static func create(condition_data: Dictionary) -> SkillCondition:
	## Create a SkillCondition from condition data dictionary.
	var condition_type = condition_data.get("type", "")

	match condition_type:
		"always":
			return AlwaysCondition.new(condition_data)
		"state_greater_than":
			return StateGreaterThanCondition.new(condition_data)
		"state_less_than":
			return StateLessThanCondition.new(condition_data)
		"has_status":
			return HasStatusCondition.new(condition_data)
		"need_threshold":
			return NeedThresholdCondition.new(condition_data)
		"stall_stock_check":
			return StallStockCheckCondition.new(condition_data)
		"has_debuff":
			return HasDebuffCondition.new(condition_data)
		"compare_needs":
			return CompareNeedsCondition.new(condition_data)
		"amount_check":
			return AmountCheckCondition.new(condition_data)
		"money_threshold":
			return MoneyThresholdCondition.new(condition_data)
		"status_is_debuff":
			return StatusIsDebuffCondition.new(condition_data)
		"need_type_check":
			return NeedTypeCheckCondition.new(condition_data)
		_:
			push_warning("Unknown condition type: %s" % condition_type)
			return SkillCondition.new(condition_data)


static func create_all(conditions_array: Array) -> Array[SkillCondition]:
	## Create SkillCondition instances for all conditions in an array.
	var result: Array[SkillCondition] = []
	for condition_data in conditions_array:
		result.append(create(condition_data))
	return result


static func evaluate_all(conditions: Array[SkillCondition], context: TriggerContext, skill: SkillInstance) -> bool:
	## Evaluate all conditions - returns true only if ALL conditions pass.
	## Empty conditions array returns true (no conditions = always valid).
	for condition in conditions:
		if not condition.evaluate(context, skill):
			return false
	return true
