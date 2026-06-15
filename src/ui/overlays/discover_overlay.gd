extends Control

## Reusable discover overlay — presents N options and lets the player pick one.
## Supports CardInstance (card display) and GuestDefinition (unit display) options.

signal option_selected(data: Variant)

var _card_display_scene: PackedScene = preload("res://src/ui/components/card_display.tscn")

@onready var prompt_label: Label = $CenterContainer/VBoxContainer/PromptLabel
@onready var options_container: HBoxContainer = $CenterContainer/VBoxContainer/OptionsContainer


func setup(prompt: String, options: Array[Dictionary]) -> void:
	## Configure the overlay with a prompt and options.
	## Each option dict must have "data" as a CardInstance or GuestDefinition.
	if prompt_label:
		prompt_label.text = prompt

	for option in options:
		var panel: Control
		if option.get("data") is CardInstance:
			panel = _create_card_option(option)
		elif option.get("data") is GuestDefinition:
			panel = _create_unit_option(option)
		else:
			push_warning("DiscoverOverlay: unsupported option data type — skipping")
			continue
		options_container.add_child(panel)


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
