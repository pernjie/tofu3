# src/instances/card_instance.gd
class_name CardInstance
extends RefCounted

## Runtime instance of a card in the player's possession.
## Tracks location, enhancement, and temporary modifiers.

enum Location {
	DECK,
	HAND,
	DISCARD,
	SHOP,
	PLAYED,
	REMOVED,
}

var definition: CardDefinition
var instance_id: String
var location: Location = Location.DECK
var enhancement = null  # EnhancementDefinition
var modifier_stack: ModifierStack
var skill_instances: Array  # Array of SkillInstance
var temporary_state: Dictionary = {}  # For "this card gains +1 this turn" effects


func _init(def: CardDefinition = null) -> void:
	instance_id = _generate_instance_id()
	modifier_stack = ModifierStack.new()
	skill_instances = []

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
	if enhancement:
		# Apply enhancement price modification if any
		pass
	return modifier_stack.calculate_stat("price", base_price)


func get_effective_stat(stat_name: String, base_value: Variant) -> Variant:
	var value = base_value
	if enhancement:
		# Apply enhancement stat modification
		pass
	value = modifier_stack.calculate_stat(stat_name, value)

	# Apply temporary state modifiers
	var bonus_key = stat_name + "_bonus"
	if temporary_state.has(bonus_key):
		value += temporary_state[bonus_key]

	return value


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
