# Guide: Creating New Guests

## Overview

Guests are supernatural visitors who walk paths across the board, stopping at stalls to fulfill needs. Each guest is defined by a JSON file and optionally references skills that give it unique behavior.

**Data flow:** `data/guests/<id>.json` -> `ContentRegistry` loads it -> `GuestDefinition` (immutable) -> `GuestInstance` (mutable runtime state)

You never touch GDScript to add a basic guest. New guests are pure data. You only write code when the guest needs behavior that can't be expressed with existing skill building blocks.

## Guest JSON Anatomy

Create `data/guests/<id>.json`:

```json
{
  "$schema": "./_schema.json",
  "id": "my_guest",
  "display_name_key": "GUEST_MY_GUEST_NAME",
  "description_key": "GUEST_MY_GUEST_DESC",
  "rarity": "common",

  "is_core_guest": true,

  "base_stats": {
    "needs": { "food": 3, "joy": 1 },
    "money": 10,
    "movement_speed": 1
  },

  "skills": [
    { "skill_id": "some_existing_skill" }
  ],

  "tags": ["spirit"]
}
```

### Fields

| Field | Required | Notes |
|-------|----------|-------|
| `id` | Yes | Unique identifier, matches filename |
| `display_name_key` | Yes | Localization key. Convention: `GUEST_<ID>_NAME` |
| `description_key` | No | Convention: `GUEST_<ID>_DESC` |
| `rarity` | No | `common`, `rare`, `epic`, `legendary`. Defaults to `common` |
| `icon_path` | No | Path to icon resource |
| `sprite_sheet` | No | Path to sprite sheet resource |
| `is_core_guest` | No | `true` (default) for normal guests. `false` for summons, mythical beasts |
| `is_boss` | No | Boss guest flag |
| `is_mythical_beast` | No | Mythical beast flag |
| `spawn_at_exit` | No | For mythical beasts that spawn at path end |
| `move_direction` | No | `"forward"` (default) or `"reverse"` |
| `base_stats.needs` | Yes | Dict of need types to amounts. Core types: `food`, `joy`. Beasts use `interact` |
| `base_stats.money` | Yes | How much the guest can spend at stalls |
| `base_stats.movement_speed` | No | Tiles per turn. Defaults to 1 |
| `skills` | No | Array of skill references (see below) |
| `animations` | No | Animation data for sprites |
| `tags` | No | Freeform tags for filtering and game logic |

### Needs

Needs are what make guests interesting. A guest walks the path and stops at stalls that match their need types. They can also be fulfilled via other means, such as spells or skill effects. Needs directly control:
- Which stalls the guest will visit
- Whether the guest ascends (all needs fulfilled) or descends (exits unsatisfied)

Fulfillment is **not clamped** — a stall offering 3 food to a guest with 1 food remaining reports the full amount (3) to events, animations, and skill triggers. Needs can go negative (overfulfilled). This means the `amount` in `on_need_fulfilled` context always reflects what was offered, not what was needed. Skills like `amount_check` rely on this.

A guest with `{ "food": 4 }` is a focused eater. A guest with `{ "food": 2, "joy": 2 }` needs variety and multiple stall types. Think about what path through your stalls makes the guest's journey interesting.

For mythical beasts, use `"interact"` as the need type. See [guide-creating-mythical-beasts.md](guide-creating-mythical-beasts.md) for the full beast creation guide.

### Skills

Skills are where guest identity comes from. The `skills` array references skill definitions by ID:

```json
"skills": [
  { "skill_id": "generous_tipper" },
  { "skill_id": "impatient", "parameters": { "turns_threshold": 3 } }
]
```

Parameter overrides let multiple guests (or stalls) share the same skill definition with different tuning. The skill definition provides defaults; the entity's `"parameters"` override them at the instance level. This is the same mechanism used by status-granted skills.

## Designing Guest Skills

### Philosophy: Compose, Don't Create

The skill system is built around composable building blocks: **triggers**, **conditions**, and **effects**. Before writing any code, try to express the guest's behavior using existing pieces.

Ask yourself:
1. **When** does this behavior fire? (trigger type)
2. **What must be true** for it to activate? (conditions)
3. **What happens?** (effects)

If you can answer all three with existing building blocks, you just need a new skill JSON. No code.

### When to Reuse vs. Create

**Reuse** an existing skill if the behavior is identical. Multiple guests can reference the same `skill_id`.

**Create a new skill JSON** (no code) when you need a new combination of existing triggers + conditions + effects. This is the most common case.

**Extend an existing effect** (code) when you need a variant of something that already exists. For example, if an effect works on a single target and you need it to work on nearby guests, add a target mode (e.g. `"target": "adjacent_guests"`) rather than creating a separate `effect_area` type. This keeps one effect class, one factory entry, and zero duplicated logic. The `target` field is the extension point — new targeting modes are cheaper than new effect types.

**Create a new condition or effect** (code) only when the existing vocabulary genuinely can't express what you need. This should be rare — the building blocks are designed to be general-purpose.

### Skill JSON Structure

Create `data/skills/<id>.json`:

```json
{
  "$schema": "./_schema.json",
  "id": "my_skill",
  "display_name_key": "SKILL_MY_SKILL_NAME",
  "description_key": "SKILL_MY_SKILL_DESC",
  "owner_types": ["guest"],
  "trigger_type": "on_serve",
  "parameters": {},
  "conditions": [
    { "type": "always" }
  ],
  "effects": [
    { "type": "grant_tokens", "target": "player", "amount": 2 }
  ],
  "tags": ["economy"]
}
```

**`trigger_type`** determines when the skill is evaluated. See the trigger types reference below.

**`conditions`** is an array — ALL must pass (logical AND). Use `"always"` or omit for unconditional skills.

**`effects`** is an array — all execute in order if conditions pass.

**`parameters`** defines configurable values with defaults. Effects and conditions reference them with `"{param_name}"` syntax:

```json
"parameters": {
  "bonus_tokens": { "type": "int", "default": 3, "min": 1, "max": 10 }
},
"effects": [
  { "type": "grant_tokens", "target": "player", "amount": "{bonus_tokens}" }
]
```

## Reference: Trigger Types

These are the trigger types available for skills. Each corresponds to an EventBus signal wired through TriggerSystem.

**Scope** indicates which entities' skills fire by default. Entity-scoped triggers only fire skills owned by the listed entities. Global triggers fire all registered skills. Any entity-scoped trigger can also be observed by skills with `"global": true` — see the [relic guide](guide-creating-relics.md) for details.

| Trigger | Fires When | Scope | Context Available |
|---------|-----------|-------|-------------------|
| `on_spawn` | Guest spawns on the board | guest | guest |
| `on_move` | Guest moves between tiles | guest | guest, from_tile, to_tile |
| `on_serve` | Guest is served at a stall | guest, stall | guest, stall |
| `on_pre_serve` | Before service resolves (can block) | guest, stall | guest, stall, service_result |
| `on_pre_fulfill` | Before need fulfillment resolves (can block/modify) | guest, source | guest, need_type, amount, fulfillment_result |
| `on_need_fulfilled` | A guest need is satisfied | guest, source | guest, need_type, amount |
| `on_enter_stall` | Guest enters a stall | guest, stall | guest, stall |
| `on_ascend` | Guest leaves satisfied | guest | guest |
| `on_descended` | Guest leaves unsatisfied | guest | guest |
| `on_place` | Stall/relic is placed | stall/relic | stall/relic, tile |
| `on_upgrade` | Stall is upgraded | stall | stall, new tier (amount) |
| `on_remove` | Stall is removed | stall | stall |
| `on_restock` | Stall restocks | stall | stall |
| `on_turn_start` | Turn begins | global | turn number (amount) |
| `on_turn_end` | Turn ends | global | turn number (amount) |
| `on_tile_enter` | Entity enters a tile | global | tile, entity |
| `on_tile_exit` | Entity exits a tile | global | tile, entity |
| `on_status_applied` | Status effect applied | global | target, status |
| `on_status_removed` | Status effect removed | global | target, status |
| `on_play` | Card is played | global | card |
| `on_pre_status` | Before status effect applied (can block) | target | target, status_definition (extra), status_result |
| `on_pre_banish` | Before guest is banished (can block) | guest | guest, banish_result |

## Reference: Conditions

| Type | What It Checks | Key Data |
|------|---------------|----------|
| `always` | Always passes | — |
| `need_threshold` | Guest's remaining need vs threshold | `target`, `need_type`, `comparison`, `value` |
| `stall_stock_check` | Stall's current stock vs threshold | `comparison`, `value` |
| `has_status` | Whether target has a status effect | `target`, `status_id` |
| `state_greater_than` | Skill state counter > threshold | `state_key`, `value` |
| `state_less_than` | Skill state counter < threshold | `state_key`, `value` |
| `has_debuff` | Whether target has any debuff | `target` |
| `compare_needs` | Total remaining needs of target vs another entity | `target`, `compare_to`, `comparison` |
| `amount_check` | Trigger context's amount vs threshold | `comparison`, `value` |
| `status_is_debuff` | Whether the status in context is a debuff | `invert` (optional, checks buff if true) |
| `need_type_check` | Whether context.need_type matches a value | `need_type` |

All conditions support `comparison` operators: `equal`, `less_than`, `greater_than`, `less_or_equal`, `greater_or_equal`.

Numeric values can be parameter references: `"value": "{my_param}"`.

## Reference: Effects

| Type | What It Does | Key Data |
|------|-------------|----------|
| `grant_tokens` | Awards tokens to the player | `amount` |
| `modify_stat` | Applies a stat modifier to an entity | `target`, `stat`, `operation`, `value` |
| `fulfill_need` | Fulfills a guest need (via `BoardSystem.fulfill_and_notify`). Use `"target": "adjacent_guests"` with `range` for area | `target`, `need_type`, `amount`, `range` |
| `apply_status` | Applies a status effect (via `BoardSystem.inflict_status`). Use `"target": "adjacent_guests"` with `range` for area | `target`, `status_id`, `stacks`, `range` |
| `increment_state` | Increments a skill state counter | `state_key`, `amount` |
| `chance_block_service` | Chance to block a service event | `chance` |
| `restock_stall` | Restocks the context stall (via `BoardSystem.restock_and_notify`) | — |
| `reset_service_durations` | Resets service timers for all in-stall guests (excluding trigger guest) | — |
| `summon_guest` | Spawns a guest at the skill owner's current tile/path position (via `BoardSystem.summon_guest`) | `guest_id` |
| `modify_fulfillment` | Modifies fulfillment multiplier/bonus via service_result or fulfillment_result | `multiplier`, `bonus` |
| `bonus_restock` | Grants bonus stock to a stall | `amount` |
| `steal_money` | Steals a fraction of guest's money | `target`, `fraction` |
| `remove_status` | Removes status effects by type or ID | `target`, `status_type`, `status_id`, `count` |
| `banish` | Forces a guest off the board (no reputation penalty) | `target` |
| `force_ascend` | Forces a guest to ascend regardless of remaining needs (sweep handles animation/lifecycle) | `target` |
| `block_status` | Blocks a status effect from being applied (sets status_result.blocked) | — |
| `block_banish` | Blocks a guest from being banished (sets banish_result.blocked) | — |

## Creating New Building Blocks

When existing conditions/effects can't express the behavior you need.

### New Condition

1. Create `src/skill_conditions/<name>_condition.gd`
2. Extend `SkillCondition`
3. Implement `evaluate(context: TriggerContext, skill: SkillInstance) -> bool`
4. Use `condition_data.get()` for config, `resolve_int_parameter()` for parameterized values
5. Register in `src/skill_conditions/skill_condition_factory.gd` — add a case to the match statement

### New Effect

1. Create `src/skill_effects/<name>_effect.gd`
2. Extend `SkillEffect`
3. Implement `execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult`
4. Return `SkillEffectResult.succeeded()` or `SkillEffectResult.failed("reason")`
5. Use `result.set_value_changed()` to track what changed
6. Register in `src/skill_effects/skill_effect_factory.gd` — add a case to the match statement

**Use BoardSystem convenience wrappers for game actions.** BoardSystem has two tiers of methods (see [game-loop.md](game-loop.md) for the full breakdown):

- **Action methods** (`spawn_guest()`, `restock_stall()`, `fulfill_guest_need()`, `apply_status_effect()`) — state + data display + animation. No events, no batch. Used by TurnSystem phases which control event timing directly.
- **Convenience wrappers** (`summon_guest()`, `restock_and_notify()`, `fulfill_and_notify()`, `inflict_status()`, `revoke_status()`, `deploy_stall()`) — action method + event emission. No batch. **Used by skill effects**, game.gd, and the debug console.

Effects should call the convenience wrapper, not the raw action method and not raw instance mutations. The wrapper handles state + data display + animation + event emission in one call. The TurnSystem's flush loop (`await AnimationCoordinator.play_batch()` after event emissions) plays any animations queued by effects.

Effects should **not** emit signals that have choreographed animation sequences in TurnSystem (`guest_ascended`, `guest_descended`, `guest_served`, `guest_moved`). TurnSystem manages specific animation→event ordering for these — e.g. ascend animation plays before `guest_ascended` fires. The sweep loop in `_flush_and_sweep()` handles ascension reactively, so effects that fulfill needs don't need to emit `guest_ascended` themselves.

Within nested trigger chains (a convenience wrapper emits a signal, which fires skills, which call more convenience wrappers), the animations-before-events ordering is not guaranteed — queued animations play in the next flush cycle, not before the cascading triggers. In practice this is fine because the player sees everything in one batch.

### New Trigger Type

If your skill needs a trigger that isn't wired yet:

1. Verify the EventBus signal exists in `src/autoload/event_bus.gd` (add if needed)
2. Verify the trigger type is in `data/skills/_schema.json`'s enum
3. In `src/systems/trigger_system.gd`:
   - Connect the signal in `_connect_event_bus_signals()`
   - Add a handler that creates a `TriggerContext` and calls the appropriate trigger method (see below)

**Entity-scoped vs global triggers:**

Use `trigger_entity_skills()` when the event is about specific entities (a guest spawning, a stall being placed). Pass the involved entities so only their skills fire:

```gdscript
# Entity-scoped: only the spawning guest's skills fire
func _on_guest_spawned(guest) -> void:
    var context = TriggerContext.create("on_spawn")
    context.with_guest(guest).with_source(guest)
    trigger_entity_skills("on_spawn", context, [guest])

# Multi-entity: both the guest's and stall's skills fire
func _on_guest_served(guest, stall) -> void:
    var context = TriggerContext.create("on_serve")
    context.with_guest(guest).with_stall(stall).with_source(stall).with_target(guest)
    trigger_entity_skills("on_serve", context, [guest, stall])
```

Use `trigger_skills()` for global events where any skill should be able to react regardless of owner:

```gdscript
# Global: all on_turn_start skills fire
func _on_turn_started(turn_number: int) -> void:
    var context = TriggerContext.create("on_turn_start")
    context.with_amount(turn_number)
    trigger_skills("on_turn_start", context)
```

**Why this matters:** Without entity scoping, a guest's `on_spawn` skill fires every time *any* guest spawns, not just when its owner spawns. This causes modifier accumulation bugs.

## Testing

Every new guest with skills needs integration tests. Tests verify the skill fires correctly and produces the expected state change. See [testing.md](testing.md) for the full framework reference.

### Which file?

Tests are grouped by **trigger type**, not by entity. A guest with an `on_spawn` skill gets tested in `test/integration/test_on_spawn_skills.gd`. A guest with an `on_serve` skill goes in `test_on_serve_skills.gd`. If a guest has skills on multiple triggers, add tests to each relevant file.

### Pattern

Create an inner class per guest (or per skill if the guest has multiple distinct skills):

```gdscript
# test/integration/test_on_spawn_skills.gd

class TestMyGuest:
    extends "res://test/helpers/test_base.gd"

    func test_applies_modifier_on_spawn():
        var guest = create_guest("my_guest")
        register_guest(guest, Vector2i(1, 0))

        fire_for("on_spawn", TriggerContext.create("on_spawn") \
            .with_guest(guest).with_source(guest), [guest])

        var speed = guest.get_stat("movement_speed", guest.definition.base_stats.movement_speed)
        assert_eq(speed, 2, "My guest should have modified speed after spawn")

    func test_no_modifier_without_condition():
        # ... test the negative case
```

### What to test

- **Positive case:** condition met, effect fires, state changes as expected
- **Negative case:** condition not met, effect does not fire
- **AoE effects:** place multiple guests at known positions, verify only those in range are affected
- **Status-granted skills:** apply the status first via `BoardSystem.inflict_status()`, then fire the trigger

### Running

```bash
# Run just the file you added tests to:
godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_spawn_skills.gd
```

## Key Files

| File | Role |
|------|------|
| `data/guests/<id>.json` | Guest data definition |
| `data/guests/_schema.json` | Guest JSON schema |
| `data/skills/<id>.json` | Skill data definition |
| `data/skills/_schema.json` | Skill JSON schema (includes trigger type enum) |
| `src/definitions/guest_definition.gd` | Parses guest JSON into typed resource |
| `src/instances/guest_instance.gd` | Runtime guest state |
| `src/instances/skill_instance.gd` | Runtime skill state, parameter resolution |
| `src/skill_conditions/skill_condition_factory.gd` | Condition type registry |
| `src/skill_effects/skill_effect_factory.gd` | Effect type registry |
| `src/systems/trigger_system.gd` | Wires EventBus signals to skill execution |
| `src/autoload/event_bus.gd` | Signal definitions |

## Checklist

When adding a new guest:

- [ ] Created `data/guests/<id>.json` with valid schema
- [ ] Skill IDs referenced in guest JSON exist in `data/skills/`
- [ ] If new skill JSON was created: trigger type, conditions, and effects are all valid
- [ ] If new condition/effect code was created: registered in the corresponding factory
- [ ] If new trigger type was wired: signal connected in TriggerSystem, handler creates proper TriggerContext
- [ ] Run the project — check ContentRegistry console output confirms the guest and skills loaded without warnings
- [ ] Added integration tests in the appropriate `test/integration/test_on_<trigger>_skills.gd` file (positive + negative cases)

## Proposing Refactors

The current codebase was built around a minimal demo level. Initial assumptions about how systems work may not be correct or complete. When adding a guest, if you find that the existing building blocks can't cleanly express the behavior you need — or that the approach feels like a workaround rather than a natural fit — **propose a refactor before implementing a hack.**

Consider refactoring when:
- A new guest behavior requires hard-coded checks in system code (e.g. `if guest.has_tag("X")` in TurnSystem) rather than working through the data-driven skill pipeline
- A useful pattern doesn't exist yet (e.g. a new stat, a new trigger type, a new effect target) and adding it would unlock a variety of future behaviors
- The current code path doesn't support modifiers or overrides where it should (e.g. a value read directly from a definition without passing through `get_stat()`)
- You find yourself duplicating logic that should be shared

### Best Practices

**Don't assume the current code is correct.** If a system method bypasses the modifier stack, reads a raw value where it should respect overrides, or lacks a hook where one would be useful — that's likely an oversight, not a deliberate design choice. Flag it and fix it.

**Design for variety of use cases, not volume.** Consider "what other behaviors could this pattern express?" A `service_duration_multiplier` stat isn't just for the old man; it's for any guest or status effect that speeds up or slows down service. Build primitives that combine in unexpected ways.

**Keep the JSON boundary clean.** If a behavior can't be expressed purely in JSON with existing building blocks, that's a signal. Either the building blocks need extending, or a new one is needed. The goal is that most guest designs never require touching GDScript.

**Prefer general mechanisms over special cases.** Instead of "old man takes longer at stalls," implement "guests can modify service duration via their stat stack." The specific guest is just one configuration of the general mechanism.

**Extend, don't duplicate.** If a new behavior is a variation of an existing effect — different targeting, different scope — extend the existing effect with a configuration option. The anti-pattern is creating `apply_status` and `apply_status_area` as separate classes with copied logic. The correct pattern is one `apply_status` effect that accepts `"target": "adjacent_guests"` alongside `"target": "self"`. One class, one place to fix bugs, and the JSON author discovers all targeting options in one effect type.

**Read the code path end-to-end before implementing.** Trace from the JSON definition through to the runtime effect. Identify every place where a value is read without modifier support, where an event fires without a corresponding trigger hook, or where behavior is hard-coded that could be data-driven. Propose fixes for what you find.
