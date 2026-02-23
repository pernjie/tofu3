# Spirit Hall — Design Document

## Fantasy

A mystical preparation chamber that attunes guests to the spirit world. Guests who pass through can no longer interact with mundane vendors, but their connection to mythical beasts is amplified — all beneficial effects from beast encounters are doubled.

**Core tension:** The player bets that beasts will show up to carry spirit-attuned guests. High capacity and low cost make it easy to funnel guests through, but if no beasts appear, those guests walk the rest of the path with unfulfilled needs.

## Stall Definition

**File:** `data/stalls/spirit_hall.json`

```json
{
  "$schema": "./_schema.json",
  "id": "spirit_hall",
  "display_name_key": "STALL_SPIRIT_HALL",
  "card_type": "stall",
  "operation_model": "service",
  "need_type": "joy",
  "tiers": [
    {
      "tier": 1,
      "cost_to_guest": 1,
      "value": 1,
      "service_duration": 2,
      "capacity": 3,
      "skills": [
        { "skill_id": "spirit_hall_apply_attuned" }
      ]
    }
  ]
}
```

**Design rationale:**
- Low value (1) — the stall is a setup piece, not a payoff
- Low cost (1) — cheap entry since you're gambling on beasts
- Short duration (2) — quick turnaround to get guests onto the beast path
- High capacity (3) — funnel multiple guests through simultaneously

## Status Effect

**File:** `data/status_effects/spirit_attuned.json`

```json
{
  "$schema": "./_schema.json",
  "id": "spirit_attuned",
  "display_name_key": "STATUS_SPIRIT_ATTUNED_NAME",
  "description_key": "STATUS_SPIRIT_ATTUNED_DESC",
  "effect_type": "buff",
  "stack_type": "passive",
  "max_stacks": 1,
  "applicable_to": ["guest"],
  "granted_skills": [
    { "skill_id": "spirit_attuned_block_entry" },
    { "skill_id": "spirit_attuned_double_encounter" }
  ],
  "tags": ["buff"]
}
```

**Design rationale:**
- `buff` — the player chose this; it's a positive strategic choice
- `passive` — permanent for the rest of the level, no timer decay (like Wet's blocking but without the countdown)
- Two granted skills handle the two halves of the effect

## Skills

### 1. `spirit_hall_apply_attuned` — Stall skill

**File:** `data/skills/spirit_hall_apply_attuned.json`

Applies the `spirit_attuned` status when a guest is served at the Spirit Hall.

```json
{
  "$schema": "./_schema.json",
  "id": "spirit_hall_apply_attuned",
  "owner_types": ["stall"],
  "trigger_type": "on_serve",
  "effects": [
    {
      "type": "apply_status",
      "target": "guest",
      "status_id": "spirit_attuned",
      "stacks": 1
    }
  ]
}
```

### 2. `spirit_attuned_block_entry` — Granted skill (blocks stall entry)

**File:** `data/skills/spirit_attuned_block_entry.json`

Prevents the guest from entering any stall. Same pattern as `wet_block_entry`.

```json
{
  "$schema": "./_schema.json",
  "id": "spirit_attuned_block_entry",
  "owner_types": ["guest"],
  "trigger_type": "on_pre_enter_stall",
  "effects": [
    { "type": "block_entry" }
  ]
}
```

### 3. `spirit_attuned_double_encounter` — Granted skill (doubles beast benefits)

**File:** `data/skills/spirit_attuned_double_encounter.json`

Sets the `benefit_multiplier` on the encounter context before beast skills fire.

```json
{
  "$schema": "./_schema.json",
  "id": "spirit_attuned_double_encounter",
  "owner_types": ["guest"],
  "trigger_type": "on_pre_encounter",
  "effects": [
    {
      "type": "modify_encounter",
      "benefit_multiplier": 2.0
    }
  ]
}
```

## Code Changes

### New: `on_pre_encounter` trigger hook

**File:** `src/systems/turn_system.gd` — `_resolve_beast_interactions()`

Add a pre-encounter trigger that fires on the **target guest** before the beast's `on_encounter` skills execute. Follows the same pattern as `on_pre_serve`, `on_pre_status`, and `on_pre_banish`.

**Flow:**

1. Beast arrives on tile with a guest
2. **NEW:** Create `encounter_result` dict on context: `{ "benefit_multiplier": 1.0, "blocked": false }`
3. **NEW:** Fire `on_pre_encounter` on the target guest's skills
   - `spirit_attuned_double_encounter` sets `benefit_multiplier` to 2.0
4. Check `encounter_result.blocked` — if true, skip this encounter entirely
5. Beast's `on_encounter` skills fire as normal, with the context carrying the multiplier

### Modified: Beast encounter effects read `benefit_multiplier`

Only specific "beneficial" effect types opt into the multiplier. This is explicit — no ambiguity about what counts as positive.

**Effects that read `encounter_result.benefit_multiplier`:**
- `fulfill_need` — scales `amount` (e.g. 2 * 2.0 = 4 food)
- `remove_status` with `status_filter: "debuff"` — scales `count` (e.g. 1 * 2.0 = removes 2 debuffs)

**Effects that ignore the multiplier (unchanged):**
- `apply_status` (Lost, Charmed, etc.)
- `banish`
- `steal_money`

### New: `modify_encounter` skill effect

**File:** `src/skill_effects/modify_encounter_effect.gd`

Registered in `skill_effect_factory.gd`. Reads `benefit_multiplier` parameter and writes it to `context.encounter_result`. Same pattern as `modify_fulfillment` / `modify_service` effects.

## What's NOT Needed

- No new skill conditions
- No changes to BoardSystem
- No changes to StatusEffectSystem
- No changes to stall/guest instance classes
- No new trigger types beyond `on_pre_encounter`

## Interaction Examples

### Tanuki + Spirit Attuned guest
- Normal: fulfills 2 food, steals 50% money
- Spirit Attuned: fulfills **4 food**, steals 50% money (unchanged)

### Baku + Spirit Attuned guest
- Normal: removes 1 debuff, fulfills 1 random need
- Spirit Attuned: removes **2 debuffs**, fulfills **2** random need

### Nine-Tailed Fox + Spirit Attuned guest
- Normal: fulfills 2 joy, applies Charmed
- Spirit Attuned: fulfills **4 joy**, applies Charmed (unchanged)

### Hanzaki + Spirit Attuned guest
- Normal: banishes if guest needs <= beast needs
- Spirit Attuned: **same** — banish doesn't read the multiplier

### No beasts on the board
- Guest walks the entire remaining path with unfulfilled needs — the gamble failed

## Testing Plan

### Integration tests needed:
1. Spirit Hall applies `spirit_attuned` status on serve
2. Spirit-attuned guest cannot enter stalls (block_entry)
3. Spirit-attuned guest receives doubled fulfillment from beast encounters
4. Spirit-attuned guest receives doubled debuff removal from beast encounters
5. Negative beast effects (apply_status, steal_money, banish) are NOT doubled
6. `on_pre_encounter` with `blocked: true` prevents the encounter entirely
7. Non-attuned guests are unaffected (benefit_multiplier defaults to 1.0)
