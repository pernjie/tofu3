class_name StallEntity
extends Node2D

## Visual representation of a stall on the board.

var instance: StallInstance

@onready var sprite: ColorRect = $Sprite
@onready var stock_label: Label = $StockLabel
@onready var tier_label: Label = $TierLabel

const TILE_SIZE := 144
const SPRITE_SIZE := 108  # Match the ColorRect size


func setup(stall_instance: StallInstance, tile_pos: Vector2i) -> void:
	instance = stall_instance
	position = Vector2(tile_pos.x, tile_pos.y) * TILE_SIZE
	position += Vector2(TILE_SIZE / 2, TILE_SIZE / 2)  # Center in tile
	refresh()


func update_labels() -> void:
	## Data display — text and label colors. Always immediate, never skipped.
	if not instance:
		return

	tier_label.text = "T%d" % instance.current_tier

	if instance.get_operation_model() == "product":
		_update_product_labels()
	else:
		_update_service_labels()


func update_visual_state() -> void:
	## Set sprite color based on current state. Non-animated (snap).
	## Used for setup and non-animated refreshes (serve, depletion).
	if not instance:
		return

	if instance.get_operation_model() == "product":
		_apply_product_sprite_color()
	else:
		_apply_service_sprite_color()


func refresh() -> void:
	## Full non-animated refresh. Used for setup and contexts where
	## no animation is desired (serve, initial placement, etc.)
	update_labels()
	update_visual_state()


func _update_product_labels() -> void:
	## Update text labels for product stalls (stock, cooldown, empty states).
	stock_label.visible = true

	if instance.current_stock > 0:
		stock_label.text = "x%d" % instance.current_stock
		stock_label.modulate = Color.WHITE
	elif instance.restock_cooldown > 0:
		stock_label.text = "(%d)" % instance.restock_cooldown
		stock_label.modulate = Color.YELLOW
	else:
		stock_label.text = "EMPTY"
		stock_label.modulate = Color.RED


func _apply_product_sprite_color() -> void:
	## Set sprite color for product stalls based on stock/cooldown state.
	if instance.current_stock > 0:
		sprite.color = Color.ORANGE
	elif instance.restock_cooldown > 0:
		sprite.color = Color.DIM_GRAY
	else:
		sprite.color = Color.DARK_GRAY


func _update_service_labels() -> void:
	## Update text labels for service/bulk_service stalls (occupancy + phase display).
	stock_label.visible = true

	var capacity = instance.get_capacity()
	var occupants = instance.current_occupants.size()

	if instance.get_operation_model() == "bulk_service" and occupants > 0:
		match instance.bulk_phase:
			StallInstance.BulkPhase.WAITING:
				stock_label.text = "%d/%d wait" % [occupants, capacity]
				stock_label.modulate = Color.ORANGE
			StallInstance.BulkPhase.SERVING:
				stock_label.text = "%d/%d serv" % [occupants, capacity]
				stock_label.modulate = Color.YELLOW
			_:
				stock_label.text = "%d/%d" % [occupants, capacity]
				stock_label.modulate = Color.WHITE
	else:
		stock_label.text = "%d/%d" % [occupants, capacity]
		if occupants >= capacity:
			stock_label.modulate = Color.ORANGE
		else:
			stock_label.modulate = Color.WHITE


func _apply_service_sprite_color() -> void:
	## Set sprite color for service/bulk_service stalls based on occupancy and phase.
	var capacity = instance.get_capacity()
	var occupants = instance.current_occupants.size()

	if instance.get_operation_model() == "bulk_service":
		match instance.bulk_phase:
			StallInstance.BulkPhase.WAITING:
				sprite.color = Color.SANDY_BROWN
			StallInstance.BulkPhase.SERVING:
				sprite.color = Color.CORAL
			_:
				sprite.color = Color.ORANGE
	elif occupants >= capacity:
		sprite.color = Color.CORAL
	else:
		sprite.color = Color.ORANGE


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


func create_restock_animation() -> QueuedAnimation:
	## Create jump + color tween animation for restocking.
	var jump_anim = JumpAnimation.new()
	jump_anim.target = self
	jump_anim.jump_height = 20.0
	jump_anim.duration = 0.3

	var color_anim = TweenAnimation.new()
	color_anim.target = sprite
	color_anim.property = "color"
	color_anim.final_value = Color.ORANGE
	color_anim.duration = 0.3

	var group = ParallelAnimationGroup.new()
	group.add(jump_anim).add(color_anim)
	return group


func _input(event: InputEvent) -> void:
	var board_visual := get_parent().get_parent() as BoardVisual
	if board_visual and board_visual.placement_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = to_local(event.global_position)
		var half_size = SPRITE_SIZE / 2.0
		if local_pos.x >= -half_size and local_pos.x <= half_size and local_pos.y >= -half_size and local_pos.y <= half_size:
			if instance:
				EventBus.debug_show_stall.emit(instance)
				get_viewport().set_input_as_handled()
