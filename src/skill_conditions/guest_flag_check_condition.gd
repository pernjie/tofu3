# src/skill_conditions/guest_flag_check_condition.gd
class_name GuestFlagCheckCondition
extends SkillCondition

## Checks a boolean flag on the context guest's definition.
## Supports: is_mythical_beast, is_boss, is_core_guest
##
## Condition data:
##   type: "guest_flag_check"
##   flag: string (the boolean flag to check)
##   target: "self", "target", "guest" (default "guest")


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var target_str = condition_data.get("target", "guest")
	var target_entity = context.resolve_target_entity(target_str, skill)

	if not target_entity or not target_entity is GuestInstance:
		return false

	var guest = target_entity as GuestInstance
	var flag = resolve_string_parameter("flag", skill, "")

	match flag:
		"is_mythical_beast":
			return guest.is_mythical_beast()
		"is_boss":
			return guest.is_boss()
		"is_core_guest":
			return guest.is_core_guest()
		_:
			push_warning("GuestFlagCheckCondition: unknown flag '%s'" % flag)
			return false
