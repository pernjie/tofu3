# src/instances/skill_instance.gd
class_name SkillInstance
extends RefCounted

## Runtime instance of a skill, tracking per-instance state.
## Each entity with a skill gets its own SkillInstance.

var definition: SkillDefinition
var owner: BaseInstance  # The entity that has this skill
var state: Dictionary     # Runtime state (counters, etc.)
var is_active: bool = true
var parameter_overrides: Dictionary = {}  # Instance-level parameter overrides


func _init(def: SkillDefinition = null, skill_owner: BaseInstance = null) -> void:
	if def:
		definition = def
		# Deep copy state template so each instance has independent state
		if def.state_template:
			state = def.state_template.duplicate(true)
		else:
			state = {}
	owner = skill_owner


func get_parameter(param_name: String) -> Variant:
	## Get a parameter value.
	## Resolution order: instance overrides → definition defaults → owner persistent_state.
	if parameter_overrides.has(param_name):
		return parameter_overrides[param_name]
	if definition and definition.parameters.has(param_name):
		var param_def = definition.parameters[param_name]
		if param_def is Dictionary and param_def.has("default"):
			return param_def["default"]
		return param_def
	if owner and owner.persistent_state.has(param_name):
		return owner.persistent_state[param_name]
	return null


func get_state(key: String, default_value: Variant = null) -> Variant:
	return state.get(key, default_value)


func set_state(key: String, value: Variant) -> void:
	state[key] = value


func increment_state(key: String, amount: int = 1) -> int:
	var current = state.get(key, 0)
	state[key] = current + amount
	return state[key]


func reset_state() -> void:
	if definition and definition.state_template:
		state = definition.state_template.duplicate(true)
	else:
		state.clear()
