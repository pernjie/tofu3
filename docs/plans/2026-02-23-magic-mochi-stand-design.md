# Magic Mochi Stand

## Overview

A rare product stall that starts humble but grows permanently across levels. Each time it restocks after midnight, it gains +1 value for the rest of the run. Slow restock and single stock make it a long-term investment — it rewards players who build around it across multiple levels.

## Stall Definition

- **Type**: Product stall, food need
- **Rarity**: Rare
- **Stock**: 1 (all tiers)
- **Restock duration**: 5 → 4 → 3 turns (tier 1/2/3)
- **Base value**: 1
- **Cost to guest**: 1

## Persistent Data System

### Problem

Stalls are ephemeral — destroyed on level clear, re-placed from cards each level. Cross-level persistence currently only exists for relics (via `RunState.relics_on_board`). We need a generic mechanism for any system to store run-scoped persistent data.

### Solution

Add a generic `persistent_data: Dictionary` field to `RunState`. Any skill effect can read/write to it directly. No instance hydration needed — effects go straight to RunState.

```
RunState.persistent_data = {
  "magic_mochi_stand": { "bonus_value": 3 },
  # future: hero progression, other stalls, etc.
}
```

**No changes to `SkillInstance.get_parameter()`** — effects that need persistent data read from RunState explicitly, opting in rather than giving every skill implicit access to global state.

## Skills

### `mochi_stand_bonus_value`

Reads accumulated bonus from persistent data and adds it as fulfillment bonus during pre-serve interception.

```json
{
  "id": "mochi_stand_bonus_value",
  "owner_types": ["stall"],
  "trigger_type": "on_pre_serve",
  "effects": [
    {
      "type": "apply_persistent_bonus",
      "store_id": "magic_mochi_stand",
      "key": "bonus_value"
    }
  ]
}
```

### `mochi_stand_permanent_growth`

On restock after midnight, permanently increments bonus value by 1.

```json
{
  "id": "mochi_stand_permanent_growth",
  "owner_types": ["stall"],
  "trigger_type": "on_restock",
  "conditions": [{ "type": "after_midnight" }],
  "effects": [
    {
      "type": "modify_persistent_state",
      "store_id": "magic_mochi_stand",
      "key": "bonus_value",
      "amount": 1
    }
  ]
}
```

## New Components

### 1. `RunState.persistent_data` field

In `game_manager.gd`, add to `RunState`:

```gdscript
var persistent_data: Dictionary = {}
```

### 2. `ModifyPersistentStateEffect`

Generic, reusable effect for any system that needs to write run-scoped persistent data.

**Parameters:**
- `store_id` (string) — top-level key in `persistent_data`. Defaults to owner's definition ID.
- `key` (string) — field to modify within the store.
- `amount` (int, default 1) — value to add.

**Logic:**
1. Read current value from `RunState.persistent_data[store_id][key]` (default 0)
2. Add `amount`
3. Write back

### 3. `ApplyPersistentBonusEffect`

Reads a value from persistent data and applies it as fulfillment bonus during pre-serve. Must be used with `on_pre_serve` trigger.

**Parameters:**
- `store_id` (string) — top-level key. Defaults to owner's definition ID.
- `key` (string) — field to read.

**Logic:**
1. Read value from `RunState.persistent_data[store_id][key]` (default 0)
2. If > 0, add to `context.service_result["fulfillment_bonus"]`

### 4. `AfterMidnightCondition`

Checks whether midnight has been reached in the current level.

**Logic:**
- Return `TurnSystem._midnight_emitted` via a new public getter `TurnSystem.is_after_midnight() -> bool`

**Requires:** Add `func is_after_midnight() -> bool: return _midnight_emitted` to TurnSystem.

## Stall JSON

```json
{
  "$schema": "./_schema.json",
  "id": "magic_mochi_stand",
  "display_name_key": "STALL_MAGIC_MOCHI_STAND_NAME",
  "description_key": "STALL_MAGIC_MOCHI_STAND_DESC",
  "rarity": "rare",
  "card_type": "stall",
  "hero_id": "",
  "operation_model": "product",
  "need_type": "food",
  "tiers": [
    {
      "tier": 1,
      "cost_to_guest": 1,
      "value": 1,
      "restock_amount": 1,
      "restock_duration": 5,
      "skills": [
        { "skill_id": "mochi_stand_bonus_value" },
        { "skill_id": "mochi_stand_permanent_growth" }
      ]
    },
    {
      "tier": 2,
      "cost_to_guest": 1,
      "value": 1,
      "restock_amount": 1,
      "restock_duration": 4,
      "skills": [
        { "skill_id": "mochi_stand_bonus_value" },
        { "skill_id": "mochi_stand_permanent_growth" }
      ]
    },
    {
      "tier": 3,
      "cost_to_guest": 1,
      "value": 1,
      "restock_amount": 1,
      "restock_duration": 3,
      "skills": [
        { "skill_id": "mochi_stand_bonus_value" },
        { "skill_id": "mochi_stand_permanent_growth" }
      ]
    }
  ],
  "placement_restriction": null,
  "tags": []
}
```

## Design Notes

**Multiple mochi stands share state.** If a player places two, both read/write the same `persistent_data["magic_mochi_stand"]["bonus_value"]`. Each restock from either stand increments the shared bonus, and both apply it. This is intentional — duplicates are a meaningful synergy for a rare stall.

## Implementation Order

1. Add `persistent_data` field to `RunState`
2. Add `is_after_midnight() -> bool` getter to TurnSystem
3. `AfterMidnightCondition` — check midnight via `TurnSystem.is_after_midnight()`
4. `ModifyPersistentStateEffect` — generic write to persistent data
5. `ApplyPersistentBonusEffect` — generic read from persistent data, apply to `service_result["fulfillment_bonus"]`
6. Register new effect and condition in factories
7. Skill JSONs (`mochi_stand_bonus_value`, `mochi_stand_permanent_growth`)
8. Stall JSON (`magic_mochi_stand.json`)
9. Tests
