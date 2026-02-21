class_name TweenAnimation
extends QueuedAnimation

## Tween-based animation that smoothly transitions a property value.

var property: String
var final_value: Variant
var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
var trans_type: Tween.TransitionType = Tween.TRANS_QUAD

var _tween: Tween


func play() -> void:
	if not target or not target.is_inside_tree():
		skip()
		finished.emit()
		return

	_tween = target.create_tween()
	_tween.tween_property(target, property, final_value, duration) \
		.set_ease(ease_type) \
		.set_trans(trans_type)
	_tween.finished.connect(_on_tween_finished)


func skip() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	if target:
		_set_property_path(target, property, final_value)


func _set_property_path(obj: Object, prop_path: String, value: Variant) -> void:
	## Set a property value, handling subproperty paths like "position:y" or "modulate:a".
	## Object.set() doesn't support these paths, but Tween does internally.
	if ":" not in prop_path:
		# Simple property - use set() directly
		obj.set(prop_path, value)
		return

	# Parse property path (e.g., "position:y" -> ["position", "y"])
	var parts = prop_path.split(":")
	var base_prop = parts[0]
	var sub_prop = parts[1]

	# Get the current value of the base property
	var base_value = obj.get(base_prop)
	if base_value == null:
		return

	# Set the subproperty on the value
	base_value[sub_prop] = value

	# Set the modified value back
	obj.set(base_prop, base_value)


func _on_tween_finished() -> void:
	finished.emit()
