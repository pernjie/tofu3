---
name: creating-relics
description: Use when adding a new relic, designing relic behavior, or creating relic JSON. Covers relic JSON anatomy, global skill scoping, persistent state, the discover pattern, and cross-level persistence.
---

# Creating Relics

**Required reading — load these docs before proceeding:**
- `docs/guide-creating-relics.md` — full relic creation guide (JSON anatomy, global skills, persistent state, discover pattern, testing, checklist)
- `docs/game-loop.md` — turn phases, event timing, action contracts, deferred effects pattern

## Before Implementation

After reading the docs above, **stop and present a summary before writing any code or JSON:**

1. **Clarify the design.** Ask questions about anything ambiguous — what the relic's effect should be, trigger scoping, whether it needs persistent state or deferred effects, intended power level vs board slot cost.
2. **Identify all changes needed.** List every file that will be created or modified: relic JSON, skill JSONs, new conditions/effects, factory registrations, trigger wiring.
3. **Flag risks.** Call out anything that doesn't fit cleanly — missing trigger types, effects that need player input without a deferred handler, behaviors requiring global scoping that might fire too broadly.
4. **Propose redesigns over hacks.** If existing building blocks can't express the behavior cleanly, recommend new trigger types, new effect types, or extending the deferred pattern. Confirm the approach before proceeding.

## Overview

Relics are permanent structures that provide passive effects through skills. Once placed, a relic occupies a stall slot for the rest of the run. The card is permanently removed from the deck on play.

**Data flow:** `data/relics/<id>.json` -> `ContentRegistry` -> `RelicDefinition` (immutable) -> `RelicInstance` (mutable)

## Key Design Principles

- **Identity is entirely skills.** No tiers, no operation model, no service. The skill IS the relic.
- **`global: true` for observing other entities.** Entity-scoped triggers only fire for participants. Relics need global to observe events they don't participate in (e.g., any stall restocking).
- **Persistent state for cross-level data.** `BaseInstance.persistent_state` dict survives level transitions via `RunState.relics_on_board`.
- **Deferred effects for player input.** Discover effects register pending requests on TriggerSystem; game.gd handles the UI.
- **Permanent board cost.** A relic permanently consumes a stall slot — the effect must justify that cost.

## Quick Reference

**Global scoping rules:**
| Scenario | `global` needed? |
|----------|-----------------|
| Relic reacts to own `on_place` | No (entity-scoped) |
| Relic observes any stall's `on_restock` | Yes |
| Relic reacts to `on_turn_start` | No (already globally dispatched) |

**Discover pattern (two skills):**
1. `on_place` skill — `discover` effect presents options, stores choice in `persistent_state`
2. `on_level_start` skill — reads `persistent_state`, applies ongoing effect

**Parameter resolution fallback:** `"{key}"` in skill params checks `SkillInstance.parameter_overrides` -> `owner.persistent_state` -> `SkillDefinition.parameters` defaults.

## Checklist

- [ ] Created `data/relics/<id>.json` with valid schema
- [ ] `card_type` is `"relic"`
- [ ] `price` appropriate — consider permanent stall slot cost
- [ ] Skill IDs in `skills` array exist in `data/skills/`
- [ ] Skill JSONs have `"relic"` in `owner_types`
- [ ] Global observer skills have `"global": true`
- [ ] If new skill JSON: trigger type and effects valid
- [ ] If new condition/effect code: registered in corresponding factory
- [ ] Run project — ContentRegistry confirms relic and skills loaded
- [ ] Integration tests in `test/integration/test_on_<trigger>_skills.gd` (positive + negative)
- [ ] If relic has skills on multiple triggers: tests in each relevant file
