---
name: creating-stalls
description: Use when adding a new stall, designing stall behavior, creating stall JSON, or working with operation models, tier progression, or stall skills. Covers product vs service stalls, tier scaling, skill design, and balance tuning.
---

# Creating Stalls

**Required reading — load these docs before proceeding:**
- `docs/guide-creating-stalls.md` — full stall creation guide (JSON anatomy, operation models, tiers, skills, testing, checklist)
- `docs/game-balance.md` — efficiency ratings, stall archetypes, tier progression, throughput analysis, board space constraints
- `docs/game-loop.md` — turn phases, event timing, action contracts, flush & sweep

## Before Implementation

After reading the docs above, **stop and present a summary before writing any code or JSON:**

1. **Clarify the design.** Ask questions about anything ambiguous — operation model choice, tier progression identity, skill behavior, intended archetype and synergies.
2. **Identify all changes needed.** List every file that will be created or modified: stall JSON, skill JSONs, new conditions/effects, factory registrations, trigger wiring.
3. **Flag risks.** Call out anything that doesn't fit cleanly — stats that lack modifier support where they should have it, missing trigger types, behaviors that would require hard-coded checks.
4. **Propose redesigns over hacks.** If the current code can't express the behavior cleanly, recommend extending building blocks, adding modifier support to raw stats, or restructuring code. Confirm the approach before proceeding.

## Overview

Stalls are structures players place to serve guests. Each stall has an operation model (product, service, or bulk_service), tier progression, and optional skills. Stalls are played as cards (`StallDefinition` extends `CardDefinition`).

**Data flow:** `data/stalls/<id>.json` -> `ContentRegistry` -> `StallDefinition` (immutable) -> `StallInstance` (mutable)

## Key Design Principles

- **Operation model defines identity.** Product = instant service, finite stock. Service = guests occupy for multiple turns, capacity-limited. Bulk_service = guests wait for capacity to fill, then all served together with group-level skills.
- **~50% improvement per tier, same axis.** Sharpen the stall's strength, don't round out weaknesses.
- **Skills for identity, tiers for power.** A stall's skill is what makes it unique; tiers make it stronger.
- **Efficiency = value / cost_to_guest.** Baseline 1.0; below means player profits; above needs a skill to justify.
- **Extend, don't duplicate.** Add config options to existing effects rather than new effect classes.

## Quick Reference

**Product stalls:** stock depletes on service, restocks after cooldown. Key stats: `restock_amount`, `restock_duration`, `value`, `cost_to_guest`.

**Service stalls:** guests occupy slots for N turns. Key stats: `service_duration`, `capacity`, `value`, `cost_to_guest`.

**Bulk service stalls:** guests wait until capacity fills, then all served together. Same tier stats as service. Wait timeout is 3 turns; new arrivals reset all waiting timers. `on_bulk_serve` trigger fires once for the group after individual `on_serve` events.

**Need types:** `"food"`, `"joy"`, or `"any"`. An `"any"` stall can serve guests with any unfulfilled need — the specific need to fulfill is chosen randomly at service time via `stall.resolve_need_type_for_guest(guest)`. When writing service logic, always use `resolve_need_type_for_guest(guest)` instead of `get_need_type()` when a guest is known.

**Tier skills:** Each tier fully encapsulates its skills. On upgrade, skills are diffed — carried over, added, or removed. Parameter overrides update per tier.

**Common triggers for stalls:** `on_place`, `on_upgrade`, `on_restock`, `on_serve`, `on_pre_serve`, `on_enter_stall`, `on_bulk_serve`, `on_remove`, `on_turn_start`/`on_turn_end`

## Checklist

- [ ] Created `data/stalls/<id>.json` with valid schema
- [ ] `card_type` is `"stall"`, `operation_model` and `need_type` set
- [ ] Tiers well-structured: ascending tier numbers, model-appropriate fields
- [ ] `price` appropriate for power level (see game-balance.md)
- [ ] Efficiency baseline makes sense for the archetype (see game-balance.md)
- [ ] Skill IDs in tier `skills` arrays exist in `data/skills/`
- [ ] If new skill JSON: `owner_types` includes `"stall"`, trigger and effects valid
- [ ] If new condition/effect code: registered in corresponding factory
- [ ] Run project — ContentRegistry confirms stall and skills loaded
- [ ] Integration tests in `test/integration/test_on_<trigger>_skills.gd` (positive + negative cases)
