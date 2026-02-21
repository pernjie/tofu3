class_name SkillDefinition extends BaseDefinition

var trigger_type: String  # passive, on_serve, on_turn_end, on_spawn, etc.
var owner_types: Array[String]  # ["guest", "stall", "relic"]
var global: bool  # If true, fires on any matching event regardless of entity involvement
var effects: Array[Dictionary]
var conditions: Array[Dictionary]
var parameters: Dictionary  # Parameter definitions with type, default, min, max
var state_template: Dictionary  # Initial state for stateful skills


static func from_dict(data: Dictionary) -> SkillDefinition:
	var def = SkillDefinition.new()
	def._populate_from_dict(data)

	def.trigger_type = data.get("trigger_type", "passive")
	def.owner_types = Array(data.get("owner_types", []), TYPE_STRING, "", null)
	def.global = data.get("global", false)
	def.parameters = data.get("parameters", {})
	def.state_template = data.get("state_template", {})

	var effects_arr: Array[Dictionary] = []
	for effect in data.get("effects", []):
		effects_arr.append(effect)
	def.effects = effects_arr

	var conditions_arr: Array[Dictionary] = []
	for condition in data.get("conditions", []):
		conditions_arr.append(condition)
	def.conditions = conditions_arr

	return def
