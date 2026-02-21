class_name ParallelAnimationGroup
extends QueuedAnimation

## Container for animations that should play simultaneously.
## Extends QueuedAnimation so it can be queued like any other animation.

var animations: Array[QueuedAnimation] = []


func add(anim: QueuedAnimation) -> ParallelAnimationGroup:
	animations.append(anim)
	return self


func play() -> void:
	## Play all contained animations in parallel.
	if animations.is_empty():
		finished.emit()
		return

	var state := {"completed": 0}
	var total := animations.size()

	for anim in animations:
		anim.finished.connect(func():
			state.completed += 1
			if state.completed >= total:
				finished.emit()
		, CONNECT_ONE_SHOT)
		anim.play()


func skip() -> void:
	## Skip all contained animations to their end states.
	for anim in animations:
		anim.skip()
