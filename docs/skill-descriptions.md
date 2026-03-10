# Skill Description Guide

Skill descriptions are functional, not flavorful. Players should be able to read a card and understand exactly what it does.

## Format

```
[Trigger]: [Effect]. [Condition if any].
```

For passive modifier skills (typically granted by status effects), skip the trigger label:

```
[Effect].
```

## Trigger Labels

| Code | Label |
|------|-------|
| `on_serve` | `Serve:` |
| `on_restock` | `Restock:` |
| `on_midnight` | `Midnight:` |
| `on_spawn` | `Spawn:` |
| `on_ascend` | `Ascend:` |
| `on_descended` | `Descend:` |
| `on_encounter` | `Encounter:` |
| `on_enter_stall` | `Enter:` |
| `on_turn_start` | `Each turn:` |
| `on_place` / `on_play` | `Play:` |
| `on_level_start` | `Level start:` |
| `on_upgrade` | `Upgrade:` |
| `on_banish` | `Banish:` |
| `on_need_fulfilled` | `Need fulfilled:` |
| `on_bulk_serve` | `After bulk serve:` |
| `on_cast` | `Cast:` |
| `aura` | `Aura ({range}):` |

Pre-event triggers (`on_pre_serve`, `on_pre_move`, `on_pre_fulfill`, `on_pre_enter_stall`, `on_pre_status`, `on_pre_banish`, `on_pre_encounter`) are passive modifiers — they describe what the effect does without a trigger prefix, since they're typically granted by a status effect and are always active while that status is present.

## Conventions

1. **Use actual values**, not parameter names: `Apply 2 Tingling` not `Apply {stacks} Tingling`
2. **Capitalize** status effect and need type names: `Tingling`, `Food`, `Joy`
3. **Target is implicit** when obvious (stall serve skill → guest), stated when not: `to nearby stalls`, `Any guest.`
4. **Conditions as suffix**: `Serve: +1 fulfillment. If guest has a debuff.`
5. **No flavor** — just mechanics
6. **"Once per X"** for state-limited skills: `Once per level.`, `Once per turn.`
7. **Global skills** (fire on any matching event) clarify scope: `Any guest.`, `Any stall.`
8. **Internal bookkeeping skills** (state resets, trackers) — leave description blank. They will be excluded from auto-generated card descriptions.

## Reference: All Skill Descriptions

### Stall Skills

| Skill ID | Description |
|----------|-------------|
| `spicy_skewer_apply_tingling` | `Serve: Apply 2 Tingling.` |
| `rest_house_grant_well_rested` | `Serve: Apply Well Rested.` |
| `spirit_hall_apply_attuned` | `Serve: Apply Spirit Attuned.` |
| `ancient_theatre_apply_spooked` | `Serve: Apply 4 Spooked.` |
| `paper_boats_apply_wet` | `Serve: Apply 2 Wet.` |
| `fish_spa_cleanse` | `Serve: Remove all debuffs.` |
| `restorative_yoga` | `Serve: +1 fulfillment. If guest has a debuff.` |
| `pufferfish_banish_on_deplete` | `Serve: Banish guest. If stock is empty.` |
| `mochi_stand_bonus_value` | `Serve: +1 value per previous restock.` |
| `candy_nuts_food_finisher` | `Serve: Fulfill remaining Food. If Food is 50%+ fulfilled.` |
| `midnight_feast` | `Midnight: Double value. Cost becomes 0.` |
| `rest_house_close_on_midnight` | `Midnight: Become Closed.` |
| `silk_market_midnight_shift` | `Midnight: Switch need type to Food.` |
| `average_adjacent_value` | `Each turn: Set value to average of adjacent stalls.` |
| `beast_shrine_value` | `Each turn: +1 value per beast on board.` |
| `unagi_escalating_restock` | `Restock: +1 stock per previous restock.` |
| `pickle_stand_summon_kappa` | `Restock: Add a Kappa to the beast queue.` |
| `red_bean_spawn_charmed` | `Restock: Spawn next queued guest with 3 Charmed.` |
| `banish_weakest_after_bulk` | `After bulk serve: Banish the guest with the lowest remaining need.` |
| `blacksmith_status_immunity` | `Block all status effects on this stall.` |
| `closed_block_service` | `Block service.` |
| `closed_block_entry` | `Block entry.` |
| `smelly_aura` | `Aura (1): Apply Smelly to nearby stalls.` |
| `moon_shrine_aura` | `Aura (1): Apply Moonlit to nearby stalls. After midnight.` |
| `whispering_altar_banish_restock` | `Banish: Restock this stall. Any guest.` |

### Guest Skills

| Skill ID | Description |
|----------|-------------|
| `slow_service` | `Spawn: Double service duration.` |
| `cat_lady_summon` | `Spawn: Summon a Cat.` |
| `lantern_summon` | `Spawn: Summon 2 guests from the queue with 1 need and 1 money.` |
| `akashita_restock_all` | `Spawn: Restock all product stalls.` |
| `disruptive_entrance` | `Enter: Reset service durations at this stall.` |
| `cat_ascend_aoe_joy` | `Ascend: Fulfill 1 Joy for nearby guests.` |
| `dancer_ascend_charm` | `Ascend: Apply 8 Charmed to nearby guests.` |
| `encounter_fulfill_need` | `Encounter: Fulfill 1 of target's need. If target has that need.` |
| `encounter_apply_status` | `Encounter: Apply status to target.` |
| `encounter_consume_debuff` | `Encounter: Remove 1 debuff from target and fulfill 1 random need. If target has a debuff.` |
| `encounter_banish` | `Encounter: Banish target. If target has equal or fewer needs.` |
| `encounter_give_money` | `Encounter: Give 1 money to target.` |
| `steal_money` | `Encounter: Steal 1 money from target. If target has money.` |
| `apply_status_on_interact` | `Interact: Apply status to target.` |
| `monkey_king_clone` | `Need fulfilled: Clone self. If needs remain.` |
| `perfectionist` | `Need fulfilled: Ascend immediately. If fulfilled exactly 2.` |
| `transform_need_on_fulfill` | `Need fulfilled: Transform one need type into another.` |
| `spider_transform` | `Midnight: Transform Joy needs into Food.` |
| `gilded_burden_extra_penalty` | `Descend: -1 reputation per stack of Gilded Burden.` |
| `samurai_banish_immunity` | `Block banish.` |
| `samurai_status_immunity` | `Block all status effects.` |
| `lost_reverse_movement` | `25% chance to reverse movement.` |
| `charmed_block_fulfillment` | `25% chance to block fulfillment.` |
| `wet_block_entry` | `Block entry.` |
| `spirit_attuned_block_entry` | `Block entry.` |
| `spirit_attuned_double_encounter` | `Double encounter benefits.` |
| `tingling_reduce_food` | `Food fulfillment -1.` |
| `spooked_reduce_joy` | `Joy fulfillment -1.` |
| `well_rested_double_fulfillment` | `Double fulfillment.` |
| `restock_on_deplete` | `Serve: Restock stall. If stock is empty.` |

### Relic Skills

| Skill ID | Description |
|----------|-------------|
| `gourd_double_restock` | `Restock: Double restock. Once per level. Any stall.` |
| `vine_basket_bonus_play` | `Restock: +1 card play. Once per turn. Any stall.` |
| `vine_basket_reset` | _(internal bookkeeping — no description)_ |
| `lucky_frog_upgrade_bonus` | `Upgrade: Apply Lucky Frog Buff to stall. Once per level. Any stall.` |
| `mystical_scroll_discover` | `Play: Choose a beast from a selection of 3.` |
| `mystical_scroll_summon` | `Level start: Add chosen beast to the queue.` |
| `ox_hour_bell_early_midnight` | `Level start: Midnight triggers at 50% through the night.` |
| `moonlit_offering_boost_interact` | `Spawn: +2 Interact need. Beasts only.` |

### Test / Debug Skills

| Skill ID | Description |
|----------|-------------|
| `test_aura` | `Aura (1): Apply Test Aura Debuff to nearby stalls.` |
