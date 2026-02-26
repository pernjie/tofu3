# Guide: Creating New Spells

## Overview

Spells are instant-effect cards. The player casts a spell by selecting a target (or no target), effects fire once using the existing skill effect pipeline, and the card is consumed. Unlike stalls and relics, spells have **no board presence and no runtime instance** — they execute and disappear.

**Data flow:** `data/spells/<id>.json` → `ContentRegistry` loads it → `SpellDefinition` (immutable) → cast at runtime (no instance class)

Spells are played as cards. The `SpellDefinition` extends `CardDefinition`, so every spell JSON also defines a card. Price is determined by `rarity` via `CardDefinition.get_price()`, same as all cards. When cast, the card is permanently removed from the deck (`REMOVED` location).

You never touch GDScript to add a basic spell. New spells are pure data. You only write code when the spell needs an effect type that doesn't exist yet.

## Spell vs Other Card Types

| | Stall | Relic | Spell |
|---|---|---|---|
| Board presence | Yes — placed on a tile | Yes — placed on a tile | No — consumed on cast |
| Runtime instance | `StallInstance` | `RelicInstance` | None |
| Has tiers / upgrades | Yes | No | No |
| Has skills | Yes (per-tier) | Yes (flat list) | No — effects are inline |
| Persists across turns | Yes | Yes (across levels) | No — instant |
| Returns to deck | Yes (reshuffled) | No — removed on play | No — removed on cast |
| Price source | Rarity | Rarity | Rarity |

The key difference: stalls and relics define their behavior through **skills** (trigger + conditions + effects), which are persistent and fire in response to game events. Spells define their behavior through **effects** directly, which execute once on cast and are gone.

## Spell JSON Anatomy

Create `data/spells/<id>.json`:

```json
{
  "$schema": "./_schema.json",
  "id": "healing_mist",
  "display_name_key": "SPELL_HEALING_MIST_NAME",
  "description_key": "SPELL_HEALING_MIST_DESC",
  "rarity": "common",

  "card_type": "spell",
  "hero_id": "",

  "target_type": "stall",
  "target_filter": { "need_type": "food" },

  "effects": [
    { "type": "fulfill_need", "target": "adjacent_guests", "need_type": "food", "amount": 2, "range": 1 },
    { "type": "apply_status", "target": "stall", "status_id": "blessed", "stacks": 1 }
  ],

  "tags": []
}
```

### Fields

| Field | Required | Notes |
|-------|----------|-------|
| `id` | Yes | Unique identifier, matches filename |
| `display_name_key` | Yes | Localization key. Convention: `SPELL_<ID>_NAME` |
| `description_key` | No | Convention: `SPELL_<ID>_DESC` |
| `rarity` | No | `common`, `rare`, `epic`, `legendary`. Defaults to `common` |
| `card_type` | Yes | Always `"spell"` |
| `hero_id` | No | Empty string for neutral spells, hero ID for hero-specific |
| `target_type` | Yes | `"none"`, `"tile"`, `"stall"`, or `"guest"` |
| `target_filter` | No | Upfront validation dict — narrows which targets are valid |
| `effects` | Yes | Array of effect dicts, executed in order on cast |
| `tags` | No | Freeform tags for filtering and game logic |

### Key Differences from Skills

Spell effects are **not** skills. This has practical consequences:

- **No trigger** — effects fire immediately on cast, not in response to a game event
- **No conditions** — there's no condition array. Target validation is handled by `target_type` + `target_filter` before the spell casts. If the player can click it, it's valid
- **No parameters** — effects execute with a `null` SkillInstance, so `"{param_name}"` references don't resolve. All values must be **literals** in the effect data (numbers, strings, arrays)
- **No state** — no `SkillInstance` means no `get_state()`, `set_state()`, or `persistent_state`. Spells can't track counters or remember choices
- **No `"self"` target** — `"self"` resolves to the skill's owner, but spells have no owner. Use `"stall"`, `"guest"`, or `"target"` instead (these resolve from the TriggerContext)

If a spell concept requires conditions, state, or parameterized values, it's a signal that the behavior belongs on a skill (perhaps on a relic or status effect) rather than on a spell — or that the spell should apply a status effect that carries the complex behavior.

## Target Types

The `target_type` determines what the player must click to cast the spell. It shapes the entire interaction.

| `target_type` | Player action | Context available to effects |
|---|---|---|
| `"none"` | Clicks the card, spell casts immediately | `spell_definition` in extra only |
| `"tile"` | Clicks any tile passing the filter | tile position |
| `"stall"` | Clicks a tile with a stall passing the filter | stall + tile position |
| `"guest"` | Clicks a tile with a guest passing the filter | guest + tile position |

**Choose the most specific type that fits.** If a spell operates on a stall, use `"stall"`, not `"tile"` with `{ "has_stall": true }`. The more specific type gives effects direct access to the entity without ambiguity.

### Target Filters

Filters narrow valid targets. During targeting, tiles that don't pass the filter will be visually disabled (when targeting UI is implemented), preventing the player from wasting a spell on an invalid target.

**For `"stall"` targets:**

| Key | Values | Example |
|-----|--------|---------|
| `need_type` | `"food"`, `"joy"` | `{ "need_type": "food" }` |
| `operation_model` | `"product"`, `"service"`, `"bulk_service"` | `{ "operation_model": "product" }` |
| `has_tag` | any stall tag | `{ "has_tag": "food_stall" }` |
| `can_upgrade` | `true`/`false` | `{ "can_upgrade": true }` |

**For `"guest"` targets:**

| Key | Values | Example |
|-----|--------|---------|
| `has_status` | any status ID | `{ "has_status": "cursed" }` |
| `has_tag` | any guest tag | `{ "has_tag": "spirit" }` |
| `is_core_guest` | `true`/`false` | `{ "is_core_guest": true }` |

**For `"tile"` targets:**

| Key | Values | Example |
|-----|--------|---------|
| `has_stall` | `true`/`false` | `{ "has_stall": false }` |
| `has_guest` | `true`/`false` | `{ "has_guest": true }` |

**For `"none"` targets:** no filter applies.

The filter vocabulary is intentionally small. If a spell needs validation beyond this, extend the vocabulary rather than building a generic query engine. See Proposing Refactors.

## Effects

Spells reuse the entire skill effect pipeline. All existing effect types work — `grant_tokens`, `fulfill_need`, `apply_status`, `restock_stall`, `banish`, etc. The only constraint is the null skill (see below).

### Target Selectors

Each effect in the array has an optional `"target"` field that determines what entity the effect operates on. Available selectors for spells:

| Selector | Resolves to |
|----------|-------------|
| `"guest"` | The guest in context (requires `target_type: "guest"`) |
| `"stall"` | The stall in context (requires `target_type: "stall"`) |
| `"target"` | Whatever entity was set as the target in context |
| `"player"` | The player (for `grant_tokens`, etc.) |
| `"adjacent_guests"` | All guests within `range` of the target tile (area effect) |
| `"random_guest_on_tile"` | A random guest on the context tile (requires `target_type: "tile"` with tile in context) |

**Not available:** `"self"` (resolves to skill owner, which is null for spells).

### The Null Skill Constraint

Spell effects execute with `skill = null`. This means:

**Works fine:**
- Literal values: `"amount": 3`, `"status_id": "blessed"`, `"need_type": "food"`
- All target selectors except `"self"`
- Effects that don't depend on skill state

**Does not work:**
- Parameter references: `"amount": "{bonus}"` — resolves to null, falls back to default
- State access: `get_state()`, `set_state()`, `increment_state` — no skill instance to store state on
- `discover` effect — stores results in persistent state on the owner, but spells have no owner
- Any effect that calls `skill.owner` — returns null

If you need parameterized values, put the literal value directly in the spell JSON. If you need state or discovery, the behavior belongs on a different entity type (a relic or status effect that the spell applies).

### Effect Ordering

Effects execute sequentially in array order. Earlier effects resolve before later ones, so you can chain them:

```json
"effects": [
  { "type": "apply_status", "target": "guest", "status_id": "blessed", "stacks": 1 },
  { "type": "fulfill_need", "target": "guest", "need_type": "food", "amount": 3 }
]
```

Here the status is applied before the need is fulfilled, so if `blessed` grants a skill that modifies fulfillment (e.g., via `on_pre_fulfill`), it will be active when the fulfillment happens.

## Designing Spell Identity

### The Instant Gratification Design Space

Stalls provide ongoing value over many turns. Relics provide permanent passive effects. Spells provide **one powerful moment** — then they're gone. This is the fundamental design lever.

A well-designed spell feels like a tactical decision: "I could hold this for a better moment, but using it now solves my immediate problem." The single-use nature creates tension between spending the spell now and saving it.

### Target Type Shapes Identity

The `target_type` isn't just a technical choice — it defines how the player thinks about the spell:

- **`"none"`** spells are fire-and-forget. They affect the whole board or the player directly. Identity comes from the scope and timing of the effect.
- **`"tile"`** spells are positional. The player thinks about *where* on the board the effect matters most. Good for area effects, placement manipulation, or tile-centric mechanics.
- **`"stall"`** spells interact with your infrastructure. The player thinks about *which stall* benefits most. Good for buffing, restocking, manipulating stall behavior.
- **`"guest"`** spells target individual guests. The player thinks about *which guest* needs help or removal. Good for direct fulfillment, status application, banishment.

### Composition Patterns

Spells compose multiple effects to create cohesive moments. Common patterns:

**Buff + Fulfill** — Apply a beneficial status, then fulfill a need. The status may modify how the fulfillment works.

```json
"effects": [
  { "type": "apply_status", "target": "guest", "status_id": "well_fed", "stacks": 1 },
  { "type": "fulfill_need", "target": "guest", "need_type": "food", "amount": 2 }
]
```

**Area Effect** — Use `"adjacent_guests"` with `range` to hit multiple guests from a central point.

```json
"effects": [
  { "type": "fulfill_need", "target": "adjacent_guests", "need_type": "food", "amount": 1, "range": 2 }
]
```

**Stall Manipulation** — Restock, apply status, modify stats on a stall.

```json
"effects": [
  { "type": "restock_stall", "target": "stall" },
  { "type": "apply_status", "target": "stall", "status_id": "overcharged", "stacks": 2 }
]
```

**Global + Positional** — A `"none"` spell that hits everything, or a `"tile"` spell that radiates outward.

### When Existing Effects Aren't Enough

The 42 existing effects cover a wide range of behaviors. Before requesting a new effect, check whether the behavior can be expressed as:

1. **A combination of existing effects** — multiple effects in the array can achieve complex results through sequencing
2. **A status effect** — if the behavior needs to last beyond the cast, apply a status that carries the skills/modifiers
3. **An existing effect with a different target selector** — `"adjacent_guests"` turns many single-target effects into area effects

If none of these work, you genuinely need a new building block. See Proposing Refactors.

### Spell Ideas as Design Exercises

To illustrate how to think through a spell design, here are three concepts at different levels of existing support:

**"Fulfill a random need" (works today):**
Target a guest, fulfill 1 of their unfulfilled needs at random. The `fulfill_need` effect already supports `"need_type": "random"`, which picks from the guest's unfulfilled needs. This is a simple, clean spell:
```json
{
  "target_type": "guest",
  "effects": [
    { "type": "fulfill_need", "target": "guest", "need_type": "random", "amount": 1 }
  ]
}
```

**"Summon a random beast" (needs a new effect):**
Target a tile, spawn a random mythical beast there. No existing effect picks a random beast from all beast definitions — `summon_guest` needs a specific `guest_id`, and `spawn_next_from_queue` pops from a pre-built queue. This needs a new effect (e.g., `summon_random_beast`) that queries ContentRegistry for all beasts and picks one. The spell JSON would be trivial once the effect exists.

**"Broadcast a stall's effect to all guests" (needs new mechanics):**
Target a stall, apply its fulfillment effect to every guest on the board, then shut down the stall. No existing effect can introspect another entity's skills, and there's no "shut down stall" effect. This requires both new effects and possibly new system-level concepts. The right approach is to design the new building blocks first (a `broadcast_stall_effect` or similar, a `disable_stall` status effect), then express the spell in terms of those blocks.

In each case, the spell JSON itself stays simple — the complexity lives in the effect building blocks, where it can be reused by other spells.

## The `on_cast` Trigger

After a spell's effects resolve, the `spell_cast` EventBus signal fires. TriggerSystem handles this as the global `on_cast` trigger, allowing **other entities** to react to spellcasting.

This is not part of the spell JSON — it's how stalls, relics, and guests respond to spells being cast.

**Example — a relic that grants tokens whenever any spell is cast:**

```json
{
  "id": "spell_synergy",
  "owner_types": ["relic"],
  "trigger_type": "on_cast",
  "global": true,
  "conditions": [],
  "effects": [
    { "type": "grant_tokens", "target": "player", "amount": 1 }
  ]
}
```

**Context available to `on_cast` skills:**

| Field | Value |
|-------|-------|
| `extra["spell_definition"]` | The `SpellDefinition` that was cast |
| `extra["target_pos"]` | The target tile position (or `null` for `"none"` spells) |
| `guest` | The target guest (if `target_type` was `"guest"`) |
| `stall` | The target stall (if `target_type` was `"stall"`) |

`on_cast` is a **global** trigger — any entity's skills can react. Entity-scoped filtering is done via conditions on individual skills (e.g., a condition that checks the spell's tags or target type).

## Testing

Every new spell needs integration tests verifying its effects execute correctly. See [testing.md](testing.md) for the full framework reference.

### Which file?

Spell tests go in `test/integration/test_spell_system.gd`. If a spell's effects interact with specific subsystems in novel ways (e.g., a spell that triggers `on_pre_fulfill` interception), add additional tests in the relevant trigger file.

### Pattern

Create an inner class per spell:

```gdscript
# test/integration/test_spell_system.gd

class TestMySpell:
    extends "res://test/helpers/test_base.gd"

    func test_fulfills_random_need():
        var guest = create_guest("hungry_ghost")
        register_guest(guest, Vector2i(2, 0))

        var spell_def = ContentRegistry.get_definition("spells", "my_spell")

        # Build context as _cast_spell does
        var context = TriggerContext.create("spell_cast")
        context.with_extra("spell_definition", spell_def)
        context.with_guest(guest)

        var effects = SkillEffectFactory.create_all(spell_def.effects)
        for effect in effects:
            effect.execute(context, null)

        # Verify the expected state change
        var total_needs = 0
        for need in guest.current_needs.values():
            total_needs += need
        assert_lt(total_needs, guest.definition.base_stats.needs.values().reduce(func(a, b): return a + b),
            "Spell should have fulfilled at least one need")
```

### Spell-specific considerations

- **Null skill:** Always pass `null` as the second argument to `effect.execute()` — this matches how `_cast_spell()` works
- **Context setup:** Build context manually to match the spell's `target_type`. Set `guest`, `stall`, and/or `tile` as appropriate
- **Effect sequencing:** If effects depend on ordering (e.g., apply status then fulfill need), test the full sequence, not individual effects
- **Target filters:** Test `_validate_spell_target()` and `_check_spell_filter()` separately for filter validation. The existing `TestSpellTargetValidation` class covers the validation infrastructure
- **`on_cast` responders:** Test `on_cast` skills in a separate test class — fire the `on_cast` trigger after spell execution and verify the responder skill's effects

### Running

```bash
godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_spell_system.gd
```

## Key Files

| File | Role |
|------|------|
| `data/spells/<id>.json` | Spell data definition |
| `data/spells/_schema.json` | Spell JSON schema |
| `src/definitions/spell_definition.gd` | Parses spell JSON into typed resource |
| `src/definitions/card_definition.gd` | Base card fields (SpellDefinition extends this) |
| `src/game/game.gd` | `_cast_spell()`, target validation, targeting flow |
| `src/skill_effects/skill_effect_factory.gd` | Effect type registry — all 42 effects available |
| `src/skill_effects/skill_effect.gd` | Base effect class — null skill handling |
| `src/systems/trigger_system.gd` | Wires `spell_cast` signal → `on_cast` trigger |
| `src/autoload/event_bus.gd` | `spell_cast` signal definition |
| `src/autoload/content_registry.gd` | Loads spell definitions from JSON |
| `src/systems/deck_system.gd` | Card consumption (sets to REMOVED on play) |

## Checklist

When adding a new spell:

- [ ] Created `data/spells/<id>.json` with valid schema
- [ ] `card_type` is `"spell"`
- [ ] `target_type` is appropriate — most specific type that fits
- [ ] `target_filter` is set if the spell shouldn't target every entity of that type
- [ ] All effect `type` values exist in `SkillEffectFactory`
- [ ] All effect values are **literals** (no `"{param}"` references — spells have no skill instance)
- [ ] Effect `target` selectors are valid for spells (no `"self"`)
- [ ] Any status effect IDs referenced exist in `data/status_effects/`
- [ ] `rarity` is set correctly (this determines shop price automatically)
- [ ] Run the project — check ContentRegistry console output confirms the spell loaded without warnings
- [ ] Added integration tests in `test/integration/test_spell_system.gd` (verify effects produce expected state changes)
- [ ] If spell effects interact with other subsystems (pre-fulfill, status application): added tests in the relevant trigger test file

## Proposing Refactors

Spells reuse the existing effect pipeline, so most spell designs should work without new code. When they don't, the issue is almost always a missing building block — not a problem with the spell system itself.

**New effect type needed** when a spell concept requires an action the pipeline can't express. Examples: "pick a random beast and spawn it" (no effect queries ContentRegistry for random definitions), "disable a stall for N turns" (no shutdown/disable effect). Propose the new effect as a general-purpose building block, not a spell-specific hack.

**New target filter key needed** when `target_filter` can't express the validation a spell needs. Examples: "target a stall with at least 2 stock" (no `min_stock` filter), "target a guest on a specific path" (no `on_path` filter). Extend the filter vocabulary in `_check_spell_filter()` and the schema.

**New target selector needed** when effects need to reach entities that current selectors can't. Examples: "all guests on the board" (no `"all_guests"` selector), "the nearest beast" (no proximity-based selector). Add the selector to `TriggerContext.resolve_target_entity()` and update the schema.

**Status effect is the right tool** when a spell concept needs lasting behavior, state tracking, or conditional reactions. Apply a status effect that carries the complex behavior — keep the spell itself simple. The spell is the delivery mechanism; the status effect is the payload.

### Best Practices

**Keep spells simple.** A spell with 5+ effects doing intricate sequencing is probably a relic or status effect in disguise. If the behavior needs to persist, react to events, or track state, it shouldn't be a spell.

**Extend, don't duplicate.** If a new spell behavior is a variation of an existing effect — different targeting, different scope — extend the existing effect rather than creating a separate one. One class, one place to fix bugs.

**Keep the JSON boundary clean.** If a spell behavior can't be expressed purely in JSON with existing effect types, that's a signal. Either the building blocks need extending, or a new one is needed. The goal is that most spell designs never require touching GDScript.

**Design effects for reuse.** When proposing a new effect for a spell, ask "what other spells (or skills) could use this?" A `summon_random_beast` effect should work equally well in a spell, a relic skill, or a status-granted skill. Build general primitives.
