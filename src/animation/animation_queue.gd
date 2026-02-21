class_name AnimationQueue
extends Node

## Manages a queue of animations that play sequentially.
## Animations are processed one at a time, with parallel groups playing simultaneously.

signal queue_empty
signal animation_started(anim: QueuedAnimation)
signal animation_completed(anim: QueuedAnimation)

var _queue: Array = []  # Array of QueuedAnimation or ParallelAnimationGroup
var _is_processing: bool = false


func queue_animation(anim: QueuedAnimation) -> void:
	## Add an animation to the queue. Starts processing if not already running.
	_queue.append(anim)
	if not _is_processing:
		_process_queue()


func queue_parallel(animations: Array[QueuedAnimation]) -> void:
	## Add multiple animations to play simultaneously.
	var group = ParallelAnimationGroup.new()
	for anim in animations:
		group.add(anim)
	_queue.append(group)
	if not _is_processing:
		_process_queue()


func skip_all() -> void:
	## Skip all queued animations, jumping to their end states.
	for item in _queue:
		if item is ParallelAnimationGroup:
			for anim in item.animations:
				anim.skip()
		else:
			item.skip()
	_queue.clear()


func is_empty() -> bool:
	return _queue.is_empty() and not _is_processing


func _process_queue() -> void:
	_is_processing = true
	while not _queue.is_empty():
		var item = _queue.pop_front()
		if item is ParallelAnimationGroup:
			await _play_parallel(item.animations)
		else:
			await _play_single(item)
	_is_processing = false
	queue_empty.emit()


func _play_single(anim: QueuedAnimation) -> void:
	animation_started.emit(anim)
	anim.play()
	await anim.finished
	animation_completed.emit(anim)


func _play_parallel(animations: Array[QueuedAnimation]) -> void:
	if animations.is_empty():
		return

	for anim in animations:
		animation_started.emit(anim)

	# Use dictionary so lambda captures by reference (primitives are captured by value)
	var state := {"completed": 0}
	var total := animations.size()

	for anim in animations:
		anim.finished.connect(func(): state.completed += 1)
		anim.play()

	# Wait until all animations complete
	while state.completed < total:
		await get_tree().process_frame

	for anim in animations:
		animation_completed.emit(anim)
