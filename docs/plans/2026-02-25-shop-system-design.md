# Shop System Design

## Overview

A between-levels shop where players spend tokens to buy cards for their deck. The shop is the main UI on the interlude screen, with 3 cards for sale based on rarity weights. Players can reroll at escalating cost. The shop refreshes every time the player enters the interlude (including before the first level).

## Core Mechanics

### Offerings
- 3 cards displayed per shop visit
- Each slot rolls rarity independently using weighted random
- Cards drawn from hero-specific pool (filtered by `hero_id` from ContentRegistry)
- No duplicate cards across the 3 slots
- If no cards match a rolled rarity, fall down to next lower rarity
- If the pool is fully exhausted, remaining slots stay empty

### Purchasing
- Card prices use existing `RARITY_PRICES` on `CardDefinition`: common 30, rare 50, epic 80, legendary 120
- Purchased card is added to persistent run deck immediately (`CardInstance.location = DECK`)
- Purchased slot becomes empty (not replaced)
- No confirmation dialog — purchases are instant

### Reroll
- Replaces only remaining (non-purchased) cards with new rolls
- Escalating cost: `REROLL_BASE_COST * (REROLL_COST_MULTIPLIER ^ reroll_count)`
- Base cost: 5 tokens, multiplier: 2 (so 5 → 10 → 20 → 40...)
- Reroll count resets each shop visit

### Future: Enhancements
- `enhancement_chance` can be layered on later — CardInstance and pricing already support it

### Future: Neutral Cards
- Cards with `hero_id = ""` (neutral) could appear in every hero's shop
- Not implemented in v1 — only hero-specific cards

## Data Model

### Global Constants (on ShopSystem)

```gdscript
const RARITY_WEIGHTS: Dictionary = {
    "common": 60,
    "rare": 30,
    "epic": 8,
    "legendary": 2,
}
const REROLL_BASE_COST: int = 5
const REROLL_COST_MULTIPLIER: int = 2
const NUM_OFFERINGS: int = 3
```

### No Pool JSON — Dynamic Pool from ContentRegistry

Instead of maintaining separate pool JSON files per hero, the shop pool is built dynamically by querying ContentRegistry for all cards matching the current hero's `hero_id`. This eliminates:
- `data/shop_pools/` directory and JSON files
- `ShopPoolDefinition` class
- Manual curation overhead when adding new cards

The pool is built at shop setup time:
```gdscript
func _build_pool(hero_id: String) -> Array[CardDefinition]:
    var pool: Array[CardDefinition] = []
    for type in ["stalls", "spells", "relics"]:
        for def in ContentRegistry.get_all_of_type(type):
            if def.hero_id == hero_id:
                pool.append(def)
    return pool
```

### ContentRegistry Helper

Add `get_card_definition(card_id: String) -> CardDefinition` to centralize the stalls/spells/relics lookup pattern used in GameManager and ShopSystem:

```gdscript
func get_card_definition(card_id: String) -> CardDefinition:
    for type in ["stalls", "spells", "relics"]:
        var def = get_definition(type, card_id)
        if def:
            return def
    return null
```

### Card Selection Algorithm

1. For each empty slot, roll a rarity using `RARITY_WEIGHTS` (weighted random)
2. Filter pool to cards matching the rolled rarity
3. Pick one at random from the filtered set, excluding already-selected cards
4. If no cards match the rolled rarity, fall down to next lower rarity (epic → rare → common)
5. If no cards available at any rarity, slot stays empty (pool exhausted)
6. Create a `CardInstance` for each with `location = SHOP`

## Architecture

### New/Changed Files

- `src/systems/shop_system.gd` — Core logic (RefCounted, ephemeral per shop visit)
- `src/ui/components/shop_panel.gd` + `.tscn` — UI component for interlude screen
- Updated `src/autoload/content_registry.gd` — Add `get_card_definition()` helper
- Delete `src/definitions/shop_pool_definition.gd` — No longer needed
- Delete `data/shop_pools/` — No longer needed

### ShopSystem (RefCounted)

ShopSystem is a RefCounted object, not a Node. It has no visual component (that's ShopPanel's job) and its state is fully ephemeral — created when the interlude screen opens, garbage collected when it closes. This matches its lifecycle cleanly: no scene tree presence needed, no persistent state between visits.

```gdscript
class_name ShopSystem
extends RefCounted

func setup(hero_id: String) -> void
    # Builds pool from ContentRegistry, resets reroll count, generates offerings

func get_offerings() -> Array  # Array of CardInstance (nulls for purchased/empty slots)
    # Returns current offerings

func purchase_card(slot_index: int) -> bool
    # Checks affordability, spends tokens via GameManager, adds to run deck
    # Returns false if can't afford or slot empty

func reroll() -> bool
    # Charges escalating cost, regenerates non-purchased slots
    # Returns false if can't afford

func get_reroll_cost() -> int
    # REROLL_BASE_COST * (REROLL_COST_MULTIPLIER ^ _reroll_count)

func can_afford_reroll() -> bool
func can_afford_card(slot_index: int) -> bool
```

### State (per shop visit)

- `_hero_id: String` — current hero
- `_pool: Array[CardDefinition]` — all eligible cards for this hero
- `_reroll_count: int` — resets to 0 each visit
- `_offerings: Array` — CardInstance per slot (null = purchased/empty)

### ShopSystem accesses GameManager directly

ShopSystem reads `GameManager.tokens` and calls `GameManager.spend_tokens()` / `GameManager.current_run.deck` directly. GameManager is an autoload — this is the standard pattern for systems that need token/deck access.

## UI Layout

The interlude screen reorganizes to make the shop the main focus:

```
┌─────────────────────────────────────┐
│  Level 2          💰 85 tokens      │
├─────────────────────────────────────┤
│                                     │
│   [Card 1]    [Card 2]    [Card 3]  │
│    30 💰       50 💰       80 💰    │
│   [Buy]       [Buy]       [Buy]     │
│                                     │
│          [Reroll - 5 💰]            │
│                                     │
├─────────────────────────────────────┤
│  [View Guests]  [View Deck]         │
│                                     │
│            [Continue]               │
└─────────────────────────────────────┘
```

### UI Behavior

- **Card slots**: Show card using existing `CardUI` component, price below, buy button
- **Buy button**: Disabled when player can't afford. On purchase: card disappears, slot shows "Sold"
- **Reroll button**: Shows current cost. Disabled when can't afford. After reroll: remaining cards replaced, cost updates
- **Token balance**: Updates reactively via `tokens_changed` signal. Buy/reroll buttons re-evaluate affordability on change
- **View Guests**: Opens guest preview as overlay (moved from being inline on interlude)
- **View Deck**: Existing overlay, unchanged
- **Continue**: Proceeds to level with updated deck

## Integration Points

### Interlude Screen (owns ShopSystem lifecycle)
- Creates `ShopSystem.new()` in `setup()`
- Calls `shop_system.setup(hero_id)` to build pool and generate offerings
- Passes `shop_system` to ShopPanel
- When interlude is freed, ShopSystem is garbage collected

### ShopPanel
- Receives ShopSystem reference
- Calls `purchase_card()` / `reroll()` on user interaction
- Listens to `GameManager.tokens_changed` to update affordability state

### EventBus (new signals)
- `card_purchased(card: CardInstance)` — for UI reactions, future analytics

### GameManager
- Uses existing `spend_tokens()` / `tokens` for all transactions
- Uses existing `current_run.deck` for adding purchased cards

## Cleanup

- Delete `src/definitions/shop_pool_definition.gd`
- Delete `data/shop_pools/` directory and any JSON files
- Remove `shop_pools` dictionary from ContentRegistry
- Remove shop pool loading logic from ContentRegistry
