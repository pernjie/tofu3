class_name BaseDefinition extends Resource

var id: String
var display_name_key: String
var description_key: String
var icon_path: String
var rarity: String  # common, rare, epic, legendary
var tags: Array[String]


static func from_dict(data: Dictionary) -> BaseDefinition:
	var def = BaseDefinition.new()
	def.id = data.get("id", "")
	def.display_name_key = data.get("display_name_key", "")
	def.description_key = data.get("description_key", "")
	def.icon_path = data.get("icon_path", "")
	def.rarity = data.get("rarity", "common")
	def.tags = Array(data.get("tags", []), TYPE_STRING, "", null)
	return def


func _populate_from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	display_name_key = data.get("display_name_key", "")
	description_key = data.get("description_key", "")
	icon_path = data.get("icon_path", "")
	rarity = data.get("rarity", "common")
	tags = Array(data.get("tags", []), TYPE_STRING, "", null)
