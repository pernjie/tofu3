class_name DiscoverEffect
extends SkillEffect

## Presents a discover choice to the player via the deferred effect pattern.
## Picks random options from a pool of guest IDs and returns a deferred request.
## The caller (game.gd) handles showing the UI and storing the result.
##
## Effect data:
##   type: "discover"
##   pool: array of guest ID strings, or "{parameter_name}"
##   count: int or "{parameter_name}" — how many options to present
##   store_key: string or "{parameter_name}" — persistent_state key for the result


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var count = resolve_int_parameter("count", skill, 3)
	var store_key = resolve_string_parameter("store_key", skill, "discovered_choice")

	# Resolve pool — may be a parameter reference or direct array in effect_data
	var pool = resolve_array_parameter("pool", skill)
	if pool.is_empty():
		return SkillEffectResult.failed("Discover pool is empty")

	# Resolve pool IDs to GuestDefinitions
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
			push_warning("DiscoverEffect: Guest '%s' not found in ContentRegistry" % guest_id)

	if available.is_empty():
		return SkillEffectResult.failed("No valid guests in discover pool")

	# Pick random subset
	available.shuffle()
	var options = available.slice(0, mini(count, available.size()))

	# Return deferred request — caller handles UI
	return SkillEffectResult.deferred({
		"type": "discover",
		"prompt": "DISCOVER_BEAST_PROMPT",
		"options": options,
		"store_key": store_key,
	})
