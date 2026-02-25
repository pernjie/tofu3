# src/skill_effects/fulfill_need_effect.gd
class_name FulfillNeedEffect
extends SkillEffect

## Directly fulfills a need on a target guest or area.
##
## Effect data:
##   type: "fulfill_need"
##   target: "self", "target", "guest", "adjacent_guests"
##   need_type: string (food, joy, or "random" to pick a random unfulfilled need)
##   amount: int, "{parameter_name}", or "remaining" (fulfills all remaining of that need)
##   range: int (Manhattan distance, only for "adjacent_guests", default 1)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var need_type = resolve_string_parameter("need_type", skill, "")
	if need_type.is_empty():
		return SkillEffectResult.failed("No need_type specified")

	var use_remaining = _is_remaining_amount(skill)
	var amount = 0 if use_remaining else resolve_int_parameter("amount", skill, 1)
	var target_mode = get_target_string()

	if target_mode == "adjacent_guests":
		return _execute_area(context, skill, need_type, amount, use_remaining)
	return _execute_single(context, skill, need_type, amount, use_remaining)


func _is_remaining_amount(skill: SkillInstance) -> bool:
	var raw = effect_data.get("amount", 1)
	var resolved = resolve_parameter(raw, skill)
	return resolved is String and resolved == "remaining"


func _execute_single(context: TriggerContext, skill: SkillInstance, need_type: String, amount: int, use_remaining: bool) -> SkillEffectResult:
	var target_entity = resolve_target(context, skill)

	if not target_entity:
		return SkillEffectResult.failed("No valid target")

	if not target_entity is GuestInstance:
		return SkillEffectResult.failed("Target is not a guest")

	var guest = target_entity as GuestInstance

	# Resolve "random" to a random unfulfilled need
	var resolved_need_type = need_type
	if need_type == "random":
		var unfulfilled: Array[String] = []
		for key in guest.current_needs:
			if guest.current_needs[key] > 0:
				unfulfilled.append(key)
		if unfulfilled.is_empty():
			return SkillEffectResult.succeeded()  # No-op, not a failure
		resolved_need_type = unfulfilled.pick_random()

	var final_amount = guest.get_remaining_need(resolved_need_type) if use_remaining else amount
	if final_amount <= 0:
		return SkillEffectResult.succeeded()  # Nothing to fulfill

	if not context.encounter_result.is_empty():
		final_amount = int(final_amount * context.encounter_result.get("benefit_multiplier", 1.0))

	var old_value = guest.get_remaining_need(resolved_need_type)
	var source = skill.owner if skill else null
	var fulfilled = BoardSystem.fulfill_and_notify(guest, resolved_need_type, final_amount, source)

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(guest)
	result.set_value_changed(resolved_need_type, old_value, guest.get_remaining_need(resolved_need_type))
	return result


func _execute_area(context: TriggerContext, skill: SkillInstance, need_type: String, amount: int, use_remaining: bool) -> SkillEffectResult:
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
			var final_amount = guest.get_remaining_need(need_type) if use_remaining else amount
			if final_amount <= 0:
				continue
			var source = skill.owner if skill else null
			var fulfilled = BoardSystem.fulfill_and_notify(guest, need_type, final_amount, source)
			if fulfilled > 0:
				result.add_modified_target(guest)

	return result
