class_name CardUI
extends Control

## Visual representation of a card.

enum Mode { HAND, DISPLAY }

signal card_clicked(card: CardInstance)

var mode: Mode = Mode.HAND
var card_instance: CardInstance
var is_selected: bool = false
var is_dimmed: bool = false

@onready var panel: Panel = $Panel
@onready var name_label: Label = $VBox/NameLabel
@onready var type_label: Label = $VBox/TypeLabel


func _ready() -> void:
	if mode == Mode.HAND:
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(card: CardInstance) -> void:
	card_instance = card
	_update_visuals()


func _update_visuals() -> void:
	if not card_instance:
		return

	name_label.text = card_instance.definition.id.replace("_", " ").capitalize()
	type_label.text = card_instance.definition.card_type.capitalize()


func set_selected(selected: bool) -> void:
	if mode != Mode.HAND:
		return
	is_selected = selected
	if is_selected:
		modulate = Color.YELLOW
	elif is_dimmed:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		modulate = Color.WHITE


func set_dimmed(dimmed: bool) -> void:
	if mode != Mode.HAND:
		return
	is_dimmed = dimmed
	if is_dimmed and not is_selected:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	elif not is_selected:
		modulate = Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if mode != Mode.HAND:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			card_clicked.emit(card_instance)
