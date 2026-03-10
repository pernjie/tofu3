class_name TierPreviewOverlay
extends Control

## Full-screen overlay showing stall tier details with arrow navigation.

var _card_display_scene: PackedScene = preload("res://src/ui/components/card_display.tscn")

var _stall_def: StallDefinition
var _current_tier: int  # 1-based, the stall's actual current tier
var _viewed_tier_index: int = 0  # 0-based index into tiers array

var _card_display: CardDisplay
var _left_button: Button
var _right_button: Button
var _tier_label: Label
var _current_marker_label: Label

@onready var _dim_bg: ColorRect = $DimBackground
@onready var _center: CenterContainer = $CenterContainer
@onready var _content_vbox: VBoxContainer = $CenterContainer/ContentVBox


func setup(stall_def: StallDefinition, current_tier: int) -> void:
	_stall_def = stall_def
	_current_tier = current_tier
	_viewed_tier_index = clampi(current_tier - 1, 0, stall_def.tiers.size() - 1)

	if is_node_ready():
		_build_content()


func _ready() -> void:
	if _stall_def:
		_build_content()

	_dim_bg.gui_input.connect(_on_bg_input)


func _build_content() -> void:
	# Tier label row (above card)
	var tier_row := HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.set("theme_override_constants/separation", 8)
	_content_vbox.add_child(tier_row)

	_tier_label = Label.new()
	_tier_label.add_theme_font_size_override("font_size", 22)
	_tier_label.add_theme_color_override("font_color", Color.WHITE)
	tier_row.add_child(_tier_label)

	_current_marker_label = Label.new()
	_current_marker_label.add_theme_font_size_override("font_size", 22)
	_current_marker_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	tier_row.add_child(_current_marker_label)

	# Card + arrows row
	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.set("theme_override_constants/separation", 24)
	_content_vbox.add_child(card_row)

	# Left arrow
	_left_button = Button.new()
	_left_button.text = "<"
	_left_button.custom_minimum_size = Vector2(48, 48)
	_left_button.add_theme_font_size_override("font_size", 28)
	_left_button.pressed.connect(_on_left_pressed)
	card_row.add_child(_left_button)

	# Card display (scaled up)
	var card_wrapper := Control.new()
	card_wrapper.custom_minimum_size = Vector2(320, 440)
	card_row.add_child(card_wrapper)

	_card_display = _card_display_scene.instantiate() as CardDisplay
	card_wrapper.add_child(_card_display)
	_card_display.set_display_scale(2.0)

	# Right arrow
	_right_button = Button.new()
	_right_button.text = ">"
	_right_button.custom_minimum_size = Vector2(48, 48)
	_right_button.add_theme_font_size_override("font_size", 28)
	_right_button.pressed.connect(_on_right_pressed)
	card_row.add_child(_right_button)

	_refresh_display()


func _refresh_display() -> void:
	_card_display.setup_for_tier(_stall_def, _viewed_tier_index)

	var tier_num := _viewed_tier_index + 1
	var max_tier := _stall_def.tiers.size()
	_tier_label.text = "Tier %d / %d" % [tier_num, max_tier]

	# Show marker if viewing the current tier
	if tier_num == _current_tier:
		_current_marker_label.text = "★"
		_current_marker_label.visible = true
	else:
		_current_marker_label.visible = false

	_left_button.disabled = _viewed_tier_index <= 0
	_right_button.disabled = _viewed_tier_index >= max_tier - 1


func _on_left_pressed() -> void:
	if _viewed_tier_index > 0:
		_viewed_tier_index -= 1
		_refresh_display()


func _on_right_pressed() -> void:
	if _viewed_tier_index < _stall_def.tiers.size() - 1:
		_viewed_tier_index += 1
		_refresh_display()


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
