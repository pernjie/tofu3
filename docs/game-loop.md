# Game Loop

This document explains the turn system, phase orchestration, and the contracts that govern how game actions execute.

For the animation system architecture (how animations are created, queued, batched, and skipped), see [animation-system.md](animation-system.md).

## Turn Structure

Each turn executes phases in this order:

1. **TURN_START** — Tick cooldowns, restock stalls, fire `on_turn_start` skills
2. **SERVICE_RESOLUTION** — Guests in stalls complete service (or tick wait countdowns for bulk_service WAITING phase), ascend if all needs fulfilled
3. **GUEST_MOVEMENT** — Guests advance along paths, exit at path end
4. **STALL_ENTRY** — Guests enter adjacent stalls, entry skills fire, then product stalls serve immediately; bulk_service stalls set wait timers and may transition to SERVING if capacity fills
5. **GUEST_SPAWN** — Next guest spawns from queue; after midnight, next beast spawns from beast queue
6. **PLAYER_ACTION** — Wait for player input (place cards, etc.)
7. **TURN_END** — Fire `on_turn_end` skills, tick status effects (stack decay, expiration), update skill states

After the player action completes, the turn ends and the next turn begins automatically.

## The Contract

Every game action follows this sequence:

```
1. Action executes    — State mutates, data display updates, animations queue
2. Batch plays        — All queued animations run in parallel (or snap if skipping)
3. Events fire        — Skills and listeners react to settled state
4. Flush & Sweep      — Play skill-effect animations, ascend newly-satisfied guests (loops until stable)
5. Settled            — Proceed to next phase
```

This means:
- State is always the source of truth
- Data display is always current (labels, text)
- Animated properties eventually catch up to state (or snap in skip mode)
- Animations can be skipped without affecting gameplay or data display
- Skills never fire mid-animation
- Skill effects that produce animations get flushed before the next phase

### Two Resolution Modes

The contract above describes **phase-originated actions** — the linear flow TurnSystem orchestrates (action → batch → event → flush). But skill effects can emit signals inline, and those signals trigger further skills via GDScript's synchronous call stack. This creates a second resolution mode:

- **Phase-originated:** TurnSystem controls timing. Action executes, batch plays, then events fire.
- **Effect-originated:** A skill effect emits a signal (e.g. `guest_spawned`, `guest_need_fulfilled`) during trigger execution. Listeners fire synchronously in the same call stack. Animations queue but don't play until the next `_flush_and_sweep()`.

This recursive resolution is correct and intentional. GDScript's synchronous signals give us call-stack cascading for free. The animation queue preserves visual ordering — the player sees everything in one flush batch. This model is event-type-agnostic: spawns, fulfillments, and any future cascading effect all work the same way.

### Deferred Effects

Some skill effects require player input before they can fully resolve — for example, a "discover" effect that presents 3 options and waits for a choice. The skill system is synchronous, and making it async would be an invasive change with limited benefit. Instead, these effects use the **deferred effect pattern**.

A deferred effect runs synchronously like any other effect, but instead of producing a final result, it registers a **pending request** on `TriggerSystem.pending_deferred_requests`. The request is a structured dictionary describing what UI interaction is needed and where to store the result.

```
1. Trigger fires              — TriggerSystem executes skill effects normally
2. Deferred effect executes   — Adds request to TriggerSystem.pending_deferred_requests
3. Trigger execution ends     — Control returns to the caller (game.gd, TurnSystem, etc.)
4. Caller checks for pending  — Reads TriggerSystem.pending_deferred_requests
5. Caller shows UI            — Presents choices, waits for player input
6. Caller stores result       — Writes to entity's persistent_state
7. Caller clears requests     — Clears pending_deferred_requests
8. Normal flow resumes
```

This mirrors the existing `TriggerContext.service_result` pattern: the effect declares intent, the caller handles execution. The skill says **what** it needs, the caller decides **how** to present it.

The deferred pattern keeps the skill execution pipeline synchronous while allowing effects to request arbitrarily complex UI interactions. The caller is responsible for handling requests appropriate to its context — game.gd shows a visual overlay, a debug console might auto-pick, tests might inject choices.

## Responsibility Boundary

| Component | Responsibility |
|-----------|----------------|
| **BoardSystem** | Hosts **action methods** that bundle state mutation + data display + animation queueing. Also hosts **convenience wrappers** that bundle action + event emission. Single source of truth for "what happens when X occurs." |
| **TurnSystem** | Orchestrates phases, calls action methods, controls batch timing, emits events, flushes after triggers |
| **StatusEffectSystem** | State-only status effect lifecycle (apply, tick, remove). Does NOT emit events or queue visuals — callers handle both. Two exceptions: (1) Tick processing queues visuals and emits `status_removed` for expiration (same pattern as TurnSystem internal bookkeeping). (2) Guest-exit cleanup (`_on_guest_exiting`) removes all effects and emits `status_removed` for each — no visuals needed since the entity is being removed. |
| **AnimationCoordinator** | Orchestrates WHEN animations play (batching, parallel execution, skip/speed) |
| **Entities (GuestEntity, StallEntity, etc.)** | Know HOW to animate themselves (animation factory methods) and how to display data (label updates) |

**Key principles:**
- AnimationCoordinator should not know entity internals. It collects animations and plays them.
- Game actions (spawn, restock, serve) should be called through BoardSystem action methods, never by directly mutating instance state. This ensures every caller — TurnSystem phases, skill effects, debug console — gets the complete behavior (state + data display + animation).
- Entities have two kinds of methods: `update_labels()` for data display (immediate) and `create_*_animation()` factories for visual property changes (batched).

## Centralized Action Methods

Game actions live on BoardSystem. Each action method handles the complete behavior so callers don't need to duplicate logic:

```gdscript
# BoardSystem — the action method
func restock_stall(stall: StallInstance) -> bool:
    stall.restock()                                                     # state mutation
    stall.restock_cooldown = 0
    var entity = board_visual.get_stall_entity(stall.board_position)
    if entity:
        entity.update_labels()                                          # data display
        AnimationCoordinator.queue(entity.create_restock_animation())   # animation
    return true
    # Does NOT emit events — caller controls timing
    # Does NOT play batch — caller controls timing
```

Similarly, `fulfill_guest_need()` bundles `on_pre_fulfill` trigger firing + `guest.fulfill_need()` + data display refresh + floating text animation:

```gdscript
# BoardSystem — the action method
func fulfill_guest_need(guest: GuestInstance, need_type: String, amount: int, source: BaseInstance = null) -> int:
    # Fire on_pre_fulfill triggers (universal fulfillment interception)
    var context = TriggerContext.create("on_pre_fulfill")
    context.with_guest(guest).with_need_type(need_type).with_amount(amount)
    context.with_target(guest).with_fulfillment_result()
    if source:
        context.with_source(source)
    TriggerSystem.trigger_entity_skills("on_pre_fulfill", context, entities)

    if context.fulfillment_result.get("blocked", false):
        return 0

    var modified = int(amount * context.fulfillment_result.get("fulfillment_multiplier", 1.0))
    modified += context.fulfillment_result.get("fulfillment_bonus", 0)
    modified = max(modified, 0)

    var fulfilled = guest.fulfill_need(need_type, modified)             # state mutation (no clamping)
    if fulfilled > 0 and board_visual:
        var entity = board_visual.get_guest_entity(guest)
        if entity:
            entity.refresh()                                            # data display
            AnimationCoordinator.queue(entity.create_need_fulfilled_animation(fulfilled, need_type))  # animation
    return fulfilled
    # Does NOT emit events — caller controls timing
    # Does NOT play batch — caller controls timing
```

**No clamping:** `guest.fulfill_need()` returns the full amount offered, not the remaining need. Needs can go negative (overfulfilled). This means the animation, events, and skill triggers all see the original service value. A stall offering 3 food to a guest with 1 food remaining reports `fulfilled = 3`. Returns 0 only if the need was already at or below 0 (nothing to fulfill).

For spawning guests from skill effects or the debug console, use `BoardSystem.summon_guest()` — it bundles `spawn_guest()` + repositioning + `guest_spawned` emission. TurnSystem phases should NOT use it; they control animation timing and event emission directly.

### Action Methods vs Convenience Wrappers

Some game actions have two tiers on BoardSystem:

| Tier | Contract | Example | Used By |
|------|----------|---------|---------|
| **Action method** | State + data display + animation. No events, no batch. | `spawn_guest()`, `place_stall()`, `apply_status_effect()` | TurnSystem phases (control timing directly) |
| **Convenience wrapper** | Action method + event emission. No batch. | `summon_guest()`, `deploy_stall()`, `inflict_status()`, `restock_and_notify()` | Skill effects, game.gd, debug console |

The convenience wrapper exists when the event emission logic is non-trivial or when multiple callers would duplicate it. For example, `inflict_status()` wraps `apply_status_effect()` and emits the appropriate event (`status_applied` for new, `status_stack_changed` for existing):

```gdscript
# BoardSystem — convenience wrapper (like summon_guest)
func inflict_status(target: BaseInstance, status_id: String, stacks: int = 1) -> StatusEffectInstance:
    var existing = target.get_status(status_id)
    var old_stacks = existing.stacks if existing else 0

    var instance = apply_status_effect(target, status_id, stacks)  # action method
    if not instance:
        return null

    if existing:
        EventBus.status_stack_changed.emit(instance, old_stacks, instance.stacks)
    else:
        EventBus.status_applied.emit(target, instance)

    return instance
```

Similarly, `revoke_status()` wraps `remove_status_effect()` + emits `status_removed`, `deploy_stall()` wraps `place_stall()`/`upgrade_stall()` + emits `stall_placed` or `stall_upgraded`, `fulfill_and_notify()` wraps `fulfill_guest_need()` + emits `guest_need_fulfilled`, and `restock_and_notify()` wraps `restock_stall()` + emits `stall_restocked`.

The status effect action methods (`apply_status_effect`, `remove_status_effect`) delegate state to `StatusEffectSystem` (which is state-only: validate, stack, apply modifiers, grant/revoke skills — no events, no visuals).

Different callers handle batch timing and events appropriately:

```gdscript
# TurnSystem phase — orchestrated, events after batch
for stall in restocked_stalls:
    board_system.restock_stall(stall)
await AnimationCoordinator.play_batch()
for stall in restocked_stalls:
    EventBus.stall_restocked.emit(stall)

# Skill effect — uses convenience wrapper (action + event), flush loop plays animations
BoardSystem.inflict_status(target, "charmed", 2)
# animation queued, event emitted inline (cascade happens synchronously), flush picks it all up

# Debug console — uses convenience wrapper + immediate batch
BoardSystem.inflict_status(guest, status_id, stacks)
await AnimationCoordinator.play_batch()
```

## The Two-Pass Pattern

Each phase follows a **two-pass pattern** to ensure correct slot positions:

```gdscript
func _execute_some_phase() -> void:
    _set_phase(Phase.SOME_PHASE)

    var animated_guests: Array[GuestInstance] = []

    # PASS 1: Execute ALL state changes via action methods
    for guest in guests:
        board_system.move_guest(guest)  # state + data display + queue animation
        if guest_moved:
            animated_guests.append(guest)

    # PASS 2: Queue repositioning for OTHER guests (skip those with animations)
    TileOccupancyManager.queue_all_repositions(animated_guests)

    # 3. Play and wait
    await AnimationCoordinator.play_batch()

    # 4. Emit events (skills react, may queue new animations via action methods)
    for guest in animated_guests:
        EventBus.guest_moved.emit(guest, from, to)

    # 5. Flush & sweep
    await _flush_and_sweep()
```

**Why two passes?** Slot positions depend on knowing ALL guests that will occupy a tile. If we queue animations while iterating, later guests haven't been processed yet, so slot calculations would be wrong.

## Flush & Sweep

After events fire, `_flush_and_sweep()` runs. It does two things:

1. **Flush** — Plays any animations queued by skill effects during event handling
2. **Sweep** — Checks all active guests for newly-satisfied needs and ascends them

The sweep loops until stable: each ascension emits `guest_ascended`, triggering `on_ascend` skills that could satisfy more guests. Convergence is guaranteed because each iteration removes at least one guest from `active_guests`. Ascension does not grant reputation — only descent costs it.

A guest ascends if all needs are fulfilled OR if `force_ascend` is set (by the `force_ascend` skill effect). This lets skills trigger early ascension without fulfilling remaining needs.

```gdscript
func _flush_and_sweep() -> void:
    await AnimationCoordinator.play_batch()

    if not board_system:
        return

    while true:
        var newly_ascending: Array[GuestInstance] = []
        for guest in board_system.active_guests:
            if not guest.is_exiting and (guest.are_all_needs_fulfilled() or guest.force_ascend):
                guest.is_exiting = true
                newly_ascending.append(guest)

        if newly_ascending.is_empty():
            break

        for guest in newly_ascending:
            _queue_guest_animation(guest, "create_ascend_animation")
        await AnimationCoordinator.play_batch()

        for guest in newly_ascending:
            _handle_guest_ascension(guest)

        await AnimationCoordinator.play_batch()
```

**Why sweep?** Any source can fulfill a guest's last need — service resolution, stall entry, skill effects, status effects. Rather than checking for ascension at every fulfillment point, the sweep catches all cases reactively after each flush.

## Service Resolution Phases

Service resolution handles three operation models with a unified phased approach:

```
Phase 1: Tick timers, resolve completions, queue fulfillment animations
  - bulk_service WAITING stalls: tick wait countdown, collect timeouts
  - service / bulk_service SERVING / product stalls: tick service timers, resolve completed guests

Phase 2: Emit service events (guest still in stall)
  - guest_need_fulfilled + guest_served per completed guest (on_serve triggers fire here)
  - on_bulk_serve fires once per completed bulk_service group (stall skills only)
  - Reset bulk_phase to IDLE for completed bulk stalls

Phase 3: Remove completed/timed-out guests from stall

Phase 4: Queue exit animations + repositioning

Phase 5: Play all animations

Phase 6: Emit exit events (guest_exited_stall)

Phase 7: Flush & sweep
```

**Why emit events before removal?** Service conceptually happens *at* the stall, so post-service triggers (`on_serve`, `on_bulk_serve`) fire while the guest is still there. This lets skills that care about stall membership (e.g., counting occupants) see the correct state.

### Bulk Service WAITING Phase

During service resolution, bulk_service stalls in WAITING phase tick each guest's `wait_turns_remaining`. The tick uses a two-pass approach to avoid modifying the occupants array during iteration:

1. **Pass 1:** Tick all guests, show wait countdown animation, identify timeouts
2. **Pass 2:** Collect timed-out guests for removal in Phase 3

Timed-out guests exit the stall silently (no `guest_served` event — they weren't served).

### Bulk Service Stall Entry

When a guest enters a bulk_service stall during STALL_ENTRY:

1. Stall transitions to WAITING (if not already)
2. Guest gets `wait_turns_remaining = 3`
3. All OTHER waiting occupants get their timers reset to 3
4. If `occupants == capacity`: transition to SERVING, calculate averaged service duration from all guests' `service_duration_multiplier` stats

No `reset_guest_service()` call — service timers are only set when capacity fills.

## Event Timing

Events fire **after** animations complete. This is about **player-perceived causality**, not game logic need — state is already correct before animations play. The principle is: the player should see the cause before the effect.

If a guest moves and a skill triggers on that move, the player sees: guest walks to new tile, then skill visual effect. Without this ordering, effects would appear to happen before their cause.

| Event | When Fired | Triggers |
|-------|------------|----------|
| `guest_moved` | After movement batch | Movement skills |
| `guest_entered_stall` | After entry batch, before service processing | Entry skills |
| `guest_exited_stall` | After exit batch | Exit skills |
| `guest_ascended` | After ascend batch (sweep or path-end exit) | Ascension skills |
| `guest_descended` | After descend batch (path-end exit) | Descent skills |
| `guest_served` | After service completion, before guest removal from stall | Service skills (`on_serve`) — guest is still in stall when this fires |
| `on_bulk_serve` | After all individual `guest_served` events for a bulk_service group | Group-level stall skills — `context.guests` has the full group |
| `guest_need_fulfilled` | After fulfillment (inline via `fulfill_and_notify`) | Fulfillment notification skills |
| `stall_restocked` | After restock batch | Restock skills |
| `status_applied` | Inline via `inflict_status()` | Status application skills |
| `status_stack_changed` | Inline via `inflict_status()` | Stack change skills |
| `status_removed` | Inline via `revoke_status()`, or during tick/exit cleanup | Status removal skills |

## Status Effect Tick Processing

Status effect tick processing (stack decay, expiration) happens during TURN_END via `StatusEffectSystem._on_turn_ended()`. This follows a different pattern from external callers because it's internal system bookkeeping — similar to how TurnSystem queues service tick countdown text directly.

```
turn_ended signal fires
  → StatusEffectSystem._tick_all_status_effects()
    1. For each effect: tick stacks, queue decay/removal visuals directly
    2. Process removals: state cleanup + emit status_removed
  → Control returns to TurnSystem
  → _flush_and_sweep() plays all queued animations
```

The tick method queues visuals directly via its own `board_visual` reference + entity factory methods, bypassing BoardSystem entirely. StatusEffectSystem tracks entities internally (added/removed as status effects are applied/removed), so it never needs to scan BoardSystem. This eliminates any circular dependency and matches TurnSystem's internal visual queueing pattern.

Tick-based stack decay does NOT emit `status_stack_changed` — it's visual-only feedback. Only explicit application via `inflict_status()` emits stack change events. Tick-based expiration (stacks reaching 0) DOES emit `status_removed`, since skills should react to effect expiration regardless of cause.

## Level Completion

Level completion checks _has_core_guests_remaining(), which scans the spawn queue and active guests on the board.

## Debug Console

The debug console triggers game actions outside of TurnSystem's phase loop. Because it calls the same BoardSystem action methods, animations are queued automatically:

```gdscript
func _cmd_spawn_guest(args: Array) -> void:
    var guest = BoardSystem.summon_guest(guest_def)  # spawn + reposition + event
    if guest:
        await AnimationCoordinator.play_batch()  # flush spawn + on_spawn effect animations

func _cmd_restock(args: Array) -> void:
    BoardSystem.restock_and_notify(stall)             # action + event
    await AnimationCoordinator.play_batch()           # play immediately

func _cmd_apply_status(args: Array) -> void:
    BoardSystem.inflict_status(guest, status_id, stacks)  # action + event + cascading triggers
    await AnimationCoordinator.play_batch()                # play immediately

func _cmd_remove_status(args: Array) -> void:
    BoardSystem.revoke_status(guest, status_id)       # action + event
    await AnimationCoordinator.play_batch()            # play immediately
```

**The pattern for debug commands:**
1. Call the BoardSystem convenience wrapper (gets action + events) or action method (for simple actions where events can be omitted)
2. Call `await AnimationCoordinator.play_batch()` (the console is its own orchestrator)
3. For actions that trigger cascading skills (spawning, status effects, restocking), use the convenience wrapper (`summon_guest()`, `inflict_status()`, `restock_and_notify()`) which emits the event.

This means adding a new debug command for an existing action is trivial: call the convenience wrapper, play the batch.

## Example: Complex Multi-Guest Scenario

This example shows how the system handles a turn where multiple things happen:

**Setup:**
- Guest A is at tile (1,0), will move to tile (2,0)
- Guest B is already at tile (2,0)
- Tile (2,0) has an adjacent stall
- Guest A will enter the stall after moving

**Phase 1: GUEST_MOVEMENT**

```gdscript
func _execute_guest_movement_phase() -> void:
    var guests_moved: Array[GuestInstance] = []

    # PASS 1: Update all state
    guest_a.current_tile = tile_2_0
    guest_a.path_index = 2
    guests_moved.append(guest_a)

    # PASS 2: Queue animations with slot positions
    # (A goes to left slot, since B is also on tile 2,0)
    var entity_a = board_visual.get_guest_entity(guest_a)
    var target_pos = TileOccupancyManager.get_slot_position_for_guest(guest_a, tile_2_0.position)
    AnimationCoordinator.queue(entity_a.create_move_animation(target_pos))

    # 3. Queue repositioning (skip A, only B repositions to right slot)
    TileOccupancyManager.queue_all_repositions(guests_moved)

    # 4. Play all in parallel
    await AnimationCoordinator.play_batch()
    # Result: A moves directly to left slot, B shifts to right slot (parallel, no conflict)

    # 5. Emit events
    EventBus.guest_moved.emit(guest_a, tile_1_0, tile_2_0)

    # 6. Flush & sweep
    await _flush_and_sweep()
```

**Phase 2: STALL_ENTRY**

```gdscript
func _execute_stall_entry_phase() -> void:
    var entering_guests: Array[GuestInstance] = []

    # PASS 1: Update all state
    guest_a.is_in_stall = true
    stall.add_occupant(guest_a)
    entering_guests.append(guest_a)

    # PASS 2: Queue entry animation with stall slot position
    var entity_a = board_visual.get_guest_entity(guest_a)
    var target_pos = TileOccupancyManager.get_stall_slot_position_for_guest(guest_a, stall)
    AnimationCoordinator.queue(entity_a.create_enter_stall_animation(target_pos))

    # 3. Queue repositioning (skip A, only B repositions to center)
    TileOccupancyManager.queue_all_repositions(entering_guests)

    # 4. Play entry animations
    await AnimationCoordinator.play_batch()
    # Result: A moves into stall slot, B slides to center (parallel, no conflict)

    # 5. Emit entry events (on_enter_stall skills fire, may queue animations)
    EventBus.guest_entered_stall.emit(guest_a, stall)

    # 6. Flush entry-skill animations
    await AnimationCoordinator.play_batch()

    # 7. Process service (product stalls serve immediately)
    var service_data = _complete_service(guest_a, stall)

    # 8. Play service animations
    await AnimationCoordinator.play_batch()

    # 9. Emit service events
    EventBus.guest_served.emit(guest_a, stall)

    # 10. Flush & sweep
    await _flush_and_sweep()
```

**What plays in parallel within each phase:**

| Phase | Animations (all parallel) |
|-------|---------------------------|
| GUEST_MOVEMENT | A moves to left slot + B repositions to right slot |
| STALL_ENTRY | A enters stall slot + B repositions to center |

**What's sequential between phases:**

```
GUEST_MOVEMENT batch completes
         |
    events fire -> flush & sweep
         |
STALL_ENTRY entry batch completes
         |
    entry events fire -> flush entry-skill animations
         |
    service processing -> service batch completes
         |
    service events fire -> flush & sweep
```

This ensures Guest A fully arrives at the tile before entering the stall (no diagonal movement). Within stall entry, entry skills get their own visual beat before service animations play, and entry skills can influence the subsequent service (e.g., modifying stall values before guests are served).

## Anti-Patterns

### Don't emit events before awaiting animations (phase-level)

This applies to TurnSystem phase orchestration. Effect-originated cascading (where a skill effect emits a signal inline during trigger execution) is correct — those animations queue for the next `_flush_and_sweep()`.

```gdscript
# BAD - Event fires while animation is still playing (in a TurnSystem phase)
guest.current_tile = new_tile
EventBus.guest_moved.emit(guest, old_tile, new_tile)  # Too early!
AnimationCoordinator.queue(anim)
await AnimationCoordinator.play_batch()
```

```gdscript
# GOOD - Event fires after animation completes
guest.current_tile = new_tile
AnimationCoordinator.queue(anim)
await AnimationCoordinator.play_batch()
EventBus.guest_moved.emit(guest, old_tile, new_tile)  # Correct timing
```

### Don't mix state changes with animation logic

```gdscript
# BAD - State and visuals interleaved
func process_guest_movement():
    guest.current_tile = new_tile
    await animate_move(guest)  # Blocks here
    guest.is_in_stall = true
    await animate_enter_stall(guest)  # Blocks again
```

```gdscript
# GOOD - All state first, then all animations
func process_guest_movement():
    # Phase 1: All state changes
    guest.current_tile = new_tile
    AnimationCoordinator.queue(entity.create_move_animation(...))
    await AnimationCoordinator.play_batch()

    # Phase 2: All state changes
    guest.is_in_stall = true
    AnimationCoordinator.queue(entity.create_enter_stall_animation(...))
    await AnimationCoordinator.play_batch()
```

### Don't queue animations before all state is settled

```gdscript
# BAD - Queue animation while still processing other guests
for guest in guests:
    guest.current_tile = new_tile
    var target = TileOccupancyManager.get_slot_position_for_guest(guest, new_tile.position)
    AnimationCoordinator.queue(entity.create_move_animation(target))
    # Problem: Later guests haven't moved yet, so slot calculation is wrong!
```

```gdscript
# GOOD - Two-pass: all state changes first, then all animations
var moved_guests: Array[GuestInstance] = []

# Pass 1: All state changes
for guest in guests:
    guest.current_tile = new_tile
    moved_guests.append(guest)

# Pass 2: All animations (now slot positions are correct)
for guest in moved_guests:
    var target = TileOccupancyManager.get_slot_position_for_guest(guest, guest.current_tile.position)
    AnimationCoordinator.queue(entity.create_move_animation(target))
```

### Don't return early from state updates without syncing all state

```gdscript
# BAD - Returns early without updating current_tile to match path_index
func advance_guest_on_path(guest, path, steps) -> bool:
    for i in range(steps):
        var next_index = path.get_next_index(guest.path_index, 1)
        if next_index == -1:
            return false  # Leaves current_tile stale!
        guest.path_index = next_index

    guest.current_tile = path.get_tile_at_index(guest.path_index)
    return true
# Result: Animation plays from old tile position because current_tile wasn't updated
```

```gdscript
# GOOD - Always sync all state before returning
func advance_guest_on_path(guest, path, steps) -> bool:
    var reached_end = false
    for i in range(steps):
        var next_index = path.get_next_index(guest.path_index, 1)
        if next_index == -1:
            reached_end = true
            break
        guest.path_index = next_index

    # ALWAYS update current_tile to match path_index
    guest.current_tile = path.get_tile_at_index(guest.path_index)
    return not reached_end
# Result: State is consistent, animations use correct position
```

### Don't skip move animations for guests reaching path end

```gdscript
# BAD - Guests that "reached end" go straight to exit animation
if reached_end:
    guests_to_exit.append(guest)  # No move animation!
else:
    guests_moved.append(guest)    # Gets move animation

for guest in guests_moved:  # Misses guests_to_exit!
    AnimationCoordinator.queue(entity.create_move_animation(...))
# Result: Guest ascends from previous tile, not the exit tile
```

```gdscript
# GOOD - All guests that moved get animations, including those reaching the end
for result in movement_results:
    if result.from != result.to:  # Only if they actually moved
        AnimationCoordinator.queue(entity.create_move_animation(result.to))

await AnimationCoordinator.play_batch()  # Movement completes first

for guest in guests_to_exit:
    AnimationCoordinator.queue(entity.create_ascend_animation())

await AnimationCoordinator.play_batch()  # Then exit animation
# Result: Guest walks to final tile, THEN ascends
```

### Don't call raw instance mutations for game actions

```gdscript
# BAD - Skill effect duplicates the action manually
func execute(context, skill):
    var stall = context.stall
    stall.restock()                        # Only state -- no data display, no animation
    stall.restock_cooldown = 0
    EventBus.stall_restocked.emit(stall)   # Caller shouldn't emit events
# Result: No animation plays, other callers must duplicate this logic
```

```gdscript
# GOOD - Skill effect calls the action method
func execute(context, skill):
    var stall = context.stall
    board_system.restock_stall(stall)  # State + data display + animation
    # Event emission handled by the orchestrator's flush loop
```

## Design Decisions Worth Discussing

### Missing trigger types for some events

Several emitted signals have no TriggerSystem handler, meaning skills can't react to them:
- `stall_depleted` — no `on_deplete` trigger
- `status_stack_changed` — no trigger
- `guest_exited_stall` — no `on_exit_stall` trigger
- `service_tick` — no trigger

These might be intentional (not everything needs skill hooks), but worth flagging. Add when a skill needs them.

### No event for blocked services

When `on_pre_serve` blocks a service, no event is emitted (just pass). Skills can't react to "service was blocked." Might want a `service_blocked` event eventually.
