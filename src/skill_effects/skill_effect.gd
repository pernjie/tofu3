# src/skill_effects/skill_effect.gd
class_name SkillEffect
extends RefCounted

## Base class for skill effects.
## Subclasses implement execute() to perform the actual effect.

var effect_data: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	effect_data = data


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	## Override in subclasses to implement the effect.
	push_warning("SkillEffect.execute() not implemented for: %s" % get_effect_type())
	return SkillEffectResult.failed("Not implemented")


func get_effect_type() -> String:
	return effect_data.get("type", "unknown")


func get_target_string() -> String:
	return effect_data.get("target", "self")


func resolve_target(context: TriggerContext, skill: SkillInstance) -> BaseInstance:
	## Resolve the target entity for this effect.
	var target_str = get_target_string()
	return context.resolve_target_entity(target_str, skill)


func resolve_parameter(value: Variant, skill: SkillInstance) -> Variant:
	## Resolve a value that may be a parameter reference.
	## Parameter references are strings like "{gold_amount}".
	if value is String and value.begins_with("{") and value.ends_with("}"):
		var param_name = value.substr(1, value.length() - 2)
		var param_value = skill.get_parameter(param_name)
		if param_value != null:
			return param_value
		push_warning("Parameter '%s' not found in skill '%s'" % [param_name, skill.definition.id])
		return null
	return value


func resolve_int_parameter(key: String, skill: SkillInstance, default: int = 0) -> int:
	## Convenience method to resolve an integer parameter.
	var raw_value = effect_data.get(key, default)
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
	var raw_value = effect_data.get(key, default)
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
	var raw_value = effect_data.get(key, default)
	var resolved = resolve_parameter(raw_value, skill)
	if resolved == null:
		return default
	return str(resolved)


func resolve_array_parameter(key: String, skill: SkillInstance, default: Array = []) -> Array:
	## Convenience method to resolve an array parameter.
	var raw_value = effect_data.get(key, default)
	var resolved = resolve_parameter(raw_value, skill)
	if resolved is Array:
		return resolved
	return default
