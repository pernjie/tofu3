# Card Display Standardization

## Problem

Cards are rendered inconsistently across 4 contexts (hand, shop, deck viewer, discover overlay) with different sizes, different information shown, and duplicated layout code. `CardUI` has a mode enum that doesn't scale, and the discover overlay builds its own card-like panels from scratch.

## Solution

Replace `CardUI` with a pure-visual `CardDisplay` component. Each context wraps it with its own interaction logic.

## Architecture

```
CardDisplay (pure visual, no interaction)
├── setup(card: CardInstance) → reads definition for all display data
├── mouse_filter = IGNORE

Context wrappers (composition, not inheritance):
  HandCard     → CardDisplay + click/hover/dimming/selection
  ShopSlot     → CardDisplay + price label + buy button
  DeckCard     → CardDisplay (no wrapper, used directly in containers)
  DiscoverCard → CardDisplay + hover highlight + click selection
```

## Visual Constants

All visual constants are centralized at the top of `card_display.gd` for easy tuning:

```gdscript
const CARD_SIZE := Vector2(160, 220)
const BORDER_WIDTH := 2
const ICON_HEIGHT := 50
const NAME_FONT_SIZE := 16
const STATS_FONT_SIZE := 12
const DESC_FONT_SIZE := 11
const TYPE_FONT_SIZE := 11
const DESC_MIN_FONT_SIZE := 8

const RARITY_COLORS := {
    "common": Color(0.5, 0.5, 0.5),
    "rare": Color(0.3, 0.5, 0.9),
    "epic": Color(0.6, 0.3, 0.8),
    "legendary": Color(0.9, 0.7, 0.2),
}
```

## CardDisplay Layout

Size: **160x220px**. Rarity-colored border (2px).

```
┌──────────────────────┐  ← Rarity border (StyleBoxFlat)
│  ┌────────────────┐  │
│  │   Icon Area     │  │  50px, TextureRect, centered
│  └────────────────┘  │  Hidden when icon_path is empty
│   Card Name          │  16px, bold, centered
│   ─────────────      │  HSeparator
│   🍜 Food  Stock: 2  │  Stats row, 12px (type-specific)
│                      │
│  Restocks target     │  Description, 11px, word-wrap
│  stall to full.      │  tr(description_key), max 3 lines
│                      │
│   ● Stall            │  Type badge, 11px, bottom-aligned
└──────────────────────┘
```

### Stats Row (adapts per card type)

Built by `_build_stats_row()` helper, switches on `card_type`:
- **Stall**: need type icon + "Food"/"Joy" + starting stock from tier 1 definition (e.g. "Stock: 3")
- **Spell**: target type ("Target: Stall", "Target: Tile", "Target: Guest", "No Target")
- **Relic**: "Passive"

### Subtype Casting

`setup()` casts to the correct definition subtype to read type-specific stats:

```gdscript
func setup(card: CardInstance) -> void:
    _card = card
    var def := card.definition
    # Common fields: display_name_key, description_key, rarity, icon_path
    _apply_common(def)
    # Type-specific stats
    _build_stats_row(def)

func _build_stats_row(def: CardDefinition) -> void:
    if def is StallDefinition:
        var stall_def := def as StallDefinition
        # stall_def.need_type, stall_def.tiers[0].stock
    elif def is SpellDefinition:
        var spell_def := def as SpellDefinition
        # spell_def.target_type
    elif def is RelicDefinition:
        # "Passive"
```

### Icon Area

- Uses `TextureRect` with `icon_path` from definition
- **Hidden** (`visible = false`) when `icon_path` is empty — no blank space shown
- When hidden, remaining elements expand naturally in the VBox

### Description Auto-Scaling

- Description label starts at `DESC_FONT_SIZE` (11px)
- If text overflows available space, font size shrinks until it fits (minimum `DESC_MIN_FONT_SIZE`, 8px)
- Checked after `setup()` via `_auto_scale_description()` which reduces font size in a loop until the content fits or hits the minimum

### Enhancement Display

Not in scope for this migration. Enhancement visuals (glow, stat modifications) will be added as a follow-up once the base component is stable.

### API

```gdscript
class_name CardDisplay extends Control

func setup(card: CardInstance) -> void
    # Reads card.definition for: display_name_key, description_key,
    # icon_path, rarity, card_type, and type-specific stats via subtype casting
```

No signals, no input handling, no modes. `mouse_filter = IGNORE`.

## Wrapper Components

### HandCard (`src/ui/components/hand_card.gd/.tscn`)
- Wraps `CardDisplay` (composition)
- Handles: `_gui_input` for click detection, selection highlight (yellow modulate), dimming (greyed out when unplayable)
- Signal: `card_clicked(card: CardInstance)`
- Used by: `HandDisplay`

### ShopSlot (`src/ui/components/shop_slot.gd/.tscn`)
- VBox: `CardDisplay` + price `Label` + `Button` ("Buy")
- `setup(card: CardInstance, price: int)` — price passed separately because shop applies discounts beyond `get_effective_price()`
- `set_sold()` — replaces content with "Sold" state
- `set_affordable(can_afford: bool)` — dims card + disables button when unaffordable
- Used by: `ShopPanel`

### DeckCard (no wrapper)
- `CardDisplay` used directly at full size in deck viewer containers
- Remove popup: interlude screen composes a VBox of `CardDisplay` + "Remove" button inline (same pattern as ShopSlot but simpler, no dedicated wrapper needed)

### DiscoverOverlay (refactored)
- When option contains a `CardInstance` in its data, instantiates `CardDisplay` instead of manually building a panel
- Keeps dict-based fallback for non-card discover prompts (relic choices, etc.)

## Migration Steps

### Step 1: Create CardDisplay
- New `src/ui/components/card_display.tscn` and `card_display.gd`
- Scene tree: Panel > VBox > IconArea, NameLabel, Separator, StatsRow, DescriptionLabel, TypeLabel
- StyleBoxFlat with rarity-colored border
- Visual constants at top of script
- `setup()` populates all fields from `CardInstance`, using `_build_stats_row()` for type-specific stats
- Icon area hidden when no icon available

### Step 2: Create HandCard
- New `src/ui/components/hand_card.tscn` and `hand_card.gd`
- Contains `CardDisplay` child
- Moves click/select/dim logic from old `CardUI`
- Signal: `card_clicked(card: CardInstance)`

### Step 3: Update HandDisplay
- Change `card_ui_scene` preload to `hand_card.tscn`
- Change type references from `CardUI` to `HandCard`
- API unchanged (`add_card`, `remove_card`, etc.)

### Step 4: Create ShopSlot
- New `src/ui/components/shop_slot.tscn` and `shop_slot.gd`
- VBox with `CardDisplay` + price label + buy button
- `setup(card, price)` takes explicit price (shop applies discounts)

### Step 5: Refactor ShopPanel
- Replace manual slot building with `ShopSlot` instances
- Simplify `_refresh()` to delegate to `ShopSlot.setup()` / `ShopSlot.set_sold()`

### Step 6: Update Deck Viewer & Remove Popup
- In `interlude_screen.gd`, use `CardDisplay` directly (full size) instead of `CardUI`
- Remove popup composes VBox of `CardDisplay` + "Remove" button inline

### Step 7: Update DiscoverOverlay
- Accept `CardInstance` in option data
- Use `CardDisplay` when card data is present
- Keep manual panel fallback for non-card options

### Step 8: Delete CardUI
- Remove `card_ui.gd` and `card_ui.tscn`
- Verify no remaining references

Note: Steps 2-3 (hand) and Steps 4-5 (shop) are independent chains and can be done in either order. Step 8 must be last.

## Files Changed
- **New**: `card_display.gd/.tscn`, `hand_card.gd/.tscn`, `shop_slot.gd/.tscn`
- **Modified**: `hand_display.gd`, `shop_panel.gd`, `interlude_screen.gd`, `discover_overlay.gd`
- **Deleted**: `card_ui.gd`, `card_ui.tscn`
