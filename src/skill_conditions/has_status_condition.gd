# src/skill_conditions/has_status_condition.gd
class_name HasStatusCondition
extends SkillCondition

## Checks if a target has a specific status effect.
##
## Condition data:
##   type: "has_status"
##   target: "self", "target", "guest", "stall"
##   status_id: string (ID of the status effect to check for)
##   invert: bool (optional, if true returns false when status is present)


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var target_str = condition_data.get("target", "self")
	var target_entity = context.resolve_target_entity(target_str, skill)

	if not target_entity:
		return false

	var status_id = condition_data.get("status_id", "")
	if status_id.is_empty():
		push_warning("HasStatusCondition: missing status_id")
		return false

	var has_status = target_entity.has_status(status_id)
	var invert = condition_data.get("invert", false)

	return has_status != invert  # XOR: return has_status unless inverted
