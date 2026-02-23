# src/skill_conditions/has_remaining_needs_condition.gd
class_name HasRemainingNeedsCondition
extends SkillCondition

## Returns true if the target guest still has at least one unfulfilled need.
##
## Condition data:
##   type: "has_remaining_needs"
##   target: "self", "target", "guest" (must be a guest)


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var target_str = condition_data.get("target", "self")
	var target_entity = context.resolve_target_entity(target_str, skill)

	if not target_entity:
		return false

	if not target_entity is GuestInstance:
		push_warning("HasRemainingNeedsCondition: target is not a guest")
		return false

	var guest = target_entity as GuestInstance
	return not guest.are_all_needs_fulfilled()
