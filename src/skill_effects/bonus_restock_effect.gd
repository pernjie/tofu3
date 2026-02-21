# src/skill_effects/bonus_restock_effect.gd
class_name BonusRestockEffect
extends SkillEffect

## Adds bonus stock to a stall equal to its restock_amount.
## Used to "double" a restock by granting the same amount again.
##
## Effect data:
##   type: "bonus_restock"


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var stall = context.stall
	if not stall:
		return SkillEffectResult.failed("No stall in context")

	var tier_data = stall.get_current_tier_data()
	if not tier_data:
		return SkillEffectResult.failed("Stall has no tier data")

	var bonus = tier_data.restock_amount
	var old_stock = stall.current_stock
	stall.current_stock += bonus

	if BoardSystem.board_visual:
		var entity = BoardSystem.board_visual.get_stall_entity(stall.board_position)
		if entity:
			entity.update_labels()

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("stock", old_stock, stall.current_stock)
	return result
