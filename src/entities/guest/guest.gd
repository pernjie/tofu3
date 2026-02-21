class_name GuestEntity
extends Node2D

## Visual representation of a guest on the board.

var instance: GuestInstance

@onready var sprite: ColorRect = $Sprite
@onready var need_label: Label = $NeedLabel

const TILE_SIZE := 144
const SPRITE_SIZE := 32  # Match the ColorRect size

# Track original path tile for returning from stall
var last_path_position: Vector2 = Vector2.ZERO

# =============================================================================
# Animation Factory Methods
# =============================================================================

func create_move_animation(to_pos: Vector2) -> QueuedAnimation:
	## Create a movement animation to a world position.
	var anim = TweenAnimation.new()
	anim.target = self
	anim.property = "position"
	anim.final_value = to_pos
	anim.duration = 0.3
	anim.ease_type = Tween.EASE_OUT
	anim.trans_type = Tween.TRANS_QUAD
	return anim


func create_enter_stall_animation(stall_pos: Vector2) -> QueuedAnimation:
	## Create animation for entering a stall.
	var anim = TweenAnimation.new()
	anim.target = self
	anim.property = "position"
	anim.final_value = stall_pos
	anim.duration = 0.2
	anim.ease_type = Tween.EASE_OUT
	anim.trans_type = Tween.TRANS_QUAD
	return anim


func create_exit_stall_animation() -> QueuedAnimation:
	## Create animation for returning to path from stall.
	var anim = TweenAnimation.new()
	anim.target = self
	anim.property = "position"
	anim.final_value = last_path_position
	anim.duration = 0.2
	anim.ease_type = Tween.EASE_OUT
	anim.trans_type = Tween.TRANS_QUAD
	return anim


func create_reposition_animation(to_pos: Vector2) -> QueuedAnimation:
	## Create animation for within-tile repositioning.
	var anim = TweenAnimation.new()
	anim.target = self
	anim.property = "position"
	anim.final_value = to_pos
	anim.duration = 0.15
	anim.ease_type = Tween.EASE_OUT
	anim.trans_type = Tween.TRANS_QUAD
	return anim


func create_ascend_animation() -> ParallelAnimationGroup:
	## Create ascension animations (float up + fade out).
	var move_anim = TweenAnimation.new()
	move_anim.target = self
	move_anim.property = "position:y"
	move_anim.final_value = position.y - 50.0
	move_anim.duration = 0.5
	move_anim.ease_type = Tween.EASE_OUT
	move_anim.trans_type = Tween.TRANS_QUAD

	var fade_anim = TweenAnimation.new()
	fade_anim.target = self
	fade_anim.property = "modulate:a"
	fade_anim.final_value = 0.0
	fade_anim.duration = 0.5
	fade_anim.ease_type = Tween.EASE_IN
	fade_anim.trans_type = Tween.TRANS_QUAD

	var group = ParallelAnimationGroup.new()
	group.add(move_anim).add(fade_anim)
	return group


func create_descend_animation() -> ParallelAnimationGroup:
	## Create descend animations (sink down + shrink + fade out) for guests with unfulfilled needs.
	var move_anim = TweenAnimation.new()
	move_anim.target = self
	move_anim.property = "position:y"
	move_anim.final_value = position.y + 40.0
	move_anim.duration = 0.5
	move_anim.ease_type = Tween.EASE_IN
	move_anim.trans_type = Tween.TRANS_QUAD

	var scale_anim = TweenAnimation.new()
	scale_anim.target = self
	scale_anim.property = "scale"
	scale_anim.final_value = Vector2(0.4, 0.4)
	scale_anim.duration = 0.5
	scale_anim.ease_type = Tween.EASE_IN
	scale_anim.trans_type = Tween.TRANS_QUAD

	var fade_anim = TweenAnimation.new()
	fade_anim.target = self
	fade_anim.property = "modulate:a"
	fade_anim.final_value = 0.0
	fade_anim.duration = 0.5
	fade_anim.ease_type = Tween.EASE_IN
	fade_anim.trans_type = Tween.TRANS_QUAD

	var group = ParallelAnimationGroup.new()
	group.add(move_anim).add(scale_anim).add(fade_anim)
	return group


func create_banish_animation() -> ParallelAnimationGroup:
	## Create banish animation (flash + shrink + fade).
	## Overbright white modulate creates a flash; simultaneous shrink and fade give the dissolve.
	var scale_anim = TweenAnimation.new()
	scale_anim.target = self
	scale_anim.property = "scale"
	scale_anim.final_value = Vector2(0, 0)
	scale_anim.duration = 0.4
	scale_anim.ease_type = Tween.EASE_IN
	scale_anim.trans_type = Tween.TRANS_QUAD

	var flash_anim = TweenAnimation.new()
	flash_anim.target = self
	flash_anim.property = "modulate"
	flash_anim.final_value = Color(3, 3, 3, 0)
	flash_anim.duration = 0.4
	flash_anim.ease_type = Tween.EASE_IN
	flash_anim.trans_type = Tween.TRANS_QUAD

	var lift_anim = TweenAnimation.new()
	lift_anim.target = self
	lift_anim.property = "position:y"
	lift_anim.final_value = position.y - 10.0
	lift_anim.duration = 0.4
	lift_anim.ease_type = Tween.EASE_OUT
	lift_anim.trans_type = Tween.TRANS_QUAD

	var group = ParallelAnimationGroup.new()
	group.add(scale_anim).add(flash_anim).add(lift_anim)
	return group


func create_spawn_animation(target_pos: Vector2) -> ParallelAnimationGroup:
	## Create spawn animations (scale up + fade in with bounce).
	## Sets initial state (small, invisible) and animates to full size at target.

	# Set initial state: at target position, small and invisible
	position = target_pos
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0

	var scale_anim = TweenAnimation.new()
	scale_anim.target = self
	scale_anim.property = "scale"
	scale_anim.final_value = Vector2(1.0, 1.0)
	scale_anim.duration = 0.4
	scale_anim.ease_type = Tween.EASE_OUT
	scale_anim.trans_type = Tween.TRANS_BACK  # Slight overshoot for bounce

	var fade_anim = TweenAnimation.new()
	fade_anim.target = self
	fade_anim.property = "modulate:a"
	fade_anim.final_value = 1.0
	fade_anim.duration = 0.25
	fade_anim.ease_type = Tween.EASE_OUT
	fade_anim.trans_type = Tween.TRANS_QUAD

	var group = ParallelAnimationGroup.new()
	group.add(scale_anim).add(fade_anim)
	return group


func set_position_immediate(pos: Vector2) -> void:
	## Snap to position without animation.
	position = pos


func update_last_path_position(pos: Vector2) -> void:
	## Update the remembered path position (for returning from stalls).
	last_path_position = pos


func _input(event: InputEvent) -> void:
	var board_visual := get_parent().get_parent() as BoardVisual
	if board_visual and board_visual.placement_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = to_local(event.global_position)
		var half_size = SPRITE_SIZE / 2.0
		if local_pos.x >= -half_size and local_pos.x <= half_size and local_pos.y >= -half_size and local_pos.y <= half_size:
			if instance:
				EventBus.debug_show_guest.emit(instance)
				get_viewport().set_input_as_handled()


func setup(guest_instance: GuestInstance) -> void:
	instance = guest_instance
	_update_visuals()


func create_need_fulfilled_animation(amount: int, need_type: String) -> FloatingTextAnimation:
	## Create a floating text animation for need fulfillment.
	var anim = FloatingTextAnimation.new()
	anim.target = self
	anim.text = "+%d %s" % [amount, need_type.capitalize()]
	match need_type:
		"food":
			anim.color = Color.LIME
		"joy":
			anim.color = Color.CYAN
		_:
			anim.color = Color.WHITE
	return anim


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


func create_service_blocked_animation() -> FloatingTextAnimation:
	## Create a floating text animation for blocked service.
	var anim = FloatingTextAnimation.new()
	anim.target = self
	anim.text = "Blocked!"
	anim.color = Color.INDIAN_RED
	return anim


func create_status_blocked_animation(status_def: StatusEffectDefinition) -> FloatingTextAnimation:
	## Create a floating text animation for a resisted status effect.
	var anim = FloatingTextAnimation.new()
	anim.target = self
	anim.text = "Resisted %s" % status_def.id.capitalize()
	anim.color = Color.CORNFLOWER_BLUE
	return anim


func create_banish_blocked_animation() -> FloatingTextAnimation:
	## Create a floating text animation for resisted banishment.
	var anim = FloatingTextAnimation.new()
	anim.target = self
	anim.text = "Resisted!"
	anim.color = Color.CORNFLOWER_BLUE
	return anim


func create_entry_blocked_animation() -> FloatingTextAnimation:
	## Create a floating text animation for blocked stall entry (e.g. wet status).
	var anim = FloatingTextAnimation.new()
	anim.target = self
	anim.text = "Blocked!"
	anim.color = Color.CORNFLOWER_BLUE
	return anim


func create_service_tick_animation(turns_remaining: int) -> FloatingTextAnimation:
	## Create a floating text animation for service tick countdown.
	var anim = FloatingTextAnimation.new()
	anim.target = self
	anim.text = "%d turns..." % turns_remaining
	anim.color = Color.YELLOW
	return anim


func create_wait_tick_animation(turns_remaining: int) -> FloatingTextAnimation:
	## Create a floating text animation for bulk service wait countdown.
	var anim = FloatingTextAnimation.new()
	anim.target = self
	anim.text = "Wait: %d" % turns_remaining
	anim.color = Color.ORANGE
	return anim


func _update_visuals() -> void:
	if not instance:
		return

	# Update need display
	var needs_text := ""
	for need_type in instance.current_needs:
		var remaining = instance.current_needs[need_type]
		var base = instance.initial_needs.get(need_type, 0)
		var fulfilled = base - remaining
		needs_text += "%s:%d/%d " % [need_type[0].to_upper(), fulfilled, base]
	need_label.text = needs_text.strip_edges()

	# Color based on state
	if instance.are_all_needs_fulfilled():
		sprite.color = Color.GREEN
	elif instance.is_in_stall:
		sprite.color = Color.YELLOW  # Being served
	else:
		sprite.color = Color.CORNFLOWER_BLUE


func refresh() -> void:
	_update_visuals()
