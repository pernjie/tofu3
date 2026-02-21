# Integration Testing

Integration tests verify skill effects by firing triggers through real systems and asserting on state changes. No mocks, no visual scene required.

## Why This Works

The architecture separates logic from visuals. All BoardSystem action methods mutate state first, then guard visual operations behind `if board_visual:`. TriggerSystem.trigger_skills() is synchronous. This means we can fire triggers, let effects execute through real systems, and check the resulting state — all without a scene tree or animation playback.

## Running Tests

Godot is not on PATH — use the full path to the binary inside the app bundle:

```bash
GODOT="/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot"

# First-time setup (imports GUT class names):
"$GODOT" --headless --import --path "$PWD"

# Run all tests:
"$GODOT" -d -s --path "$PWD" addons/gut/gut_cmdln.gd

# Run a single test file:
"$GODOT" -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_serve_skills.gd

# Run multiple test files:
"$GODOT" -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_serve_skills.gd,res://test/integration/test_on_midnight_skills.gd
```

The `-gtest` flag accepts `res://` paths (Godot resource paths, not filesystem paths). Separate multiple files with commas.

## Directory Structure

```
test/
  helpers/
    test_base.gd                    # Base class — setup/teardown + helpers
  integration/
    test_on_spawn_skills.gd         # on_spawn triggers
    test_on_serve_skills.gd         # on_serve, on_pre_serve triggers
    test_on_ascend_skills.gd        # on_ascend triggers
    test_on_enter_stall_skills.gd   # on_enter_stall triggers
    test_on_encounter_skills.gd     # on_encounter, on_interact triggers
    test_on_need_fulfilled_skills.gd # on_need_fulfilled triggers
    test_on_restock_skills.gd       # on_restock triggers (relic skills)
    test_status_effects.gd          # Status application, stacking, granted skills
    test_skill_conditions.gd        # Condition evaluation in isolation
```

Tests are grouped by **trigger type**, which maps directly to how skills fire. Within each file, **inner classes** group tests for individual guests/skills.

## Organisation Principles

### Group by trigger, not by entity

A guest's skill fires on a specific trigger. The apothecary's `restock_on_deplete` fires `on_serve` — so that test goes in `test_on_serve_skills.gd`, not a hypothetical `test_apothecary.gd`.

This keeps related tests together. All `on_serve` skills (from guests, stalls, status-granted skills) live in one file. When debugging a trigger pipeline, you look in one place.

### One inner class per skill (or per entity when closely related)

```gdscript
# test/integration/test_on_serve_skills.gd
extends "res://test/helpers/test_base.gd"

class TestApothecaryRestock:
    extends "res://test/helpers/test_base.gd"

    func test_restocks_when_stall_depleted():
        # ...

    func test_does_not_restock_when_stall_has_stock():
        # ...

class TestRestorativeYoga:
    extends "res://test/helpers/test_base.gd"

    func test_bonus_fulfillment_when_guest_has_debuff():
        # ...
```

Each inner class extends the base so it gets its own `before_each`/`after_each` isolation. The outer file also extends the base (GUT requirement for file-level structure).

### Name tests after the behaviour, not the method

```gdscript
# Good
func test_restocks_when_stall_depleted():
func test_does_not_restock_when_stall_has_stock():
func test_charms_adjacent_guests_on_ascend():

# Bad
func test_restock_on_deplete():
func test_dancer_ascend_charm():
```

### Test both the positive and negative case

Every conditional skill needs at least two tests: one where the condition passes and one where it doesn't. This catches both false-negative and false-positive execution.

## Base Class API

All tests extend `res://test/helpers/test_base.gd`, which provides:

### Lifecycle

`before_each()` resets all state between tests:

| System | Reset Method | What It Clears |
|--------|-------------|----------------|
| AnimationCoordinator | `skip_animations = true`, `clear_batch()` | Prevents animation queueing from blocking |
| BoardSystem | `clear_level()`, `relics.clear()` | active_guests, stalls, guest_queue, beast_queue, board |
| TriggerSystem | `clear_all()` | Skill registry, trigger depth, deferred requests |
| GameManager | Direct assignment | tokens = 100, reputation = 10 |
| StatusEffectSystem | Fresh instance each test | Clean status state, wired to TriggerSystem and BoardSystem |

`after_each()` disconnects non-autoload systems from BoardSystem and explicitly frees the StatusEffectSystem node (using `free()`, not `queue_free()`, to avoid orphan accumulation in GUT's test runner).

### Default Board

A 5-tile horizontal path. Tiles at `(0,0)` through `(4,0)`. Adjacent tiles are at Manhattan distance 1.

```
(0,0) — (1,0) — (2,0) — (3,0) — (4,0)
```

### Instance Helpers

```gdscript
# Create instances from real JSON definitions
var guest = create_guest("old_man")        # -> GuestInstance
var stall = create_stall("noodle_stand")   # -> StallInstance
var relic = create_relic("gourd")          # -> RelicInstance

# Place on board and register skills with TriggerSystem
register_guest(guest, Vector2i(1, 0))     # path tile
register_stall(stall, Vector2i(2, 1))     # adjacent to path (y=1)
register_relic(relic, Vector2i(1, 1))     # adjacent to path (y=1)
```

`register_guest` sets `current_tile` and derives `path_index` from the board layout. `register_stall` sets `board_position` and adds to `BoardSystem.stalls`. `register_relic` creates a standalone `Tile` for position tracking (relics are placed adjacent to path tiles, not on them).

### Trigger Helpers

```gdscript
# fire() — triggers ALL registered skills for a trigger type (global triggers)
var results = fire("on_restock", TriggerContext.create("on_restock") \
    .with_stall(stall).with_source(stall))

# fire_for() — triggers only skills owned by the specified entities
# Use this for entity-specific triggers to match production behaviour
var results = fire_for("on_spawn", TriggerContext.create("on_spawn") \
    .with_guest(guest).with_source(guest), [guest])
```

In production, most triggers use `trigger_entity_skills()` (entity-filtered), not `trigger_skills()` (global). Use `fire_for()` to match this behaviour. Use `fire()` only for truly global triggers like `on_restock` (where relic skills have `global: true`) or `on_turn_start`/`on_level_start`.

## Writing Tests by Entity Type

### Guest skills

Guests are the most common entity with skills. The pattern is always: create the guest, register it, set up any required context (other guests, stalls, status effects), fire the trigger, assert on state.

```gdscript
func test_slow_service_applies_modifier_on_spawn():
    var guest = create_guest("old_man")
    register_guest(guest, Vector2i(1, 0))

    fire_for("on_spawn", TriggerContext.create("on_spawn") \
        .with_guest(guest).with_source(guest), [guest])

    var multiplier = guest.get_stat("service_duration_multiplier", 1)
    assert_gt(multiplier, 1, "Old man should have increased service duration")
```

**Key considerations:**
- Guest needs are in `guest.current_needs` (dict of need_type -> remaining amount)
- Use `guest.get_stat(stat_name, base_value)` to check modifier effects
- For AoE effects, place multiple guests at known positions and check adjacency
- Beasts use the same `GuestInstance` class but have `interact` needs and reverse movement

### Stall skills

Stalls have tier-based skills — the skill list changes when the stall upgrades. Tier 1 is the default.

```gdscript
func test_restorative_yoga_bonus():
    var guest = create_guest("hungry_ghost")
    var stall = create_stall("yoga_mats")
    register_guest(guest, Vector2i(2, 0))
    register_stall(stall, Vector2i(2, 1))

    # Apply a debuff so the condition passes
    BoardSystem.inflict_status(guest, "charmed", 1)

    var context = TriggerContext.create("on_pre_serve") \
        .with_guest(guest).with_stall(stall).with_source(stall) \
        .with_target(guest).with_service_result()
    fire_for("on_pre_serve", context, [guest, stall])

    assert_gt(context.service_result["fulfillment_bonus"], 0,
        "Restorative yoga should add fulfillment bonus for debuffed guest")
```

**Key considerations:**
- Stalls have two operation models: `product` (stock-based, like noodle_stand) and `service` (capacity-based, like game_booth)
- Use `stall.current_stock` for product stalls, `stall.current_occupants` for service stalls
- `stall.get_service_duration()` returns the tier-specific duration
- To test upgraded stall skills, call `BoardSystem.upgrade_stall(stall)` before registering skills

### Relic skills

Relics persist across levels and fire on placement or level-wide triggers. The `create_relic` and `register_relic` helpers are provided by the base class.

```gdscript
func test_doubles_first_restock():
    var gourd = create_relic("gourd")
    register_relic(gourd, Vector2i(1, 1))
    var stall = create_stall("noodle_stand")
    register_stall(stall, Vector2i(2, 1))
    var tier_data = stall.get_current_tier_data()
    var restock_amount = tier_data.restock_amount
    stall.current_stock = restock_amount

    # on_restock is global, so fire() works
    fire("on_restock", TriggerContext.create("on_restock") \
        .with_stall(stall).with_source(stall))

    assert_eq(stall.current_stock, restock_amount * 2,
        "Gourd should double the first restock")
```

**Key considerations:**
- Relics use `on_place` triggers (fired once on placement) and passive triggers (like `on_restock`)
- Relic skills often have `global: true` — they fire regardless of which entity triggered the event. Use `fire()` for these.
- `register_relic` creates a standalone `Tile` (not from the board) since relics are placed adjacent to paths
- Test relic effects by setting up the relic, then triggering the event from another entity
- Relics can have skill state (e.g. `gourd_double_restock` tracks `restock_count`) — access via `relic.skill_instances[0].get_state(key)`

### Status effect granted skills

Status effects can grant temporary skills. The full chain: apply status -> skill gets registered -> trigger fires -> effect executes.

```gdscript
func test_charmed_registers_block_service_skill():
    var guest = create_guest("hungry_ghost")
    register_guest(guest, Vector2i(2, 0))

    BoardSystem.inflict_status(guest, "charmed", 8)

    var status = guest.get_status("charmed")
    assert_not_null(status, "Guest should have charmed status")
    # Verify the granted skill exists on the guest
    var has_block_skill = false
    for skill in guest.skill_instances:
        if skill.definition.id == "charmed_block_service":
            has_block_skill = true
            break
    assert_true(has_block_skill,
        "Charmed should grant charmed_block_service skill")
```

**Key considerations:**
- `BoardSystem.inflict_status()` applies the status AND emits `status_applied`, which triggers StatusEffectSystem to grant skills and register them with TriggerSystem
- Use `guest.get_status(status_id)` to check status presence and `.stacks` for stack count
- Use `guest.has_status(status_id)` for simple boolean checks

## Trigger Type Reference

Each trigger requires specific context fields. Use the wrong fields and conditions/effects won't find their data.

### on_spawn
Fires when a guest appears on the board. Entity-filtered to the spawned guest.
```gdscript
fire_for("on_spawn", TriggerContext.create("on_spawn") \
    .with_guest(guest).with_source(guest), [guest])
```

### on_serve / on_pre_serve
`on_pre_serve` fires before service (for interception — blocking, modifying fulfillment). `on_serve` fires after service completes. Both use entity-filtered triggers with `[guest, stall]`.
```gdscript
# Pre-serve (interception)
var context = TriggerContext.create("on_pre_serve") \
    .with_guest(guest).with_stall(stall).with_source(stall) \
    .with_target(guest).with_service_result()
fire_for("on_pre_serve", context, [guest, stall])

# Post-serve
fire_for("on_serve", TriggerContext.create("on_serve") \
    .with_guest(guest).with_stall(stall).with_source(stall) \
    .with_target(guest), [guest, stall])
```
Check `context.service_result["blocked"]`, `context.service_result["fulfillment_multiplier"]`, and `context.service_result["fulfillment_bonus"]` after pre-serve triggers.

### on_ascend
Fires when a guest ascends (exits satisfied). AoE effects typically use this. Entity-filtered.
```gdscript
fire_for("on_ascend", TriggerContext.create("on_ascend") \
    .with_guest(guest).with_source(guest), [guest])
```

### on_enter_stall
Fires when a guest enters a stall for service. Entity-filtered to both guest and stall.
```gdscript
fire_for("on_enter_stall", TriggerContext.create("on_enter_stall") \
    .with_guest(guest).with_stall(stall).with_source(guest), [guest, stall])
```

### on_need_fulfilled
Fires when a specific need is fulfilled. Entity-filtered to the guest (and source if it's a BaseInstance). The `amount` field is the fulfillment amount — conditions like `amount_check` compare against it.
```gdscript
fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
    .with_guest(guest).with_need_type("food").with_amount(2) \
    .with_source(stall), [guest, stall])
```

### on_encounter / on_interact
Two-phase beast interaction. `on_encounter` fires first (beast's skills only — e.g. `encounter_fulfill_need`, `encounter_banish`). If any effect succeeds, `on_interact` fires (both beast and guest skills — e.g. `apply_status_on_interact`, `steal_money`).
```gdscript
# on_encounter — only the beast's skills fire
fire_for("on_encounter", TriggerContext.create("on_encounter") \
    .with_guest(target).with_source(beast).with_target(target), [beast])

# on_interact — both beast and guest skills fire
fire_for("on_interact", TriggerContext.create("on_interact") \
    .with_guest(target).with_source(beast).with_target(target), [beast, target])
```
Context convention: `guest` = the regular guest being interacted with, `source` = the beast, `target` = the regular guest.

### on_pre_fulfill
Fires before need fulfillment resolves inside `BoardSystem.fulfill_guest_need()`. Entity-filtered to the guest (and source if provided). Universal — fires for all fulfillment regardless of source (stalls, spells, skills).
```gdscript
var context = TriggerContext.create("on_pre_fulfill") \
    .with_guest(guest).with_need_type("food").with_amount(2) \
    .with_target(guest).with_fulfillment_result()
# Optionally: context.with_source(stall)
fire_for("on_pre_fulfill", context, [guest])
```
Check `context.fulfillment_result["blocked"]`, `context.fulfillment_result["fulfillment_multiplier"]`, and `context.fulfillment_result["fulfillment_bonus"]` after pre-fulfill triggers.

### on_place
Fires when a stall or relic is placed. Entity-filtered to the placed entity.
```gdscript
# Stall
fire_for("on_place", TriggerContext.create("on_place") \
    .with_stall(stall).with_tile(tile).with_source(stall), [stall])

# Relic
fire_for("on_place", TriggerContext.create("on_place") \
    .with_tile(relic.tile).with_source(relic), [relic])
```

### on_restock
Fires when a stall is restocked. Entity-filtered to the stall, but relic skills with `global: true` also fire.
```gdscript
# Use fire() since global relic skills need to fire too
fire("on_restock", TriggerContext.create("on_restock") \
    .with_stall(stall).with_source(stall))
```

### on_turn_start / on_turn_end
Fires at turn boundaries. Amount is the turn number. Global (not entity-filtered).
```gdscript
fire("on_turn_start", TriggerContext.create("on_turn_start") \
    .with_amount(turn_number))
```

### on_level_start
Fires at the beginning of a level. No entity context. Global.
```gdscript
fire("on_level_start", TriggerContext.create("on_level_start"))
```

## Asserting on State

### Stat modifiers
```gdscript
# Check a modified stat (base_value is what it would be without modifiers)
var speed = guest.get_stat("movement_speed", guest.definition.base_stats.movement_speed)
assert_eq(speed, 2, "Guest should have modified speed")
```

### Guest needs
```gdscript
# Check remaining needs
assert_eq(guest.current_needs["food"], 0, "Food should be fulfilled")
assert_eq(guest.current_needs.get("joy", 0), 1, "Joy should be partially fulfilled")
```

### Stall stock
```gdscript
assert_eq(stall.current_stock, 3, "Stall should be fully stocked")
assert_gt(stall.current_stock, 0, "Stall should have been restocked")
```

### Status effects
```gdscript
assert_true(guest.has_status("charmed"), "Guest should be charmed")
assert_eq(guest.get_status("charmed").stacks, 5, "Should have 5 stacks")
```

### Board state
```gdscript
assert_eq(BoardSystem.active_guests.size(), 3, "Should have 3 guests on board")
assert_eq(GameManager.tokens, 105, "Should have earned 5 tokens")
```

### Service result (pre-serve interception)
```gdscript
assert_true(context.service_result["blocked"], "Service should be blocked")
assert_eq(context.service_result["fulfillment_bonus"], 2, "Should add bonus")
```

### Fulfillment result (pre-fulfill interception)
```gdscript
assert_true(context.fulfillment_result["blocked"], "Fulfillment should be blocked")
assert_eq(context.fulfillment_result["fulfillment_bonus"], -1, "Should reduce by 1")
assert_eq(context.fulfillment_result["fulfillment_multiplier"], 1.0, "Multiplier unchanged")
```

### Guest flags
```gdscript
assert_true(guest.force_ascend, "Guest should be forced to ascend")
assert_true(guest.is_banished, "Guest should be banished")
assert_true(guest.is_exiting, "Guest should be marked as exiting")
```

### Skill state
```gdscript
var skill = relic.skill_instances[0]
assert_eq(skill.get_state("restock_count", -1), 1, "Should track restock count")
```

## What Tests Don't Cover

- **Turn simulation** — full multi-turn sequences need `await` for `play_batch()`, which isn't available without a running scene tree
- **Visual regression** — animations are skipped entirely
- **Chance-based effects** — effects with random chance (like `charmed_block_service` with 25% chance) can't be tested deterministically without seeding; test the deterministic path instead (condition met -> effect fires)
- **Deferred/UI effects** — effects like `discover` that return deferred requests for UI resolution (player choice) can't be tested headlessly
- **UI interactions** — card playing, drag-and-drop, etc.
