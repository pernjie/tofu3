class_name CardPreviewOverlay
extends Control

## Full-screen overlay showing card or unit details at 2x scale.
## Handles any card type (stall, spell, relic) and guest units.

var _card_display_scene: PackedScene = preload("res://src/ui/components/card_display.tscn")

var _card_display: CardDisplay
var _setup_callable: Callable

@onready var _dim_bg: ColorRect = $DimBackground
@onready var _content_vbox: VBoxContainer = $CenterContainer/ContentVBox


func setup_card(card: CardInstance) -> void:
	_setup_callable = func(): _card_display.setup(card)

	if is_node_ready():
		_build_content()


func setup_unit(guest_def: GuestDefinition) -> void:
	_setup_callable = func(): _card_display.setup_unit(guest_def)

	if is_node_ready():
		_build_content()


func _ready() -> void:
	if _setup_callable.is_valid():
		_build_content()

	_dim_bg.gui_input.connect(_on_bg_input)


func _build_content() -> void:
	var card_wrapper := Control.new()
	card_wrapper.custom_minimum_size = Vector2(320, 440)
	_content_vbox.add_child(card_wrapper)

	_card_display = _card_display_scene.instantiate() as CardDisplay
	card_wrapper.add_child(_card_display)
	_card_display.set_display_scale(2.0)
	_setup_callable.call()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	queue_free()
