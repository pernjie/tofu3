class_name JumpAnimation
extends QueuedAnimation

## Animates a node jumping up then landing back at its original position.

var jump_height: float = 20.0
var _tween: Tween


func _init() -> void:
	duration = 0.3


func play() -> void:
	if not target or not target.is_inside_tree():
		finished.emit()
		return

	var start_y = target.position.y
	_tween = target.create_tween()
	_tween.tween_property(target, "position:y", start_y - jump_height, duration / 2.0) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(target, "position:y", start_y, duration / 2.0) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)
	_tween.finished.connect(func(): finished.emit())


func skip() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	# Jump returns to original position — no net state change needed
