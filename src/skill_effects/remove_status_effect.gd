# src/skill_effects/remove_status_effect.gd
class_name RemoveStatusEffect
extends SkillEffect

## Removes status effects from a target, filtered by type.
##
## Effect data:
##   type: "remove_status"
##   target: "self", "target", "guest"
##   status_filter: "debuff", "buff", or a specific status_id
##   count: int or "{parameter_name}" (default 1, -1 for all)
##   exclude_tags: string or Array[String] — skip statuses whose definition has any of these tags


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var status_filter = resolve_string_parameter("status_filter", skill, "debuff")
	var count = resolve_int_parameter("count", skill, 1)
	var exclude_tags_raw = effect_data.get("exclude_tags", [])
	var exclude_tags: Array[String] = []
	if exclude_tags_raw is String:
		exclude_tags.append(exclude_tags_raw)
	elif exclude_tags_raw is Array:
		for tag in exclude_tags_raw:
			exclude_tags.append(str(tag))

	var target_entity = resolve_target(context, skill)
	if not target_entity:
		return SkillEffectResult.failed("No valid target")

	# Collect matching status effects
	var matches: Array[StatusEffectInstance] = []
	for effect in target_entity.status_effects:
		if not effect or not effect.definition:
			continue
		if status_filter == "debuff" or status_filter == "buff":
			if effect.definition.effect_type != status_filter:
				continue
		else:
			# Treat as specific status_id
			if effect.definition.id != status_filter:
				continue
		# Check exclude_tags
		if not exclude_tags.is_empty():
			var excluded = false
			for tag in exclude_tags:
				if effect.definition.tags.has(tag):
					excluded = true
					break
			if excluded:
				continue
		matches.append(effect)

	if matches.is_empty():
		return SkillEffectResult.failed("No matching status effects to remove")

	# Apply encounter benefit multiplier for debuff removal
	var final_count = count
	if status_filter == "debuff" and count > 0 and not context.encounter_result.is_empty():
		final_count = int(count * context.encounter_result.get("benefit_multiplier", 1.0))

	# Shuffle and pick count
	matches.shuffle()
	var to_remove: Array[StatusEffectInstance] = []
	if final_count < 0:
		to_remove = matches
	else:
		for i in mini(final_count, matches.size()):
			to_remove.append(matches[i])

	# Remove each
	for effect in to_remove:
		BoardSystem.remove_status_effect(target_entity, effect.definition.id)

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(target_entity)
	result.set_value_changed("statuses_removed", to_remove.size(), 0)
	return result
