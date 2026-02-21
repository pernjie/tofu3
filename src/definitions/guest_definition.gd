class_name GuestDefinition extends BaseDefinition

var base_needs: Dictionary  # { "food": 3, "joy": 1 }
var base_money: int
var movement_speed: int = 1
var skill_data: Array[Dictionary]  # [{ "skill_id": "...", "parameters": {...} }, ...]
var sprite_sheet: String
var animations: Dictionary
var is_core_guest: bool = true
var is_boss: bool = false
var is_mythical_beast: bool = false
var spawn_at_exit: bool = false
var move_direction: String = "forward"  # "forward" or "reverse"


static func from_dict(data: Dictionary) -> GuestDefinition:
	var def = GuestDefinition.new()
	def._populate_from_dict(data)

	var base_stats = data.get("base_stats", {})
	def.base_needs = base_stats.get("needs", {})
	def.base_money = base_stats.get("money", 0)
	def.movement_speed = base_stats.get("movement_speed", 1)

	def.sprite_sheet = data.get("sprite_sheet", "")
	def.animations = data.get("animations", {})
	def.is_core_guest = data.get("is_core_guest", true)
	def.is_boss = data.get("is_boss", false)
	def.is_mythical_beast = data.get("is_mythical_beast", false)
	def.spawn_at_exit = data.get("spawn_at_exit", false)
	def.move_direction = data.get("move_direction", "forward")

	var skills_data = data.get("skills", [])
	var skill_data_arr: Array[Dictionary] = []
	for skill in skills_data:
		if skill is Dictionary:
			skill_data_arr.append(skill)
		elif skill is String:
			skill_data_arr.append({ "skill_id": skill })
	def.skill_data = skill_data_arr

	return def
