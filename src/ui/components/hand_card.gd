class_name HandCard
extends Control

## Card wrapper for hand display. Adds click, selection, and dimming.

signal card_clicked(card: CardInstance)

var card_instance: CardInstance
var is_selected: bool = false
var is_dimmed: bool = false

@onready var _card_display: CardDisplay = $CardDisplay


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = CardDisplay.CARD_SIZE


func setup(card: CardInstance) -> void:
	card_instance = card
	_card_display.setup(card)


func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_modulate()


func set_dimmed(dimmed: bool) -> void:
	is_dimmed = dimmed
	_update_modulate()


func _update_modulate() -> void:
	if is_selected:
		modulate = Color.YELLOW
	elif is_dimmed:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		modulate = Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(card_instance)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_request_tier_preview()


func _request_tier_preview() -> void:
	if not card_instance:
		return
	if not card_instance.definition is StallDefinition:
		return
	var stall_def := card_instance.definition as StallDefinition
	EventBus.tier_preview_requested.emit(stall_def, 1)
