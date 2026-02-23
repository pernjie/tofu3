# src/skill_effects/restock_all_product_stalls_effect.gd
class_name RestockAllProductStallsEffect
extends SkillEffect

## Restocks every product stall on the board.
##
## Effect data:
##   type: "restock_all_product_stalls"


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var restocked_count := 0
	for stall in BoardSystem.get_all_stalls():
		if stall.get_operation_model() != "product":
			continue
		var tier_data = stall.get_current_tier_data()
		if not tier_data or stall.current_stock >= tier_data.restock_amount:
			continue
		if BoardSystem.restock_and_notify(stall):
			restocked_count += 1

	if restocked_count == 0:
		return SkillEffectResult.failed("No product stalls needed restocking")

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("restocked_count", 0, restocked_count)
	return result
