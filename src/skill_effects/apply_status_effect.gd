# src/skill_effects/apply_status_effect.gd
class_name ApplyStatusEffect
extends SkillEffect

## Applies a status effect to a target or area.
##
## Effect data:
##   type: "apply_status"
##   target: "self", "target", "guest", "stall", "adjacent_guests"
##   status_id: string (ID of the status effect definition)
##   stacks: int or "{parameter_name}" (optional, default 1)
##   range: int (Manhattan distance, only for "adjacent_guests", default 1)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var status_id = resolve_string_parameter("status_id", skill, "")
	if status_id.is_empty():
		return SkillEffectResult.failed("No status_id specified")

	var stacks = resolve_int_parameter("stacks", skill, 1)
	var target_mode = get_target_string()

	if target_mode == "adjacent_guests":
		return _execute_area(context, skill, status_id, stacks)
	return _execute_single(context, skill, status_id, stacks)


func _execute_single(context: TriggerContext, skill: SkillInstance, status_id: String, stacks: int) -> SkillEffectResult:
	var target_entity = resolve_target(context, skill)
	if not target_entity:
		return SkillEffectResult.failed("No valid target")

	var result = SkillEffectResult.succeeded()
	if _apply_status_to(target_entity, status_id, stacks):
		result.add_modified_target(target_entity)
	else:
		return SkillEffectResult.failed("Failed to apply status: %s" % status_id)
	return result


func _execute_area(context: TriggerContext, skill: SkillInstance, status_id: String, stacks: int) -> SkillEffectResult:
	var range_val = resolve_int_parameter("range", skill, 1)

	var owner_guest = context.guest
	if not owner_guest or not owner_guest.current_tile:
		return SkillEffectResult.failed("No guest with position in context")

	var center_pos = owner_guest.current_tile.position

	if not BoardSystem.board:
		return SkillEffectResult.failed("No board available")

	var adjacent_tiles = BoardSystem.board.get_adjacent_tiles(center_pos)
	var result = SkillEffectResult.succeeded()

	for tile in adjacent_tiles:
		var distance = abs(tile.position.x - center_pos.x) + abs(tile.position.y - center_pos.y)
		if distance > range_val:
			continue

		var guests_on_tile = BoardSystem.get_guests_at(tile.position)
		for guest in guests_on_tile:
			if _apply_status_to(guest, status_id, stacks):
				result.add_modified_target(guest)

	return result


func _apply_status_to(target, status_id: String, stacks: int) -> bool:
	var instance = BoardSystem.inflict_status(target, status_id, stacks)
	return instance != null
