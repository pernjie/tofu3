# Guide: Creating New Stalls

## Overview

Stalls are the structures players place on the board to serve guests. Each stall fulfills a specific need type and follows one of three operation models: **product** (instant service, finite stock), **service** (guests occupy the stall for multiple turns), or **bulk_service** (guests wait for capacity to fill, then all are served together). Stalls are defined by JSON files and optionally reference skills for unique behavior.

**Data flow:** `data/stalls/<id>.json` -> `ContentRegistry` loads it -> `StallDefinition` (immutable) -> `StallInstance` (mutable runtime state)

Stalls are played as cards. The `StallDefinition` extends `CardDefinition`. When played, a `StallInstance` is created on the board at the chosen position. Playing a stall card onto an existing stall of the same type upgrades it instead. Shop purchase price is determined automatically by the card's rarity (see `CardDefinition.RARITY_PRICES`).

You never touch GDScript to add a basic stall. New stalls are pure data. You only write code when the stall needs behavior that can't be expressed with existing skill building blocks.

## Stall JSON Anatomy

Create `data/stalls/<id>.json`:

```json
{
  "$schema": "./_schema.json",
  "id": "my_stall",
  "display_name_key": "STALL_MY_STALL_NAME",
  "description_key": "STALL_MY_STALL_DESC",
  "rarity": "common",

  "card_type": "stall",
  "hero_id": "",

  "operation_model": "product",
  "need_type": "food",

  "tiers": [
    { "tier": 1, "cost_to_guest": 3, "value": 2, "restock_amount": 2, "restock_duration": 2 },
    { "tier": 2, "cost_to_guest": 3, "value": 3, "restock_amount": 2, "restock_duration": 2 },
    { "tier": 3, "cost_to_guest": 3, "value": 5, "restock_amount": 2, "restock_duration": 2 }
  ],

  "placement_restriction": null,
  "tags": ["food_stall", "product"]
}
```

### Top-Level Fields

| Field | Required | Notes |
|-------|----------|-------|
| `id` | Yes | Unique identifier, matches filename |
| `display_name_key` | Yes | Localization key. Convention: `STALL_<ID>_NAME` |
| `description_key` | No | Convention: `STALL_<ID>_DESC` |
| `rarity` | No | `common`, `rare`, `epic`, `legendary`. Defaults to `common` |
| `icon_path` | No | Path to icon resource |
| `sprite_sheet` | No | Path to sprite sheet resource |
| `card_type` | Yes | Always `"stall"` |
| `hero_id` | No | Empty string for neutral cards, hero ID for hero-specific cards |
| `operation_model` | Yes | `"product"`, `"service"`, or `"bulk_service"` — determines how the stall serves guests |
| `need_type` | Yes | `"food"` or `"joy"` — what need this stall fulfills |
| `tiers` | Yes | Array of tier progression data (at least 1) |
| `placement_restriction` | No | Placement rule ID, or `null` for unrestricted |
| `animations` | No | Animation data for sprites |
| `tags` | No | Freeform tags for filtering and game logic |

### Shop Price vs Cost to Guest

These are two separate economies — don't confuse them:

- **Shop price** (token cost to purchase the card) is **not set in JSON**. It is determined automatically by the card's `rarity` via `CardDefinition.RARITY_PRICES`. All commons cost the same, all rares cost the same, etc. Balance a stall's power through its tier stats and skills, not its price.
- **`cost_to_guest`** (in tier data) is the **money the guest pays** when served. This IS tuned per stall and per tier as a core part of the stall's identity and progression.

### Tier Data

Tiers define how the stall scales when upgraded. Each tier object has fields shared by both operation models plus fields specific to one model:

**Shared fields:**

| Field | Notes |
|-------|-------|
| `tier` | Tier number (1, 2, 3, ...) |
| `cost_to_guest` | Money the guest pays for service |
| `value` | How much of the need is fulfilled |

**Product-only fields:**

| Field | Notes |
|-------|-------|
| `restock_amount` | Units of stock restored on restock (also initial stock at tier) |
| `restock_duration` | Turns of cooldown before automatic restock |

**Service and bulk_service fields:**

| Field | Notes |
|-------|-------|
| `service_duration` | Number of turns guests are served (after capacity fills for bulk_service) |
| `capacity` | Maximum simultaneous guests (required fill count for bulk_service) |

**Both models (optional):**

| Field | Notes |
|-------|-------|
| `skills` | Array of skill references active at this tier (see Skills section) |

You can include all fields on every tier — the irrelevant ones are simply ignored based on `operation_model`. But for clarity, only include what applies.

**One dimension per tier.** Each stall picks a single scaling dimension — the one thing that improves across tiers. All other stats stay constant. This keeps each stall's upgrade path readable and distinct: a player can look at the tier progression and immediately understand what upgrading does.

Scaling dimensions (pick one):
- **Value:** more need fulfilled per service (the simplest upgrade)
- **Efficiency:** reduced `restock_duration` or `service_duration`
- **Capacity:** more guests served simultaneously (service stalls)
- **Stock:** more `restock_amount` per cycle (product stalls)
- **Skill power:** per-tier parameter overrides or unlocking new skills at higher tiers (see Scaling Skills with Tiers below)

`cost_to_guest` may increase alongside the scaling dimension as an economic reward for upgrading — but it should not be the primary upgrade axis. It follows from the stall getting stronger, not the other way around.

Do **not** scale multiple dimensions simultaneously (e.g. value + capacity) or alternate dimensions between tiers (e.g. value at T2, then capacity at T3). If a stall concept feels like it needs two scaling axes, split it into two stalls or choose the axis that defines its identity.

## Operation Models

### Product Stalls

Product stalls serve guests **instantly** when entered. The guest pays, the need is fulfilled, and one unit of stock is consumed — all in the same turn.

**Lifecycle:**
1. Stall starts with `restock_amount` units of stock
2. Guest enters an adjacent stall → `can_serve_guest()` checks stock > 0
3. Service is immediate: need fulfilled, stock decremented
4. When stock hits 0 → `restock_cooldown` starts from `restock_duration`
5. Each turn start: cooldown ticks down by 1
6. When cooldown reaches 0 → stock refilled to `restock_amount`

**Key tension:** Product stalls are fast but run out. `restock_duration` is the tuning lever: low values mean the stall is almost always available; high values mean depletion is a real cost.

**Example — Noodle Stand:**
```json
{
  "operation_model": "product",
  "need_type": "food",
  "tiers": [
    { "tier": 1, "cost_to_guest": 3, "value": 2, "restock_amount": 2, "restock_duration": 2 },
    { "tier": 2, "cost_to_guest": 3, "value": 2, "restock_amount": 3, "restock_duration": 2 },
    { "tier": 3, "cost_to_guest": 3, "value": 2, "restock_amount": 4, "restock_duration": 2 }
  ]
}
```

Scaling dimension: **stock**. Each tier restocks at the same speed and serves the same food value, but carries more stock before depleting. The stall goes from serving 2 guests per restock cycle to 4.

### Service Stalls

Service stalls hold guests for **multiple turns** before fulfilling their need. Guests occupy a slot in the stall and a timer counts down each turn during the service resolution phase.

**Lifecycle:**
1. Guest enters an adjacent stall → `can_serve_guest()` checks occupants < capacity
2. Guest occupies a slot, timer set to `service_duration × service_duration_multiplier` (guest stat)
3. Each service resolution phase: timer ticks down by 1
4. When timer reaches 0 → `on_pre_serve` triggers fire (can block). If not blocked, need is fulfilled and guest is charged
5. Guest exits the stall slot (but may remain on the tile if other needs exist)

**Key tension:** Service stalls never run out, but they're slow. Capacity is the bottleneck — a stall with `capacity: 2` can only process 2 guests at once. `service_duration` and `capacity` are the tuning levers.

**Example — Game Booth:**
```json
{
  "operation_model": "service",
  "need_type": "joy",
  "tiers": [
    { "tier": 1, "cost_to_guest": 2, "value": 2, "service_duration": 2, "capacity": 1 },
    { "tier": 2, "cost_to_guest": 2, "value": 2, "service_duration": 2, "capacity": 2 },
    { "tier": 3, "cost_to_guest": 2, "value": 2, "service_duration": 2, "capacity": 3 }
  ]
}
```

Scaling dimension: **capacity**. Each tier serves the same joy value at the same speed, but handles more guests simultaneously. The bottleneck loosens with each upgrade.

### Bulk Service Stalls

Bulk service stalls require **all capacity slots to fill** before service begins. Guests that enter early wait for others. If they wait too long, they leave unfulfilled.

**Lifecycle:**
1. Guest enters an adjacent stall → `can_serve_guest()` checks occupants < capacity AND `bulk_phase != SERVING`
2. Stall transitions to `WAITING` phase (if not already)
3. Guest gets a wait timer (3 turns). All other waiting occupants get their timers reset to 3
4. Each service resolution: wait countdown ticks. If a guest's timer hits 0, they exit unfulfilled
5. When occupant count == capacity → stall transitions to `SERVING`
6. Service duration is calculated as `avg(all guest service_duration_multipliers) × base_duration`
7. From here, same as service stalls: timer ticks down, `on_pre_serve` fires per guest, need fulfilled, guest charged
8. After all individual `on_serve` events: `on_bulk_serve` fires once with all guests (group-level skills)
9. Stall transitions back to `IDLE`

**Key tension:** Bulk service stalls offer group-level effects but require coordination. The wait timer creates urgency — if guests arrive too far apart, early arrivals time out. This rewards path layouts that funnel guests to the stall together. The `on_bulk_serve` trigger is the hook for group-level skills (e.g., banish the weakest, buff all served guests).

**Wait timer behavior:**
- Each new arrival resets ALL waiting occupants' timers (not just their own)
- Timeout exits do NOT reset other guests' timers — only new arrivals do
- The wait duration is 3 turns (constant `BULK_WAIT_DURATION` in TurnSystem)

**Example — Bonfire:**
```json
{
  "operation_model": "bulk_service",
  "need_type": "joy",
  "tiers": [
    { "tier": 1, "cost_to_guest": 2, "value": 3, "service_duration": 2, "capacity": 2,
      "skills": [{ "skill_id": "banish_weakest_after_bulk" }] },
    { "tier": 2, "cost_to_guest": 2, "value": 4, "service_duration": 2, "capacity": 2 },
    { "tier": 3, "cost_to_guest": 2, "value": 5, "service_duration": 2, "capacity": 3 }
  ]
}
```

Scaling dimension: **value** (T1→T2) then **capacity** at T3. The stall requires 2 guests to start, serves good joy, and has a group-level skill at T1. T3 increases the required group size to 3 for a larger service.

## Designing Stall Identity

A stall's identity comes from the combination of its **operation model**, **tier progression**, and **skills**. Two food stalls with different operation models play very differently even if they fulfill the same need.

## Skills

Each tier's `skills` array defines the skills active at that tier. Skills are referenced by ID, with optional parameter overrides:

```json
"tiers": [
  {
    "tier": 1, "cost_to_guest": 3, "value": 2, "restock_amount": 2, "restock_duration": 2,
    "skills": [
      { "skill_id": "bonus_tokens_on_serve" },
      { "skill_id": "aura_buff", "parameters": { "range": 2, "stat": "value", "bonus": 1 } }
    ]
  }
]
```

Parameter overrides let multiple tiers use the same skill definition with different tuning. The skill definition provides defaults; the tier's `"parameters"` override them at the instance level.

### Stall-Owned Skills

Stall-owned skills use `"owner_types": ["stall"]` in their skill JSON. They fire when the stall is involved in the trigger event.

**Example — Bonus tokens on each service:**
```json
{
  "id": "profitable_stall",
  "display_name_key": "SKILL_PROFITABLE_STALL_NAME",
  "description_key": "SKILL_PROFITABLE_STALL_DESC",
  "owner_types": ["stall"],
  "trigger_type": "on_serve",
  "parameters": {
    "bonus": { "type": "int", "default": 1, "min": 1, "max": 5 }
  },
  "conditions": [],
  "effects": [
    { "type": "grant_tokens", "target": "player", "amount": "{bonus}" }
  ],
  "tags": ["economy"]
}
```

This fires after any guest is served at the stall that owns this skill. The stall in JSON would reference it as `{ "skill_id": "profitable_stall", "parameters": { "bonus": 2 } }`.

**Example — Apply status to guests on entry:**
```json
{
  "id": "welcoming_aura",
  "display_name_key": "SKILL_WELCOMING_AURA_NAME",
  "description_key": "SKILL_WELCOMING_AURA_DESC",
  "owner_types": ["stall"],
  "trigger_type": "on_enter_stall",
  "parameters": {
    "status": { "type": "string", "default": "well_fed" },
    "stacks": { "type": "int", "default": 1 }
  },
  "conditions": [],
  "effects": [
    { "type": "apply_status", "target": "guest", "status_id": "{status}", "stacks": "{stacks}" }
  ],
  "tags": ["buff"]
}
```

This fires when any guest enters the stall. The context provides both the guest and the stall, so `"target": "guest"` refers to the entering guest.

### Scaling Skills with Tiers

Tiers don't just scale raw stats like `value` and `restock_amount` — they can also scale skill behavior through parameter overrides.

Each tier fully encapsulates its skills. When a stall upgrades, skills are diffed against the previous tier:
- Skills present in both tiers are carried over (preserving runtime state like counters), with parameter overrides updated from the new tier
- New skills are created and registered with the trigger system
- Removed skills are unregistered and discarded

This enables two design patterns:
- **Parameter scaling:** Same skill at every tier with increasing values
- **Skill unlocking:** New skills appearing at higher tiers

**Example — a stall that scales bonus tokens and unlocks an aura at T3:**

```json
"tiers": [
  {
    "tier": 1, "cost_to_guest": 3, "value": 2, "restock_amount": 2, "restock_duration": 2,
    "skills": [
      { "skill_id": "profitable_stall", "parameters": { "bonus": 1 } }
    ]
  },
  {
    "tier": 2, "cost_to_guest": 3, "value": 2, "restock_amount": 2, "restock_duration": 2,
    "skills": [
      { "skill_id": "profitable_stall", "parameters": { "bonus": 2 } }
    ]
  },
  {
    "tier": 3, "cost_to_guest": 3, "value": 2, "restock_amount": 2, "restock_duration": 2,
    "skills": [
      { "skill_id": "profitable_stall", "parameters": { "bonus": 3 } },
      { "skill_id": "welcoming_aura", "parameters": { "status": "well_fed", "stacks": 2 } }
    ]
  }
]
```

Scaling dimension: **skill power**. Base stats stay flat — the stall serves the same food at the same speed across all tiers. What improves is the skill: bonus tokens scale from 1→2→3, and T3 unlocks a new aura. The stall's identity comes entirely from its skills, not its raw stats. The `profitable_stall` skill instance is preserved across upgrades (keeping any runtime counters), while `welcoming_aura` is newly created at T3.

### Stall-Relevant Trigger Types

| Trigger | Fires When | Entity Scope | Notes |
|---------|-----------|--------------|-------|
| `on_place` | Stall placed on board | stall only | Good for one-time setup effects |
| `on_upgrade` | Stall upgraded to next tier | stall only | Context includes new tier as `amount` |
| `on_restock` | Stall restocks | stall only | Product stalls only |
| `on_serve` | Guest served at stall (post-service) | guest + stall | Both guest's and stall's skills fire |
| `on_pre_serve` | Before service resolves | guest + stall | Can block via `service_result`. Both entities' skills fire |
| `on_pre_fulfill` | Before need fulfillment resolves | guest + source | Universal interception — fires for ALL fulfillment, not just stall service |
| `on_enter_stall` | Guest enters stall | guest + stall | Both entities' skills fire |
| `on_bulk_serve` | All guests in a bulk_service stall complete service | stall only | `context.guests` has the full group. Fires once after individual `on_serve` events |
| `on_remove` | Stall removed from board | stall only | Cleanup effects |
| `on_turn_start` / `on_turn_end` | Turn boundaries | global | Any skill can react regardless of owner |

**Entity scoping matters.** For `on_serve`, `on_pre_serve`, and `on_enter_stall`, both the guest's and the stall's skills fire. For `on_place`, `on_upgrade`, `on_restock`, and `on_remove`, only the stall's own skills fire — unless another entity (e.g., a relic) has a `global: true` skill on the same trigger type, in which case that skill also fires as a global observer. See the [guest guide](guide-creating-guests.md) for the full trigger type reference and the [relic guide](guide-creating-relics.md) for how global observers work.

### Pre-Serve Interception

The `on_pre_serve` trigger is the interception point for modifying or blocking service. The `TriggerContext.service_result` dict is mutable — effects can set:

- `service_result["blocked"] = true` — prevents the service entirely
- `service_result["fulfillment_multiplier"]` — scales the amount of need fulfilled
- `service_result["fulfillment_bonus"]` — adds flat bonus to need fulfilled

This is how effects like `chance_block_service` work. A stall could own a pre-serve skill that, say, doubles fulfillment for the first service each turn.

### Pre-Fulfill Interception

The `on_pre_fulfill` trigger is a **universal** interception point for ALL need fulfillment — not just stall service. It fires inside `BoardSystem.fulfill_guest_need()`, which is the single funnel for all fulfillment regardless of source (stalls, spells, skills, status effects). The `TriggerContext.fulfillment_result` dict is mutable:

- `fulfillment_result["blocked"] = true` — prevents the fulfillment entirely
- `fulfillment_result["fulfillment_multiplier"]` — scales the amount fulfilled
- `fulfillment_result["fulfillment_bonus"]` — adds flat bonus to amount fulfilled

**Key difference from `on_pre_serve`:** Pre-serve fires before stall service specifically (and can block the entire service transaction). Pre-fulfill fires for any fulfillment and only modifies the amount. For stall service, both compose: pre-serve modifiers produce a `final_value`, which pre-fulfill then further modifies.

The `modify_fulfillment` effect works in both contexts — it writes to whichever result dict is active.

### Shared Triggers

For `on_serve` and `on_enter_stall`, both the guest's and the stall's skills fire. This means:
- A guest with a "tip extra at food stalls" skill reacts to being served at any food stall
- A stall with a "grant bonus tokens" skill reacts to any guest being served there
- Both skills fire independently in the same trigger cycle

Design skills with this in mind — avoid creating pairs of guest + stall skills that produce unintended double effects.

## Modifier Support

StallInstance routes stat lookups through a `ModifierStack`, which means status effects and skills can modify stall stats at runtime.

**Currently modifier-aware stats:**

| Accessor | Stat Key | What It Controls |
|----------|----------|-----------------|
| `get_cost_to_guest()` | `"cost_to_guest"` | Money charged to guest |
| `get_value()` | `"value"` | Need fulfilled per service |

**Currently raw (no modifier support):**

| Accessor | What It Returns |
|----------|----------------|
| `get_capacity()` | Raw tier data |
| `get_service_duration()` | Raw tier data |

If a new stall design needs to modify capacity or service duration via skills/status effects, those accessors should be routed through `get_stat()` first. See the Proposing Refactors section.

## Future: Enhancements

The `StallInstance` has an `enhancement` field reserved for a future enhancement system (analogous to card upgrades). This is not yet implemented — when it is, enhancements will modify stats, add skills, or alter stall behavior. The guide will be updated when this feature lands.

## Testing

Every new stall with skills needs integration tests. Tests verify the skill fires correctly and produces the expected state change. See [testing.md](testing.md) for the full framework reference.

### Which file?

Tests are grouped by **trigger type**. A stall with an `on_pre_serve` skill gets tested in `test/integration/test_on_serve_skills.gd`. A stall with an `on_restock` skill goes in `test_on_restock_skills.gd`. If a stall has skills on multiple triggers, add tests to each relevant file.

### Pattern

Create an inner class per stall skill:

```gdscript
# test/integration/test_on_serve_skills.gd

class TestMyStallBonusTokens:
    extends "res://test/helpers/test_base.gd"

    func test_grants_bonus_tokens_on_serve():
        var guest = create_guest("hungry_ghost")
        var stall = create_stall("my_stall")
        register_guest(guest, Vector2i(2, 0))
        register_stall(stall, Vector2i(2, 1))

        var tokens_before = GameManager.tokens
        fire_for("on_serve", TriggerContext.create("on_serve") \
            .with_guest(guest).with_stall(stall).with_source(stall) \
            .with_target(guest), [guest, stall])

        assert_gt(GameManager.tokens, tokens_before,
            "Stall should grant bonus tokens on serve")
```

### Stall-specific considerations

- **Pre-serve interception:** Use `TriggerContext.with_service_result()` and check `context.service_result["blocked"]`, `["fulfillment_multiplier"]`, or `["fulfillment_bonus"]` after firing
- **Tier-specific skills:** Call `BoardSystem.upgrade_stall(stall)` before registering to test higher-tier skills
- **Product vs service:** Set `stall.current_stock` for product stalls, `stall.current_occupants` for service stalls to test stock/capacity conditions
- **Shared triggers:** For `on_serve` and `on_enter_stall`, pass both `[guest, stall]` to `fire_for()` since both entities' skills fire

### Running

```bash
godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_serve_skills.gd
```

## Key Files

| File | Role |
|------|------|
| `data/stalls/<id>.json` | Stall data definition |
| `data/stalls/_schema.json` | Stall JSON schema |
| `data/skills/<id>.json` | Skill data definition |
| `data/skills/_schema.json` | Skill JSON schema (includes trigger type enum) |
| `src/definitions/stall_definition.gd` | Parses stall JSON into typed resource |
| `src/definitions/stall_tier_data.gd` | Tier data resource |
| `src/definitions/card_definition.gd` | Base card fields (StallDefinition extends this) |
| `src/instances/stall_instance.gd` | Runtime stall state |
| `src/instances/skill_instance.gd` | Runtime skill state, parameter resolution |
| `src/autoload/board_system.gd` | Stall placement, service, restock, spatial queries |
| `src/systems/turn_system.gd` | Turn phases: restock ticking, service resolution, stall entry |
| `src/systems/trigger_system.gd` | Wires EventBus signals to skill execution |
| `src/autoload/event_bus.gd` | Signal definitions |
| `src/skill_conditions/skill_condition_factory.gd` | Condition type registry |
| `src/skill_effects/skill_effect_factory.gd` | Effect type registry |

## Checklist

When adding a new stall:

- [ ] Created `data/stalls/<id>.json` with valid schema
- [ ] `card_type` is `"stall"`, `operation_model` and `need_type` are set
- [ ] Tiers are well-structured: tier numbers ascending, model-appropriate fields present
- [ ] `rarity` is set correctly (this determines shop price automatically)
- [ ] Skill IDs referenced in tier `skills` arrays exist in `data/skills/`
- [ ] If new skill JSON was created: `owner_types` includes `"stall"`, trigger type and effects are valid
- [ ] If new condition/effect code was created: registered in the corresponding factory
- [ ] Run the project — check ContentRegistry console output confirms the stall and skills loaded without warnings
- [ ] Added integration tests in the appropriate `test/integration/test_on_<trigger>_skills.gd` file (positive + negative cases)

## Proposing Refactors

The current codebase was built around a minimal demo level. When adding a stall, if you find that the existing building blocks can't cleanly express the behavior you need — or that the approach feels like a workaround rather than a natural fit — **propose a refactor before implementing a hack.**

Consider refactoring when:
- A new stall behavior requires hard-coded checks in system code rather than working through the data-driven skill pipeline
- A stat is read directly from tier data without passing through `get_stat()` where it should respect modifiers (e.g. `capacity`, `service_duration`)
- A useful trigger type doesn't exist yet (e.g. `on_deplete` for when stock runs out) and adding it would unlock a variety of stall behaviors
- You find yourself duplicating logic that should be shared between product and service stalls

### Best Practices

**Respect the operation model split.** Product, service, and bulk_service stalls have fundamentally different lifecycles. Don't try to make a hybrid — if you need behavior that crosses model boundaries, that's a signal for a new operation model or a skill-based workaround.

**Use skills for identity, tiers for power.** A stall's skill is what makes it unique. Its tiers make it stronger. Keep these concerns separate — a skill that only matters at tier 3 is harder to understand than a skill that always works but scales naturally with better tier stats.

**Keep the JSON boundary clean.** If a behavior can't be expressed purely in JSON with existing building blocks, that's a signal. Either the building blocks need extending, or a new one is needed. The goal is that most stall designs never require touching GDScript.

**Extend, don't duplicate.** If a new stall behavior is a variation of an existing effect — different targeting, different scope — extend the existing effect with a configuration option rather than creating a separate effect class.
