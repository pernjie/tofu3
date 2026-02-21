# src/instances/guest_instance.gd
class_name GuestInstance
extends BaseInstance

## Runtime instance of a guest on the board.
## Tracks position, remaining needs, money, and service state.

var current_needs: Dictionary = {}  # { "food": 2, "joy": 1 } (remaining)
var initial_needs: Dictionary = {}  # Starting needs (for display denominator)
var current_money: int = 0
var current_tile = null  # Tile reference
var path_index: int = 0  # Position along their path

# Service state
var is_in_stall: bool = false
var current_stall = null  # StallInstance
var service_turns_remaining: int = 0
var wait_turns_remaining: int = 0  # Bulk service: countdown to timeout exit

# Exit state
var is_exiting: bool = false
var is_banished: bool = false
var force_ascend: bool = false

# Beast interaction state
var interacted_this_turn: bool = false


func _init(def: GuestDefinition = null) -> void:
	super._init(def)
	if def:
		_initialize_from_definition(def)


func _initialize_from_definition(def: GuestDefinition) -> void:
	# Copy base needs as starting needs
	current_needs = def.base_needs.duplicate()
	initial_needs = def.base_needs.duplicate()
	current_money = def.base_money

	# Create skill instances
	for entry in def.skill_data:
		var skill_id = entry.get("skill_id", "")
		var skill_def = ContentRegistry.get_definition("skills", skill_id)
		if skill_def:
			var skill_instance = SkillInstance.new(skill_def, self)
			var param_overrides = entry.get("parameters", {})
			for param_name in param_overrides:
				skill_instance.parameter_overrides[param_name] = param_overrides[param_name]
			skill_instances.append(skill_instance)


func get_entity_type() -> String:
	return "guest"


func get_remaining_need(need_type: String) -> int:
	return current_needs.get(need_type, 0)


func fulfill_need(need_type: String, amount: int) -> int:
	## Fulfill a need and return the amount applied.
	## Does NOT clamp — needs can go negative (overfulfilled).
	## Returns 0 if the need is already fulfilled (at or below 0).
	var current = current_needs.get(need_type, 0)
	if current <= 0:
		return 0
	current_needs[need_type] = current - amount
	return amount


func are_all_needs_fulfilled() -> bool:
	for need_type in current_needs:
		if current_needs[need_type] > 0:
			return false
	return true


func get_total_remaining_needs() -> int:
	var total = 0
	for need_type in current_needs:
		total += current_needs[need_type]
	return total


func spend_money(amount: int) -> bool:
	## Spend money. Returns true if had enough.
	var effective_money = get_effective_money()
	if effective_money >= amount:
		current_money -= amount
		return true
	return false


func get_effective_money() -> int:
	## Get money with modifiers applied.
	return get_stat("money", current_money)


func get_movement_speed() -> int:
	var guest_def = definition as GuestDefinition
	var base_speed = guest_def.movement_speed if guest_def else 1
	return get_stat("movement_speed", base_speed)


func is_core_guest() -> bool:
	var guest_def = definition as GuestDefinition
	return guest_def.is_core_guest if guest_def else true


func is_boss() -> bool:
	var guest_def = definition as GuestDefinition
	return guest_def.is_boss if guest_def else false


func is_mythical_beast() -> bool:
	var guest_def = definition as GuestDefinition
	return guest_def.is_mythical_beast if guest_def else false


func get_move_direction() -> int:
	## Get movement direction: 1 for forward, -1 for reverse.
	var guest_def = definition as GuestDefinition
	if guest_def and guest_def.move_direction == "reverse":
		return -1
	return 1
