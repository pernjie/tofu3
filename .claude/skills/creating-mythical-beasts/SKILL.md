---
name: creating-mythical-beasts
description: Use when adding a new mythical beast, designing beast encounter or interaction behavior, or creating beast JSON. Covers beast lifecycle, on_encounter and on_interact triggers, reverse movement, interact needs, and reusable beast skill patterns.
---

# Creating Mythical Beasts

**Required reading — load these docs before proceeding:**
- `docs/guide-creating-mythical-beasts.md` — full beast creation guide (JSON anatomy, encounter/interact triggers, reusable skills, lifecycle, testing, checklist)
- `docs/game-loop.md` — turn phases (BEAST_MOVEMENT, BEAST_INTERACTION), event timing, flush & sweep

## Before Implementation

After reading the docs above, **stop and present a summary before writing any code or JSON:**

1. **Clarify the design.** Ask questions about anything ambiguous — encounter behavior, interaction effects, interact count, how the beast should feel to play against.
2. **Identify all changes needed.** List every file that will be created or modified: beast JSON, skill JSONs, new conditions/effects, factory registrations, status effects.
3. **Flag risks.** Call out anything that doesn't fit cleanly — behaviors that can't be expressed with existing encounter/interact skills, edge cases with interaction resolution, hard-coded checks that would be needed.
4. **Propose redesigns over hacks.** If existing beast building blocks can't express the behavior cleanly, recommend extending `encounter_fulfill_need` or other reusable skills, adding new conditions/effects, or restructuring code. Confirm the approach before proceeding.

## Overview

Mythical beasts are supernatural creatures that walk paths in reverse, interacting with regular guests directly. They reuse the guest data pipeline but with distinct flags and skill-driven behavior.

**Data flow:** `data/guests/<id>.json` -> `ContentRegistry` -> `GuestDefinition` -> `GuestInstance`

## Key Design Principles

- **Beasts are guests with flags.** `is_mythical_beast: true`, `is_core_guest: false`, `spawn_at_exit: true`, `move_direction: "reverse"`.
- **Behavior is entirely skill-driven.** `on_encounter` determines eligibility and effects; `on_interact` handles post-interaction effects.
- **`interact` need type.** N successful interactions needed to ascend. No stall has this need type, so beasts are naturally skipped by stall entry.
- **Compose with reusable skills.** `encounter_fulfill_need`, `apply_status_on_interact`, `steal_money`, `encounter_banish` cover most patterns.

## Quick Reference

**Required beast fields:** `is_core_guest: false`, `is_mythical_beast: true`, `spawn_at_exit: true`, `move_direction: "reverse"`, `base_stats.needs: { "interact": N }`, `base_stats.money: 0`

**Two-phase interaction:**
1. `on_encounter` — beast's skills only fire. If any effect succeeds, interaction is successful.
2. `on_interact` — both beast and guest skills fire (post-interaction effects).

**Spawning:** Primarily via beast queue (one per turn after midnight). Also via `guest_groups` or `BoardSystem.summon_guest()`.

**Turn phases:** BEAST_MOVEMENT (beasts move, interact on arrival) -> GUEST_MOVEMENT (interacted guests skip) -> BEAST_INTERACTION (beasts interact with newly arrived guests) -> STALL_ENTRY (interacted guests skip)

## Checklist

- [ ] Created `data/guests/<id>.json` with beast flags set correctly
- [ ] `base_stats.needs` uses `"interact"` with desired count
- [ ] `skills` array defines encounter behavior (e.g. `encounter_fulfill_need`)
- [ ] Post-interaction effects use `on_interact` trigger skills
- [ ] Skill IDs in `skills` array exist in `data/skills/`
- [ ] Status effect IDs referenced exist in `data/status_effects/`
- [ ] Run project — verify beast spawns at exit, walks backward, interacts, ascends
- [ ] Integration tests in `test/integration/test_on_encounter_skills.gd` (positive + negative)
- [ ] If beast has `on_interact` skills: tests for post-interaction effects
- [ ] If beast has other trigger skills: tests in corresponding trigger file
