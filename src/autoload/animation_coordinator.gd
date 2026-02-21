# src/autoload/animation_coordinator.gd
extends Node

## Central coordinator for game animations.
## Collects animations during phase execution, plays them in parallel,
## and signals completion so the turn system can proceed.

signal batch_completed

# Configuration
@export var animation_speed: float = 1.0
@export var skip_animations: bool = false

# Current batch of animations to play
var _current_batch: Array[QueuedAnimation] = []
var _is_playing: bool = false

# Reference to board visual for entity lookup
var board_visual: BoardVisual = null


func set_board_visual(visual: BoardVisual) -> void:
	board_visual = visual


# =============================================================================
# Batch Management
# =============================================================================

func queue(anim: QueuedAnimation) -> void:
	## Add an animation to the current batch.
	_current_batch.append(anim)


func queue_all(anims: Array[QueuedAnimation]) -> void:
	## Add multiple animations to the current batch.
	for anim in anims:
		_current_batch.append(anim)


func clear_batch() -> void:
	## Clear all queued animations without playing them.
	_current_batch.clear()


func play_batch() -> void:
	## Play all queued animations in parallel, then signal completion.
	## If skip_animations is true, jumps to end states immediately.
	if _current_batch.is_empty():
		# Yield one frame even with empty batch to ensure consistent coroutine behavior.
		await get_tree().process_frame
		batch_completed.emit()
		return

	_is_playing = true

	if skip_animations:
		_skip_all()
		# Yield one frame to ensure this function behaves as a coroutine.
		# Without this, callers using `await play_batch()` may not properly
		# yield/resume when the skip path is taken, breaking turn sequencing.
		await get_tree().process_frame
	else:
		await _play_all_parallel()

	_current_batch.clear()
	_is_playing = false
	batch_completed.emit()


func _skip_all() -> void:
	## Skip all animations, setting entities to final positions.
	for anim in _current_batch:
		anim.skip()


func _play_all_parallel() -> void:
	## Play all animations simultaneously and wait for completion.
	if _current_batch.is_empty():
		return

	var state := {"completed": 0}
	var total := _current_batch.size()

	for anim in _current_batch:
		# Adjust duration based on speed
		_apply_speed_to_animation(anim)

		anim.finished.connect(func(): state.completed += 1, CONNECT_ONE_SHOT)
		anim.play()

	# Wait until all complete
	while state.completed < total:
		await get_tree().process_frame


func _apply_speed_to_animation(anim: QueuedAnimation) -> void:
	## Recursively apply animation_speed to an animation or group.
	if anim is ParallelAnimationGroup:
		for child in anim.animations:
			_apply_speed_to_animation(child)
	elif anim.duration > 0.0:
		anim.duration = anim.duration / animation_speed
