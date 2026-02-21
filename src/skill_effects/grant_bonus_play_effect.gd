# src/skill_effects/grant_bonus_play_effect.gd
class_name GrantBonusPlayEffect
extends SkillEffect

## Grants bonus card plays for the current turn.
## Increases the max plays per turn via BoardSystem facade.
##
## Effect data:
##   type: "grant_bonus_play"
##   amount: int or "{parameter_name}" (default 1)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var amount = resolve_int_parameter("amount", skill, 1)

	if amount <= 0:
		return SkillEffectResult.failed("Amount must be positive")

	var old_max = BoardSystem.deck_system.max_plays_per_turn if BoardSystem.deck_system else 0
	BoardSystem.grant_bonus_plays(amount)
	var new_max = BoardSystem.deck_system.max_plays_per_turn if BoardSystem.deck_system else 0

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("max_plays_per_turn", old_max, new_max)
	return result
