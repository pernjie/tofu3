# Guide: Creating New Relics

## Overview

Relics are permanent structures players place on the board. Unlike stalls, relics don't serve guests — they provide passive effects, react to game events, or modify other entities through the skill system. Once placed, a relic occupies a stall slot for the rest of the run and cannot be removed.

**Data flow:** `data/relics/<id>.json` -> `ContentRegistry` loads it -> `RelicDefinition` (immutable) -> `RelicInstance` (mutable runtime state)

Relics are played as cards. The `RelicDefinition` extends `CardDefinition`, so every relic JSON also defines a card with a `price` field. When played, a `RelicInstance` is created on the board at the chosen position and the card is permanently removed from the deck.

You never touch GDScript to add a basic relic. New relics are pure data — a JSON file for the relic and optionally new skill JSON files. You only write code when the relic needs behavior that can't be expressed with existing skill building blocks.

## Relic vs Stall

| | Stall | Relic |
|---|---|---|
| Serves guests | Yes | No |
| Has tiers / upgrades | Yes | No |
| Has stock / occupants | Yes | No |
| Removed after level | Yes | No — persists for the run |
| Returns to deck | Yes (reshuffled) | No — removed from deck on play |
| Occupies stall slot | Yes | Yes |
| Has skills | Yes (per-tier) | Yes (flat list) |
| Can receive status effects | Yes | Yes |
| Can be target of modifiers | Yes | Yes |

The key trade-off for players: a relic permanently consumes a stall slot, reducing the space available for revenue-generating stalls. The relic's effect must justify that cost.

## Relic JSON Anatomy

Create `data/relics/<id>.json`:

```json
{
  "$schema": "./_schema.json",
  "id": "my_relic",
  "display_name_key": "RELIC_MY_RELIC_NAME",
  "description_key": "RELIC_MY_RELIC_DESC",
  "rarity": "common",

  "card_type": "relic",
  "price": 40,
  "hero_id": "",

  "skills": [
    { "skill_id": "some_passive_effect" }
  ],

  "sprite_sheet": "",
  "animations": {},
  "tags": ["economy"]
}
```

### Fields

| Field | Required | Notes |
|-------|----------|-------|
| `id` | Yes | Unique identifier, matches filename |
| `display_name_key` | Yes | Localization key. Convention: `RELIC_<ID>_NAME` |
| `description_key` | No | Convention: `RELIC_<ID>_DESC` |
| `rarity` | No | `common`, `rare`, `epic`, `legendary`. Defaults to `common` |
| `icon_path` | No | Path to icon resource |
| `sprite_sheet` | No | Path to sprite sheet resource |
| `card_type` | Yes | Always `"relic"` |
| `price` | No | Token cost for the player to play this card. Defaults to 0 |
| `hero_id` | No | Empty string for neutral cards, hero ID for hero-specific cards |
| `skills` | Yes | Array of skill references (see Skills section) |
| `animations` | No | Animation data for sprites |
| `tags` | No | Freeform tags for filtering and game logic |

Relics have no tiers, no operation model, and no need type. All relic behavior comes from skills.

## Persistence

Relics persist across levels within a run:

- The board layout is fixed for the entire run. A relic placed at position `(2, 1)` on level 1 remains at `(2, 1)` on level 2.
- When a relic card is played, it is permanently removed from the deck — it will never be drawn again.
- At the start of each level, all previously placed relics are restored to the board with their skills re-registered.
- Relics cannot be removed, sold, or repositioned (for now). Placement is a permanent decision.

This means relic placement is a strategic commitment: the player trades a deck slot and a board slot for a persistent effect.

## Skills

Relics use the same skill system as stalls and guests. Each relic's `skills` array defines the skills active for the lifetime of the relic. Skills are referenced by ID, with optional parameter overrides:

```json
"skills": [
  { "skill_id": "bonus_on_restock", "parameters": { "bonus": 2 } }
]
```

### Trigger Scoping: Entity vs Global Skills

Most triggers are **entity-scoped** — a skill only fires when its owner is a direct participant in the event. For example, a stall's `on_restock` skill only fires when *that* stall restocks.

Relics are different. They don't serve guests or restock — they passively observe the board. A relic that reacts to "any stall restocking" needs to fire on events it doesn't participate in. This is what the **`global`** flag is for.

Setting `"global": true` on a skill makes it fire on *any* matching event, regardless of whether the owner is a participant. The trigger system still uses entity-scoped dispatch — global skills simply bypass the ownership check.

| Skill type | `global` | Fires when |
|-----------|----------|------------|
| Stall's `on_restock` | `false` (default) | That stall restocks |
| Relic's `on_restock` observer | `true` | Any stall restocks |
| Relic's `on_place` | `false` (default) | That relic is placed |
| Any `on_turn_start` | N/A (already global) | Turn starts — `trigger_skills` has no entity filter |

**When to use `global: true`:**
- The skill reacts to events involving *other* entities (relic observing stall restocks, guest spawns, etc.)

**When NOT to use it:**
- The skill reacts to events involving its *own* entity (`on_place` for the relic itself)
- The trigger is already globally dispatched (`on_turn_start`, `on_turn_end`, `on_play`)

### Relic-Owned Skills

Relic-owned skills use `"owner_types": ["relic"]` in their skill JSON. Since relics don't serve guests, they don't participate in service-related events. Relic skills typically combine a `global` observer trigger with conditions and state to create reactive effects.

**Example — grant tokens at the start of each turn:**
```json
{
  "id": "prosperity_aura",
  "owner_types": ["relic"],
  "trigger_type": "on_turn_start",
  "parameters": {
    "amount": { "type": "int", "default": 1, "min": 1, "max": 5 }
  },
  "conditions": [],
  "effects": [
    { "type": "grant_tokens", "target": "player", "amount": "{amount}" }
  ],
  "tags": ["economy"]
}
```
Note: no `global` needed here — `on_turn_start` is already dispatched globally via `trigger_skills`.

**Example — react to any stall restocking (global observer):**
```json
{
  "id": "restock_observer_example",
  "owner_types": ["relic"],
  "trigger_type": "on_restock",
  "global": true,
  "conditions": [],
  "effects": [
    { "type": "grant_tokens", "target": "player", "amount": 1 }
  ],
  "tags": ["economy"]
}
```
The `global: true` flag lets this relic skill fire when *any* stall restocks, even though the relic is not a participant in the restock event.

**Example — Mystical Scroll (discover + recurring effect):**

The Mystical Scroll is a two-skill relic: on placement, the player discovers (picks) a beast; at the start of every level, the chosen beast is added to the beast queue.

`data/relics/mystical_scroll.json`:
```json
{
  "id": "mystical_scroll",
  "card_type": "relic",
  "rarity": "rare",
  "price": 50,
  "skills": [
    { "skill_id": "mystical_scroll_discover" },
    { "skill_id": "mystical_scroll_summon" }
  ]
}
```

`data/skills/mystical_scroll_discover.json` — `on_place`, uses the `discover` effect to present 3 random beasts from a pool, stores the choice in `persistent_state["chosen_beast_id"]`.

`data/skills/mystical_scroll_summon.json` — `on_level_start`, uses `add_to_beast_queue` with `"{chosen_beast_id}"` which resolves via `persistent_state` fallback.

No GDScript needed — the relic is entirely data-driven using the `discover` and `add_to_beast_queue` building blocks.

### Designing Relic Identity

A relic's identity is entirely defined by its skills. Since relics have no tiers or service mechanics, the skill _is_ the relic. 

## Persistent State

`BaseInstance` includes a `persistent_state: Dictionary` — a general-purpose key-value store for data that should survive across levels. Any entity type can use it, but currently only relics benefit because they persist across levels.

Skill effects read and write persistent state via `context.owner.persistent_state`. Parameter resolution checks `persistent_state` as a fallback — a skill parameter like `"{chosen_beast_id}"` resolves by looking up `persistent_state["chosen_beast_id"]` on the owner.

**How persistence works for relics:**

`RunState.relics_on_board` stores both the definition and the persistent state for each relic. When `BoardSystem.restore_relics()` recreates relic instances at level start, it copies the stored persistent state onto the new instance.

**Use cases:**
- Storing a player's choice from a discover effect (e.g., which beast to summon)
- Tracking cumulative counters across the entire run (e.g., "total guests served while this relic was active")
- Remembering one-time setup that shouldn't repeat (e.g., "already discovered, skip on restore")

### Deferred Effects (Discover Pattern)

Some relic skills need player input — for example, choosing a beast from a pool on placement. Since skill effects are synchronous, they use the **deferred effect pattern**: the effect registers a pending request on `TriggerSystem`, and the caller (game.gd) handles the UI after trigger execution completes. See [game-loop.md](game-loop.md#deferred-effects) for the full pattern.

A typical discover relic uses two skills:

```json
"skills": [
  { "skill_id": "shrine_discover" },
  { "skill_id": "shrine_ongoing_effect" }
]
```

1. **`on_place` skill** — `discover` effect presents options, stores the player's choice in `persistent_state`
2. **`on_level_start` skill** — reads `persistent_state` and applies the ongoing effect (e.g., adds a beast to the queue)

The `on_level_start` trigger fires at the beginning of each level, including the current level after placement. This lets relics have setup-once + repeat-every-level behavior purely through data.

## Modifier Support

`RelicInstance` inherits `BaseInstance`, which includes `modifier_stack` and `status_effects`. This means relics can be the target of status effects and stat modifiers, just like stalls and guests.

This could enable skills or events that buff/debuff relics (e.g., a guest curse that temporarily disables a relic's skills).

## Testing

Every new relic with skills needs integration tests. Tests verify the skill fires correctly and produces the expected state change. See [testing.md](testing.md) for the full framework reference.

### Which file?

Tests are grouped by **trigger type**. A relic with an `on_restock` observer skill goes in `test/integration/test_on_restock_skills.gd`. A relic with an `on_place` skill goes in whichever file matches that trigger. If a relic has skills on multiple triggers, add tests to each relevant file.

### Pattern

Create an inner class per relic:

```gdscript
# test/integration/test_on_restock_skills.gd

class TestMyRelic:
    extends "res://test/helpers/test_base.gd"

    func test_grants_bonus_on_restock():
        var relic = create_relic("my_relic")
        register_relic(relic, Vector2i(1, 1))
        var stall = create_stall("noodle_stand")
        register_stall(stall, Vector2i(2, 1))

        var tokens_before = GameManager.tokens
        # on_restock is global, so fire() works
        fire("on_restock", TriggerContext.create("on_restock") \
            .with_stall(stall).with_source(stall))

        assert_gt(GameManager.tokens, tokens_before,
            "Relic should grant tokens when any stall restocks")

    func test_no_effect_without_restock():
        # ... test that the relic doesn't fire on unrelated events
```

### Relic-specific considerations

- **Global skills:** Relic skills with `global: true` observe events from other entities. Use `fire()` (not `fire_for()`) since these fire regardless of entity ownership
- **`on_place` skills:** Use `fire_for()` with `[relic]` since placement is entity-scoped
- **Skill state:** Access via `relic.skill_instances[0].get_state(key)` to verify counters and flags
- **Persistent state:** Access via `relic.persistent_state` for cross-level data (e.g. discover choices)
- **Relic positioning:** `register_relic` creates a standalone tile at the given position (relics are adjacent to path, not on it)

### Running

```bash
godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_restock_skills.gd
```

## Key Files

| File | Role |
|------|------|
| `data/relics/<id>.json` | Relic data definition |
| `data/relics/_schema.json` | Relic JSON schema |
| `data/skills/<id>.json` | Skill data definition |
| `data/skills/_schema.json` | Skill JSON schema (includes trigger type enum) |
| `src/definitions/relic_definition.gd` | Parses relic JSON into typed resource |
| `src/definitions/card_definition.gd` | Base card fields (RelicDefinition extends this) |
| `src/instances/relic_instance.gd` | Runtime relic state |
| `src/instances/skill_instance.gd` | Runtime skill state, parameter resolution |
| `src/autoload/board_system.gd` | Relic placement, spatial queries, persistence restore |
| `src/game/game.gd` | Card playing dispatches relic placement |
| `src/systems/trigger_system.gd` | Wires EventBus signals to skill execution |
| `src/autoload/event_bus.gd` | Signal definitions |

## Checklist

When adding a new relic:

- [ ] Created `data/relics/<id>.json` with valid schema
- [ ] `card_type` is `"relic"`
- [ ] `price` feels right — consider that the player permanently loses a stall slot
- [ ] Skill IDs referenced in `skills` array exist in `data/skills/`
- [ ] Skill JSONs have `"relic"` in their `owner_types`
- [ ] If new skill JSON was created: trigger type and effects are valid
- [ ] If new condition/effect code was created: registered in the corresponding factory
- [ ] Run the project — check ContentRegistry console output confirms the relic and skills loaded without warnings
- [ ] Added integration tests in the appropriate `test/integration/test_on_<trigger>_skills.gd` file (positive + negative cases)
- [ ] If relic has skills on multiple triggers: added tests in each relevant trigger file

## Proposing Refactors

The relic system is intentionally simple. When adding a relic, if you find that existing skill building blocks can't cleanly express the behavior you need, consider:

- **A new trigger type** if the relic needs to react to an event that doesn't have one yet (e.g., `on_level_start`)
- **A new condition type** if the relic needs to check state that existing conditions can't (e.g., "first time per turn")
- **A new effect type** if the relic needs to produce an outcome that existing effects can't

Propose a new building block rather than hacking around the limitation. The goal is that most relic designs never require touching GDScript.
