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

const CORNER_RADIUS := 6
const PADDING_H := 8
const PADDING_V := 6
const TYPE_FONT_SIZE := 10

const CHANGED_COLOR := Color(0.3, 0.9, 0.3)  # Green highlight for changed stats

var _card: CardInstance
var _display_scale: float = 1.0

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


func set_display_scale(s: float) -> void:
	## Render the card at s× native size with crisp text.
	_display_scale = s
	custom_minimum_size = CARD_SIZE * s
	_icon_area.custom_minimum_size = Vector2(0, ICON_HEIGHT * s)
	_vbox.offset_left = PADDING_H * s
	_vbox.offset_top = PADDING_V * s
	_vbox.offset_right = -PADDING_H * s
	_vbox.offset_bottom = -PADDING_V * s
	_name_label.add_theme_font_size_override("font_size", roundi(NAME_FONT_SIZE * s))
	_type_label.add_theme_font_size_override("font_size", roundi(TYPE_FONT_SIZE * s))
	_description_label.add_theme_font_size_override("font_size", roundi(DESC_FONT_SIZE * s))


func setup(card: CardInstance) -> void:
	_card = card
	var def := card.definition
	_apply_common(def)
	_build_stall_stats(def)
	_auto_scale_description()


func setup_for_tier(stall_def: StallDefinition, tier_index: int) -> void:
	## Render this card showing a specific tier's stats.
	## tier_index is 0-based. Highlights stats that changed from previous tier.
	if stall_def.tiers.is_empty():
		return

	tier_index = clampi(tier_index, 0, stall_def.tiers.size() - 1)
	var tier := stall_def.tiers[tier_index]
	var prev_tier: StallTierData = stall_def.tiers[tier_index - 1] if tier_index > 0 else null

	_apply_common_from_def(stall_def, tier)
	_build_tier_stats(stall_def, tier, prev_tier)
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

	# Rarity border (scaled for crisp rendering at display_scale)
	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var border_color: Color = RARITY_COLORS.get(def.rarity, RARITY_COLORS["common"])
	style.border_color = border_color
	var bw := roundi(BORDER_WIDTH * _display_scale)
	style.border_width_left = bw
	style.border_width_top = bw
	style.border_width_right = bw
	style.border_width_bottom = bw
	var cr := roundi(CORNER_RADIUS * _display_scale)
	style.corner_radius_top_left = cr
	style.corner_radius_top_right = cr
	style.corner_radius_bottom_right = cr
	style.corner_radius_bottom_left = cr
	_panel.add_theme_stylebox_override("panel", style)

	# Type badge
	_type_label.text = def.card_type.capitalize()


func _apply_common_from_def(stall_def: StallDefinition, tier: StallTierData) -> void:
	## Reuse base visual setup, then override description with tier-specific content.
	_apply_common(stall_def)

	# Override description: explicit or auto-concat from this tier's skills
	var explicit := stall_def.get_explicit_description()
	if explicit:
		_description_label.text = explicit
	else:
		var parts: Array[String] = []
		for entry in tier.skill_data:
			var skill_id: String = entry.get("skill_id", "")
			if skill_id.is_empty():
				continue
			var skill_def := ContentRegistry.get_definition("skills", skill_id) as SkillDefinition
			if skill_def and skill_def.description:
				parts.append(skill_def.description)
		_description_label.text = "\n".join(parts)


func _build_stall_stats(def: CardDefinition) -> void:
	for child in _stats_box.get_children():
		child.queue_free()

	if not def is StallDefinition:
		_stats_box.visible = false
		return

	var stall_def := def as StallDefinition
	if stall_def.tiers.is_empty():
		_stats_box.visible = false
		return

	_build_tier_stats(stall_def, stall_def.tiers[0], null)


func _build_tier_stats(stall_def: StallDefinition, tier: StallTierData, prev_tier: StallTierData) -> void:
	for child in _stats_box.get_children():
		child.queue_free()
	_stats_box.visible = true

	# Line 1: "Product · Food" (never changes between tiers)
	var type_text := stall_def.operation_model.capitalize()
	if stall_def.need_type:
		type_text += " · " + stall_def.need_type.capitalize()
	_add_stat_line(type_text)

	# Line 2: "2 food for 1¢"
	var value_changed := prev_tier != null and (tier.value != prev_tier.value or tier.cost_to_guest != prev_tier.cost_to_guest)
	var value_text := "%d %s for %d¢" % [tier.value, stall_def.need_type, tier.cost_to_guest]
	_add_stat_line(value_text, value_changed)

	# Line 3: model-specific
	if stall_def.operation_model == "product":
		var stock_changed := prev_tier != null and (tier.restock_amount != prev_tier.restock_amount or tier.restock_duration != prev_tier.restock_duration)
		_add_stat_line("Restock %d every %d turns" % [tier.restock_amount, tier.restock_duration], stock_changed)
	else:
		var cap_changed := prev_tier != null and (tier.capacity != prev_tier.capacity or tier.service_duration != prev_tier.service_duration)
		_add_stat_line("Serves %d over %d turns" % [tier.capacity, tier.service_duration], cap_changed)


func _add_stat_line(text: String, highlight: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", roundi(STATS_FONT_SIZE * _display_scale))
	var color := CHANGED_COLOR if highlight else Color(0.7, 0.7, 0.7)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_box.add_child(label)


func _auto_scale_description() -> void:
	if not _description_label or _description_label.text.is_empty():
		return

	var current_size := roundi(DESC_FONT_SIZE * _display_scale)
	_description_label.add_theme_font_size_override("font_size", current_size)

	# Wait one frame for layout to settle
	await get_tree().process_frame

	var min_size := roundi(DESC_MIN_FONT_SIZE * _display_scale)
	while _description_label.get_line_count() > 3 and current_size > min_size:
		current_size -= 1
		_description_label.add_theme_font_size_override("font_size", current_size)
		await get_tree().process_frame
