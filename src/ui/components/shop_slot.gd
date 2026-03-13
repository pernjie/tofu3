class_name ShopSlot
extends VBoxContainer

## Shop slot: displays any ShopOffering (card or enhancement) + price label. Click to buy.
## All offering types share the same hover, click, sold, and pending behavior.

signal buy_pressed

const RARITY_COLORS := {
	"common": Color(0.5, 0.5, 0.5),
	"rare": Color(0.3, 0.5, 0.9),
	"epic": Color(0.6, 0.3, 0.8),
	"legendary": Color(0.9, 0.7, 0.2),
}

const SOLD_MODULATE := Color(0.4, 0.4, 0.4, 0.5)
const PENDING_MODULATE := Color(0.7, 0.7, 0.7, 0.8)
const UNAFFORDABLE_MODULATE := Color(0.6, 0.6, 0.6, 0.8)

var _card: CardInstance
var _enhancement: EnhancementDefinition
var _is_sold: bool = false
var _is_pending: bool = false
var _can_afford: bool = true
var _hover_tween: Tween
var _enhancement_panel: Panel

@onready var _card_display: CardDisplay = $CardDisplay
@onready var _price_label: Label = $PriceLabel


func setup_offering(offering: ShopOffering) -> void:
	## Single entry point for all offering types.
	_is_sold = false
	_is_pending = false
	_can_afford = true

	if offering.is_enhancement():
		_card = null
		_enhancement = offering.enhancement
		_show_enhancement_display(offering.enhancement)
	else:
		_card = offering.card
		_enhancement = null
		_show_card_display()
		_card_display.modulate = Color.WHITE
		_card_display.scale = Vector2.ONE
		_card_display.setup(_card)

	_price_label.text = "%d tokens" % offering.get_price()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_sold() -> void:
	## Gray out whatever is currently displayed. Works for any offering type.
	_is_sold = true
	_is_pending = false
	_price_label.text = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	var display := _get_active_display()
	if display:
		display.modulate = SOLD_MODULATE
		display.scale = Vector2.ONE


func set_empty() -> void:
	## Hide everything — used when there's no offering for this slot.
	_is_sold = true
	_is_pending = false
	_card = null
	_enhancement = null
	_price_label.text = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_enhancement_panel()
	_card_display.visible = false


func set_pending() -> void:
	_is_pending = true
	_price_label.text = "Choosing..."
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	var display := _get_active_display()
	if display:
		display.modulate = PENDING_MODULATE


func set_affordable(can_afford: bool) -> void:
	_can_afford = can_afford
	if _is_sold or _is_pending:
		return
	var display := _get_active_display()
	if display:
		display.modulate = Color.WHITE if can_afford else UNAFFORDABLE_MODULATE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_afford else Control.CURSOR_ARROW


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _get_active_display() -> Control:
	return _enhancement_panel if _enhancement_panel and _enhancement_panel.visible else _card_display


func _on_mouse_entered() -> void:
	if _is_sold or _is_pending:
		return
	var display := _get_active_display()
	display.pivot_offset = display.size / 2
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(display, "scale", Vector2(1.05, 1.05), 0.1)


func _on_mouse_exited() -> void:
	if _is_sold or _is_pending:
		return
	var display := _get_active_display()
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(display, "scale", Vector2.ONE, 0.1)


func _gui_input(event: InputEvent) -> void:
	if _is_sold or _is_pending:
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


func _show_card_display() -> void:
	_card_display.visible = true
	_hide_enhancement_panel()


func _show_enhancement_display(enhancement: EnhancementDefinition) -> void:
	_card_display.visible = false
	_hide_enhancement_panel()

	_enhancement_panel = Panel.new()
	_enhancement_panel.custom_minimum_size = CardDisplay.CARD_SIZE
	_enhancement_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.13, 0.2)
	var border_color: Color = RARITY_COLORS.get(enhancement.rarity, RARITY_COLORS["common"])
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	_enhancement_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 6
	vbox.offset_right = -8
	vbox.offset_bottom = -6
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_enhancement_panel.add_child(vbox)

	var type_label := Label.new()
	type_label.text = "Enhancement"
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", border_color)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(type_label)

	var name_label := Label.new()
	name_label.text = enhancement.get_display_name()
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	var desc_label := Label.new()
	desc_label.text = enhancement.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	# Show applicability
	var models: Array = enhancement.applicable_to.get("operation_models", [])
	if not models.is_empty():
		var applies_label := Label.new()
		var model_names: Array[String] = []
		for m in models:
			model_names.append(m.capitalize())
		applies_label.text = "(%s only)" % " / ".join(model_names)
		applies_label.add_theme_font_size_override("font_size", 10)
		applies_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		applies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		applies_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(applies_label)

	add_child(_enhancement_panel)
	move_child(_enhancement_panel, 0)


func _hide_enhancement_panel() -> void:
	if _enhancement_panel:
		_enhancement_panel.queue_free()
		_enhancement_panel = null
