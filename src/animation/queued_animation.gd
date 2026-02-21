class_name QueuedAnimation
extends RefCounted

## Base class for animations that can be queued and played sequentially.

signal finished

var target: Node
var can_skip: bool = true
var duration: float = 0.0


func play() -> void:
	## Override in subclasses to perform the animation.
	## Must emit finished signal when complete.
	finished.emit()


func skip() -> void:
	## Jump to end state immediately.
	## Override in subclasses to set final values.
	pass
