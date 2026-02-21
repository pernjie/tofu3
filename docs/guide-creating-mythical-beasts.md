# Guide: Creating Mythical Beasts

## Overview

Mythical beasts are supernatural creatures that walk the paths in reverse, interacting with regular guests as they pass through. Unlike regular guests who visit stalls, beasts fulfill their needs by encountering guests directly — their encounter and post-interaction effects are defined as skills using `on_encounter` and `on_interact` triggers.

**Data flow:** `data/guests/<id>.json` -> `ContentRegistry` loads it -> `GuestDefinition` (immutable) -> `GuestInstance` (mutable runtime state)

Mythical beasts reuse the guest data pipeline. A beast is a guest with `is_mythical_beast: true`, `is_core_guest: false`, `spawn_at_exit: true`, and `move_direction: "reverse"`. The key difference is behavioral: beasts don't visit stalls and interact with guests on arrival instead.

## Beast JSON Anatomy

Create `data/guests/<id>.json`:

```json
{
  "$schema": "./_schema.json",
  "id": "nine_tailed_fox",
  "display_name_key": "GUEST_NINE_TAILED_FOX_NAME",
  "description_key": "GUEST_NINE_TAILED_FOX_DESC",
  "rarity": "rare",

  "is_core_guest": false,
  "is_mythical_beast": true,
  "spawn_at_exit": true,
  "move_direction": "reverse",

  "base_stats": {
    "needs": { "interact": 2 },
    "money": 0,
    "movement_speed": 1
  },

  "skills": [
    { "skill_id": "encounter_fulfill_need", "parameters": { "need_type": "joy", "amount": 2 } },
    { "skill_id": "apply_status_on_interact", "parameters": { "status_id": "charmed", "stacks": 1 } }
  ],

  "tags": ["mythical", "spirit"]
}
```

### Required Beast Fields

These fields distinguish a beast from a regular guest:

| Field | Value | Why |
|-------|-------|-----|
| `is_core_guest` | `false` | Beasts don't affect reputation or level completion |
| `is_mythical_beast` | `true` | Enables beast movement phase and interaction logic |
| `spawn_at_exit` | `true` | Spawns at the last tile of the path |
| `move_direction` | `"reverse"` | Walks backward toward the spawn point |
| `base_stats.needs` | `{ "interact": N }` | N successful interactions needed to ascend |
| `base_stats.money` | `0` | Beasts don't spend money at stalls |

### Beast Skills: `on_encounter` and `on_interact`

Beast behavior is defined entirely through skills. Two trigger types work together:

**`on_encounter`** — Fires when the beast and a guest share a tile (before the interaction is committed). The beast's `on_encounter` skills determine *eligibility* and *effects*. If any `on_encounter` skill succeeds, the interaction is considered successful: the beast's `interact` need is decremented, and the guest's turn is consumed.

**`on_interact`** — Fires after a successful interaction (via `EventBus.beast_interacted`). Use this for post-interaction effects like applying status effects.

#### Reusable Skill Definitions

Three generic skills cover the most common beast patterns:

**`encounter_fulfill_need`** — Checks if the target guest has a remaining need of `{need_type}` > 0, then fulfills `{amount}` of it. Parameters: `need_type` (string), `amount` (int).

**`apply_status_on_interact`** — Applies a status effect to the target guest after interaction. Parameters: `status_id` (string), `stacks` (int).

**`steal_money`** — Steals a fraction of the target guest's money and gives it to the beast. Parameters: `fraction` (float, 0.0–1.0).

**`encounter_banish`** — Banishes the target guest if their total remaining needs are less than or equal to the beast's total remaining needs. No parameters. Uses the `compare_needs` condition and `banish` effect.

Example usage with parameter overrides:
```json
"skills": [
  { "skill_id": "encounter_fulfill_need", "parameters": { "need_type": "joy", "amount": 2 } },
  { "skill_id": "apply_status_on_interact", "parameters": { "status_id": "charmed", "stacks": 1 } }
]
```

### The `interact` Need Type

Beast needs use the same `base_stats.needs` dictionary as regular guests, with `"interact"` as the need type. This is intentional — it reuses the existing need infrastructure:

- **Ascension:** When `interact` reaches 0, `are_all_needs_fulfilled()` returns true and the beast ascends immediately (removed from the board)
- **Modifiers:** Skills and status effects that modify needs can target beast interaction needs
- **Display:** The need label shows interaction progress alongside any other need types
- **No stall conflict:** No stall has `need_type: "interact"`, so beasts are naturally skipped during stall entry

## Beast Lifecycle

### Spawning

Beasts can enter the level in three ways:
- **Beast queue:** Added to `BoardSystem.beast_queue` for deferred spawning. One beast pops from this queue per turn during GUEST_SPAWN, but only after midnight has been reached (all core guests have left the regular queue). This is the primary spawn path for beasts.
- **Queued:** Mixed into the regular `guest_groups` in the level definition. They spawn from the queue like any guest, but at the path exit instead of the start.
- **Event-triggered:** Spawned by skills, status effects, or other game events via `BoardSystem.summon_guest()`.

### Turn Phase Ordering

Beasts introduce two phases into the turn sequence:

```
TURN_START
SERVICE_RESOLUTION
BEAST_MOVEMENT          <- beasts move, interact with guests at destination
GUEST_MOVEMENT          <- interacted guests skip; regular guests move
BEAST_INTERACTION       <- beasts interact with guests that just arrived on their tile
STALL_ENTRY             <- interacted guests skip
GUEST_SPAWN
PLAYER_ACTION
TURN_END
```

### Movement

Each turn, beasts move toward the path spawn point (index 0). Movement uses the same `advance_guest_on_path` as regular guests, but with direction `-1` (reverse).

A beast that starts the turn on the same tile as guests from a previous interaction does **not** re-interact — it simply moves away. Interaction only triggers on arrival (when either party moves onto the other's tile).

### Interaction Resolution

When a beast arrives at a tile with regular guests (or a guest arrives at a beast's tile):

1. Identify eligible guests on the tile (regular guests only, not in stalls, not other beasts, not already interacted)
2. For each eligible guest:
   a. Create a `TriggerContext("on_encounter")` with beast as source, guest as target
   b. Fire the beast's `on_encounter` skills via `trigger_entity_skills`
   c. If any skill effect succeeds: decrement beast's `interact` need, mark guest as interacted
   d. If no skill succeeds: skip this guest
   e. If beast's `interact` need reaches 0: beast ascends immediately, stop processing
3. Guests marked as interacted skip their remaining turn actions (movement and/or stall entry)
4. After all interactions, `EventBus.beast_interacted` fires for each successful pair, triggering `on_interact` skills

### Interaction Triggers on Arrival

Interaction happens at two distinct moments each turn:

**After beast movement (BEAST_MOVEMENT phase):**
- Beast moves to a new tile
- If regular guests are standing there, the beast interacts with them
- Interacted guests are marked — they skip GUEST_MOVEMENT and STALL_ENTRY

**After guest movement (BEAST_INTERACTION phase):**
- Regular guests have just moved
- If a guest landed on a tile where a beast is standing, the beast interacts with them
- Interacted guests are marked — they skip STALL_ENTRY

In both cases, the same interaction logic runs. The only difference is which turn actions the guest still has to skip.

### Exit

When a beast reaches path index 0 (the regular spawn point):
- If all `interact` needs are fulfilled: ascends (same animation/logic as regular guests)
- If unfulfilled needs remain: descends (no reputation penalty, since `is_core_guest: false`)

A beast can also ascend mid-path if its last `interact` need is fulfilled during an interaction — ascension is immediate on fulfillment, same as regular guests.

## Interaction Rules Summary

| Rule | Detail |
|------|--------|
| Beasts interact with regular guests only | Not other beasts, not guests in stalls |
| Interaction triggers on arrival | When beast moves onto a guest's tile, or guest moves onto a beast's tile |
| No re-interaction on co-location | If beast starts turn on same tile as a guest, it moves away without interacting |
| One interaction per beast-guest encounter | A guest is only interacted with once per arrival event |
| Skills determine eligibility | `on_encounter` skill conditions gate whether the interaction succeeds |
| Beast stops when satisfied | Once `interact` need hits 0, the beast ascends and stops processing |
| Interacted guests lose their turn | Skip all remaining actions (movement and/or stall entry) for that turn |

## Skills on Beasts

Beasts can use any skill trigger, not just `on_encounter` and `on_interact`. Common use cases:

- `on_spawn`: Effects when the beast appears
- `on_move`: Effects when the beast moves between tiles
- `on_ascend`: Effects when the beast ascends (all interactions complete)
- `on_encounter`: Pre-interaction effects (fulfilling needs, checking eligibility)
- `on_interact`: Post-interaction effects (applying statuses, granting tokens)

## Example: Nine-Tailed Fox

A fox spirit that charms guests, fulfilling their desire for joy:

```json
{
  "$schema": "./_schema.json",
  "id": "nine_tailed_fox",
  "display_name_key": "GUEST_NINE_TAILED_FOX_NAME",
  "description_key": "GUEST_NINE_TAILED_FOX_DESC",
  "rarity": "rare",

  "is_core_guest": false,
  "is_mythical_beast": true,
  "spawn_at_exit": true,
  "move_direction": "reverse",

  "base_stats": {
    "needs": { "interact": 2 },
    "money": 0,
    "movement_speed": 1
  },

  "skills": [
    { "skill_id": "encounter_fulfill_need", "parameters": { "need_type": "joy", "amount": 2 } },
    { "skill_id": "apply_status_on_interact", "parameters": { "status_id": "charmed", "stacks": 1 } }
  ],

  "tags": ["mythical", "spirit"]
}
```

**Behavior:** Spawns at path exit, walks backward. When it shares a tile with a guest that has joy needs, it fulfills 2 joy (via `encounter_fulfill_need` skill). After the interaction, charmed is applied (via `apply_status_on_interact` skill). After 2 successful interactions, it ascends. Guests it interacts with skip their turn.

## Example: Tanuki

A mischievous trickster that feeds guests but steals their money:

```json
{
  "$schema": "./_schema.json",
  "id": "tanuki",
  "display_name_key": "GUEST_TANUKI_NAME",
  "description_key": "GUEST_TANUKI_DESC",
  "rarity": "rare",

  "is_core_guest": false,
  "is_mythical_beast": true,
  "spawn_at_exit": true,
  "move_direction": "reverse",

  "base_stats": {
    "needs": { "interact": 3 },
    "money": 0,
    "movement_speed": 1
  },

  "skills": [
    { "skill_id": "encounter_fulfill_need", "parameters": { "need_type": "food", "amount": 2 } },
    { "skill_id": "steal_money", "parameters": { "fraction": 0.5 } }
  ],

  "tags": ["mythical", "trickster"]
}
```

**Behavior:** Spawns at path exit, walks backward. Fulfills 2 food for guests it encounters (via `encounter_fulfill_need`), and steals half their money via a `steal_money` skill on the `on_interact` trigger. Ascends after 3 successful interactions.

## Example: Hanzaki (Giant Salamander)

A predatory beast that devours weaker guests — those with fewer remaining needs:

```json
{
  "$schema": "./_schema.json",
  "id": "hanzaki",
  "display_name_key": "GUEST_HANZAKI_NAME",
  "description_key": "GUEST_HANZAKI_DESC",
  "rarity": "rare",

  "is_core_guest": false,
  "is_mythical_beast": true,
  "spawn_at_exit": true,
  "move_direction": "reverse",

  "base_stats": {
    "needs": { "interact": 3 },
    "money": 0,
    "movement_speed": 1
  },

  "skills": [
    { "skill_id": "encounter_banish" }
  ],

  "tags": ["mythical", "yokai"]
}
```

**Behavior:** Spawns at path exit, walks backward. When it shares a tile with a guest whose total remaining needs are less than or equal to the beast's remaining interact count, it banishes them (forced removal, no reputation penalty). As it banishes guests, its remaining interact count decreases, making it progressively pickier — a beast at interact 3 banishes guests with 3 or fewer remaining needs, but at interact 1 it can only banish guests with 1 or fewer. After 3 banishments it ascends.

## Testing

Every new beast needs integration tests for its encounter and interaction skills. Tests verify the skill fires correctly and produces the expected state change. See [testing.md](testing.md) for the full framework reference.

### Which file?

Beast encounter and interaction skills go in `test/integration/test_on_encounter_skills.gd`. If a beast also has skills on other triggers (e.g. `on_spawn`, `on_ascend`), add those tests to the corresponding trigger file.

### Pattern

Create an inner class per beast:

```gdscript
# test/integration/test_on_encounter_skills.gd

class TestMyBeast:
    extends "res://test/helpers/test_base.gd"

    var beast: GuestInstance
    var target: GuestInstance

    func before_each():
        super.before_each()
        beast = create_guest("my_beast")
        target = create_guest("hungry_ghost")
        register_guest(beast, Vector2i(2, 0))
        register_guest(target, Vector2i(2, 0))  # same tile

    func test_encounter_fulfills_need():
        fire_for("on_encounter", TriggerContext.create("on_encounter") \
            .with_guest(target).with_source(beast).with_target(target), [beast])

        assert_eq(target.current_needs.get("joy", 0), 0,
            "Beast should fulfill target's joy need")

    func test_encounter_fails_when_no_matching_need():
        target.current_needs["joy"] = 0  # already fulfilled
        fire_for("on_encounter", TriggerContext.create("on_encounter") \
            .with_guest(target).with_source(beast).with_target(target), [beast])

        # Verify no state change or effect failure
```

### Beast-specific considerations

- **`on_encounter` vs `on_interact`:** `on_encounter` fires the beast's skills only (`[beast]`). `on_interact` fires both entities' skills (`[beast, target]`)
- **Context convention:** `guest` = the regular guest being targeted, `source` = the beast, `target` = the regular guest
- **Post-interaction effects:** Test `on_interact` separately — apply status, steal money, etc.
- **Banish effects:** Check `target.is_banished` after encounter

### Running

```bash
godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_encounter_skills.gd
```

## Key Files

| File | Role |
|------|------|
| `data/guests/<id>.json` | Beast data definition (same as guests) |
| `data/guests/_schema.json` | Guest JSON schema |
| `data/skills/encounter_fulfill_need.json` | Generic encounter skill (fulfills a need on target) |
| `data/skills/apply_status_on_interact.json` | Generic post-interact skill (applies status on target) |
| `data/skills/steal_money.json` | Generic post-interact skill (steals money from target to beast) |
| `data/skills/encounter_banish.json` | Generic encounter skill (banishes weaker guests) |
| `src/definitions/guest_definition.gd` | Parses beast JSON |
| `src/instances/guest_instance.gd` | Runtime beast state |
| `src/systems/turn_system.gd` | Phase orchestration, fires `on_encounter` directly, emits `beast_interacted` |
| `src/autoload/board_system.gd` | Movement direction, spawn-at-exit |
| `src/autoload/event_bus.gd` | `beast_interacted` signal |
| `src/systems/trigger_system.gd` | Wires `on_interact` (post-event, via EventBus); executes `on_encounter` skills when called by TurnSystem |

## Checklist

When adding a new mythical beast:

- [ ] Created `data/guests/<id>.json` with `is_mythical_beast: true`, `is_core_guest: false`, `spawn_at_exit: true`, `move_direction: "reverse"`
- [ ] `base_stats.needs` uses `"interact"` need type with the desired count
- [ ] `skills` array defines encounter behavior (e.g. `encounter_fulfill_need` with parameter overrides)
- [ ] Post-interaction effects use `on_interact` trigger skills (e.g. `apply_status_on_interact`)
- [ ] Any skill IDs referenced in `skills` array exist in `data/skills/`
- [ ] Any status effect IDs referenced exist in `data/status_effects/`
- [ ] Run the project — verify beast spawns at exit, walks backward, interacts correctly, and ascends on completion
- [ ] Added integration tests in `test/integration/test_on_encounter_skills.gd` for encounter skills (positive + negative cases)
- [ ] If beast has `on_interact` skills: added tests for post-interaction effects
- [ ] If beast has other trigger skills (`on_spawn`, `on_ascend`): added tests in the corresponding trigger file

## Proposing Refactors

The beast system builds on top of the guest infrastructure. When adding a new beast, if you find that the existing building blocks can't cleanly express the behavior you need — or that the approach feels like a workaround rather than a natural fit — **propose a refactor before implementing a hack.**

Consider refactoring when:
- A new beast behavior requires hard-coded checks in system code (e.g. `if guest.is_mythical_beast` branches in TurnSystem) rather than working through the data-driven skill pipeline
- A useful pattern doesn't exist yet (e.g. a new encounter condition, a new interaction effect, a new target mode) and adding it would unlock a variety of future beasts
- The current code path doesn't support modifiers or overrides where it should (e.g. interaction count read directly from a definition without passing through `get_stat()`)
- You find yourself duplicating logic that should be shared between beast skills and guest skills

### Best Practices

**Don't assume the current code is correct.** If a system method bypasses the modifier stack, reads a raw value where it should respect overrides, or lacks a hook where one would be useful — that's likely an oversight, not a deliberate design choice. Flag it and fix it.

**Design for variety of use cases, not volume.** Consider "what other beasts could this pattern express?" An `encounter_fulfill_need` skill isn't just for the nine-tailed fox; it's for any beast that fulfills guest needs on contact. Build primitives that combine in unexpected ways.

**Keep the JSON boundary clean.** If a beast behavior can't be expressed purely in JSON with existing building blocks, that's a signal. Either the building blocks need extending, or a new one is needed. The goal is that most beast designs never require touching GDScript.

**Prefer general mechanisms over special cases.** Instead of "beasts applies charm to interacted guest," implement "apply status effect via a configurable effect of type 'interaction'." The specific beast is just one configuration of the general mechanism.

**Extend, don't duplicate.** If a new behavior is a variation of an existing effect — different targeting, different scope — extend the existing effect with a configuration option. The anti-pattern is creating `encounter_fulfill_need` and `encounter_fulfill_need_area` as separate classes with copied logic. The correct pattern is one effect that accepts targeting options. One class, one place to fix bugs, and the JSON author discovers all targeting options in one effect type.

**Read the code path end-to-end before implementing.** Trace from the beast JSON definition through spawning, movement, interaction resolution, and ascension. Identify every place where a value is read without modifier support, where an event fires without a corresponding trigger hook, or where behavior is hard-coded that could be data-driven. Propose fixes for what you find.
