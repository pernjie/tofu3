# src/skill_effects/summon_from_queue_effect.gd
class_name SummonFromQueueEffect
extends SkillEffect

## Picks a random eligible guest from the spawn queue and summons mini copies.
##
## Effect data:
##   type: "summon_from_queue"
##   count: int — number of mini copies to spawn (default 2, parameterizable)
##   needs_count: int — how many need types the mini keeps (default 1, parameterizable)
##   money: int — money override for the mini (default 1, parameterizable)
##
## Exclusion rules (hardcoded):
##   - Excludes guests with the same definition ID as the skill owner
##   - Excludes boss guests


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var count = resolve_int_parameter("count", skill, 2)
	var needs_count = resolve_int_parameter("needs_count", skill, 1)
	var money = resolve_int_parameter("money", skill, 1)

	# Get the skill owner (must be a guest)
	var owner = skill.owner
	if not owner is GuestInstance:
		return SkillEffectResult.failed("Owner is not a guest")
	var owner_guest = owner as GuestInstance
	var owner_def = owner_guest.definition as GuestDefinition

	# Filter queue for eligible guests
	var eligible: Array[GuestDefinition] = []
	for guest_def in BoardSystem.guest_queue:
		# Exclude same type as owner (prevents loops)
		if guest_def.id == owner_def.id:
			continue
		# Exclude bosses
		if guest_def.is_boss:
			continue
		eligible.append(guest_def)

	if eligible.is_empty():
		return SkillEffectResult.failed("No eligible guests in queue")

	# Pick one random eligible guest
	var picked_def = eligible.pick_random()

	# Determine spawn position (owner's current path/position)
	var path_id: String = ""
	var spawn_index: int = owner_guest.path_index
	if owner_guest.current_tile and BoardSystem.board:
		for path in BoardSystem.board.paths:
			for tile in path.tiles:
				if tile.position == owner_guest.current_tile.position:
					path_id = path.id
					break
			if not path_id.is_empty():
				break

	# Build mini needs: pick random need types from the original
	var original_need_types = picked_def.base_needs.keys()
	var result = SkillEffectResult.succeeded()

	for i in range(count):
		# Shuffle and pick needs_count need types
		var shuffled_needs = original_need_types.duplicate()
		shuffled_needs.shuffle()
		var mini_needs: Dictionary = {}
		for j in range(mini(needs_count, shuffled_needs.size())):
			mini_needs[shuffled_needs[j]] = 1

		var summoned = BoardSystem.summon_guest_with_overrides(
			picked_def, path_id, spawn_index, mini_needs, money)
		if summoned:
			result.add_modified_target(summoned)

	return result
