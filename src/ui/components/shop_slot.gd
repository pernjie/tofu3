class_name ShopSlot
extends VBoxContainer

## Shop slot: CardDisplay + price label + buy button.

signal buy_pressed

var _card: CardInstance

@onready var _card_display: CardDisplay = $CardDisplay
@onready var _price_label: Label = $PriceLabel
@onready var _buy_button: Button = $BuyButton


func setup(card: CardInstance, price: int) -> void:
	_card = card
	_card_display.visible = true
	_card_display.setup(card)
	_price_label.text = "%d tokens" % price
	_buy_button.visible = true
	_buy_button.disabled = false


func set_sold() -> void:
	_card = null
	_card_display.visible = false
	_price_label.text = ""
	_buy_button.visible = false


func set_affordable(can_afford: bool) -> void:
	_buy_button.disabled = not can_afford


func _ready() -> void:
	_buy_button.pressed.connect(func() -> void: buy_pressed.emit())
