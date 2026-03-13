class_name CardDefinition extends BaseDefinition

var card_type: String  # stall, spell, relic
var hero_id: String  # Empty string = neutral card
var shopable: bool  # Whether this card appears in shop offerings
var skill_data: Array[Dictionary]  # [{ "skill_id": "...", "parameters": {...} }, ...]


func get_price() -> int:
	return RARITY_PRICES.get(rarity, 0)


func get_description() -> String:
	# Explicit description overrides auto-generated
	var explicit := super.get_description()
	if explicit:
		return explicit

	# Auto-concat skill descriptions
	var parts: Array[String] = []
	for entry in skill_data:
		var skill_id: String = entry.get("skill_id", "")
		if skill_id.is_empty():
			continue
		var skill_def := ContentRegistry.get_definition("skills", skill_id) as SkillDefinition
		if skill_def and skill_def.description:
			parts.append(skill_def.description)
	return "\n".join(parts)


static func from_dict(data: Dictionary) -> CardDefinition:
	var def = CardDefinition.new()
	def._populate_from_dict(data)
	def._populate_card_fields(data)
	return def


func _populate_card_fields(data: Dictionary) -> void:
	card_type = data.get("card_type", "")
	hero_id = data.get("hero_id", "")
	shopable = data.get("shopable", true)

	var skills_data = data.get("skills", [])
	var skill_data_arr: Array[Dictionary] = []
	for skill in skills_data:
		if skill is Dictionary:
			skill_data_arr.append(skill)
		elif skill is String:
			skill_data_arr.append({ "skill_id": skill })
	skill_data = skill_data_arr
