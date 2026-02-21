class_name AddToBeastQueueEffect
extends SkillEffect

## Adds a guest to the beast queue.
##
## Effect data:
##   type: "add_to_beast_queue"
##   guest_id: string or "{parameter_name}" — guest definition ID to add


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var guest_id = resolve_string_parameter("guest_id", skill, "")

	if guest_id.is_empty():
		return SkillEffectResult.failed("No guest_id specified")

	var guest_def = ContentRegistry.get_definition("guests", guest_id)
	if not guest_def:
		return SkillEffectResult.failed("Guest definition not found: %s" % guest_id)

	BoardSystem.beast_queue.append(guest_def)

	return SkillEffectResult.succeeded()
