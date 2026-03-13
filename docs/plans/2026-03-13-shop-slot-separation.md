# Shop Slot Separation

Split the shop into stall-only main slots and a separate "extras" slot for spells, relics, and future card types.

## Current Behavior

- 3 shop slots drawn from a single combined pool (stalls + spells + relics)
- `_select_with_stall_guarantee()` ensures at least 2 of the 3 are stalls
- Reroll refreshes all 3 slots

## New Behavior

- **3 main slots**: stalls only
- **1 extra slot**: non-stall cards only (spells, relics, enhancements later)
- Reroll refreshes all 4 slots together (same escalating cost)
- Extra slot hidden if no non-stall cards exist in the pool
- Extra slot uses same visual style as main slots, separated by a wider gap

## Changes

### 1. `shop_system.gd` — Pool splitting and offering generation

- Split `_pool` into `_stall_pool: Array[CardDefinition]` and `_other_pool: Array[CardDefinition]` in `_build_pool()`
  - Stalls: `card.card_type == "stall"`
  - Other: everything else (`spell`, `relic`, etc.)
- Replace `_select_with_stall_guarantee()` with straightforward logic:
  - Pick 3 from `_stall_pool` via weighted rarity (same weights: common 60, rare 30, epic 8, legendary 2)
  - Pick 1 from `_other_pool` via weighted rarity (same weights)
  - If `_other_pool` is empty, `_offerings` has only 3 entries
- `_offerings` array holds all 4 (or 3) entries — no structural change to how slots are indexed
- `purchase_card()`, `reroll()` work unchanged since they operate on indices
- Remove `_select_with_stall_guarantee()` (no longer needed)

### 2. `shop_panel.gd` — Layout with extra slot

- After building the 3 main slots, add the 4th slot to `slots_row`
- Use 48px left margin (or spacer) before the 4th slot to visually separate it from the stall group
- `_refresh()` iterates over all offerings (3 or 4) — already index-based, just needs to handle variable count
- Hide the 4th slot container if `shop_system.get_offerings().size() <= 3`

### 3. No changes needed

- `shop_slot.gd` / `shop_slot.tscn` — already generic, works with any card type
- `card_display.gd` — already renders all card types
- `interlude_screen.gd` — delegates to ShopPanel, no direct slot knowledge
