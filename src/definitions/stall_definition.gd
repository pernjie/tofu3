class_name StallDefinition extends CardDefinition

var operation_model: String  # product, service, bulk_service
var need_type: String  # food, joy
var tiers: Array[StallTierData]
var placement_restriction: String
var sprite_sheet: String
var animations: Dictionary


func get_explicit_description() -> String:
	## Returns the explicit description only (no auto-generation from skills).
	return super.get_description()


func get_description() -> String:
	# Explicit description overrides auto-generated
	var explicit := super.get_description()
	if explicit:
		return explicit

	# Auto-concat skill descriptions from tier 1
	if tiers.is_empty():
		return ""
	var parts: Array[String] = []
	for entry in tiers[0].skill_data:
		var skill_id: String = entry.get("skill_id", "")
		if skill_id.is_empty():
			continue
		var skill_def := ContentRegistry.get_definition("skills", skill_id) as SkillDefinition
		if skill_def and skill_def.description:
			parts.append(skill_def.description)
	return "\n".join(parts)


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
