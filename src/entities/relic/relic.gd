class_name RelicEntity
extends Node2D

## Visual representation of a relic on the board.

var instance: RelicInstance

@onready var sprite: ColorRect = $Sprite
@onready var name_label: Label = $NameLabel

const TILE_SIZE := 144
const SPRITE_SIZE := 108


func setup(relic_instance: RelicInstance, tile_pos: Vector2i) -> void:
	instance = relic_instance
	position = Vector2(tile_pos.x, tile_pos.y) * TILE_SIZE
	position += Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	refresh()


func refresh() -> void:
	if not instance:
		return
	sprite.color = Color.MEDIUM_PURPLE
	name_label.text = instance.definition.id.replace("_", " ").capitalize()


func _input(event: InputEvent) -> void:
	var board_visual := get_parent().get_parent() as BoardVisual
	if board_visual and board_visual.placement_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = to_local(event.global_position)
		var half_size = SPRITE_SIZE / 2.0
		if local_pos.x >= -half_size and local_pos.x <= half_size and local_pos.y >= -half_size and local_pos.y <= half_size:
			if instance:
				EventBus.debug_show_relic.emit(instance)
				get_viewport().set_input_as_handled()


func create_status_applied_animation(status_def: StatusEffectDefinition, stacks: int) -> FloatingTextAnimation:
	var anim = FloatingTextAnimation.new()
	anim.target = self
	anim.text = "+%s (%d)" % [status_def.id.capitalize(), stacks]
	anim.color = Color.MEDIUM_PURPLE if status_def.effect_type == "debuff" else Color.LIME_GREEN
	return anim


func create_status_removed_animation(status_def: StatusEffectDefinition) -> FloatingTextAnimation:
	var anim = FloatingTextAnimation.new()
	anim.target = self
	anim.text = "-%s" % status_def.id.capitalize()
	anim.color = Color.MEDIUM_PURPLE if status_def.effect_type == "debuff" else Color.LIME_GREEN
	return anim


func create_status_stacks_changed_animation(status_def: StatusEffectDefinition, delta: int) -> FloatingTextAnimation:
	var anim = FloatingTextAnimation.new()
	anim.target = self
	var sign_str = "+" if delta > 0 else ""
	anim.text = "%s %s%d" % [status_def.id.capitalize(), sign_str, delta]
	anim.color = Color.MEDIUM_PURPLE if status_def.effect_type == "debuff" else Color.LIME_GREEN
	return anim
