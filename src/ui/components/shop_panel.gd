class_name ShopPanel
extends VBoxContainer

## Shop UI component embedded in the interlude screen.
## Displays card offerings, buy buttons, and reroll.

signal remove_card_requested

var _shop_system: ShopSystem
var _card_ui_scene: PackedScene = preload("res://src/ui/components/card_ui.tscn")

var _slot_containers: Array[VBoxContainer] = []
var _buy_buttons: Array[Button] = []
var _price_labels: Array[Label] = []
var _reroll_button: Button
var _remove_button: Button
var _remove_slot: VBoxContainer
var _remove_price_label: Label


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

	# Remove card button (circular, to the right of offerings)
	_remove_slot = VBoxContainer.new()
	_remove_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.add_child(_remove_slot)

	_remove_button = Button.new()
	_remove_button.custom_minimum_size = Vector2(80, 80)
	_remove_button.text = "Remove\nCard"
	_remove_button.pressed.connect(_on_remove_pressed)
	_remove_slot.add_child(_remove_button)

	_remove_price_label = Label.new()
	_remove_price_label.text = "%d tokens" % ShopSystem.REMOVE_CARD_COST
	_remove_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_remove_slot.add_child(_remove_price_label)

	# Apply circular styling
	var circle_style := StyleBoxFlat.new()
	circle_style.bg_color = Color(0.25, 0.2, 0.35)
	circle_style.corner_radius_top_left = 40
	circle_style.corner_radius_top_right = 40
	circle_style.corner_radius_bottom_left = 40
	circle_style.corner_radius_bottom_right = 40
	_remove_button.add_theme_stylebox_override("normal", circle_style)

	var circle_hover := circle_style.duplicate()
	circle_hover.bg_color = Color(0.35, 0.28, 0.45)
	_remove_button.add_theme_stylebox_override("hover", circle_hover)

	var circle_pressed := circle_style.duplicate()
	circle_pressed.bg_color = Color(0.4, 0.32, 0.5)
	_remove_button.add_theme_stylebox_override("pressed", circle_pressed)

	var circle_disabled := circle_style.duplicate()
	circle_disabled.bg_color = Color(0.15, 0.13, 0.2)
	_remove_button.add_theme_stylebox_override("disabled", circle_disabled)

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
	_update_remove_button()


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
	_update_remove_button()


func _update_remove_button() -> void:
	if _shop_system.has_removed_card():
		if is_instance_valid(_remove_button):
			_remove_button.queue_free()
			var sold_label := Label.new()
			sold_label.text = "Sold"
			sold_label.custom_minimum_size = Vector2(80, 80)
			sold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_remove_slot.add_child(sold_label)
			_remove_slot.move_child(sold_label, 0)
			_remove_price_label.text = ""
	else:
		_remove_button.disabled = not _shop_system.can_remove_card()


func _on_buy_pressed(slot_index: int) -> void:
	if _shop_system.purchase_card(slot_index):
		_refresh()


func _on_reroll_pressed() -> void:
	if _shop_system.reroll():
		_refresh()


func _on_remove_pressed() -> void:
	if _shop_system.can_remove_card():
		remove_card_requested.emit()


func _on_tokens_changed(_old_value: int, _new_value: int) -> void:
	_update_affordability()


func _exit_tree() -> void:
	if EventBus.tokens_changed.is_connected(_on_tokens_changed):
		EventBus.tokens_changed.disconnect(_on_tokens_changed)
