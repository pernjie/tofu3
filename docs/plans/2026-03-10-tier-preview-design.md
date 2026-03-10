# Stall Tier Preview Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Right-click any stall card (shop, hand, board) to open a full-screen overlay showing tier details with arrow navigation and diff highlighting.

**Architecture:** A new `TierPreviewOverlay` scene (full-screen Control) renders an enlarged CardDisplay for a single tier at a time. CardDisplay gains a `setup_for_tier()` method that accepts a StallDefinition, tier index, and optional previous tier for diff highlighting. Right-click signals propagate through an EventBus signal to the overlay manager (game.gd and interlude_screen.gd).

**Tech Stack:** GDScript, Godot 4.5 UI (Control nodes)

---

### Task 1: Add `setup_for_tier()` to CardDisplay

Extend CardDisplay to render a specific tier of a stall, with changed stats highlighted.

**Files:**
- Modify: `src/ui/components/card_display.gd`

**Step 1: Add the highlight color constant and `setup_for_tier()` method**

Add after the `RARITY_COLORS` constant (~line 20):

```gdscript
const CHANGED_COLOR := Color(0.3, 0.9, 0.3)  # Green highlight for changed stats
```

Add after the `setup()` method (~line 53):

```gdscript
func setup_for_tier(stall_def: StallDefinition, tier_index: int, current_tier: int) -> void:
	## Render this card showing a specific tier's stats.
	## tier_index is 0-based. Highlights stats that changed from previous tier.
	## current_tier is 1-based (the stall's actual current tier, for description).
	if stall_def.tiers.is_empty():
		return

	tier_index = clampi(tier_index, 0, stall_def.tiers.size() - 1)
	var tier := stall_def.tiers[tier_index]
	var prev_tier: StallTierData = stall_def.tiers[tier_index - 1] if tier_index > 0 else null

	_apply_common_from_def(stall_def, tier)
	_build_tier_stats(stall_def, tier, prev_tier)
	_auto_scale_description()
```

**Step 2: Add `_apply_common_from_def()` helper**

This is like `_apply_common()` but takes a definition directly (no CardInstance needed), and resolves description from the tier's skills:

```gdscript
func _apply_common_from_def(stall_def: StallDefinition, tier: StallTierData) -> void:
	_name_label.text = stall_def.get_display_name()

	# Description: explicit or auto-concat from this tier's skills
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

	if stall_def.icon_path and ResourceLoader.exists(stall_def.icon_path):
		_icon_area.texture = load(stall_def.icon_path)
		_icon_area.visible = true
	else:
		_icon_area.visible = false

	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var border_color: Color = RARITY_COLORS.get(stall_def.rarity, RARITY_COLORS["common"])
	style.border_color = border_color
	_panel.add_theme_stylebox_override("panel", style)

	_type_label.text = "Stall"
```

**Step 3: Add `_build_tier_stats()` method**

Similar to `_build_stall_stats()` but takes explicit tier data and highlights changes:

```gdscript
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
		_add_stat_line("Stock: %d / %d trn" % [tier.restock_amount, tier.restock_duration], stock_changed)
	else:
		var cap_changed := prev_tier != null and (tier.capacity != prev_tier.capacity or tier.service_duration != prev_tier.service_duration)
		_add_stat_line("Cap: %d / %d trn" % [tier.capacity, tier.service_duration], cap_changed)
```

**Step 4: Update `_add_stat_line()` to accept an optional highlight flag**

Replace the existing `_add_stat_line()`:

```gdscript
func _add_stat_line(text: String, highlight: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", STATS_FONT_SIZE)
	var color := CHANGED_COLOR if highlight else Color(0.7, 0.7, 0.7)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_box.add_child(label)
```

**Step 5: Add `get_explicit_description()` to StallDefinition**

We need a way to get the explicit description (without auto-generation) so `setup_for_tier` can generate per-tier descriptions.

Modify `src/definitions/stall_definition.gd` — add before `get_description()`:

```gdscript
func get_explicit_description() -> String:
	## Returns the explicit description only (no auto-generation from skills).
	return super.get_description()
```

Wait — `super.get_description()` calls `CardDefinition.get_description()` which calls `BaseDefinition.get_description()` which just resolves the key. That already does the right thing — it returns the translated key or empty string. So this works.

**Step 6: Verify — run the project to check for parse errors**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" --headless --import --path /Users/pern/night`

Expected: No errors related to card_display.gd or stall_definition.gd

---

### Task 2: Create TierPreviewOverlay scene and script

**Files:**
- Create: `src/ui/overlays/tier_preview_overlay.gd`
- Create: `src/ui/overlays/tier_preview_overlay.tscn`

**Step 1: Create the overlay script**

```gdscript
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
	_card_display.scale = Vector2(2, 2)

	# Right arrow
	_right_button = Button.new()
	_right_button.text = ">"
	_right_button.custom_minimum_size = Vector2(48, 48)
	_right_button.add_theme_font_size_override("font_size", 28)
	_right_button.pressed.connect(_on_right_pressed)
	card_row.add_child(_right_button)

	_refresh_display()


func _refresh_display() -> void:
	_card_display.setup_for_tier(_stall_def, _viewed_tier_index, _current_tier)

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
```

**Step 2: Create the .tscn scene file**

The scene structure mirrors DiscoverOverlay:

```
TierPreviewOverlay (Control, fills screen)
├── DimBackground (ColorRect, Color(0,0,0,0.6), mouse_filter = STOP)
└── CenterContainer (fills screen)
    └── ContentVBox (VBoxContainer, centered, separation = 24)
```

The content (tier label, arrows, card display) is built dynamically in `_build_content()`.

**Step 3: Verify — run import check**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" --headless --import --path /Users/pern/night`

Expected: No errors

---

### Task 3: Add EventBus signal and right-click to HandCard

**Files:**
- Modify: `src/autoload/event_bus.gd`
- Modify: `src/ui/components/hand_card.gd`

**Step 1: Add EventBus signal**

Add after `debug_show_relic` (~line 63):

```gdscript
# Tier preview
signal tier_preview_requested(stall_def: StallDefinition, current_tier: int)
```

**Step 2: Add right-click handling to HandCard**

Update `_gui_input()` in `hand_card.gd`:

```gdscript
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(card_instance)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_request_tier_preview()


func _request_tier_preview() -> void:
	if not card_instance:
		return
	if not card_instance.definition is StallDefinition:
		return
	var stall_def := card_instance.definition as StallDefinition
	EventBus.tier_preview_requested.emit(stall_def, 1)
```

Hand cards are always tier 1 (not yet placed).

---

### Task 4: Add right-click to ShopSlot

**Files:**
- Modify: `src/ui/components/shop_slot.gd`

**Step 1: Add gui_input handler for right-click**

Add after `_on_mouse_exited()` (~line 74):

```gdscript
func _gui_input(event: InputEvent) -> void:
	if _is_sold:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_request_tier_preview()


func _request_tier_preview() -> void:
	if not _card:
		return
	if not _card.definition is StallDefinition:
		return
	var stall_def := _card.definition as StallDefinition
	EventBus.tier_preview_requested.emit(stall_def, 1)
```

Shop cards are always tier 1.

---

### Task 5: Add right-click to StallEntity (board)

**Files:**
- Modify: `src/entities/stall/stall.gd`

**Step 1: Add right-click handling to the existing `_input()` method**

Update the `_input()` method to also handle right-click:

```gdscript
func _input(event: InputEvent) -> void:
	var board_visual := get_parent().get_parent() as BoardVisual
	if board_visual and board_visual.placement_mode:
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	var local_pos = to_local(event.global_position)
	var half_size = SPRITE_SIZE / 2.0
	if local_pos.x < -half_size or local_pos.x > half_size or local_pos.y < -half_size or local_pos.y > half_size:
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if instance:
			EventBus.debug_show_stall.emit(instance)
			get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if instance:
			var stall_def := instance.definition as StallDefinition
			if stall_def:
				EventBus.tier_preview_requested.emit(stall_def, instance.current_tier)
				get_viewport().set_input_as_handled()
```

Board stalls pass their actual `current_tier`.

---

### Task 6: Connect EventBus signal to overlay in game.gd

**Files:**
- Modify: `src/game/game.gd`

**Step 1: Preload the overlay scene**

Add after the existing `DiscoverOverlayScene` preload (~line 5):

```gdscript
const TierPreviewOverlayScene = preload("res://src/ui/overlays/tier_preview_overlay.tscn")
```

**Step 2: Connect the signal in `_connect_signals()`**

Add to `_connect_signals()`:

```gdscript
EventBus.tier_preview_requested.connect(_on_tier_preview_requested)
```

**Step 3: Add the handler method**

```gdscript
func _on_tier_preview_requested(stall_def: StallDefinition, current_tier: int) -> void:
	if _ui_blocking:
		return
	var overlay = TierPreviewOverlayScene.instantiate()
	$HUD.add_child(overlay)
	overlay.setup(stall_def, current_tier)
```

No need to set `_ui_blocking` — the overlay is dismissible and non-blocking (no await). The overlay's `_unhandled_input` consumes Escape/right-click, and `DimBackground` mouse_filter=STOP blocks clicks to the game beneath.

---

### Task 7: Connect EventBus signal in interlude_screen.gd (shop context)

**Files:**
- Modify: `src/ui/screens/interlude/interlude_screen.gd`

**Step 1: Preload the overlay scene**

Add after existing preload (~line 8):

```gdscript
var _tier_preview_scene: PackedScene = preload("res://src/ui/overlays/tier_preview_overlay.tscn")
```

**Step 2: Connect signal in `_ready()`**

Add to `_ready()`:

```gdscript
EventBus.tier_preview_requested.connect(_on_tier_preview_requested)
```

**Step 3: Add handler and cleanup**

```gdscript
func _on_tier_preview_requested(stall_def: StallDefinition, current_tier: int) -> void:
	var overlay = _tier_preview_scene.instantiate()
	add_child(overlay)
	overlay.setup(stall_def, current_tier)
```

Add disconnect in `_exit_tree()`:

```gdscript
if EventBus.tier_preview_requested.is_connected(_on_tier_preview_requested):
	EventBus.tier_preview_requested.disconnect(_on_tier_preview_requested)
```

**Important:** Since both game.gd and interlude_screen.gd connect to the same signal, only one will be active at a time (game scene during gameplay, interlude screen between levels), so no double-firing.

---

### Task 8: Manual testing

**Step 1: Test in shop (interlude screen)**

- Start a run, reach the shop
- Right-click a stall card → overlay should appear with tier 1, star marker visible
- Click arrows to navigate tiers → stats update, changed values shown in green
- Tier 1 should have no green highlights
- Dismiss with Escape, right-click, or clicking background
- Right-click a spell card → nothing should happen

**Step 2: Test in hand (gameplay)**

- Play a level, draw stall cards
- Right-click a stall card in hand → overlay appears
- Verify current tier shows as 1 with star

**Step 3: Test on board (placed stall)**

- Place a stall on the board
- Right-click the placed stall → overlay opens at tier 1 with star
- If possible, upgrade the stall and right-click again → opens at tier 2 with star on tier 2
- Navigate to tier 1 → no star, no green; navigate to tier 2 → star, green highlights on changed stats
- Navigate to tier 3 → no star, green highlights on changes from tier 2
