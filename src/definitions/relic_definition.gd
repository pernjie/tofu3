class_name RelicDefinition extends CardDefinition

var sprite_sheet: String
var animations: Dictionary


static func from_dict(data: Dictionary) -> RelicDefinition:
	var def = RelicDefinition.new()
	def._populate_from_dict(data)
	def._populate_card_fields(data)

	def.sprite_sheet = data.get("sprite_sheet", "")
	def.animations = data.get("animations", {})

	return def
