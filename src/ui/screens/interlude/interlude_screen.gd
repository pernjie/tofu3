extends Control

## Interlude screen between levels.
## Features the shop as main content, with guest and deck view as overlays.

signal continue_pressed

var _card_display_scene: PackedScene = preload("res://src/ui/components/card_display.tscn")
var _tier_preview_scene: PackedScene = preload("res://src/ui/overlays/tier_preview_overlay.tscn")
var _card_preview_scene: PackedScene = preload("res://src/ui/overlays/card_preview_overlay.tscn")
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

@onready var remove_popup: Panel = $RemoveCardPopup
@onready var remove_grid: HFlowContainer = $RemoveCardPopup/MarginContainer/VBoxContainer/ScrollContainer/RemoveGrid
@onready var remove_title: Label = $RemoveCardPopup/MarginContainer/VBoxContainer/RemoveTitle
@onready var cancel_remove_button: Button = $RemoveCardPopup/MarginContainer/VBoxContainer/CancelRemoveButton

@onready var guest_popup: Panel = $GuestPopup
@onready var guest_grid: HFlowContainer = $GuestPopup/MarginContainer/VBoxContainer/ScrollContainer/GuestGrid
@onready var guest_title: Label = $GuestPopup/MarginContainer/VBoxContainer/GuestTitle
@onready var close_guests_button: Button = $GuestPopup/MarginContainer/VBoxContainer/CloseGuestsButton


func _ready() -> void:
	view_guests_button.pressed.connect(_on_view_guests_pressed)
	view_deck_button.pressed.connect(_on_view_deck_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	close_deck_button.pressed.connect(_on_close_deck_pressed)
	close_guests_button.pressed.connect(_on_close_guests_pressed)
	cancel_remove_button.pressed.connect(_on_cancel_remove_pressed)
	deck_popup.hide()
	guest_popup.hide()
	remove_popup.hide()

	EventBus.tokens_changed.connect(_on_tokens_changed)
	EventBus.tier_preview_requested.connect(_on_tier_preview_requested)
	EventBus.card_preview_requested.connect(_on_card_preview_requested)
	EventBus.unit_preview_requested.connect(_on_unit_preview_requested)
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
	shop_panel.remove_card_requested.connect(_on_remove_card_requested)


func _update_guest_list() -> void:
	for child in guest_grid.get_children():
		child.queue_free()

	guest_title.text = "Upcoming Guests (%d)" % guest_preview.size()

	for guest_def in guest_preview:
		var card_display := _card_display_scene.instantiate() as CardDisplay
		guest_grid.add_child(card_display)
		card_display.setup_unit(guest_def)


func _update_deck_list() -> void:
	for child in deck_grid.get_children():
		child.queue_free()

	deck_title.text = "Your Deck (%d cards)" % deck.size()

	var sorted_deck = deck.duplicate()
	sorted_deck.sort_custom(func(a, b): return a.definition.id < b.definition.id)

	for card in sorted_deck:
		var card_display := _card_display_scene.instantiate() as CardDisplay
		deck_grid.add_child(card_display)
		card_display.setup(card)


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


func _on_remove_card_requested() -> void:
	_update_remove_card_list()
	remove_popup.show()


func _update_remove_card_list() -> void:
	for child in remove_grid.get_children():
		child.queue_free()

	remove_title.text = "Remove a Card (%d tokens)" % ShopSystem.REMOVE_CARD_COST

	var sorted_deck := deck.duplicate()
	sorted_deck.sort_custom(func(a, b): return a.definition.id < b.definition.id)

	for card in sorted_deck:
		var card_display := _card_display_scene.instantiate() as CardDisplay
		remove_grid.add_child(card_display)
		card_display.setup(card)
		card_display.mouse_filter = Control.MOUSE_FILTER_STOP
		card_display.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card_display.gui_input.connect(_on_remove_card_input.bind(card, card_display))


func _on_remove_card_input(event: InputEvent, card: CardInstance, card_display: CardDisplay) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _shop_system.remove_card(card):
			deck.erase(card)
			remove_popup.hide()


func _on_cancel_remove_pressed() -> void:
	remove_popup.hide()


func _on_continue_pressed() -> void:
	continue_pressed.emit()


func _on_tokens_changed(_old_value: int, _new_value: int) -> void:
	_update_token_display()


func _on_tier_preview_requested(stall_def: StallDefinition, current_tier: int) -> void:
	var overlay = _tier_preview_scene.instantiate()
	add_child(overlay)
	overlay.setup(stall_def, current_tier)


func _on_card_preview_requested(card: CardInstance) -> void:
	var overlay = _card_preview_scene.instantiate()
	add_child(overlay)
	overlay.setup_card(card)


func _on_unit_preview_requested(guest_def: GuestDefinition) -> void:
	var overlay = _card_preview_scene.instantiate()
	add_child(overlay)
	overlay.setup_unit(guest_def)


func _exit_tree() -> void:
	if EventBus.tokens_changed.is_connected(_on_tokens_changed):
		EventBus.tokens_changed.disconnect(_on_tokens_changed)
	if EventBus.tier_preview_requested.is_connected(_on_tier_preview_requested):
		EventBus.tier_preview_requested.disconnect(_on_tier_preview_requested)
	if EventBus.card_preview_requested.is_connected(_on_card_preview_requested):
		EventBus.card_preview_requested.disconnect(_on_card_preview_requested)
	if EventBus.unit_preview_requested.is_connected(_on_unit_preview_requested):
		EventBus.unit_preview_requested.disconnect(_on_unit_preview_requested)
