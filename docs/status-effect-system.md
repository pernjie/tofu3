# Status Effect System

This document explains how status effects work, how they integrate with the skill and service systems, and how to author new status effects.

## Architecture Overview

```
StatusEffectDefinition (JSON)     SkillDefinition (JSON)
        |                                |
        v                                v
StatusEffectInstance              SkillInstance (granted)
        |                                |
        v                                v
StatusEffectSystem               TriggerSystem
(lifecycle: apply, tick, remove)  (fires skills on events)
```

Status effects are buffs or debuffs applied to entities (guests, stalls). They can modify stats via `stat_modifiers`, and they can grant temporary skills to their target via `granted_skills`. The `StatusEffectSystem` manages the full lifecycle.

### Key Files

| File | Purpose |
|------|---------|
| `src/systems/status_effect_system.gd` | Lifecycle manager (apply, tick, remove, cleanup) |
| `src/instances/status_effect_instance.gd` | Runtime state (stacks, modifiers, granted skills) |
| `src/definitions/status_effect_definition.gd` | Parses JSON into typed definition |
| `data/status_effects/_schema.json` | JSON schema for validation |
| `data/status_effects/*.json` | Status effect data files |

## How It Works

### Applying a Status Effect

All application goes through `StatusEffectSystem.apply_status()`:

```gdscript
# From any system or skill effect:
var ses = Engine.get_main_loop().root.find_child("StatusEffectSystem", true, false)
ses.apply_status(target_guest, "charmed", 3)  # Apply 3 stacks
```

Or from JSON via the `apply_status` skill effect:

```json
{
  "type": "apply_status",
  "target": "guest",
  "status_id": "charmed",
  "stacks": 1
}
```

When applied:
1. Definition is loaded from `ContentRegistry`
2. Applicability is validated (`applicable_to` check)
3. If target already has this status, stacks are added (up to `max_stacks`)
4. If new: instance is created, stat modifiers are applied, granted skills are created and registered with `TriggerSystem`
5. `EventBus.status_applied` is emitted

### Stacking

Re-applying the same status effect adds stacks rather than creating a duplicate. Stacks are clamped to `max_stacks`. Stat modifiers are recalculated based on current stack count.

```
Guest has Charmed (2 stacks)
  -> apply_status("charmed", 3)
  -> stacks = min(2 + 3, max_stacks) = 5
  -> stat modifiers recalculated for 5 stacks
```

### Turn Ticking

`StatusEffectSystem` listens to `EventBus.turn_ended`. Each turn:

1. Collects all entities with active status effects
2. For each effect with `stack_type == "time"`:
   - Processes `on_turn_end_effects` (e.g., `remove_stacks`)
   - If stacks reach 0, marks for removal
3. Removes expired effects in a second pass (safe iteration)

### Removal

When an effect is removed (expired or explicitly):
1. Stat modifiers are removed from the target's `ModifierStack`
2. Granted skills are unregistered from `TriggerSystem` and removed from the target
3. `EventBus.status_removed` is emitted

### Guest Exit Cleanup

`StatusEffectSystem` listens to `guest_ascended` and `guest_descended`. When a guest leaves the board, all their status effects are properly removed, ensuring no stale skill references remain in `TriggerSystem`.

## Granted Skills

Status effects can grant temporary skills to their target. This is how effects like Charmed implement complex behavior through the existing skill pipeline rather than hardcoded logic.

```json
{
  "id": "charmed",
  "granted_skills": [
    {
      "skill_id": "charmed_block_service",
      "parameters": { "chance": 0.25 }
    }
  ]
}
```

When Charmed is applied, a `SkillInstance` for `charmed_block_service` is created on the guest. When Charmed is removed, that skill instance is destroyed.

### Parameter Overrides

Granted skills can override their definition's default parameters. These overrides are stored on `SkillInstance.parameter_overrides` (never mutating the shared `SkillDefinition`). The `get_parameter()` method checks overrides first, then falls back to definition defaults.

## Service Interception

Status effects can intercept service via the `on_pre_serve` trigger. This is distinct from the post-service `on_serve` trigger fired by EventBus.

```
Service resolution flow:
  1. TurnSystem calls _check_service_blocked(guest, stall)
  2. Creates TriggerContext with trigger_type "on_pre_serve"
  3. Initializes service_result: {blocked: false, fulfillment_multiplier: 1.0, fulfillment_bonus: 0}
  4. TriggerSystem fires all "on_pre_serve" skills
  5. Effects can modify service_result (set blocked=true, adjust multiplier, etc.)
  6. If blocked: guest gets nothing, no guest_served event emitted
  7. If not blocked: service proceeds normally, guest_served emitted
```

The `on_pre_serve` / `on_serve` distinction prevents double-triggering: interception skills fire before service, notification skills fire after.

## Fulfillment Interception

Status effects can also intercept **all** need fulfillment (not just stall service) via the `on_pre_fulfill` trigger. This fires inside `BoardSystem.fulfill_guest_need()` — the single funnel for all fulfillment regardless of source.

```
Fulfillment interception flow:
  1. BoardSystem.fulfill_guest_need() called (from stall service, spells, skills, etc.)
  2. Creates TriggerContext with trigger_type "on_pre_fulfill"
  3. Initializes fulfillment_result: {blocked: false, fulfillment_multiplier: 1.0, fulfillment_bonus: 0}
  4. TriggerSystem fires all "on_pre_fulfill" skills on the guest (+ source if provided)
  5. Effects can modify fulfillment_result (set blocked=true, adjust multiplier/bonus)
  6. If blocked: fulfillment returns 0
  7. If not blocked: amount is modified by multiplier and bonus, then fulfilled
```

For stall service, `on_pre_serve` and `on_pre_fulfill` compose: pre-serve modifiers produce a `final_value`, which is then passed to `fulfill_guest_need()` where pre-fulfill triggers further modify it.

## Authoring a New Status Effect

### 1. Create the JSON definition

Create `data/status_effects/<id>.json`:

```json
{
  "$schema": "./_schema.json",
  "id": "my_effect",
  "display_name_key": "STATUS_MY_EFFECT_NAME",
  "description_key": "STATUS_MY_EFFECT_DESC",
  "icon_path": "res://assets/sprites/effects/my_effect.png",

  "effect_type": "buff",
  "stack_type": "time",
  "max_stacks": 5,
  "initial_stacks": 1,

  "applicable_to": ["guest"],

  "stat_modifiers": [],
  "granted_skills": [],
  "on_apply_effects": [],
  "on_turn_end_effects": [
    { "type": "remove_stacks", "amount": 1 }
  ],
  "on_remove_effects": [],

  "visual": {
    "tint_color": "#FFFFFF"
  },

  "tags": []
}
```

### 2. Choose the mechanism

**Simple stat modification** (no granted skill needed):

```json
"stat_modifiers": [
  { "stat": "movement_speed", "operation": "add", "value_per_stack": 1 }
]
```

**Complex behavior** (grant a skill):

```json
"granted_skills": [
  { "skill_id": "my_custom_skill", "parameters": { "amount": 5 } }
]
```

Then create the skill definition in `data/skills/` and the effect class in `src/skill_effects/` (register in `SkillEffectFactory`).

### 3. Stack types

| Type | Behavior |
|------|----------|
| `time` | Stacks decrease by `on_turn_end_effects` each turn. Removed at 0. |
| `trigger` | Stacks consumed by specific events (not yet implemented). |
| `passive` | Permanent until explicitly removed. Used by aura-applied statuses (see [Aura System](aura-system.md)). |

## Example: Charmed

Charmed is a debuff that gives a 25% chance to waste a guest's stall visit.

**Data flow:**
```
charmed.json (status effect)
  -> granted_skills: ["charmed_block_service"]

charmed_block_service.json (skill)
  -> trigger_type: "on_pre_serve"
  -> effects: [{ type: "chance_block_service", chance: "{chance}" }]

ChanceBlockServiceEffect (GDScript)
  -> rolls randf() < 0.25
  -> sets context.service_result["blocked"] = true
```

**Lifecycle:**
1. Some skill applies Charmed to a guest (e.g., fox spirit encounter)
2. `StatusEffectSystem.apply_status()` creates the instance and grants `charmed_block_service` skill
3. Guest enters a stall, TurnSystem calls `_check_service_blocked()`
4. `on_pre_serve` fires, `ChanceBlockServiceEffect` rolls 25%
5. If blocked: guest wastes the visit. If not: normal service.
6. Each turn end: stacks decrement by 1
7. At 0 stacks: Charmed removed, `charmed_block_service` skill unregistered

## Example: Tingling

Tingling is a debuff that reduces all food fulfillment by 1 for the affected guest.

**Data flow:**
```
tingling.json (status effect)
  -> granted_skills: ["tingling_reduce_food"]

tingling_reduce_food.json (skill)
  -> trigger_type: "on_pre_fulfill"
  -> conditions: [{ type: "need_type_check", need_type: "food" }]
  -> effects: [{ type: "modify_fulfillment", bonus: "{bonus}" }]  (bonus defaults to -1)

ModifyFulfillmentEffect (GDScript)
  -> writes bonus to context.fulfillment_result["fulfillment_bonus"]
```

**Lifecycle:**
1. Spicy Skewer Stand serves a guest, `on_serve` fires `spicy_skewer_apply_tingling`
2. `ApplyStatusEffect` applies Tingling to the guest, granting `tingling_reduce_food` skill
3. Guest visits another food stall, `fulfill_guest_need()` fires `on_pre_fulfill`
4. `need_type_check` condition passes (need_type == "food"), `modify_fulfillment` applies -1 bonus
5. Guest receives 1 less food fulfillment from the service
6. Each turn end: stacks decrement by 1
7. At 0 stacks: Tingling removed, `tingling_reduce_food` skill unregistered

**Key difference from Charmed:** Charmed uses `on_pre_serve` (stall-service-specific interception). Tingling uses `on_pre_fulfill` (universal fulfillment interception) — it affects food from any source, not just stalls.
