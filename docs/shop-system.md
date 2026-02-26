# Shop System

The shop appears during interlude screens between levels. Players spend tokens to buy cards, reroll offerings, or remove cards from their deck.

## Architecture

```
InterludeScreen (Control)
├── creates ShopSystem (RefCounted, ephemeral)
├── creates ShopPanel (VBoxContainer, UI component)
└── manages popups (DeckPopup, RemoveCardPopup, GuestPopup)
```

- **ShopSystem** (`src/systems/shop_system.gd`) - Pure logic, no UI. Created fresh each interlude visit and garbage collected when the screen closes.
- **ShopPanel** (`src/ui/components/shop_panel.gd`) - Builds all shop UI programmatically (no `.tscn`). Displays card offerings, buy/reroll buttons, and the remove card button.
- **InterludeScreen** (`src/ui/screens/interlude/interlude_screen.gd` + `.tscn`) - Owns the ShopSystem, ShopPanel, and overlay popups (deck view, guest preview, card removal picker).

## Lifecycle

1. `LevelFlowManager` calls `InterludeScreen.setup(level_id, guests, deck, hero_id)`
2. InterludeScreen creates a new `ShopSystem` and calls `setup(hero_id)`
3. ShopSystem builds the card pool from ContentRegistry and generates 3 random offerings
4. InterludeScreen creates a `ShopPanel` and passes the ShopSystem to it
5. Player interacts (buy, reroll, remove card, view deck/guests)
6. Player clicks Continue, interlude emits `continue_pressed`, LevelFlowManager loads the next level
7. ShopSystem is garbage collected (RefCounted, no persistent state)

All shop state resets each interlude. Reroll cost escalation, removal usage, and slot state do not carry between visits.

## Card Pool

Built by `ShopSystem._build_pool(hero_id)`:
- Queries ContentRegistry for all stalls, spells, and relics
- Includes cards where `card.hero_id == hero_id` (hero-exclusive) or `card.hero_id == ""` (neutral)
- Pool is fixed for the duration of the visit (rerolls draw from the same pool)

## Offerings

- 3 card slots (`NUM_OFFERINGS = 3`)
- Selected via `WeightedRandom.select_multiple()` using rarity weights
- Each card gets a random `price_offset` from `PRICE_OFFSETS` array

### Rarity Weights

| Rarity    | Weight |
|-----------|--------|
| common    | 60     |
| rare      | 30     |
| epic      | 8      |
| legendary | 2      |

### Pricing

Base prices are defined in `CardDefinition.RARITY_PRICES`:

| Rarity    | Base Price |
|-----------|------------|
| common    | 3          |
| rare      | 5          |
| epic      | 8          |
| legendary | 12         |

Effective price = base + `price_offset` (from `PRICE_OFFSETS: [-2, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1]`). The distribution is heavily weighted toward 0 offset.

## Actions

### Buy Card

- Cost: card's effective price (base + offset + modifiers)
- Calls `GameManager.spend_tokens(price)`
- Card added to `GameManager.current_run.deck` with `location = DECK`
- Slot becomes null, UI shows "Sold" label
- Emits `EventBus.card_purchased(card)`

### Reroll

- Cost: `REROLL_BASE_COST * (REROLL_COST_MULTIPLIER ^ reroll_count)` = 1, 2, 4, 8...
- Only re-generates non-purchased (non-null) slots
- Excludes cards still on display from the new selection
- Reroll count resets to 0 each interlude visit
- Hidden when all slots are sold

### Remove Card

- Cost: `REMOVE_CARD_COST = 2` tokens
- Once per interlude visit (`_card_removed` flag)
- Clicking the circular button opens a RemoveCardPopup showing the full deck
- Player picks a card; it is erased from `GameManager.current_run.deck` and set to `Location.REMOVED`
- Remove button transitions to "Sold" state (same visual pattern as purchased card slots)

## UI Layout

ShopPanel builds this structure programmatically:

```
VBoxContainer (ShopPanel)
├── HBoxContainer (slots_row, centered, 24px separation)
│   ├── VBoxContainer (Slot 0)
│   │   ├── CardUI (140x200) or "Sold" Label
│   │   ├── Label (price, e.g. "3 tokens")
│   │   └── Button ("Buy")
│   ├── VBoxContainer (Slot 1)
│   │   └── [same structure]
│   ├── VBoxContainer (Slot 2)
│   │   └── [same structure]
│   └── VBoxContainer (remove_slot)
│       ├── Button (80x80, circular styling) or "Sold" Label
│       └── Label ("2 tokens")
└── CenterContainer
    └── Button ("Reroll - N tokens")
```

The remove button uses `StyleBoxFlat` with 40px corner radius for a circular appearance, with distinct colors for normal/hover/pressed/disabled states.

## Sold State Pattern

Both card slots and the remove button follow the same pattern when used:
- The interactive element (CardUI + Buy button, or circular Remove button) is freed
- Replaced with a centered "Sold" label at the same minimum size
- Price label cleared to empty string

## Token Flow

All token spending goes through `GameManager.spend_tokens(amount)`:
- Returns false if `tokens < amount` (no partial spend)
- Emits `EventBus.tokens_changed(old, new)` on success
- ShopPanel listens to `tokens_changed` to update all button affordability states

## Signals

| Signal | Source | Purpose |
|--------|--------|---------|
| `EventBus.tokens_changed` | GameManager | ShopPanel updates affordability, InterludeScreen updates token display |
| `EventBus.card_purchased` | ShopSystem | Notification that a card was bought |
| `ShopPanel.remove_card_requested` | ShopPanel | Tells InterludeScreen to open the removal popup |

## Key Files

| File | Role |
|------|------|
| `src/systems/shop_system.gd` | Shop logic (pool, offerings, purchase, reroll, removal) |
| `src/ui/components/shop_panel.gd` | Shop UI (programmatic, no tscn) |
| `src/ui/screens/interlude/interlude_screen.gd` | Interlude controller, popup management |
| `src/ui/screens/interlude/interlude_screen.tscn` | Scene layout (popups defined here) |
| `src/autoload/game_manager.gd` | Token state, persistent run deck |
| `src/autoload/level_flow_manager.gd` | Creates interlude, passes deck/hero_id |

## Constants Reference

```gdscript
NUM_OFFERINGS = 3
RARITY_WEIGHTS = { "common": 60, "rare": 30, "epic": 8, "legendary": 2 }
REROLL_BASE_COST = 1
REROLL_COST_MULTIPLIER = 2
REMOVE_CARD_COST = 2
PRICE_OFFSETS = [-2, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
```
