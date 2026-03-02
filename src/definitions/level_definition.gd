class_name LevelDefinition extends BaseDefinition

var level_number: int
var guest_groups: Array[Dictionary]  # [{ id, weight, guests: [guest_id, ...] }]
var boss_guests: Array[String]  # guest_ids for boss spawn; one selected randomly if multiple
var special_rules: Array[Dictionary]


static func from_dict(data: Dictionary) -> LevelDefinition:
	var def = LevelDefinition.new()
	def._populate_from_dict(data)

	def.level_number = data.get("level_number", 1)

	var groups: Array[Dictionary] = []
	for group in data.get("guest_groups", []):
		groups.append(group)
	def.guest_groups = groups

	# Support both string and array for boss_guest(s)
	var boss_raw = data.get("boss_guests", [])
	if boss_raw is String:
		if boss_raw != "":
			def.boss_guests = [boss_raw]
	elif boss_raw is Array:
		for entry in boss_raw:
			def.boss_guests.append(entry)

	var rules: Array[Dictionary] = []
	for rule in data.get("special_rules", []):
		rules.append(rule)
	def.special_rules = rules

	return def
