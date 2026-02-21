# src/skill_effects/average_adjacent_stall_values_effect.gd
class_name AverageAdjacentStallValuesEffect
extends SkillEffect

## Sets a stat on the owner stall to the average value of adjacent stalls.
##
## Effect data:
##   type: "average_adjacent_stall_values"
##   target: "self"
##   stat: string (stat name to set, typically "value")


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var target_entity = resolve_target(context, skill)

	if not target_entity:
		return SkillEffectResult.failed("No valid target")

	if not target_entity is StallInstance:
		return SkillEffectResult.failed("Target is not a stall")

	var stall: StallInstance = target_entity

	var stat_name = effect_data.get("stat", "")
	if stat_name.is_empty():
		return SkillEffectResult.failed("No stat specified")

	# Query adjacent stalls
	var adjacent_stalls = BoardSystem.get_stalls_adjacent_to(stall.board_position)

	# Remove any existing modifier from this skill before recalculating
	stall.modifier_stack.remove_modifiers_from_source(skill)

	if adjacent_stalls.is_empty():
		var result = SkillEffectResult.succeeded()
		result.add_modified_target(stall)
		result.set_value_changed(stat_name, "base", "0 (no adjacent stalls)")
		return result

	# Calculate average value (floor)
	var total := 0
	for adj_stall in adjacent_stalls:
		total += adj_stall.get_value()

	var average := total / adjacent_stalls.size()

	if average > 0:
		var modifier = StatModifier.new(stat_name, StatModifier.Operation.SET, average, skill)
		stall.modifier_stack.add_modifier(modifier)

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(stall)
	result.set_value_changed(stat_name, "base", "%d (avg of %d stalls)" % [average, adjacent_stalls.size()])
	return result
