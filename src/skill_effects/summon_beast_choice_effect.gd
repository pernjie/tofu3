class_name SummonBeastChoiceEffect
extends SkillEffect

## Presents a beast selection to the player, then spawns the chosen beast at the target tile.
## Returns a deferred request — the caller (game.gd) handles showing the UI and spawning.
##
## Effect data:
##   type: "summon_beast_choice"
##   pool: array of guest ID strings (must be mythical beasts)
##   choices: int — how many options to present (default 3)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	if not context.tile:
		return SkillEffectResult.failed("No tile in context — cannot summon beast without target position")

	var choices = resolve_int_parameter("choices", skill, 3)
	var pool = resolve_array_parameter("pool", skill)
	if pool.is_empty():
		return SkillEffectResult.failed("Beast pool is empty")

	# Resolve pool IDs to GuestDefinitions (skip invalid)
	var available: Array[Dictionary] = []
	for guest_id in pool:
		var guest_def = ContentRegistry.get_definition("guests", guest_id)
		if guest_def:
			available.append({
				"title": guest_def.display_name_key,
				"description": guest_def.description_key if guest_def.description_key else "",
				"data": guest_def.id
			})
		else:
			push_warning("SummonBeastChoiceEffect: Guest '%s' not found in ContentRegistry" % guest_id)

	if available.is_empty():
		return SkillEffectResult.failed("No valid guests in beast pool")

	# Pick random subset
	available.shuffle()
	var options = available.slice(0, mini(choices, available.size()))

	return SkillEffectResult.deferred({
		"type": "summon_beast_choice",
		"prompt": "DISCOVER_BEAST_PROMPT",
		"options": options,
		"target_pos": context.tile.position,
	})
