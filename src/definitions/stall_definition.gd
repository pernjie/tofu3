class_name StallDefinition extends CardDefinition

var operation_model: String  # product, service, bulk_service
var need_type: String  # food, joy
var tiers: Array[StallTierData]
var placement_restriction: String
var sprite_sheet: String
var animations: Dictionary


static func from_dict(data: Dictionary) -> StallDefinition:
	var def = StallDefinition.new()
	def._populate_from_dict(data)
	def._populate_card_fields(data)

	def.operation_model = data.get("operation_model", "product")
	def.need_type = data.get("need_type", "")
	var restriction = data.get("placement_restriction")
	def.placement_restriction = restriction if restriction != null else ""
	def.sprite_sheet = data.get("sprite_sheet", "")
	def.animations = data.get("animations", {})

	var tiers_arr: Array[StallTierData] = []
	for tier_data in data.get("tiers", []):
		tiers_arr.append(StallTierData.from_dict(tier_data))
	def.tiers = tiers_arr

	return def
