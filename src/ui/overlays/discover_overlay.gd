extends Control

## Reusable discover overlay — presents N options and lets the player pick one.
## Generic: receives display data, returns the selected option's opaque "data" field.

signal option_selected(data: Variant)

@onready var prompt_label: Label = $CenterContainer/VBoxContainer/PromptLabel
@onready var options_container: HBoxContainer = $CenterContainer/VBoxContainer/OptionsContainer


func setup(prompt: String, options: Array[Dictionary]) -> void:
	## Configure the overlay with a prompt and options.
	## Each option dict: { "title": String, "description": String, "data": Variant }
	if prompt_label:
		prompt_label.text = prompt

	for option in options:
		var button = _create_option_button(option)
		options_container.add_child(button)


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
	title.text = tr(option.get("title", "???"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var separator = HSeparator.new()
	vbox.add_child(separator)

	var desc = Label.new()
	desc.text = tr(option.get("description", ""))
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
