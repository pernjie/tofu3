class_name CardDefinition extends BaseDefinition

const RARITY_PRICES: Dictionary = {
	"common": 30,
	"rare": 50,
	"epic": 80,
	"legendary": 120,
}

var card_type: String  # stall, spell, relic
var hero_id: String  # Empty string = neutral card
var skill_data: Array[Dictionary]  # [{ "skill_id": "...", "parameters": {...} }, ...]


func get_price() -> int:
	return RARITY_PRICES.get(rarity, 0)


static func from_dict(data: Dictionary) -> CardDefinition:
	var def = CardDefinition.new()
	def._populate_from_dict(data)
	def._populate_card_fields(data)
	return def


func _populate_card_fields(data: Dictionary) -> void:
	card_type = data.get("card_type", "")
	hero_id = data.get("hero_id", "")

	var skills_data = data.get("skills", [])
	var skill_data_arr: Array[Dictionary] = []
	for skill in skills_data:
		if skill is Dictionary:
			skill_data_arr.append(skill)
		elif skill is String:
			skill_data_arr.append({ "skill_id": skill })
	skill_data = skill_data_arr
