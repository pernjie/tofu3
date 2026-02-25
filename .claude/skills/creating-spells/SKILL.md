---
name: creating-spells
description: Use when adding a new spell, designing spell behavior, or creating spell JSON. Covers spell JSON anatomy, target types and filters, inline effects with null skill, the on_cast trigger, and when to propose new building blocks.
---

# Creating Spells

**Required reading — load these docs before proceeding:**
- `docs/guide-creating-spells.md` — full spell creation guide (JSON anatomy, target types, filters, effects, null skill constraint, on_cast trigger, testing, checklist)
- `docs/game-loop.md` — turn phases, event timing, action contracts

## Before Implementation

After reading the docs above, **stop and present a summary before writing any code or JSON:**

1. **Clarify the design.** Ask questions about anything ambiguous — target type choice, which effects to use, whether the behavior can be expressed with existing effects or needs new building blocks.
2. **Identify all changes needed.** List every file that will be created or modified: spell JSON, new effects, factory registrations. Spells rarely need new skills — if you're writing skill JSONs, reconsider whether this should be a relic or status effect instead.
3. **Flag risks.** Call out anything that doesn't fit cleanly — effects that need parameter references (won't work with null skill), behaviors that need state tracking (spells have no instance), effects that need `"self"` target (unavailable for spells).
4. **Propose redesigns over hacks.** If existing effects can't express the behavior cleanly, recommend new effect types, new target filter keys, or new target selectors. If the behavior needs persistence or reactivity, recommend delivering it via a status effect the spell applies. Confirm the approach before proceeding.

## Overview

Spells are instant-effect cards. Cast, execute effects, consumed — no board presence, no runtime instance. Effects are inline in the spell JSON (not skills). All 42 existing skill effects are available, but execute with `skill = null`.

**Data flow:** `data/spells/<id>.json` -> `ContentRegistry` -> `SpellDefinition` (immutable) -> cast at runtime (no instance)

## Key Design Principles

- **No instance, no persistence.** Spells execute and vanish. If the behavior needs to last, apply a status effect as payload.
- **Effects, not skills.** Spell effects are inline dicts, not skill references. No trigger, no conditions, no parameters — just literal values.
- **Null skill constraint.** Effects run with `skill = null`. No `"{param}"` references, no `"self"` target, no state access, no discover effect. All values must be literals.
- **Target type shapes identity.** `"none"` = global/player effect. `"tile"` = positional. `"stall"` = infrastructure. `"guest"` = individual targeting.
- **Keep spells simple.** 1-3 effects max. Complex behavior belongs on a status effect the spell applies.

## Quick Reference

**Target types:**
| Type | Player action | Context for effects |
|------|--------------|-------------------|
| `"none"` | Click card, cast immediately | `spell_definition` in extra only |
| `"tile"` | Click a tile | tile position |
| `"stall"` | Click a stall | stall + tile |
| `"guest"` | Click a guest | guest + tile |

**Available effect target selectors:** `"guest"`, `"stall"`, `"target"`, `"player"`, `"adjacent_guests"` (with `range`), `"random_guest_on_tile"` (random guest from context tile). NOT `"self"`.

**Filter keys:**
- Stall: `need_type`, `operation_model`, `has_tag`
- Guest: `has_status`, `has_tag`, `is_core_guest`
- Tile: `has_stall`, `has_guest`

**on_cast trigger:** Fires globally after spell effects resolve. Other entities (relics, stalls, guests) can react via skills with `"trigger_type": "on_cast"`. Context includes `spell_definition` and `target_pos` in extra, plus `guest`/`stall` if targeted.

## Checklist

- [ ] Created `data/spells/<id>.json` with valid schema
- [ ] `card_type` is `"spell"`
- [ ] `target_type` is the most specific type that fits
- [ ] `target_filter` set if not all entities of that type are valid
- [ ] All effect `type` values exist in `SkillEffectFactory`
- [ ] All effect values are **literals** (no `"{param}"` — null skill)
- [ ] Effect targets use valid selectors (no `"self"`)
- [ ] Any status IDs referenced exist in `data/status_effects/`
- [ ] `rarity` set correctly (determines price)
- [ ] Run project — ContentRegistry confirms spell loaded
- [ ] Integration tests in `test/integration/test_spell_system.gd`
- [ ] If effects interact with other subsystems: tests in relevant trigger file
