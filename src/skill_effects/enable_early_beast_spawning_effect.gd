# src/skill_effects/enable_early_beast_spawning_effect.gd
class_name EnableEarlyBeastSpawningEffect
extends SkillEffect

## Enables beast spawning before midnight for the current level.
## Sets TurnSystem.early_beast_spawning = true.
##
## Effect data:
##   type: "enable_early_beast_spawning"


func execute(_context: TriggerContext, _skill: SkillInstance) -> SkillEffectResult:
	TurnSystem.early_beast_spawning = true
	return SkillEffectResult.succeeded()
