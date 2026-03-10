class_name CardDisplay
extends Control

## Pure visual card display. No interaction, no signals.
## Used by HandCard, ShopSlot, DeckViewer, and DiscoverOverlay.

const CARD_SIZE := Vector2(160, 220)
const BORDER_WIDTH := 2
const ICON_HEIGHT := 50
const NAME_FONT_SIZE := 16
const DESC_FONT_SIZE := 11
const DESC_MIN_FONT_SIZE := 8
const STATS_FONT_SIZE := 11

const RARITY_COLORS := {
	"common": Color(0.5, 0.5, 0.5),
	"rare": Color(0.3, 0.5, 0.9),
	"epic": Color(0.6, 0.3, 0.8),
	"legendary": Color(0.9, 0.7, 0.2),
}

var _card: CardInstance

@onready var _panel: Panel = $Panel
@onready var _vbox: VBoxContainer = $Panel/VBox
@onready var _icon_area: TextureRect = $Panel/VBox/IconArea
@onready var _name_label: Label = $Panel/VBox/NameLabel
@onready var _separator: HSeparator = $Panel/VBox/Separator
@onready var _stats_box: VBoxContainer = $Panel/VBox/StatsBox
@onready var _description_label: Label = $Panel/VBox/DescriptionLabel
@onready var _type_label: Label = $Panel/VBox/TypeLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mouse_ignore_recursive(self)
	custom_minimum_size = CARD_SIZE


func _set_mouse_ignore_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)


func setup(card: CardInstance) -> void:
	_card = card
	var def := card.definition
	_apply_common(def)
	_build_stall_stats(def)
	_auto_scale_description()


func _apply_common(def: CardDefinition) -> void:
	# Name
	_name_label.text = def.get_display_name()

	# Description
	_description_label.text = def.get_description()

	# Icon
	if def.icon_path and ResourceLoader.exists(def.icon_path):
		_icon_area.texture = load(def.icon_path)
		_icon_area.visible = true
	else:
		_icon_area.visible = false

	# Rarity border
	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var border_color: Color = RARITY_COLORS.get(def.rarity, RARITY_COLORS["common"])
	style.border_color = border_color
	_panel.add_theme_stylebox_override("panel", style)

	# Type badge
	_type_label.text = def.card_type.capitalize()


func _build_stall_stats(def: CardDefinition) -> void:
	# Clear previous
	for child in _stats_box.get_children():
		child.queue_free()

	if not def is StallDefinition:
		_stats_box.visible = false
		return

	var stall_def := def as StallDefinition
	if stall_def.tiers.is_empty():
		_stats_box.visible = false
		return

	_stats_box.visible = true
	var tier := stall_def.tiers[0]

	# Line 1: "Product · Food"
	var type_text := stall_def.operation_model.capitalize()
	if stall_def.need_type:
		type_text += " \u00b7 " + stall_def.need_type.capitalize()
	_add_stat_line(type_text)

	# Line 2: "2 food for 1¢"
	var value_text := "%d %s for %d\u00a2" % [tier.value, stall_def.need_type, tier.cost_to_guest]
	_add_stat_line(value_text)

	# Line 3: model-specific
	if stall_def.operation_model == "product":
		_add_stat_line("Stock: %d / %d trn" % [tier.restock_amount, tier.restock_duration])
	else:
		_add_stat_line("Cap: %d / %d trn" % [tier.capacity, tier.service_duration])


func _add_stat_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", STATS_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_box.add_child(label)


func _auto_scale_description() -> void:
	if not _description_label or _description_label.text.is_empty():
		return

	var current_size := DESC_FONT_SIZE
	_description_label.add_theme_font_size_override("font_size", current_size)

	# Wait one frame for layout to settle
	await get_tree().process_frame

	while _description_label.get_line_count() > 3 and current_size > DESC_MIN_FONT_SIZE:
		current_size -= 1
		_description_label.add_theme_font_size_override("font_size", current_size)
		await get_tree().process_frame
