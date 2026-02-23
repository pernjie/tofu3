# src/skill_conditions/skill_condition.gd
class_name SkillCondition
extends RefCounted

## Base class for skill conditions.
## Subclasses implement evaluate() to check if the condition is met.

var condition_data: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	condition_data = data


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	## Override in subclasses to implement the condition check.
	push_warning("SkillCondition.evaluate() not implemented for: %s" % get_condition_type())
	return false


func get_condition_type() -> String:
	return condition_data.get("type", "unknown")


func resolve_parameter(value: Variant, skill: SkillInstance) -> Variant:
	## Resolve a value that may be a parameter reference.
	## Parameter references are strings like "{turns_threshold}".
	if value is String and value.begins_with("{") and value.ends_with("}"):
		var param_name = value.substr(1, value.length() - 2)
		var param_value = skill.get_parameter(param_name)
		if param_value != null:
			return param_value
		push_warning("Parameter '%s' not found in skill '%s'" % [param_name, skill.definition.id])
		return 0
	return value


func resolve_int_parameter(key: String, skill: SkillInstance, default: int = 0) -> int:
	## Convenience method to resolve an integer parameter.
	var raw_value = condition_data.get(key, default)
	var resolved = resolve_parameter(raw_value, skill)
	if resolved is int:
		return resolved
	if resolved is float:
		return int(resolved)
	if resolved is String:
		return int(resolved) if resolved.is_valid_int() else default
	return default


func resolve_float_parameter(key: String, skill: SkillInstance, default: float = 0.0) -> float:
	## Convenience method to resolve a float parameter.
	var raw_value = condition_data.get(key, default)
	var resolved = resolve_parameter(raw_value, skill)
	if resolved is float:
		return resolved
	if resolved is int:
		return float(resolved)
	if resolved is String:
		return float(resolved) if resolved.is_valid_float() else default
	return default


func resolve_string_parameter(key: String, skill: SkillInstance, default: String = "") -> String:
	## Convenience method to resolve a string parameter.
	var raw_value = condition_data.get(key, default)
	var resolved = resolve_parameter(raw_value, skill)
	return str(resolved)
