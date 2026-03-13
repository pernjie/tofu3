class_name ShopSlot
extends VBoxContainer

## Shop slot: CardDisplay + price label. Click card to buy.

signal buy_pressed

var _card: CardInstance
var _is_sold: bool = false
var _can_afford: bool = true
var _hover_tween: Tween

@onready var _card_display: CardDisplay = $CardDisplay
@onready var _price_label: Label = $PriceLabel


func setup(card: CardInstance, price: int) -> void:
	_card = card
	_is_sold = false
	_can_afford = true
	_card_display.visible = true
	_card_display.modulate = Color.WHITE
	_card_display.scale = Vector2.ONE
	_card_display.setup(card)
	_price_label.text = "%d tokens" % price
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_sold(card: CardInstance = null) -> void:
	_is_sold = true
	_price_label.text = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW

	if card:
		_card = card
		_card_display.visible = true
		_card_display.modulate = Color(0.4, 0.4, 0.4, 0.5)
		_card_display.scale = Vector2.ONE
	else:
		_card = null
		_card_display.visible = false


func set_affordable(can_afford: bool) -> void:
	_can_afford = can_afford
	if _is_sold:
		return
	_card_display.modulate = Color.WHITE if can_afford else Color(0.6, 0.6, 0.6, 0.8)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_afford else Control.CURSOR_ARROW


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if _is_sold:
		return
	_card_display.pivot_offset = _card_display.size / 2
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(_card_display, "scale", Vector2(1.05, 1.05), 0.1)


func _on_mouse_exited() -> void:
	if _is_sold:
		return
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(_card_display, "scale", Vector2.ONE, 0.1)


func _gui_input(event: InputEvent) -> void:
	if _is_sold:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _can_afford:
			buy_pressed.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_request_preview()


func _request_preview() -> void:
	if not _card:
		return
	if _card.definition is StallDefinition:
		var stall_def := _card.definition as StallDefinition
		EventBus.tier_preview_requested.emit(stall_def, 1)
	else:
		EventBus.card_preview_requested.emit(_card)
