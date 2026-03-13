class_name EnhancementDefinition extends BaseDefinition

var shopable: bool
var hero_id: String  # Empty string = neutral (available to all heroes)
var stat_modifiers: Array[Dictionary]
var applicable_to: Dictionary  # { "operation_models": Array[String] }
var added_skills: Array[String]


func get_price() -> int:
	return RARITY_PRICES.get(rarity, 0)


static func from_dict(data: Dictionary) -> EnhancementDefinition:
	var def = EnhancementDefinition.new()
	def._populate_from_dict(data)

	def.shopable = data.get("shopable", true)
	def.hero_id = data.get("hero_id", "")
	def.applicable_to = data.get("applicable_to", {})
	def.added_skills = Array(data.get("added_skills", []), TYPE_STRING, "", null)

	var stat_mods: Array[Dictionary] = []
	for mod in data.get("stat_modifiers", []):
		stat_mods.append(mod)
	def.stat_modifiers = stat_mods

	return def
