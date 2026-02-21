# src/skill_effects/skill_effect_result.gd
class_name SkillEffectResult
extends RefCounted

## Result container for effect execution.
## Tracks success, any modifications made, and data for chaining.

var success: bool = false
var modified_targets: Array = []  # Entities that were modified
var values_changed: Dictionary = {}  # Stat/value changes made
var error_message: String = ""
var deferred_request: Dictionary = {}  # Non-empty if this result needs UI resolution


static func succeeded() -> SkillEffectResult:
	var result = SkillEffectResult.new()
	result.success = true
	return result


static func failed(message: String = "") -> SkillEffectResult:
	var result = SkillEffectResult.new()
	result.success = false
	result.error_message = message
	return result


static func deferred(request: Dictionary) -> SkillEffectResult:
	## Create a deferred result that requires UI interaction to resolve.
	var result = SkillEffectResult.new()
	result.success = true
	result.deferred_request = request
	return result


func add_modified_target(entity: BaseInstance) -> SkillEffectResult:
	if entity and entity not in modified_targets:
		modified_targets.append(entity)
	return self


func set_value_changed(key: String, old_value: Variant, new_value: Variant) -> SkillEffectResult:
	values_changed[key] = {
		"old": old_value,
		"new": new_value
	}
	return self
