class_name ShopPanel
extends VBoxContainer

## Shop UI component embedded in the interlude screen.
## Displays card offerings, buy buttons, and reroll.

var _shop_system: ShopSystem
var _card_ui_scene: PackedScene = preload("res://src/ui/components/card_ui.tscn")

var _slot_containers: Array[VBoxContainer] = []
var _buy_buttons: Array[Button] = []
var _price_labels: Array[Label] = []
var _reroll_button: Button


func setup(shop_system: ShopSystem) -> void:
	_shop_system = shop_system
	EventBus.tokens_changed.connect(_on_tokens_changed)
	_build_ui()
	_refresh()


func _build_ui() -> void:
	# Card slots row
	var slots_row := HBoxContainer.new()
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.set("theme_override_constants/separation", 24)
	add_child(slots_row)

	for i in ShopSystem.NUM_OFFERINGS:
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.set("theme_override_constants/separation", 8)
		slots_row.add_child(slot)

		# Placeholder for CardUI (added/replaced in _refresh)
		var card_placeholder := Control.new()
		card_placeholder.custom_minimum_size = Vector2(140, 200)
		slot.add_child(card_placeholder)

		var price_label := Label.new()
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(price_label)

		var buy_button := Button.new()
		buy_button.text = "Buy"
		buy_button.pressed.connect(_on_buy_pressed.bind(i))
		slot.add_child(buy_button)

		_slot_containers.append(slot)
		_price_labels.append(price_label)
		_buy_buttons.append(buy_button)

	# Reroll button
	var reroll_row := CenterContainer.new()
	add_child(reroll_row)

	_reroll_button = Button.new()
	_reroll_button.pressed.connect(_on_reroll_pressed)
	reroll_row.add_child(_reroll_button)


func _refresh() -> void:
	if not _shop_system:
		return

	var offerings := _shop_system.get_offerings()
	for i in ShopSystem.NUM_OFFERINGS:
		var slot := _slot_containers[i]
		var card: CardInstance = offerings[i] if i < offerings.size() else null

		# Replace first child (card display area) with updated content
		var old_card_area := slot.get_child(0)
		old_card_area.queue_free()

		if card:
			var card_ui := _card_ui_scene.instantiate() as CardUI
			card_ui.mode = CardUI.Mode.DISPLAY
			slot.add_child(card_ui)
			slot.move_child(card_ui, 0)
			card_ui.setup(card)

			_price_labels[i].text = "%d tokens" % card.get_effective_price()
			_buy_buttons[i].visible = true
			_buy_buttons[i].disabled = not _shop_system.can_afford_card(i)
		else:
			var sold_label := Label.new()
			sold_label.text = "Sold"
			sold_label.custom_minimum_size = Vector2(140, 200)
			sold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(sold_label)
			slot.move_child(sold_label, 0)

			_price_labels[i].text = ""
			_buy_buttons[i].visible = false

	_update_reroll_button()


func _update_reroll_button() -> void:
	if _shop_system.has_offerings():
		_reroll_button.visible = true
		_reroll_button.text = "Reroll - %d tokens" % _shop_system.get_reroll_cost()
		_reroll_button.disabled = not _shop_system.can_afford_reroll()
	else:
		_reroll_button.visible = false


func _update_affordability() -> void:
	if not _shop_system:
		return
	for i in ShopSystem.NUM_OFFERINGS:
		var offerings := _shop_system.get_offerings()
		var card: CardInstance = offerings[i] if i < offerings.size() else null
		if card:
			_buy_buttons[i].disabled = not _shop_system.can_afford_card(i)
	_update_reroll_button()


func _on_buy_pressed(slot_index: int) -> void:
	if _shop_system.purchase_card(slot_index):
		_refresh()


func _on_reroll_pressed() -> void:
	if _shop_system.reroll():
		_refresh()


func _on_tokens_changed(_old_value: int, _new_value: int) -> void:
	_update_affordability()


func _exit_tree() -> void:
	if EventBus.tokens_changed.is_connected(_on_tokens_changed):
		EventBus.tokens_changed.disconnect(_on_tokens_changed)
