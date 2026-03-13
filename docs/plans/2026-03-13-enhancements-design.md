# Enhancement System Design

## Overview

Enhancements are permanent modifications to stall cards, typically with an upside and downside (e.g. +1 value but +1 restock duration). They persist across levels on the CardInstance and transfer to StallInstance at placement time.

## Data Model

### EnhancementDefinition (extends BaseDefinition)

Stays extending `BaseDefinition`. Shop-related fields (`shopable`, `hero_id`) are added directly on the class — this avoids inheriting `card_type`, `skill_data`, and `_populate_card_fields()` from `CardDefinition`, none of which apply to enhancements. Pricing reuses a shared `RARITY_PRICES` constant extracted to `BaseDefinition` (both `CardDefinition` and `EnhancementDefinition` reference it from there).

**Example: stat-only enhancement (product stalls)**
```json
{
  "id": "economical",
  "display_name_key": "enhancement_economical",
  "description": "-1 value, -1 price",
  "rarity": "common",
  "shopable": true,
  "hero_id": "",
  "applicable_to": {
    "operation_models": ["product"]
  },
  "stat_modifiers": [
    { "stat": "value", "operation": "add", "value": -1 },
    { "stat": "cost_to_guest", "operation": "add", "value": -1 }
  ],
  "added_skills": []
}
```

**Example: enhancement with added skill (any stall)**
```json
{
  "id": "healthy",
  "display_name_key": "enhancement_healthy",
  "description": "+1 price, grants status protection",
  "rarity": "rare",
  "shopable": true,
  "hero_id": "",
  "applicable_to": {
    "operation_models": []
  },
  "stat_modifiers": [
    { "stat": "cost_to_guest", "operation": "add", "value": 1 }
  ],
  "added_skills": ["healthy_shield"]
}
```
The `healthy_shield` skill would use an `on_serve` trigger to apply a status effect that blocks the next negative status granted to the served guest.

Fields:
- `shopable: bool` — whether this enhancement appears in shop offerings
- `hero_id: String` — empty string = neutral (available to all heroes)
- `stat_modifiers: Array[Dictionary]` — each dict has `stat`, `operation` (add/multiply/set/add_final), `value`
- `applicable_to: Dictionary` — only `operation_models: Array[String]` (product/service/bulk_service). Empty array = applies to all operation models. This is an explicit convention: empty means "universal", not "none".
- `added_skills: Array[String]` — skill IDs granted to the stall when the enhancement is active

```gdscript
# On BaseDefinition (shared by CardDefinition and EnhancementDefinition)
const RARITY_PRICES: Dictionary = {
    "common": 3, "rare": 4, "epic": 6, "legendary": 8,
}

# On EnhancementDefinition
func get_price() -> int:
    return RARITY_PRICES.get(rarity, 0)
```

Removed: `conflicts_with` (was scaffolded but not part of the design).

### ShopOffering (new wrapper)

The shop offerings array currently holds `Array[CardInstance]`. Since enhancements are not cards, we introduce a lightweight wrapper so the shop can hold both types without type lies:

```gdscript
class_name ShopOffering extends RefCounted

var card: CardInstance          # Non-null for stall/spell/relic offerings
var enhancement: EnhancementDefinition  # Non-null for enhancement offerings
var price_offset: int = 0

func get_price() -> int:
    if card:
        return card.get_effective_price()
    if enhancement:
        return enhancement.get_price()
    return 0

func is_enhancement() -> bool:
    return enhancement != null
```

`ShopSystem._offerings` becomes `Array[ShopOffering]` (nullable entries for empty slots). This eliminates the need to branch on `card_type` strings and avoids wrapping `EnhancementDefinition` in a fake `CardInstance`.

### CardInstance Changes

```gdscript
# Old
var enhancement = null  # EnhancementDefinition

# New
var enhancements: Array = []  # Array[EnhancementDefinition]
```

- Default limit: 1 enhancement per card. Stored as a constant `const DEFAULT_ENHANCEMENT_LIMIT: int = 1` on `CardInstance` for now. When a relic/skill needs to raise the limit, it becomes a stat in the modifier stack (`"enhancement_limit"`), with the constant as base value.
- `get_effective_price()` — no enhancement logic. Enhancements don't change a stall card's shop price.
- `get_effective_stat()` — no enhancement logic. Enhancement stat effects are applied at the `StallInstance` level on placement. Remove the existing placeholder comments.
- `get_enhancement_limit()` — returns `modifier_stack.calculate_stat("enhancement_limit", DEFAULT_ENHANCEMENT_LIMIT)`. Used by `apply_enhancement()`.
- `get_enhanced_stat_preview(stat_name: String, base_value: Variant) -> Variant` — iterates enhancements to preview what the stat would be after placement. For tooltip/display only, not part of the stat pipeline.

### StallInstance Changes

```gdscript
# Old
var enhancement = null  # EnhancementDefinition

# New
var enhancements: Array = []  # Array[EnhancementDefinition]
```

On placement (StallInstance created from CardInstance):
1. Copy `card.enhancements` to `stall.enhancements`
2. Call `_inject_enhancement_modifiers()` — for each enhancement, create `StatModifier` objects from `stat_modifiers` and inject into `stall.modifier_stack` (source = enhancement def for traceability)
3. Call `_register_enhancement_skills()` — for each enhancement's `added_skills`, create `SkillInstance` and register with TriggerSystem, appending to `skill_instances`

**Plumbing requirement:** Currently `game.gd._place_stall()` calls `BoardSystem.deploy_stall(stall_def, pos)` with only the `StallDefinition`, not the `CardInstance`. The `CardInstance` is consumed separately by `deck_system.play_card()`. To flow enhancement data from card to stall, `deploy_stall()` and `place_stall()` must accept the `CardInstance` (or at minimum an `enhancements: Array` parameter). The upgrade path (`deploy_stall` → `upgrade_and_notify`) needs the same treatment for merge support.

Enhancement-granted skills are added to the stall's `skill_instances` array. On stall removal, the existing cleanup path (unregistering all `skill_instances` from TriggerSystem) handles enhancement skills automatically — no special teardown needed. The enhancements are lost from the placed stall, but the original `CardInstance` retains its enhancements — future plays of that card will re-apply them.

## Stat Getter Prerequisite

Currently `get_capacity()` and `get_service_duration()` return raw tier data without going through `modifier_stack`. Before enhancements can modify these stats, all stall stat getters must be wired through `get_stat()`:

```gdscript
# Before (current)
func get_capacity() -> int:
    var tier_data = get_current_tier_data()
    return tier_data.capacity if tier_data else 1

# After
func get_capacity() -> int:
    var tier_data = get_current_tier_data()
    var base = tier_data.capacity if tier_data else 1
    return maxi(get_stat("capacity", base), 0)
```

This applies to: `get_capacity()`, `get_service_duration()`, and new getters for `restock_amount` and `restock_duration` (currently accessed directly from tier data, not through getter methods).

## Stat Clamping

All stall stat getters clamp to floor of 0. No exceptions.

| Stat | Floor | Notes |
|------|-------|-------|
| `value` | 0 | 0 = stall fulfills nothing (useless but allowed) |
| `cost_to_guest` | 0 | 0 = free for guests |
| `capacity` | 0 | 0 = can't seat anyone (useless but allowed) |
| `service_duration` | 0 | 0 = instant service (powerful but mechanically safe) |
| `restock_amount` | 0 | 0 = never restocks (punishing but allowed) |
| `restock_duration` | 0 | 0 = instant restock |

Clamping is applied in the getter methods (`get_value()`, `get_capacity()`, etc.), not when modifiers are added. Getters use `maxi(get_stat(...), 0)`.

## Enhancement Application

### Applying to a CardInstance (in shop)

Lives on `CardInstance` as an instance method (`card.apply_enhancement(enhancement)`). Validation logic:

```gdscript
func apply_enhancement(enhancement: EnhancementDefinition) -> bool:
    if get_card_type() != "stall":
        return false
    var stall_def := definition as StallDefinition
    var allowed_models: Array = enhancement.applicable_to.get("operation_models", [])
    if not allowed_models.is_empty() and stall_def.operation_model not in allowed_models:
        return false
    if enhancements.size() >= get_enhancement_limit():
        return false
    enhancements.append(enhancement)
    return true
```

### Upgrade Merging

When playing a stall card onto an existing stall to upgrade:
- The played card's `enhancements` array is merged into the stall's `enhancements` (simple concat)
- No conflict checks, no deduplication
- Duplicate enhancements stack (e.g. two "Extra Spicy" = +2 value, +2 restock duration)
- Stat clamping at floor 0 prevents negative values in practice
- Tooltip shows each enhancement by name — duplicates appear as separate entries (e.g. "Extra Spicy" listed twice)

This lives in `BoardSystem`'s upgrade path (where `StallInstance.upgrade()` is called). After `upgrade()` completes tier changes, the calling code:
1. Appends the played card's enhancements to `stall.enhancements`
2. Calls `stall._inject_enhancement_modifiers()` for only the new enhancements
3. Calls `stall._register_enhancement_skills()` for only the new enhancements

### Runtime Modifier Injection

`StallInstance._inject_enhancement_modifiers(enhancement_list: Array)`:
1. Each enhancement's `stat_modifiers` are converted to `StatModifier` objects:
   - `stat` maps directly
   - `operation` string maps to `StatModifier.Operation` enum
   - `source` is set to the enhancement definition (for debugging/removal via `remove_modifiers_from_source()`)
2. Modifiers are added to `stall.modifier_stack`

`StallInstance._register_enhancement_skills(enhancement_list: Array)`:
1. Each enhancement's `added_skills` are instantiated as `SkillInstance` objects
2. `SkillInstance.owner` is set to the stall
3. Registered with TriggerSystem
4. Appended to `stall.skill_instances`

Modifier application order follows existing `ModifierStack` rules: ADD -> MULTIPLY -> SET -> ADD_FINAL.

## Shop Integration

### Enhancement as Shop Offering

Enhancements appear in the non-stall offering pool (`_enhancement_pool`, separate from `_other_pool`) alongside spells and relics. They are selected by the same rarity-weighted random system. No dedicated enhancement slot — they compete for the extra slot(s).

Pricing uses the same rarity table as cards:
- common: 3 tokens
- rare: 4 tokens
- epic: 6 tokens
- legendary: 8 tokens

### Purchase Flow

When a player purchases an enhancement offering (detected via `offering.is_enhancement()`):
1. Slot is marked as "pending" (visually locked, not yet paid for)
2. Deck overlay opens (reusing the existing remove-card popup pattern)
3. Overlay shows only **eligible** stall cards: filtered by `applicable_to.operation_models` and `card.get_enhancement_limit()`
4. Player clicks a card → tokens are deducted, enhancement is applied, slot is marked purchased
5. If player cancels the picker: slot returns to unpurchased state (no tokens were spent)

**Deferred deduction pattern:** Tokens are only spent when the action completes, not when it begins. This avoids needing refund logic and is the standard for any shop action that requires a secondary selection step (e.g., future "choose a target" purchases). The slot's "pending" state prevents double-clicking or purchasing other items while the picker is open.

### Pre-Enhanced Shop Stalls

In `_generate_offerings()`, after creating each stall `CardInstance`:
1. Roll 5% chance
2. If hit, pick a random compatible `EnhancementDefinition` from the registry (matching the stall's `operation_model`)
3. Append to `card.enhancements`
4. Card displays with a visual indicator (badge/label — UI detail deferred). The enhancement and its name are visible before purchase.
5. No price increase — the enhancement is a bonus

### Pool Building

`ShopSystem._build_pool()` adds enhancements to a separate `_enhancement_pool`:
```
_enhancement_pool = []
for def in ContentRegistry.get_all_of_type("enhancements"):
    if not def.shopable:
        continue
    if def.hero_id == hero_id or def.hero_id == "":
        _enhancement_pool.append(def)
```

When selecting the "other" offering slot, roll from `_other_pool + _enhancement_pool` combined (or pick from each pool with weighted probability — implementation detail).

## Display

Enhancement info on cards is exposed via `CardInstance`:
- `enhancements` array is public — UI reads it directly for badge/icon rendering
- `get_enhanced_stat_preview(stat, base)` allows tooltips to show "effective" stats at a glance
- Enhancement `description` field provides human-readable summary text

Full visual design is deferred, but the data interface is: iterate `card.enhancements`, read `.description` and `.stat_modifiers` for display.

## Persistence

Enhancements persist across levels on `CardInstance`. When serializing deck state (save/load), each card's `enhancements` array is saved as an array of enhancement IDs (strings). On load, IDs are resolved back to `EnhancementDefinition` references via `ContentRegistry.get_definition("enhancements", id)`. This follows the same pattern as other definition references in save data.

## Implementation Scope

### Phase 1: Stat Getter Prerequisite
- Wire `get_capacity()`, `get_service_duration()` through `get_stat()` + modifier_stack
- Add `get_restock_amount()` and `get_restock_duration()` getters that go through `get_stat()`
- Add `maxi(..., 0)` clamping to all six stat getters
- Update **runtime** call sites that read tier data directly to use the new getters:
  - `stall_instance.gd`: `tier_data.restock_duration` and `tier_data.restock_amount` in `restock()`, `start_restock_cooldown()`, `reset_stock()`
  - `bonus_restock_effect.gd`: `tier_data.restock_amount`
  - `restock_all_product_stalls_effect.gd`: `tier_data.restock_amount`
  - `debug_info_panel.gd`: `tier_data.restock_amount`
- **Do not change** definition-level display sites (e.g. `card_display.gd` showing unplaced card tier data) — these correctly read raw tier data since no modifiers apply to unplaced cards

### Phase 2: Core Data Model
- Extract `RARITY_PRICES` to `BaseDefinition` (shared by `CardDefinition` and `EnhancementDefinition`)
- Remove `conflicts_with` from `EnhancementDefinition`
- Add `shopable`, `hero_id`, `get_price()` to `EnhancementDefinition` (stays extending `BaseDefinition`)
- Update `from_dict()` to parse `shopable` and `hero_id`
- Change `CardInstance.enhancement` to `enhancements: Array`
- Add `DEFAULT_ENHANCEMENT_LIMIT` constant and `get_enhancement_limit()` on `CardInstance`
- Add `get_enhanced_stat_preview()` on `CardInstance`
- Remove enhancement placeholder comments from `get_effective_price()` / `get_effective_stat()`
- Change `StallInstance.enhancement` to `enhancements: Array`
- Add `_inject_enhancement_modifiers()` and `_register_enhancement_skills()` on `StallInstance`
- **Modify `BoardSystem.deploy_stall()` / `place_stall()` to accept `CardInstance`** (or enhancements array) so enhancement data flows from card to stall at placement time
- Wire enhancement injection into stall creation path
- Verify stall removal path unregisters enhancement skills (should work automatically via `skill_instances`)
- Add enhancement serialization: save as ID array on `CardInstance`, resolve on load via `ContentRegistry`
- Create sample enhancement JSON files

### Phase 3: Upgrade Merging
- In `BoardSystem`'s upgrade path (using the `CardInstance` now available from Phase 2 plumbing), after `StallInstance.upgrade()`:
  - Merge played card's enhancements into stall's enhancements array
  - Call `_inject_enhancement_modifiers()` for new enhancements
  - Call `_register_enhancement_skills()` for new enhancements

### Phase 4: Shop Integration
- Create `ShopOffering` wrapper class
- Refactor `ShopSystem._offerings` from `Array[CardInstance]` to `Array[ShopOffering]`
- Update all shop UI and logic to work with `ShopOffering` (get price, display, purchase)
- Build `_enhancement_pool` in `_build_pool()`
- Add enhancement purchase flow with deferred deduction: slot → "pending" state → deck picker → apply + deduct on confirm, or cancel with no cost
- Add enhancement deck picker popup (reuse remove-card overlay pattern, with eligibility filter)
- Add 5% pre-enhanced stall roll in `_generate_offerings()` (enhancement visible before purchase)
