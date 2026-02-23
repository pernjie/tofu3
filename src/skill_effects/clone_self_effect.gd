# src/skill_effects/clone_self_effect.gd
class_name CloneSelfEffect
extends SkillEffect

## Spawns a copy of the skill owner at the same path position,
## with the owner's current remaining needs and money.
##
## Effect data:
##   type: "clone_self"


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var owner = skill.owner
	if not owner is GuestInstance:
		return SkillEffectResult.failed("Clone owner is not a guest")

	var owner_guest = owner as GuestInstance

	# Find the path the owner is on
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

	var clone = BoardSystem.summon_guest_with_overrides(
		owner_guest.definition, path_id, spawn_index,
		owner_guest.current_needs.duplicate(), owner_guest.current_money)
	if not clone:
		return SkillEffectResult.failed("Failed to spawn clone")

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(clone)
	return result
