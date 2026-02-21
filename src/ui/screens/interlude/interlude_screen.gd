extends Control

## Interlude screen between levels.
## Shows upcoming guest queue and provides deck view access.

signal continue_pressed

var card_ui_scene: PackedScene = preload("res://src/ui/components/card_ui.tscn")
var deck: Array[CardInstance] = []

var next_level_id: String = ""
var guest_preview: Array = []

@onready var title_label: Label = $MainContainer/TitleLabel
@onready var guest_list: VBoxContainer = $MainContainer/GuestPanel/GuestList
@onready var deck_popup: Panel = $DeckPopup
@onready var deck_grid: HFlowContainer = $DeckPopup/MarginContainer/VBoxContainer/ScrollContainer/DeckGrid
@onready var deck_title: Label = $DeckPopup/MarginContainer/VBoxContainer/DeckTitle
@onready var view_deck_button: Button = $MainContainer/ButtonContainer/ViewDeckButton
@onready var continue_button: Button = $MainContainer/ButtonContainer/ContinueButton
@onready var close_deck_button: Button = $DeckPopup/MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	view_deck_button.pressed.connect(_on_view_deck_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	close_deck_button.pressed.connect(_on_close_deck_pressed)
	deck_popup.hide()

	# Update if setup() was called before _ready()
	if next_level_id != "":
		var level_def = ContentRegistry.get_definition("levels", next_level_id)
		if level_def:
			title_label.text = "Day %d" % level_def.level_number
	if not guest_preview.is_empty():
		_update_guest_list()


func setup(level_id: String, guests: Array, player_deck: Array[CardInstance] = []) -> void:
	next_level_id = level_id
	guest_preview = guests
	deck = player_deck

	var level_def = ContentRegistry.get_definition("levels", level_id)
	if level_def and is_node_ready():
		title_label.text = "Day %d" % level_def.level_number
	if is_node_ready():
		_update_guest_list()


func _update_guest_list() -> void:
	# Clear existing
	for child in guest_list.get_children():
		child.queue_free()

	# Add header
	var header = Label.new()
	header.text = "Upcoming Guests:"
	guest_list.add_child(header)

	# Add guest entries
	for entry in guest_preview:
		var label = Label.new()
		var needs_str = ""
		if entry.has("needs"):
			var parts: Array[String] = []
			for need_type in entry.needs:
				parts.append("%s: %d" % [need_type, entry.needs[need_type]])
			needs_str = " (" + ", ".join(parts) + ")"
		label.text = "- %s%s" % [entry.id, needs_str]
		if entry.get("is_boss", false):
			label.text += " [boss]"
		guest_list.add_child(label)


func _update_deck_list() -> void:
	# Clear existing
	for child in deck_grid.get_children():
		child.queue_free()

	# Update title with count
	deck_title.text = "Your Deck (%d cards)" % deck.size()

	# Sort alphabetically by card id
	var sorted_deck = deck.duplicate()
	sorted_deck.sort_custom(func(a, b): return a.definition.id < b.definition.id)

	# Create CardUI for each card in DISPLAY mode
	for card in sorted_deck:
		var card_ui = card_ui_scene.instantiate() as CardUI
		card_ui.mode = CardUI.Mode.DISPLAY
		card_ui.custom_minimum_size = Vector2(100, 140)
		deck_grid.add_child(card_ui)
		card_ui.setup(card)


func _on_view_deck_pressed() -> void:
	_update_deck_list()
	deck_popup.show()


func _on_close_deck_pressed() -> void:
	deck_popup.hide()


func _on_continue_pressed() -> void:
	continue_pressed.emit()
