class_name FloatingTextAnimation
extends QueuedAnimation

## Transient floating text animation.
## Creates a temporary Label on the target, animates it upward + fades out,
## then cleans it up. Used for need fulfillment and service tick feedback.

var text: String = ""
var color: Color = Color.WHITE
var font_size: int = 16
var offset: Vector2 = Vector2(-20, -30)
var rise_distance: float = 30.0
var _tween: Tween


func _init() -> void:
	duration = 0.8


func play() -> void:
	if not target or not target.is_inside_tree():
		finished.emit()
		return

	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.position = offset
	target.add_child(label)

	_tween = target.create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(label, "position:y", offset.y - rise_distance, duration)
	_tween.tween_property(label, "modulate:a", 0.0, duration)
	_tween.chain().tween_callback(label.queue_free)
	_tween.finished.connect(func(): finished.emit())


func skip() -> void:
	# No-op — transient cosmetic effect with no persistent state.
	# Data display (need labels) updates via refresh() regardless.
	if _tween and _tween.is_running():
		_tween.kill()
