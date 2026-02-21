class_name HandDisplay
extends Control

## Custom hand layout that manually positions cards with tween animations.
## Replaces HBoxContainer to allow draw/reposition animations.

signal card_clicked(card: CardInstance)

const CARD_WIDTH: float = 140.0
const CARD_HEIGHT: float = 200.0
const CARD_GAP: float = 15.0
const DRAW_DURATION: float = 0.3
const REPOSITION_DURATION: float = 0.2
const OFFSCREEN_OFFSET: float = 400.0

var card_ui_scene: PackedScene = preload("res://src/ui/components/card_ui.tscn")
var _card_uis: Array[CardUI] = []
var _active_tweens: Array[Tween] = []


func add_card(card: CardInstance, animate: bool = true) -> CardUI:
	var card_ui := card_ui_scene.instantiate() as CardUI
	add_child(card_ui)
	card_ui.setup(card)
	card_ui.card_clicked.connect(_on_card_ui_clicked)
	_card_uis.append(card_ui)

	var positions := _calculate_positions()
	var new_index := _card_uis.size() - 1

	if animate and not AnimationCoordinator.skip_animations:
		# Place new card off-screen to the right
		card_ui.position = Vector2(positions[new_index].x + OFFSCREEN_OFFSET, positions[new_index].y)
		card_ui.modulate.a = 0.0

		_kill_tweens()

		# Tween existing cards to new positions
		_reposition_all(new_index)

		# Tween new card in
		var speed: float = AnimationCoordinator.animation_speed
		var tween := create_tween()
		_active_tweens.append(tween)
		tween.set_parallel(true)
		tween.tween_property(card_ui, "position", positions[new_index], DRAW_DURATION / speed)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card_ui, "modulate:a", 1.0, REPOSITION_DURATION / speed)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		_snap_all_to_positions(positions)

	return card_ui


func remove_card(card: CardInstance) -> void:
	var index := _find_card_index(card)
	if index == -1:
		return

	var card_ui := _card_uis[index]
	_card_uis.remove_at(index)
	card_ui.queue_free()

	_kill_tweens()

	if _card_uis.is_empty():
		return

	var positions := _calculate_positions()
	if AnimationCoordinator.skip_animations:
		_snap_all_to_positions(positions)
	else:
		_reposition_all()


func get_card_ui(card: CardInstance) -> CardUI:
	var index := _find_card_index(card)
	if index == -1:
		return null
	return _card_uis[index]


func refresh_all_dimming(playable_types: Array[String]) -> void:
	for card_ui in _card_uis:
		if card_ui.card_instance:
			card_ui.set_dimmed(card_ui.card_instance.get_card_type() not in playable_types)


func _calculate_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var count := _card_uis.size()
	if count == 0:
		return positions

	var total_width: float = count * CARD_WIDTH + (count - 1) * CARD_GAP
	var center_x: float = size.x / 2.0
	var start_x: float = center_x - total_width / 2.0

	for i in count:
		var x: float = start_x + i * (CARD_WIDTH + CARD_GAP)
		positions.append(Vector2(x, 0.0))

	return positions


func _reposition_all(skip_index: int = -1) -> void:
	var positions := _calculate_positions()
	var speed: float = AnimationCoordinator.animation_speed

	for i in _card_uis.size():
		if i == skip_index:
			continue
		var card_ui := _card_uis[i]
		var tween := create_tween()
		_active_tweens.append(tween)
		tween.tween_property(card_ui, "position", positions[i], REPOSITION_DURATION / speed)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _snap_all_to_positions(positions: Array[Vector2]) -> void:
	for i in _card_uis.size():
		if i < positions.size():
			_card_uis[i].position = positions[i]
			_card_uis[i].modulate.a = 1.0


func _kill_tweens() -> void:
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()


func _find_card_index(card: CardInstance) -> int:
	for i in _card_uis.size():
		if _card_uis[i].card_instance and _card_uis[i].card_instance.instance_id == card.instance_id:
			return i
	return -1


func _on_card_ui_clicked(card: CardInstance) -> void:
	card_clicked.emit(card)
