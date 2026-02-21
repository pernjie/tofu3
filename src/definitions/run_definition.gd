class_name RunDefinition
extends BaseDefinition

## Defines the structure of a game run (acts and levels).

var acts: Array = []  # Array of ActData


static func from_dict(data: Dictionary) -> RunDefinition:
	var def = RunDefinition.new()
	def.id = data.get("id", "")
	def.display_name_key = data.get("display_name_key", "")
	def.description_key = data.get("description_key", "")

	# Parse acts
	for act_data in data.get("acts", []):
		var act = ActData.new()
		act.act_number = act_data.get("act_number", 1)
		act.levels = []
		for level_id in act_data.get("levels", []):
			act.levels.append(level_id)
		act.boss = act_data.get("boss", "")
		def.acts.append(act)

	return def


func get_level_id(act: int, level_index: int, is_boss: bool) -> String:
	## Get the level ID for a given position in the run.
	if act < 1 or act > acts.size():
		return ""

	var act_data = acts[act - 1]

	if is_boss:
		return act_data.boss

	if level_index < 0 or level_index >= act_data.levels.size():
		return ""

	return act_data.levels[level_index]


func get_levels_in_act(act: int) -> int:
	## Get the number of regular levels in an act.
	if act < 1 or act > acts.size():
		return 0
	return acts[act - 1].levels.size()


func get_total_acts() -> int:
	return acts.size()


class ActData:
	var act_number: int = 1
	var levels: Array = []  # Array of String (level IDs)
	var boss: String = ""
