# Design: Spell System

## Overview

Spells are instant-effect cards. The player casts a spell by selecting a target tile (or no target), effects fire once using the existing skill effect pipeline, and the card is consumed.

**Data flow:** `data/spells/<id>.json` → `ContentRegistry` → `SpellDefinition` (immutable) → cast at runtime (no instance class)

Unlike stalls and relics, spells have **no board presence and no runtime instance**. They execute and disappear. Lasting effects are achieved by applying status effects to targets.

## Spell JSON Anatomy

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

### Top-Level Fields

| Field | Required | Notes |
|-------|----------|-------|
| `id` | Yes | Unique identifier, matches filename |
| `display_name_key` | Yes | Localization key. Convention: `SPELL_<ID>_NAME` |
| `description_key` | No | Convention: `SPELL_<ID>_DESC` |
| `rarity` | No | `common`, `rare`, `epic`, `legendary`. Defaults to `common` |
| `card_type` | Yes | Always `"spell"` |
| `hero_id` | No | Empty string for neutral cards, hero ID for hero-specific |
| `target_type` | Yes | `"none"`, `"tile"`, `"stall"`, or `"guest"` |
| `target_filter` | No | Upfront validation dict for valid targets (see below) |
| `effects` | Yes | Array of skill effects, executed in order on cast |
| `tags` | No | Freeform tags for filtering and game logic |

### Key Differences from Other Card Types

- **No tiers** — spells are flat, no upgrade progression
- **No skills array** — spells don't persist, so no persistent skills. Lasting effects use status effects
- **No operation model** — spells are always instant
- **No board presence** — consumed on cast, no StallInstance/RelicInstance equivalent
- **Shop price** is determined by rarity via `CardDefinition.RARITY_PRICES`, same as all cards

## Target Types & Validation

### Target Types

| `target_type` | Player action | Context built with |
|---|---|---|
| `"none"` | No tile selection, cast immediately | No target tile/entity |
| `"tile"` | Click any valid tile | Target tile position |
| `"stall"` | Click a tile containing a stall | Target tile + stall |
| `"guest"` | Click a tile containing a guest | Target tile + guest |

### Target Filter

The `target_filter` dict provides upfront validation. During targeting, tiles that don't pass the filter are visually disabled, preventing the player from wasting a spell on an invalid target.

**For `"stall"` targets:**

| Key | Values | Example |
|-----|--------|---------|
| `need_type` | `"food"`, `"joy"` | `{ "need_type": "food" }` |
| `operation_model` | `"product"`, `"service"`, `"bulk_service"` | `{ "operation_model": "product" }` |
| `has_tag` | any stall tag | `{ "has_tag": "food_stall" }` |

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

The filter vocabulary is intentionally small. If a spell needs complex validation beyond this, extend the vocabulary rather than building a generic query engine.

## Cast Execution Flow

When the player casts a spell in `game.gd`:

1. **Player clicks card** → enters targeting mode (or casts immediately for `"none"`)
2. **Player clicks valid tile** → `_cast_spell()` is called
3. **Build TriggerContext** — populate with target tile, target guest/stall based on `target_type`
4. **Execute effects** — iterate `SpellDefinition.effects`, create each via `SkillEffectFactory`, execute with the context
5. **Consume card** — `deck_system.play_card()` sets location to `REMOVED`
6. **Emit `spell_cast` signal** — `EventBus.spell_cast.emit(spell_def, target_pos, target_entity)`
7. **Fire `on_cast` trigger** — TriggerSystem fires global trigger so other entities can react
8. **Flush animations** — `await AnimationCoordinator.play_batch()`

### Context Passed to Effects

| `target_type` | Context fields |
|---|---|
| `"none"` | `extra.spell_definition` |
| `"tile"` | `extra.spell_definition`, tile position |
| `"stall"` | `extra.spell_definition`, stall, tile position |
| `"guest"` | `extra.spell_definition`, guest, tile position |

No `SkillInstance` is needed. Effects are created and executed inline — there's no persistent skill to track state. The spell definition is passed as `extra` on the context so effects and `on_cast` responders can inspect it.

## The `on_cast` Trigger

A new global trigger that fires after spell effects resolve. This lets other entities react to spellcasting.

**EventBus signal:**
```gdscript
signal spell_cast(spell_definition: SpellDefinition, target_pos, target_entity)
```

**TriggerSystem handler:**
```gdscript
func _on_spell_cast(spell_def, target_pos, target_entity) -> void:
    var context = TriggerContext.create("on_cast")
    context.with_source(null)
    context.with_extra({"spell_definition": spell_def, "target_pos": target_pos})
    if target_entity:
        if target_entity is GuestInstance:
            context.with_guest(target_entity)
        elif target_entity is StallInstance:
            context.with_stall(target_entity)
    trigger_skills("on_cast", context)
```

This is a **global** trigger — any entity's skills can react (relics, stalls, guests). Entity-scoped filtering is done via conditions on individual skills.

**Example — relic that grants tokens on any spell cast:**
```json
{
  "id": "spell_synergy",
  "owner_types": ["relic"],
  "trigger_type": "on_cast",
  "conditions": [],
  "effects": [
    { "type": "grant_tokens", "target": "player", "amount": 1 }
  ]
}
```

**Additions needed:**
- `on_cast` added to `data/skills/_schema.json` trigger type enum
- `spell_cast` signal added to `EventBus`
- Handler connected in TriggerSystem

## Implementation Scope

### Changes needed

**Data layer:**
- Create `data/spells/_schema.json`
- Add `on_cast` to `data/skills/_schema.json` trigger type enum

**EventBus (`src/autoload/event_bus.gd`):**
- Add `spell_cast` signal

**TriggerSystem (`src/systems/trigger_system.gd`):**
- Connect `spell_cast` signal
- Add `_on_spell_cast` handler (global trigger)

**game.gd (`src/game/game.gd`):**
- Add spell handling in `_on_slot_clicked()` (alongside stall/relic paths)
- Add `_cast_spell()` — build context, execute effects, consume card, emit signal
- Add target validation using `target_type` + `target_filter`

### Already exists (no changes needed)

- `SpellDefinition` — already has `target_type`, `target_filter`, `effects`
- `ContentRegistry` — already loads `"spells"` type
- `DeckSystem` — already handles spell cards (sets to `REMOVED` on play)
- `SkillEffectFactory` — all 42 existing effects available to spells
- `SkillConditionFactory` — all 16 existing conditions available

### Not needed

- `SpellInstance` — no persistent state, no board presence
- New effect types — reuses existing pipeline
- New condition types — reuses existing pipeline

### Not in scope (future)

- Targeting UI (greying out invalid tiles) — depends on board visual implementation, separate task
- Spell-specific condition types (e.g., `spell_tag_check` for `on_cast` responders) — add when first needed
- Spell content (actual spell JSONs) — separate creative task after the system works
