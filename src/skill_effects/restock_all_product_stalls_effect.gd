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
		if stall.current_stock >= stall.get_restock_amount():
			continue
		if BoardSystem.restock_and_notify(stall):
			restocked_count += 1

	if restocked_count == 0:
		return SkillEffectResult.failed("No product stalls needed restocking")

	var result = SkillEffectResult.succeeded()
	result.set_value_changed("restocked_count", 0, restocked_count)
	return result
