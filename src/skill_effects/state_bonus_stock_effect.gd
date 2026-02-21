# src/skill_effects/state_bonus_stock_effect.gd
class_name StateBonusStockEffect
extends SkillEffect

## Adds bonus stock to a stall based on a skill state counter value.
##
## Effect data:
##   type: "state_bonus_stock"
##   state_key: string (key in skill.state to read)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var stall = context.stall
	if not stall:
		return SkillEffectResult.failed("No stall in context")

	var state_key = effect_data.get("state_key", "")
	if state_key.is_empty():
		return SkillEffectResult.failed("No state_key specified")

	var bonus = skill.get_state(state_key, 0)
	if bonus <= 0:
		return SkillEffectResult.succeeded()

	var old_stock = stall.current_stock
	stall.current_stock += bonus

	if BoardSystem.board_visual:
		var entity = BoardSystem.board_visual.get_stall_entity(stall.board_position)
		if entity:
			entity.update_labels()

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("stock", old_stock, stall.current_stock)
	return result
