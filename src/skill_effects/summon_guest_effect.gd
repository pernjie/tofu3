# src/skill_effects/summon_guest_effect.gd
class_name SummonGuestEffect
extends SkillEffect

## Summons a guest at the skill owner's current tile position.
##
## Effect data:
##   type: "summon_guest"
##   guest_id: string (ID of the guest definition to summon)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var guest_id = resolve_string_parameter("guest_id", skill, "")
	if guest_id.is_empty():
		return SkillEffectResult.failed("No guest_id specified")

	var guest_def = ContentRegistry.get_definition("guests", guest_id) as GuestDefinition
	if not guest_def:
		return SkillEffectResult.failed("Guest definition not found: %s" % guest_id)

	var owner = skill.owner
	if not owner is GuestInstance:
		return SkillEffectResult.failed("Summon owner is not a guest")

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

	var summoned = BoardSystem.summon_guest(guest_def, path_id, spawn_index)
	if not summoned:
		return SkillEffectResult.failed("Failed to spawn guest")

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(summoned)
	return result
