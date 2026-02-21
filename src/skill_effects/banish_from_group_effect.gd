# src/skill_effects/banish_from_group_effect.gd
class_name BanishFromGroupEffect
extends SkillEffect

## Banishes a guest from a bulk group based on a stat comparison.
## Operates on context.guests (all guests in the group).
##
## Effect data:
##   type: "banish_from_group"
##   target: "min" or "max" — which end of the comparison to banish
##   compare_stat: "remaining_need" — what to compare across the group
##
## Rules:
##   - If only 1 guest in group, nobody is banished
##   - Tiebreaker: among tied guests, the last to arrive (highest index) is banished
##   - At most 1 guest is banished per execution


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var group = context.guests
	if group.size() < 2:
		return SkillEffectResult.failed("Group too small to banish from")

	var compare_stat = resolve_string_parameter("compare_stat", skill, "remaining_need")
	var target_end = resolve_string_parameter("target", skill, "min")

	# Collect stat values for each guest
	var values: Array[int] = []
	for guest in group:
		values.append(_get_compare_value(guest, compare_stat, context))

	# Find the target value (min or max)
	var target_value: int = values[0]
	for v in values:
		if target_end == "min" and v < target_value:
			target_value = v
		elif target_end == "max" and v > target_value:
			target_value = v

	# Among guests with the target value, pick the last arrived (highest index)
	var banish_target: GuestInstance = null
	for i in range(group.size()):
		if values[i] == target_value:
			banish_target = group[i]  # Later index overwrites, so last arrived wins

	if not banish_target:
		return SkillEffectResult.failed("No valid banish target found")

	if banish_target.is_exiting:
		return SkillEffectResult.failed("Target already exiting")

	if not BoardSystem.banish_guest(banish_target):
		return SkillEffectResult.failed("Banishment was blocked")

	print("[BanishFromGroup] Banished: %s (stat: %s = %d)" % [
		banish_target.definition.id, compare_stat,
		_get_compare_value(banish_target, compare_stat, context)])

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(banish_target)
	return result


func _get_compare_value(guest: GuestInstance, stat: String, context: TriggerContext) -> int:
	match stat:
		"remaining_need":
			var need_type = context.stall.resolve_need_type_for_guest(guest) if context.stall else ""
			return guest.get_remaining_need(need_type)
		_:
			push_warning("Unknown compare_stat: %s" % stat)
			return 0
