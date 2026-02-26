class_name SpellDefinition extends CardDefinition

var target_type: String  # stall, guest, tile, none
var target_filter: Dictionary
var effects: Array[Dictionary]


static func from_dict(data: Dictionary) -> SpellDefinition:
	var def = SpellDefinition.new()
	def._populate_from_dict(data)
	def._populate_card_fields(data)

	def.target_type = data.get("target_type", "none")
	def.target_filter = data.get("target_filter", {})

	var effects_arr: Array[Dictionary] = []
	for effect in data.get("effects", []):
		effects_arr.append(effect)
	def.effects = effects_arr

	return def


func is_valid_stall_target(stall: StallInstance) -> bool:
	## Check if a stall passes this spell's target_filter.
	if target_filter.is_empty():
		return true
	if target_filter.has("need_type") and stall.definition.need_type != target_filter["need_type"]:
		return false
	if target_filter.has("operation_model") and stall.definition.operation_model != target_filter["operation_model"]:
		return false
	if target_filter.has("has_tag") and target_filter["has_tag"] not in stall.definition.tags:
		return false
	if target_filter.has("can_upgrade") and stall.can_upgrade() != target_filter["can_upgrade"]:
		return false
	return true


func is_valid_tile_target(pos: Vector2i) -> bool:
	## Check if a tile position passes this spell's target_filter.
	if target_filter.is_empty():
		return true
	if target_filter.has("is_on_path"):
		var on_path = BoardSystem.board.get_tile_at(pos) != null
		if on_path != target_filter["is_on_path"]:
			return false
	if target_filter.has("has_stall"):
		var has_stall = BoardSystem.get_stall_at(pos) != null
		if has_stall != target_filter["has_stall"]:
			return false
	if target_filter.has("has_guest"):
		var has_guest = not BoardSystem.get_guests_at(pos).is_empty()
		if has_guest != target_filter["has_guest"]:
			return false
	return true


func is_valid_guest_target(guest: GuestInstance) -> bool:
	## Check if a guest passes this spell's target_filter.
	if target_filter.is_empty():
		return true
	if target_filter.has("has_status") and not guest.has_status(target_filter["has_status"]):
		return false
	if target_filter.has("has_tag") and target_filter["has_tag"] not in guest.definition.tags:
		return false
	if target_filter.has("is_core_guest") and guest.definition.is_core_guest != target_filter["is_core_guest"]:
		return false
	return true
