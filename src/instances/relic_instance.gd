# src/instances/relic_instance.gd
class_name RelicInstance
extends BaseInstance

## Runtime instance of a relic placed on the board.
## Relics are permanent structures that provide passive effects through skills.

var tile = null  # Tile reference
var board_position: Vector2i = Vector2i.ZERO


func _init(def: RelicDefinition = null) -> void:
	super._init(def)
	if def:
		_build_skills(def)


func _build_skills(def: RelicDefinition) -> void:
	## Build skill instances from the definition's skill_data.
	for entry in def.skill_data:
		var skill_id = entry.get("skill_id", "")
		var skill_def = ContentRegistry.get_definition("skills", skill_id)
		if skill_def:
			var skill_instance = SkillInstance.new(skill_def, self)
			var param_overrides = entry.get("parameters", {})
			for param_name in param_overrides:
				skill_instance.parameter_overrides[param_name] = param_overrides[param_name]
			skill_instances.append(skill_instance)


func get_entity_type() -> String:
	return "relic"


func get_relic_definition() -> RelicDefinition:
	return definition as RelicDefinition
