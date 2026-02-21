# src/skill_effects/grant_tokens_effect.gd
class_name GrantTokensEffect
extends SkillEffect

## Grants tokens to the player.
##
## Effect data:
##   type: "grant_tokens"
##   target: "player" (only valid target)
##   amount: int or "{parameter_name}"


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var amount = resolve_int_parameter("amount", skill, 0)

	if amount <= 0:
		return SkillEffectResult.failed("Amount must be positive")

	var old_tokens = GameManager.tokens
	BoardSystem.add_tokens(amount)
	var new_tokens = GameManager.tokens

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("tokens", old_tokens, new_tokens)
	return result
