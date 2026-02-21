class_name EnhancementDefinition extends BaseDefinition

var stat_modifiers: Array[Dictionary]
var applicable_to: Dictionary  # card_types, operation_models, excluded_stall_ids
var conflicts_with: Array[String]
var added_skills: Array[String]


static func from_dict(data: Dictionary) -> EnhancementDefinition:
	var def = EnhancementDefinition.new()
	def._populate_from_dict(data)

	def.applicable_to = data.get("applicable_to", {})
	def.conflicts_with = Array(data.get("conflicts_with", []), TYPE_STRING, "", null)
	def.added_skills = Array(data.get("added_skills", []), TYPE_STRING, "", null)

	var stat_mods: Array[Dictionary] = []
	for mod in data.get("stat_modifiers", []):
		stat_mods.append(mod)
	def.stat_modifiers = stat_mods

	return def
