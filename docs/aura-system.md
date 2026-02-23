# Aura System

This document explains how the aura system works, how it integrates with status effects and the board, and how to author new aura skills.

## Architecture Overview

```
SkillDefinition (JSON, trigger_type: "aura")
        |
        v
AuraSystem (spatial proximity engine)
        |
        v
StatusEffectSystem (applies/removes statuses on targets)
        |
        v
BoardVisual (draws aura range tiles on the board)
```

Auras are proximity-based status effect applicators. An entity with an aura skill continuously applies a status effect to all valid targets within Manhattan distance. When targets move in or out of range, statuses are automatically applied or revoked.

AuraSystem is a non-autoload node, created as a child of the game scene alongside StatusEffectSystem.

### Key Files

| File | Purpose |
|------|---------|
| `src/systems/aura_system.gd` | Core engine: registration, recalculation, tile caching |
| `src/ui/board_visual.gd` | Renders aura range tiles (passive + selected overlays) |
| `src/game/game.gd` | Wires AuraSystem to BoardVisual, handles click-to-inspect |
| `data/skills/*.json` | Aura skill definitions (`trigger_type: "aura"`) |
| `data/status_effects/*.json` | Status effects applied by auras |

## How It Works

### Aura Skill Parameters

Aura skills use `trigger_type: "aura"` and are configured entirely through parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `range` | int | 1 | Manhattan distance from source |
| `target_type` | String | `"stall"` | `"stall"`, `"guest"`, or `"all"` |
| `status_effect_id` | String | *(required)* | Status effect to apply to targets |
| `exclude_self` | bool | `true` | Whether the source is excluded from its own aura |

Aura skills have no `conditions` or `effects` arrays — the AuraSystem handles all logic internally. They are skipped by TriggerSystem (not event-driven).

### Registration

When an entity enters the board, AuraSystem checks its skills for `trigger_type == "aura"` and registers each one. Registration happens automatically via EventBus signals:

- `stall_placed` / `stall_upgraded` — stall auras
- `guest_spawned` — guest auras
- `relic_placed` — relic auras

Each registered aura creates a record tracking source, skill, and current targets.

### Recalculation

Recalculation diffs current targets against entities now in range:

1. Find all valid targets within Manhattan `range` of the source
2. **Lost targets** (were in range, now aren't): revoke the status effect
3. **New targets** (weren't in range, now are): apply the status effect
4. **Blocked targets** (application failed, e.g. immunity): not tracked, retried on next recalc

Recalculation is triggered by board state changes:
- Entity placed, moved, or removed
- Stall upgraded (skills may change)

### Aura Statuses

Aura-applied statuses should use `stack_type: "passive"` — they persist until explicitly revoked by the AuraSystem when the target leaves range or the source is removed. They should not decay on their own.

Aura status effect definitions **must include `"aura"` in their `tags` array**. This allows cleanse effects (e.g., `remove_status` with `exclude_tags: ["aura"]`) to skip aura-applied statuses — removing them would be pointless since the aura reapplies them when the target re-enters range.

### Level Lifecycle

- `BoardSystem.clear_level()` calls `aura_system.clear_all()`, which revokes all applied statuses and clears tracking
- Relics persist across levels — their auras are re-registered when relics are restored in the new level via `relic_placed`

## UI: Board Range Overlay

### Passive Overlay

All tiles affected by any active aura are drawn with a light purple overlay. This is always visible and updates automatically when auras change (via the `aura_tiles_changed` signal).

### Selected Overlay

Clicking a stall that has an active aura (when no card is selected) highlights that stall's aura range with a more prominent purple overlay. Clicking again or clicking elsewhere deselects. Selecting a card from hand clears the aura selection.

### Colors

| Layer | Fill | Border |
|-------|------|--------|
| Passive | `Color(0.4, 0.2, 0.6, 0.15)` | `Color(0.5, 0.3, 0.7, 0.3)` |
| Selected | `Color(0.4, 0.2, 0.6, 0.4)` | `Color(0.6, 0.3, 0.8, 0.7)` |

Overlapping tiles are drawn at the highest intensity (selected wins over passive).

### Tile Caching

AuraSystem maintains a cached `_all_aura_tiles` dictionary (Vector2i -> bool) rebuilt on every mutation. BoardVisual connects to the `aura_tiles_changed` signal to `queue_redraw()`. This avoids per-frame recalculation.

## Authoring an Aura Skill

### 1. Create the status effect

Create `data/status_effects/<id>.json` with `stack_type: "passive"`:

```json
{
  "$schema": "./_schema.json",
  "id": "stinky_debuff",
  "display_name_key": "STATUS_STINKY_DEBUFF_NAME",
  "description_key": "STATUS_STINKY_DEBUFF_DESC",
  "icon_path": "",
  "is_buff": false,
  "stack_type": "passive",
  "max_stacks": 1,
  "applicable_to": ["stall"],
  "stat_modifiers": [
    { "stat": "value", "operation": "add", "value_per_stack": -1 }
  ],
  "on_turn_end_effects": [],
  "granted_skills": [],
  "tags": ["debuff", "aura"]
}
```

### 2. Create the aura skill

Create `data/skills/<id>.json` with `trigger_type: "aura"`:

```json
{
  "$schema": "./_schema.json",
  "id": "stinky_aura",
  "display_name_key": "SKILL_STINKY_AURA",
  "description_key": "SKILL_STINKY_AURA_DESC",
  "trigger_type": "aura",
  "owner_types": ["stall"],
  "global": false,
  "parameters": {
    "range": { "type": "int", "default": 1 },
    "target_type": { "type": "string", "default": "stall" },
    "status_effect_id": { "type": "string", "default": "stinky_debuff" },
    "exclude_self": { "type": "bool", "default": true }
  },
  "conditions": [],
  "effects": []
}
```

### 3. Assign to an entity

Add the skill to a stall/guest/relic's `skill_data`:

```json
"skill_data": [
  { "skill_id": "stinky_aura" }
]
```

Parameter overrides work as usual:

```json
"skill_data": [
  { "skill_id": "stinky_aura", "parameters": { "range": 2 } }
]
```

## Entity Sources

| Entity Type | As Source | As Target |
|-------------|----------|-----------|
| Stall | Yes | Yes |
| Guest | Yes | Yes |
| Relic | Yes | No (only stalls/guests are queried as targets) |

## Animation Timing

Aura recalculation queues status text animations (applied/removed) via `AnimationCoordinator.queue()`, but the AuraSystem itself never calls `play_batch()`. The caller that triggered the board state change is responsible for flushing the batch.

| Trigger | Where batch is flushed |
|---------|----------------------|
| Stall/relic placed (player action) | `game.gd` — `_place_stall()` / `_place_relic()` await `play_batch()` after placement |
| Guest spawned | `turn_system.gd` — `_flush_and_sweep()` after `guest_spawned` emit |
| Guest moved | `turn_system.gd` — `_flush_and_sweep()` after `guest_moved` emit |
| Entity removed | `turn_system.gd` — sweep loop already playing batches |
| Stall upgraded | `game.gd` — `_place_stall()` (upgrade goes through `deploy_stall`) |

When adding new code paths that change board state and could trigger aura recalculation, ensure an `await AnimationCoordinator.play_batch()` follows the event emission. Without it, aura status text animations will be orphaned in the queue and appear attached to the next unrelated action.

## Relationship to Status Effect System

The aura system builds on top of the status effect system — it does not replace it. Auras are a *delivery mechanism* for status effects. The status effect itself (stat modifiers, granted skills, visual tint) is defined and managed by StatusEffectSystem as usual. The AuraSystem only controls *when* statuses are applied and revoked based on spatial proximity.

See [Status Effect System](status-effect-system.md) for how to author status effects.
