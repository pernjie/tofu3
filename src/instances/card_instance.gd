# src/instances/card_instance.gd
class_name CardInstance
extends RefCounted

## Runtime instance of a card in the player's possession.
## Tracks location, enhancements, and temporary modifiers.

enum Location {
	DECK,
	HAND,
	DISCARD,
	SHOP,
	PLAYED,
	REMOVED,
}

const DEFAULT_ENHANCEMENT_LIMIT: int = 1

var definition: CardDefinition
var instance_id: String
var location: Location = Location.DECK
var enhancements: Array = []  # Array[EnhancementDefinition]
var modifier_stack: ModifierStack
var skill_instances: Array  # Array of SkillInstance
var price_offset: int = 0  # Random shop price variance
var temporary_state: Dictionary = {}  # For "this card gains +1 this turn" effects


func _init(def: CardDefinition = null) -> void:
	instance_id = _generate_instance_id()
	modifier_stack = ModifierStack.new()
	skill_instances = []
	enhancements = []

	if def:
		definition = def
		_initialize_from_definition(def)


func _initialize_from_definition(def: CardDefinition) -> void:
	# Create skill instances for card skills
	for entry in def.skill_data:
		var skill_id = entry.get("skill_id", "")
		var skill_def = ContentRegistry.get_definition("skills", skill_id)
		if skill_def:
			var skill_instance = SkillInstance.new(skill_def, null)
			var param_overrides = entry.get("parameters", {})
			for param_name in param_overrides:
				skill_instance.parameter_overrides[param_name] = param_overrides[param_name]
			skill_instances.append(skill_instance)


func get_card_type() -> String:
	return definition.card_type if definition else ""


func get_effective_price() -> int:
	var base_price = definition.get_price() if definition else 0
	var price = modifier_stack.calculate_stat("price", base_price) + price_offset
	return maxi(price, 1)


func get_effective_stat(stat_name: String, base_value: Variant) -> Variant:
	var value = modifier_stack.calculate_stat(stat_name, base_value)

	# Apply temporary state modifiers
	var bonus_key = stat_name + "_bonus"
	if temporary_state.has(bonus_key):
		value += temporary_state[bonus_key]

	return value


func get_enhancement_limit() -> int:
	return modifier_stack.calculate_stat("enhancement_limit", DEFAULT_ENHANCEMENT_LIMIT)


func apply_enhancement(enhancement: EnhancementDefinition) -> bool:
	## Apply an enhancement to this card. Returns false if ineligible.
	if get_card_type() != "stall":
		return false
	var stall_def := definition as StallDefinition
	if not stall_def:
		return false
	var allowed_models: Array = enhancement.applicable_to.get("operation_models", [])
	if not allowed_models.is_empty() and stall_def.operation_model not in allowed_models:
		return false
	if enhancements.size() >= get_enhancement_limit():
		return false
	enhancements.append(enhancement)
	return true


func get_enhanced_stat_preview(stat_name: String, base_value: Variant) -> Variant:
	## Preview what a stat would be after enhancement modifiers are applied.
	## For tooltip/display only — not part of the runtime stat pipeline.
	var value = base_value
	for enhancement in enhancements:
		for mod in enhancement.stat_modifiers:
			if mod.get("stat", "") == stat_name:
				var op: String = mod.get("operation", "add")
				var mod_value = mod.get("value", 0)
				match op:
					"add":
						value += mod_value
					"multiply":
						value *= mod_value
					"set":
						value = mod_value
					"add_final":
						value += mod_value
	return value


func get_enhancement_ids() -> Array[String]:
	## Return enhancement IDs for serialization.
	var ids: Array[String] = []
	for enhancement in enhancements:
		ids.append(enhancement.id)
	return ids


func load_enhancements_from_ids(ids: Array) -> void:
	## Restore enhancements from saved ID array.
	enhancements = []
	for id in ids:
		var def = ContentRegistry.get_definition("enhancements", id)
		if def:
			enhancements.append(def)


func get_location_string() -> String:
	match location:
		Location.DECK: return "deck"
		Location.HAND: return "hand"
		Location.DISCARD: return "discard"
		Location.SHOP: return "shop"
		Location.PLAYED: return "played"
		Location.REMOVED: return "removed"
	return "unknown"


func clear_temporary_state() -> void:
	temporary_state.clear()


func _generate_instance_id() -> String:
	return "card_%d_%d" % [Time.get_ticks_msec(), randi()]
