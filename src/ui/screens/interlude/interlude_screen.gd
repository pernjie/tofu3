extends Control

## Interlude screen between levels.
## Features the shop as main content, with guest and deck view as overlays.

signal continue_pressed

var card_ui_scene: PackedScene = preload("res://src/ui/components/card_ui.tscn")
var deck: Array[CardInstance] = []

var next_level_id: String = ""
var guest_preview: Array = []
var _shop_system: ShopSystem

@onready var title_label: Label = $MainContainer/HeaderContainer/TitleLabel
@onready var token_label: Label = $MainContainer/HeaderContainer/TokenLabel
@onready var shop_area: VBoxContainer = $MainContainer/ShopArea

@onready var view_guests_button: Button = $MainContainer/ButtonContainer/ViewGuestsButton
@onready var view_deck_button: Button = $MainContainer/ButtonContainer/ViewDeckButton
@onready var continue_button: Button = $MainContainer/ButtonContainer/ContinueButton

@onready var deck_popup: Panel = $DeckPopup
@onready var deck_grid: HFlowContainer = $DeckPopup/MarginContainer/VBoxContainer/ScrollContainer/DeckGrid
@onready var deck_title: Label = $DeckPopup/MarginContainer/VBoxContainer/DeckTitle
@onready var close_deck_button: Button = $DeckPopup/MarginContainer/VBoxContainer/CloseDeckButton

@onready var guest_popup: Panel = $GuestPopup
@onready var guest_list: VBoxContainer = $GuestPopup/MarginContainer/VBoxContainer/GuestList
@onready var close_guests_button: Button = $GuestPopup/MarginContainer/VBoxContainer/CloseGuestsButton


func _ready() -> void:
	view_guests_button.pressed.connect(_on_view_guests_pressed)
	view_deck_button.pressed.connect(_on_view_deck_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	close_deck_button.pressed.connect(_on_close_deck_pressed)
	close_guests_button.pressed.connect(_on_close_guests_pressed)
	deck_popup.hide()
	guest_popup.hide()

	EventBus.tokens_changed.connect(_on_tokens_changed)
	_update_token_display()

	if next_level_id != "":
		_update_title()
	if _shop_system:
		_setup_shop_panel()


func setup(level_id: String, guests: Array, player_deck: Array[CardInstance] = [], hero_id: String = "") -> void:
	next_level_id = level_id
	guest_preview = guests
	deck = player_deck

	# Create shop system
	if hero_id != "":
		_shop_system = ShopSystem.new()
		_shop_system.setup(hero_id)

	if is_node_ready():
		_update_title()
		_update_token_display()
		_setup_shop_panel()


func _update_title() -> void:
	var level_def = ContentRegistry.get_definition("levels", next_level_id)
	if level_def:
		title_label.text = "Day %d" % level_def.level_number


func _update_token_display() -> void:
	token_label.text = "%d tokens" % GameManager.tokens


func _setup_shop_panel() -> void:
	if not _shop_system:
		return

	var shop_panel := ShopPanel.new()
	shop_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_area.add_child(shop_panel)
	shop_panel.setup(_shop_system)


func _update_guest_list() -> void:
	for child in guest_list.get_children():
		child.queue_free()

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
	for child in deck_grid.get_children():
		child.queue_free()

	deck_title.text = "Your Deck (%d cards)" % deck.size()

	var sorted_deck = deck.duplicate()
	sorted_deck.sort_custom(func(a, b): return a.definition.id < b.definition.id)

	for card in sorted_deck:
		var card_ui = card_ui_scene.instantiate() as CardUI
		card_ui.mode = CardUI.Mode.DISPLAY
		card_ui.custom_minimum_size = Vector2(100, 140)
		deck_grid.add_child(card_ui)
		card_ui.setup(card)


func _on_view_guests_pressed() -> void:
	_update_guest_list()
	guest_popup.show()


func _on_close_guests_pressed() -> void:
	guest_popup.hide()


func _on_view_deck_pressed() -> void:
	_update_deck_list()
	deck_popup.show()


func _on_close_deck_pressed() -> void:
	deck_popup.hide()


func _on_continue_pressed() -> void:
	continue_pressed.emit()


func _on_tokens_changed(_old_value: int, _new_value: int) -> void:
	_update_token_display()


func _exit_tree() -> void:
	if EventBus.tokens_changed.is_connected(_on_tokens_changed):
		EventBus.tokens_changed.disconnect(_on_tokens_changed)
