# src/instances/stall_instance.gd
class_name StallInstance
extends BaseInstance

## Runtime instance of a stall placed on the board.
## Tracks tier, stock, occupants, and enhancements.

enum BulkPhase { IDLE, WAITING, SERVING }

const _OPERATION_MAP: Dictionary = {
	"add": StatModifier.Operation.ADD,
	"multiply": StatModifier.Operation.MULTIPLY,
	"set": StatModifier.Operation.SET,
	"add_final": StatModifier.Operation.ADD_FINAL,
}

var current_tier: int = 1
var tile = null  # Tile reference
var board_position: Vector2i = Vector2i.ZERO  # Position on board
var enhancements: Array = []  # Array[EnhancementDefinition]

# Product stall state
var current_stock: int = 0
var restock_cooldown: int = 0

# Service stall state
var current_occupants: Array = []  # Array of GuestInstance

# Bulk service state
var bulk_phase: BulkPhase = BulkPhase.IDLE

# Runtime override for need_type (set by skills like silk_market_midnight_shift)
var need_type_override: String = ""


func _init(def: StallDefinition = null) -> void:
	super._init(def)
	if def:
		_initialize_from_definition(def)


func _initialize_from_definition(def: StallDefinition) -> void:
	current_tier = 1

	# Initialize stock for product stalls
	if def.operation_model == "product":
		current_stock = get_restock_amount()

	# Create skill instances from tier data
	var tier_data = get_current_tier_data()
	if tier_data:
		_build_skills_from_tier(tier_data)


func _build_skills_from_tier(tier_data: StallTierData) -> void:
	## Build skill instances from a tier's skill_data array.
	for entry in tier_data.skill_data:
		var skill_id = entry.get("skill_id", "")
		var skill_def = ContentRegistry.get_definition("skills", skill_id)
		if skill_def:
			var skill_instance = SkillInstance.new(skill_def, self)
			var param_overrides = entry.get("parameters", {})
			for param_name in param_overrides:
				skill_instance.parameter_overrides[param_name] = param_overrides[param_name]
			skill_instances.append(skill_instance)


func get_entity_type() -> String:
	return "stall"


func get_stall_definition() -> StallDefinition:
	return definition as StallDefinition


func get_current_tier_data() -> StallTierData:
	var stall_def = get_stall_definition()
	if stall_def and stall_def.tiers.size() >= current_tier:
		return stall_def.tiers[current_tier - 1]
	return null


func get_operation_model() -> String:
	var stall_def = get_stall_definition()
	return stall_def.operation_model if stall_def else "product"


func get_need_type() -> String:
	if not need_type_override.is_empty():
		return need_type_override
	var stall_def = get_stall_definition()
	return stall_def.need_type if stall_def else "food"


func resolve_need_type_for_guest(guest: GuestInstance) -> String:
	## Resolve the actual need type to fulfill for a specific guest.
	## For "any" stalls, randomly picks one of the guest's unfulfilled needs.
	var need_type = get_need_type()
	if need_type != "any":
		return need_type
	var unfulfilled: Array[String] = []
	for type in guest.current_needs:
		if guest.get_remaining_need(type) > 0:
			unfulfilled.append(type)
	if unfulfilled.is_empty():
		return ""
	return unfulfilled.pick_random()


func get_cost_to_guest() -> int:
	var tier_data = get_current_tier_data()
	var base_cost = tier_data.cost_to_guest if tier_data else 0
	return maxi(get_stat("cost_to_guest", base_cost), 0)


func get_value() -> int:
	## Get how much need this stall fulfills.
	var tier_data = get_current_tier_data()
	var base_value = tier_data.value if tier_data else 0
	return maxi(get_stat("value", base_value), 0)


func get_capacity() -> int:
	## For service stalls: max simultaneous guests.
	var tier_data = get_current_tier_data()
	var base = tier_data.capacity if tier_data else 1
	return maxi(get_stat("capacity", base), 0)


func get_service_duration() -> int:
	## For service stalls: turns to complete service.
	var tier_data = get_current_tier_data()
	var base = tier_data.service_duration if tier_data else 1
	return maxi(get_stat("service_duration", base), 0)


func get_restock_amount() -> int:
	## For product stalls: stock refilled on restock.
	var tier_data = get_current_tier_data()
	var base = tier_data.restock_amount if tier_data else 0
	return maxi(get_stat("restock_amount", base), 0)


func get_restock_duration() -> int:
	## For product stalls: turns of cooldown before auto-restock.
	var tier_data = get_current_tier_data()
	var base = tier_data.restock_duration if tier_data else 0
	return maxi(get_stat("restock_duration", base), 0)


func apply_enhancements(enhancement_list: Array, register_with_trigger_system: bool = false) -> void:
	## Apply a list of enhancements to this stall (modifiers + skills).
	## Called on initial placement and on upgrade merge.
	## Set register_with_trigger_system=true when calling after entity is already registered
	## (e.g. during upgrade merge).
	_inject_enhancement_modifiers(enhancement_list)
	_register_enhancement_skills(enhancement_list, register_with_trigger_system)


func _inject_enhancement_modifiers(enhancement_list: Array) -> void:
	## Convert enhancement stat_modifiers to StatModifier objects and add to modifier_stack.
	for enhancement in enhancement_list:
		for mod_dict in enhancement.stat_modifiers:
			var stat_name: String = mod_dict.get("stat", "")
			var op_string: String = mod_dict.get("operation", "add")
			var mod_value = mod_dict.get("value", 0)
			var operation = _OPERATION_MAP.get(op_string, StatModifier.Operation.ADD)
			var modifier = StatModifier.new(stat_name, operation, mod_value, enhancement)
			modifier_stack.add_modifier(modifier)


func _register_enhancement_skills(enhancement_list: Array, register_with_trigger_system: bool = false) -> void:
	## Instantiate skills granted by enhancements and add to skill_instances.
	## If register_with_trigger_system is true, also register with TriggerSystem directly
	## (used for upgrade merge when entity skills are already registered).
	var trigger_system = _get_trigger_system() if register_with_trigger_system else null
	for enhancement in enhancement_list:
		for skill_id in enhancement.added_skills:
			var skill_def = ContentRegistry.get_definition("skills", skill_id)
			if skill_def:
				var skill_instance = SkillInstance.new(skill_def, self)
				skill_instances.append(skill_instance)
				if trigger_system:
					trigger_system.register_skill(skill_instance)


func can_serve_guest(guest: GuestInstance) -> bool:
	## Check if this stall can serve the given guest.
	var stall_def = get_stall_definition()
	if not stall_def:
		return false

	# Check if guest has the need type ("any" matches any unfulfilled need)
	var need_type = get_need_type()
	if need_type == "any":
		var has_any_need = false
		for type in guest.current_needs:
			if guest.get_remaining_need(type) > 0:
				has_any_need = true
				break
		if not has_any_need:
			return false
	elif guest.get_remaining_need(need_type) <= 0:
		return false

	# Check if guest can afford it
	if guest.get_effective_money() < get_cost_to_guest():
		return false

	# For product stalls, check stock
	if stall_def.operation_model == "product" and current_stock <= 0:
		return false

	# For service stalls, check capacity
	if stall_def.operation_model == "service":
		if current_occupants.size() >= get_capacity():
			return false

	# For bulk_service stalls, check capacity and phase
	if stall_def.operation_model == "bulk_service":
		if current_occupants.size() >= get_capacity():
			return false
		if bulk_phase == BulkPhase.SERVING:
			return false

	return true


func use_stock(amount: int = 1) -> bool:
	## Consume stock. Returns true if stock just depleted (was > 0, now 0).
	var old_stock = current_stock
	current_stock = maxi(current_stock - amount, 0)

	# Start restock cooldown when stock depletes
	var just_depleted = old_stock > 0 and current_stock == 0
	if just_depleted:
		var tier_data = get_current_tier_data()
		var duration = get_restock_duration()
		if tier_data and tier_data.auto_restock and duration > 0:
			restock_cooldown = duration

	return just_depleted


func restock() -> void:
	current_stock = get_restock_amount()


func can_upgrade() -> bool:
	var stall_def = get_stall_definition()
	if not stall_def:
		return false
	return current_tier < stall_def.tiers.size()


func upgrade() -> bool:
	if can_upgrade():
		# Separate enhancement-granted skills from tier skills for preservation
		var enhancement_skill_ids: Dictionary = {}
		for enhancement in enhancements:
			for skill_id in enhancement.added_skills:
				enhancement_skill_ids[skill_id] = true
		var enhancement_skills: Array = []
		var tier_skills: Array = []
		for skill in skill_instances:
			if skill.definition and enhancement_skill_ids.has(skill.definition.id):
				enhancement_skills.append(skill)
			else:
				tier_skills.append(skill)

		# Snapshot old tier skills by skill_id for diffing
		var old_skills_by_id: Dictionary = {}
		for skill in tier_skills:
			if skill.definition:
				old_skills_by_id[skill.definition.id] = skill

		current_tier += 1

		# Refresh stock for product stalls (new tier may have more stock)
		if get_operation_model() == "product":
			current_stock = get_restock_amount()
			restock_cooldown = 0  # Reset cooldown

		# Rebuild skills from new tier
		var new_tier_data = get_current_tier_data()
		var new_skill_instances: Array = []

		if new_tier_data:
			for entry in new_tier_data.skill_data:
				var skill_id = entry.get("skill_id", "")
				var param_overrides = entry.get("parameters", {})

				if old_skills_by_id.has(skill_id):
					# Carry over existing skill, update parameters
					var existing_skill = old_skills_by_id[skill_id]
					existing_skill.parameter_overrides = {}
					for param_name in param_overrides:
						existing_skill.parameter_overrides[param_name] = param_overrides[param_name]
					new_skill_instances.append(existing_skill)
					old_skills_by_id.erase(skill_id)
				else:
					# New skill — create fresh
					var skill_def = ContentRegistry.get_definition("skills", skill_id)
					if skill_def:
						var skill_instance = SkillInstance.new(skill_def, self)
						for param_name in param_overrides:
							skill_instance.parameter_overrides[param_name] = param_overrides[param_name]
						new_skill_instances.append(skill_instance)

		# Unregister removed tier skills (anything left in old_skills_by_id)
		var trigger_system = _get_trigger_system()
		if trigger_system:
			for skill in old_skills_by_id.values():
				trigger_system.unregister_skill(skill)
			# Register new tier skills (ones not carried over)
			for skill in new_skill_instances:
				if skill not in tier_skills:
					trigger_system.register_skill(skill)

		# Preserve enhancement-granted skills alongside rebuilt tier skills
		skill_instances = new_skill_instances + enhancement_skills
		return true
	return false


func add_occupant(guest: GuestInstance) -> void:
	if guest not in current_occupants:
		current_occupants.append(guest)


func remove_occupant(guest: GuestInstance) -> void:
	current_occupants.erase(guest)
	if current_occupants.is_empty():
		bulk_phase = BulkPhase.IDLE


func _get_trigger_system():
	## Get TriggerSystem autoload. Returns null if not available.
	var tree = Engine.get_main_loop()
	if tree and tree is SceneTree:
		return tree.root.get_node_or_null("TriggerSystem")
	return null
