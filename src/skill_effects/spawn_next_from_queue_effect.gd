# src/skill_effects/spawn_next_from_queue_effect.gd
class_name SpawnNextFromQueueEffect
extends SkillEffect

## Pops the next guest from the spawn queue and summons them immediately.
## Optionally applies a status effect to the spawned guest.
##
## Effect data:
##   type: "spawn_next_from_queue"
##   status_id: string (optional - status effect to apply to spawned guest)
##   stacks: int or "{parameter_name}" (optional, default 1)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	if BoardSystem.guest_queue.is_empty():
		return SkillEffectResult.failed("Guest queue is empty")

	var guest_def = BoardSystem.guest_queue.pop_front()
	var summoned = BoardSystem.summon_guest(guest_def)
	if not summoned:
		return SkillEffectResult.failed("Failed to spawn guest from queue")

	# Optionally apply a status effect to the spawned guest
	var status_id = resolve_string_parameter("status_id", skill, "")
	if not status_id.is_empty():
		var stacks = resolve_int_parameter("stacks", skill, 1)
		BoardSystem.inflict_status(summoned, status_id, stacks)

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(summoned)
	return result
