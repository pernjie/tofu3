extends Control

## Reusable discover overlay — presents N options and lets the player pick one.
## Generic: receives display data, returns the selected option's opaque "data" field.
## When option data is a CardInstance, uses CardDisplay for consistent card rendering.

signal option_selected(data: Variant)

var _card_display_scene: PackedScene = preload("res://src/ui/components/card_display.tscn")

@onready var prompt_label: Label = $CenterContainer/VBoxContainer/PromptLabel
@onready var options_container: HBoxContainer = $CenterContainer/VBoxContainer/OptionsContainer


func setup(prompt: String, options: Array[Dictionary]) -> void:
	## Configure the overlay with a prompt and options.
	## Each option dict: { "title": String, "description": String, "data": Variant }
	## When data is a CardInstance, renders using CardDisplay instead of manual panel.
	if prompt_label:
		prompt_label.text = prompt

	for option in options:
		var panel: Control
		if option.get("data") is CardInstance:
			panel = _create_card_option(option)
		elif option.get("data") is GuestDefinition:
			panel = _create_unit_option(option)
		else:
			panel = _create_option_button(option)
		options_container.add_child(panel)


func _resolve_text(key: String) -> String:
	if key.is_empty():
		return ""
	var translated := tr(key)
	return translated if translated != key else key


func _create_option_button(option: Dictionary) -> PanelContainer:
	## Create a clickable option card with visible styling.
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 280)

	# Style the panel as a visible card
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2)
	style.border_color = Color(0.6, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var title = Label.new()
	title.text = _resolve_text(option.get("title", "???"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var separator = HSeparator.new()
	vbox.add_child(separator)

	var desc = Label.new()
	desc.text = _resolve_text(option.get("description", ""))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size.x = 180
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vbox.add_child(desc)

	panel.add_child(vbox)

	# Hover style
	var hover_style = style.duplicate()
	hover_style.border_color = Color(0.9, 0.8, 1.0)
	hover_style.bg_color = Color(0.22, 0.18, 0.3)

	# Make clickable
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			option_selected.emit(option.get("data"))
	)

	# Hover feedback
	panel.mouse_entered.connect(func(): panel.add_theme_stylebox_override("panel", hover_style))
	panel.mouse_exited.connect(func(): panel.add_theme_stylebox_override("panel", style))

	return panel


func _create_unit_option(option: Dictionary) -> Control:
	## Create a clickable option using CardDisplay for GuestDefinition data.
	var guest_def: GuestDefinition = option["data"]

	var wrapper := PanelContainer.new()
	wrapper.custom_minimum_size = CardDisplay.CARD_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	wrapper.add_theme_stylebox_override("panel", style)

	var card_display := _card_display_scene.instantiate() as CardDisplay
	wrapper.add_child(card_display)
	card_display.setup_unit(guest_def)

	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	highlight_style.set_border_width_all(2)
	highlight_style.border_color = Color(0.9, 0.8, 1.0)
	highlight_style.set_corner_radius_all(6)

	wrapper.mouse_entered.connect(func() -> void: wrapper.add_theme_stylebox_override("panel", highlight_style))
	wrapper.mouse_exited.connect(func() -> void: wrapper.add_theme_stylebox_override("panel", style))

	wrapper.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			option_selected.emit(guest_def)
	)

	return wrapper


func _create_card_option(option: Dictionary) -> Control:
	## Create a clickable option using CardDisplay for CardInstance data.
	var card: CardInstance = option["data"]

	var wrapper := PanelContainer.new()
	wrapper.custom_minimum_size = CardDisplay.CARD_SIZE

	# Transparent wrapper — CardDisplay handles its own visuals
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	wrapper.add_theme_stylebox_override("panel", style)

	var card_display := _card_display_scene.instantiate() as CardDisplay
	wrapper.add_child(card_display)
	card_display.setup(card)

	# Hover highlight
	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	highlight_style.set_border_width_all(2)
	highlight_style.border_color = Color(0.9, 0.8, 1.0)
	highlight_style.set_corner_radius_all(6)

	wrapper.mouse_entered.connect(func() -> void: wrapper.add_theme_stylebox_override("panel", highlight_style))
	wrapper.mouse_exited.connect(func() -> void: wrapper.add_theme_stylebox_override("panel", style))

	# Click
	wrapper.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			option_selected.emit(card)
	)

	return wrapper
