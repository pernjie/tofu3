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
