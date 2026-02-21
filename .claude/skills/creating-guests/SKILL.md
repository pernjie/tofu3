---
name: creating-guests
description: Use when adding a new guest, designing guest behavior, or creating guest JSON and skills. Covers guest JSON anatomy, needs, skills, trigger types, conditions, effects, testing, and balance tuning.
---

# Creating Guests

**Required reading — load these docs before proceeding:**
- `docs/guide-creating-guests.md` — full guest creation guide (JSON anatomy, fields, skill design, building blocks, testing, checklist)
- `docs/game-balance.md` — money budgets, guest archetypes, VU framework
- `docs/game-loop.md` — turn phases, event timing, action contracts, flush & sweep

## Before Implementation

After reading the docs above, **stop and present a summary before writing any code or JSON:**

1. **Clarify the design.** Ask questions about anything ambiguous — guest identity, intended difficulty, skill behavior, interactions with existing content.
2. **Identify all changes needed.** List every file that will be created or modified: guest JSON, skill JSONs, new conditions/effects, factory registrations, trigger wiring.
3. **Flag risks.** Call out anything that doesn't fit cleanly with existing building blocks — behaviors that would require hacky workarounds, hard-coded checks, or bypassing the data-driven pipeline.
4. **Propose redesigns over hacks.** If the current code can't express the behavior cleanly, recommend extending building blocks, adding new trigger types, or restructuring code. Confirm the approach before proceeding.

## Overview

Guests are supernatural visitors who walk paths, stopping at stalls to fulfill needs. Defined purely in JSON — no GDScript needed unless existing skill building blocks can't express the behavior.

**Data flow:** `data/guests/<id>.json` -> `ContentRegistry` -> `GuestDefinition` (immutable) -> `GuestInstance` (mutable)

## Key Design Principles

- **Compose, don't create.** Express behavior using existing triggers + conditions + effects before writing code.
- **Extend, don't duplicate.** If a new behavior is a variant, add a config option to the existing effect rather than creating a new class.
- **1 need = 1 money** baseline. Deviate intentionally based on guest archetype (see game-balance.md).
- **JSON boundary.** If behavior can't be expressed in JSON with existing building blocks, that's a signal to extend the building blocks.

## Quick Reference

**Need types:** `food`, `joy` (core). `interact` (beasts only)

**Skill composition:** trigger (when) + conditions (if all pass) + effects (then)

**Common triggers for guests:** `on_spawn`, `on_move`, `on_serve`, `on_pre_serve`, `on_need_fulfilled`, `on_enter_stall`, `on_ascend`, `on_descended`

**Parameter overrides:** Define defaults in skill JSON `parameters`, override per-entity in guest JSON `skills[].parameters`. Never mutate shared definitions.

## Checklist

- [ ] Created `data/guests/<id>.json` with valid schema
- [ ] Skill IDs in guest JSON exist in `data/skills/`
- [ ] If new skill JSON: trigger type, conditions, and effects are valid
- [ ] If new condition/effect code: registered in corresponding factory
- [ ] If new trigger type: signal connected in TriggerSystem with proper TriggerContext
- [ ] Run project — ContentRegistry confirms guest and skills loaded
- [ ] Balance: money budget follows `total_needs + skill_adjustment` formula (see game-balance.md)
- [ ] Integration tests in `test/integration/test_on_<trigger>_skills.gd` (positive + negative cases)
