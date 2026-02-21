class_name LevelDefinition extends BaseDefinition

var act: int
var level_number: int
var is_boss: bool = false
var board: Dictionary  # width, height, paths, stall_slots, tile_properties
var guest_groups: Array[Dictionary]  # [{ id, weight, guests: [guest_id, ...] }]
var boss_guest: String  # guest_id appended as final spawn, empty = none
var win_condition: Dictionary  # type and parameters
var special_rules: Array[Dictionary]
var rewards: Dictionary  # tokens, card_choices


static func from_dict(data: Dictionary) -> LevelDefinition:
	var def = LevelDefinition.new()
	def._populate_from_dict(data)

	def.act = data.get("act", 1)
	def.level_number = data.get("level_number", 1)
	def.is_boss = data.get("is_boss", false)
	def.board = data.get("board", {})
	def.boss_guest = data.get("boss_guest", "")

	var groups: Array[Dictionary] = []
	for group in data.get("guest_groups", []):
		groups.append(group)
	def.guest_groups = groups

	def.win_condition = data.get("win_condition", {})
	def.rewards = data.get("rewards", {})

	var rules: Array[Dictionary] = []
	for rule in data.get("special_rules", []):
		rules.append(rule)
	def.special_rules = rules

	return def
