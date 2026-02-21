# src/skill_conditions/compare_needs_condition.gd
class_name CompareNeedsCondition
extends SkillCondition

## Compares total remaining needs between two entities.
##
## Condition data:
##   type: "compare_needs"
##   target: "self", "target", "guest", "source" (entity whose needs are checked)
##   compare_to: "self", "target", "guest", "source" (entity to compare against)
##   comparison: "greater_than", "less_than", "equal", "greater_or_equal", "less_or_equal"


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var target_str = condition_data.get("target", "target")
	var target_entity = context.resolve_target_entity(target_str, skill)

	if not target_entity or not target_entity is GuestInstance:
		return false

	var compare_to_str = condition_data.get("compare_to", "source")
	var compare_to_entity = context.resolve_target_entity(compare_to_str, skill)

	if not compare_to_entity or not compare_to_entity is GuestInstance:
		return false

	var target_guest = target_entity as GuestInstance
	var compare_to_guest = compare_to_entity as GuestInstance

	var target_needs = target_guest.get_total_remaining_needs()
	var compare_to_needs = compare_to_guest.get_total_remaining_needs()
	var comparison = condition_data.get("comparison", "less_than")

	match comparison:
		"greater_than":
			return target_needs > compare_to_needs
		"less_than":
			return target_needs < compare_to_needs
		"equal":
			return target_needs == compare_to_needs
		"greater_or_equal":
			return target_needs >= compare_to_needs
		"less_or_equal":
			return target_needs <= compare_to_needs
		_:
			push_warning("CompareNeedsCondition: unknown comparison '%s'" % comparison)
			return false
