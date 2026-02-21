# src/skill_effects/reset_service_durations_effect.gd
class_name ResetServiceDurationsEffect
extends SkillEffect

## Resets service_turns_remaining for all guests currently being served at stalls.
## Each guest's timer is recalculated from their stall's base duration and their
## own service_duration_multiplier stat.
##
## Effect data:
##   type: "reset_service_durations"


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var reset_count: int = 0

	for guest in BoardSystem.active_guests:
		if not guest.is_in_stall:
			continue
		# Don't reset the guest who triggered this (they just entered)
		if guest == context.guest:
			continue

		if BoardSystem.reset_guest_service(guest):
			reset_count += 1

	if reset_count == 0:
		return SkillEffectResult.failed("No guests to reset")

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("guests_reset", 0, reset_count)
	return result
