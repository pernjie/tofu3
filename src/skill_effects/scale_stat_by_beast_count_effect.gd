# src/skill_effects/scale_stat_by_beast_count_effect.gd
class_name ScaleStatByBeastCountEffect
extends SkillEffect

## Scales a stat based on the total number of mythical beasts (queued + on board).
##
## Effect data:
##   type: "scale_stat_by_beast_count"
##   target: "self", "target", "guest", "stall"
##   stat: string (stat name to modify)
##   per_beast: int or "{parameter_name}" (bonus per beast)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var target_entity = resolve_target(context, skill)

	if not target_entity:
		return SkillEffectResult.failed("No valid target")

	var stat_name = effect_data.get("stat", "")
	if stat_name.is_empty():
		return SkillEffectResult.failed("No stat specified")

	var per_beast = resolve_int_parameter("per_beast", skill, 1)

	# Count total beasts: queue + on board
	var beast_count = BoardSystem.beast_queue.size()
	for guest in BoardSystem.active_guests:
		if guest.is_mythical_beast():
			beast_count += 1

	# Remove any existing modifier from this skill, then apply fresh
	target_entity.modifier_stack.remove_modifiers_from_source(skill)

	var total_bonus = beast_count * per_beast
	if total_bonus > 0:
		var modifier = StatModifier.new(stat_name, StatModifier.Operation.ADD, total_bonus, skill)
		target_entity.modifier_stack.add_modifier(modifier)

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(target_entity)
	result.set_value_changed(stat_name, "base", "+%d (%d beasts x %d)" % [total_bonus, beast_count, per_beast])
	return result
