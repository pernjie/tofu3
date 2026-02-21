# Animation System

This document explains the animation architecture, its design philosophy, and the specific problems it solves.

For the game loop, turn phases, event timing, and orchestration patterns, see [game-loop.md](game-loop.md).

## Philosophy: Separation of Logic and Visuals

The core principle is that **game logic and visual presentation are completely separate concerns**, and visual presentation itself has two distinct categories.

```
Logic                    Data Display              Animation
─────────────────────    ─────────────────────     ─────────────────────
State changes instantly  Labels read from state    Visual properties interpolate
Deterministic            Immediate, always runs    Can be skipped or sped up
Source of truth          Text, counters, HUD       Position, color, scale, opacity
Testable without UI      Shows logical data        Purely cosmetic transitions
```

**Data display** is text and labels that project logical state onto the UI — stock counts, cooldown numbers, tier indicators. These update immediately when state changes and are never skipped.

**Animation** is every visual property change — position, color, scale, opacity. These are queued, batched, and played by the AnimationCoordinator. In skip mode, they snap to their final values. This includes changes that might seem "instant" like a stall's sprite changing from gray to orange on restock — that's an animated property, not data display.

**The test:** if `skip_animations` is true, should this change snap to its end state? If yes, it's animation. If it should always happen regardless, it's data display.

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                        TurnSystem                           │
│  Orchestrates phases, calls actions, emits events, flushes  │
└─────────────────────────┬───────────────────────────────────┘
                          │ calls action methods
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
┌─────────────────┐ ┌───────────────┐ ┌─────────────────────┐
│ AnimationCoord- │ │ TileOccupancy │ │     BoardSystem     │
│    inator       │ │    Manager    │ │  (actions + state)  │
│                 │ │               │ │                     │
│ - queue()       │ │ - queue_all_  │ │ - spawn_guest()     │
│ - play_batch()  │ │   repositions │ │ - summon_guest()    │
│ - skip/speed    │ │ - slot calc   │ │ - restock_stall()   │
│                 │ │               │ │ - fulfill_guest_need│
│                 │ │               │ │ - apply_status_eff. │
│                 │ │               │ │ - inflict_status()  │
│                 │ │               │ │ - active_guests     │
└────────┬────────┘ └───────┬───────┘ └──────────┬──────────┘
         │                  │                     │
         │  asks for        │  asks for           │ calls
         │  animations      │  animations         │
         │                  │                     │
         └────────┬─────────┴─────────────────────┘
                  ▼
        ┌─────────────────┐
        │    Entities      │
        │  (visual nodes)  │
        │                  │
        │ - create_*()     │  ← Animation factories
        │ - update_labels()│  ← Data display
        │ - position       │
        │ - modulate       │
        └─────────────────┘
```

### AnimationCoordinator

Central autoload that orchestrates WHEN animations play. It does NOT create animations directly - it collects them from entities.

**Key methods:**
- `queue(animation: QueuedAnimation)` - Add animation to current batch
- `queue_all(animations: Array[QueuedAnimation])` - Add multiple animations
- `play_batch()` - Play all queued animations in parallel, await completion
- `clear_batch()` - Discard queued animations without playing

**Configuration:**
- `animation_speed: float` - Multiplier for animation duration (default 1.0)
- `skip_animations: bool` - Skip to end state instantly (default false)

### GuestEntity

Visual node that knows HOW to animate itself. Creates animation objects on request.

**Animation factory methods:**
- `create_move_animation(to_pos: Vector2) -> QueuedAnimation`
- `create_enter_stall_animation(stall_pos: Vector2) -> QueuedAnimation`
- `create_exit_stall_animation() -> QueuedAnimation`
- `create_reposition_animation(to_pos: Vector2) -> QueuedAnimation`
- `create_ascend_animation() -> QueuedAnimation` (returns parallel group)
- `create_spawn_animation(target_pos: Vector2) -> QueuedAnimation` (returns parallel group, sets initial state)
- `create_need_fulfilled_animation(amount: int, need_type: String) -> FloatingTextAnimation` (transient floating text)
- `create_service_tick_animation(turns_remaining: int) -> FloatingTextAnimation` (transient floating text)
- `create_status_applied_animation(status_def: StatusEffectDefinition, stacks: int) -> FloatingTextAnimation` (transient floating text)
- `create_status_removed_animation(status_def: StatusEffectDefinition) -> FloatingTextAnimation` (transient floating text)
- `create_status_stacks_changed_animation(status_def: StatusEffectDefinition, delta: int) -> FloatingTextAnimation` (transient floating text)

**Immediate methods (for setup, no animation):**
- `set_position_immediate(pos: Vector2)` - Snap to position without animation

### StallEntity

Visual node for stall representation. Has its own animation factories.

**Animation factory methods:**
- `create_restock_animation() -> QueuedAnimation` (jump + color change, returns parallel group)
- `create_status_applied_animation(status_def: StatusEffectDefinition, stacks: int) -> FloatingTextAnimation` (transient floating text)
- `create_status_removed_animation(status_def: StatusEffectDefinition) -> FloatingTextAnimation` (transient floating text)
- `create_status_stacks_changed_animation(status_def: StatusEffectDefinition, delta: int) -> FloatingTextAnimation` (transient floating text)

### TileOccupancyManager

Calculates guest positions within tiles to prevent overlap.

**Key methods:**
- `queue_all_repositions(skip_guests: Array[GuestInstance] = [])` - Queue reposition animations for all guests, excluding those in skip list
- `get_slot_position_for_guest(guest, tile_pos) -> Vector2` - Calculate slot position for a guest on a path tile
- `get_stall_slot_position_for_guest(guest, stall) -> Vector2` - Calculate slot position for a guest in a stall

**Distribution algorithms:**
- Path tiles: Centered rows (guests arranged in a compact grid)
- Stalls: Horizontal row (guests spread left-to-right)

**Important:** Use `get_slot_position_for_guest()` or `get_stall_slot_position_for_guest()` to calculate animation targets, then pass those guests to `queue_all_repositions(skip_guests)` to avoid conflicting animations.

## Adding New Animations

To add a new animation type:

1. **Add factory method to the entity class:**
```gdscript
# In GuestEntity
func create_spin_animation() -> QueuedAnimation:
    var anim = TweenAnimation.new()
    anim.target = self
    anim.property = "rotation"
    anim.final_value = TAU  # Full rotation
    anim.duration = 0.5
    return anim
```

2. **Add or update an action method on BoardSystem** that calls the factory:
```gdscript
# In BoardSystem
func spin_guest(guest: GuestInstance) -> void:
    # state changes if any...
    var entity = board_visual.get_guest_entity(guest)
    if entity:
        entity.update_labels()  # if data display changed
        AnimationCoordinator.queue(entity.create_spin_animation())
```

3. **Call the action method from any caller:**
```gdscript
# TurnSystem, skill effect, or debug console
board_system.spin_guest(guest)
await AnimationCoordinator.play_batch()  # or let flush loop handle it
```

**For parallel animations within one entity** (e.g., move + fade):
```gdscript
# In GuestEntity
func create_ascend_animation() -> QueuedAnimation:
    var move_anim = TweenAnimation.new()
    move_anim.target = self
    move_anim.property = "position:y"
    move_anim.final_value = position.y - 50.0
    move_anim.duration = 0.5

    var fade_anim = TweenAnimation.new()
    fade_anim.target = self
    fade_anim.property = "modulate:a"
    fade_anim.final_value = 0.0
    fade_anim.duration = 0.5

    # Return a parallel group - both play simultaneously
    var group = ParallelAnimationGroup.new()
    group.animations = [move_anim, fade_anim]
    return group
```

## Animation Timing

| Animation | Duration | Used For |
|-----------|----------|----------|
| Move to tile | 0.3s | Path movement |
| Enter stall | 0.2s | Stall entry |
| Exit stall | 0.2s | Return to path |
| Reposition | 0.15s | Within-tile adjustment |
| Ascend | 0.5s | Guest ascension (all needs fulfilled) |
| Spawn | 0.5s | Guest appearing at path start |
| Restock | 0.3s | Stall restocking (jump + color change) |
| Floating text | 0.8s | Need fulfillment, service tick countdown, status effect changes |

All durations are affected by `animation_speed` multiplier (`duration` is on the base `QueuedAnimation` class).

## Skip Mode

Press **Space** during gameplay to toggle skip mode.

When `skip_animations = true`:
- `play_batch()` calls `skip()` on all queued animations
- All animated properties (position, color, scale, opacity) snap to their final values instantly
- No visual interpolation occurs
- Game logic proceeds at maximum speed
- **Data display always updates regardless** — labels, text, counters are never skippable

The distinction matters: a stall's stock label changing from "(2)" to "x3" happens immediately (data display). The stall's sprite color changing from gray to orange is an animated property that snaps to orange in skip mode.

Useful for:
- Testing and debugging
- Accessibility (motion sensitivity)
- Speedrunning
- Impatient players

## Problems Solved

### Problem 1: Diagonal Movement

**Before:** When a guest moved to a tile and then entered an adjacent stall, they would move diagonally (cutting corners) instead of sequentially.

**Cause:** Events fired immediately on state change. Multiple listeners started competing animations:
1. `guest_moved` -> start move animation (0.3s)
2. `guest_entered_stall` -> start stall entry animation (0.2s, kills previous)

The second animation interrupted the first, causing diagonal movement.

**After:** Animations are batched per phase. Movement phase completes entirely before stall entry phase begins. Guest moves to tile, animation completes, THEN enters stall.

### Problem 2: Ascension at Wrong Position

**Before:** When a guest with 2+ movement reached the end of the path and ascended, the float-up animation played from an intermediate position (mid-flight between tiles).

**Cause:** Events fired before animations completed:
1. Move tile 0->1 (animation starts)
2. Move tile 1->2 (animation starts, previous still running)
3. Guest ascends (uses current visual position, which is wrong)

**After:** Movement animations complete fully. Ascension queues after movement batch finishes. Guest ascends from their actual final position.

### Problem 3: Guest Overlap

**Before:** Multiple guests on the same tile stacked on top of each other at the tile center.

**After:** `TileOccupancyManager` calculates slot positions and distributes guests within tiles. When occupancy changes, all affected guests reposition in parallel.

### Problem 4: No Skip Support

**Before:** No way to speed up or skip animations during testing or for accessibility.

**After:** `AnimationCoordinator.skip_animations = true` snaps all animations to their end state instantly. Press Space during gameplay to toggle.

### Problem 5: Animation Rubberbanding

**Before:** When a guest moved, spawned, or entered a stall, they would overshoot their target position, bounce back, and oscillate before settling.

**Cause:** Two animations targeting the same property (`position`) ran in parallel:
1. Move/spawn/entry animation -> tile/stall center
2. Reposition animation -> slot position (offset from center)

The shorter reposition animation (0.15s) would finish first, snapping the guest to the slot. Then the longer move animation (0.3s) would continue pulling back toward center, causing rubberbanding.

**After:** Animation targets go directly to slot positions, and guests with position animations are skipped from repositioning:
1. Move/spawn/entry animation -> **slot position** (calculated by TileOccupancyManager)
2. Reposition animation -> skipped for this guest
3. Other guests on the same tile get reposition animations

**The Rule:** Never queue two animations targeting the same property on the same entity in the same batch.

### Problem 6: Broken Turn Sequencing When Skipping

**Before:** When pressing Space to skip animations, the level end trigger wouldn't fire. All guests would leave, but the game wouldn't detect that the level was complete.

**Cause:** The `play_batch()` function had conditional `await` paths:
```gdscript
if skip_animations:
    _skip_all()           # Synchronous - no await
else:
    await _play_all_parallel()  # Async - awaits
```

In GDScript 4, a function that conditionally awaits may not properly behave as a coroutine when the non-await path is taken. Callers using `await play_batch()` would not properly yield/resume, breaking turn phase sequencing.

**After:** `play_batch()` always yields at least one frame in every code path:
```gdscript
if skip_animations:
    _skip_all()
    await get_tree().process_frame  # Ensures coroutine behavior
else:
    await _play_all_parallel()
```

**The Rule:** Functions that are `await`ed by callers must always await something, even if just `await get_tree().process_frame`. Conditional await paths break coroutine behavior in GDScript 4.

### Problem 7: Invisible Entities When Skipping

**Before:** When skipping animations, spawned guests were invisible. The game logic worked (logs showed guests descending), but entities never appeared visually.

**Cause:** Spawn animations set initial state (invisible, offset position) then animate to final state:
```gdscript
func create_spawn_animation(target_pos: Vector2) -> ParallelAnimationGroup:
    position = Vector2(target_pos.x, target_pos.y - 50.0)
    modulate.a = 0.0  # Invisible!
    # ... create animations to position:y and modulate:a
```

When `skip()` was called, it used `target.set(property, final_value)`:
```gdscript
func skip() -> void:
    target.set("modulate:a", 1.0)  # Fails silently!
```

**The problem:** `Object.set()` does NOT support property subpaths like `"position:y"` or `"modulate:a"`. Only the Tween class has special internal handling for these paths. The `set()` call silently failed, leaving entities invisible.

**After:** `TweenAnimation.skip()` uses a helper that parses subpaths:
```gdscript
func _set_property_path(obj: Object, prop_path: String, value: Variant) -> void:
    if ":" not in prop_path:
        obj.set(prop_path, value)
        return

    var parts = prop_path.split(":")
    var base_value = obj.get(parts[0])
    base_value[parts[1]] = value
    obj.set(parts[0], base_value)
```

**The Rule:** When implementing `skip()` for animations that use property subpaths (like `position:y`, `modulate:a`, `scale:x`), you cannot use `Object.set()` directly. Parse the path and set the subproperty on the base value.

## Debugging

**Animations not playing:**
- Check `skip_animations` is false
- Verify `board_visual` is set on AnimationCoordinator
- Check entity exists via `board_visual.get_guest_entity(guest)`

**Guests not repositioning:**
- Verify `TileOccupancyManager.queue_all_repositions()` is called
- Check guest isn't filtered out (is_exiting, is_in_stall flags)

**Entity doesn't know how to animate:**
- Ensure the entity class has the required `create_*_animation()` method
- Check the method returns a valid `QueuedAnimation` (not null)

**Rubberbanding (guest overshoots and bounces back):**
- Two animations are targeting the same property on the same entity
- Check if move/spawn/entry animation goes to tile center instead of slot position
- Ensure guests with position animations are passed to `queue_all_repositions(skip_guests)`
- Use `get_slot_position_for_guest()` or `get_stall_slot_position_for_guest()` for animation targets

**Turn sequencing breaks when skipping animations:**
- Check that `play_batch()` awaits in ALL code paths, including empty batch and skip paths
- Functions that callers `await` must always yield, even if just `await get_tree().process_frame`
- In GDScript 4, conditional await paths break coroutine behavior

**Entities invisible when skipping animations (spawn, fade-in effects):**
- Check that `skip()` properly handles property subpaths like `"position:y"` or `"modulate:a"`
- `Object.set()` does NOT support subpaths - only Tween does internally
- Ensure `TweenAnimation.skip()` uses `_set_property_path()` helper or equivalent

## Anti-Patterns

### Don't create animations in AnimationCoordinator

```gdscript
# BAD - Coordinator knows too much about entity internals
func queue_guest_move(guest, tile):
    var anim = TweenAnimation.new()
    anim.target = entity
    anim.property = "position"  # Coordinator shouldn't know this
    anim.duration = 0.3
    queue(anim)
```

```gdscript
# GOOD - Entity creates its own animation
func queue_guest_move(guest, tile):
    var entity = board_visual.get_guest_entity(guest)
    var anim = entity.create_move_animation(tile.center_position)
    queue(anim)
```

### Don't play animations immediately in entities

```gdscript
# BAD - Entity plays animation on its own, bypassing coordinator
func enter_stall(stall):
    var tween = create_tween()  # Starts immediately!
    tween.tween_property(self, "position", stall.position, 0.2)
```

```gdscript
# GOOD - Entity returns animation for coordinator to batch
func create_enter_stall_animation(stall_pos: Vector2) -> QueuedAnimation:
    var anim = TweenAnimation.new()
    anim.target = self
    anim.property = "position"
    anim.final_value = stall_pos
    anim.duration = 0.2
    return anim  # Coordinator decides when to play
```

### Don't have multiple animation queues per entity

```gdscript
# BAD - Entity has its own queue AND coordinator has a queue
class GuestEntity:
    var animation_queue: AnimationQueue  # Redundant!

    func move_to_tile(tile):
        var anim = TweenAnimation.new()
        animation_queue.queue_animation(anim)  # Which queue is used when?
```

```gdscript
# GOOD - Single source of truth (coordinator's batch)
class GuestEntity:
    func create_move_animation(to_pos: Vector2) -> QueuedAnimation:
        # Just creates and returns, doesn't manage playback
        return TweenAnimation.new().setup(self, "position", to_pos, 0.3)
```

### Don't queue conflicting animations on the same entity

```gdscript
# BAD - Two animations target "position" on the same entity
var move_anim = entity.create_move_animation(tile_center)
AnimationCoordinator.queue(move_anim)
TileOccupancyManager.queue_all_repositions()  # Also queues position animation!
# Result: Rubberbanding as animations fight each other
```

```gdscript
# GOOD - Move animation targets slot position, skip from repositioning
var target_pos = TileOccupancyManager.get_slot_position_for_guest(guest, tile_pos)
var move_anim = entity.create_move_animation(target_pos)
AnimationCoordinator.queue(move_anim)
TileOccupancyManager.queue_all_repositions([guest])  # Skip this guest
# Result: Smooth movement to correct slot
```

### Don't conditionally await in functions that callers await

```gdscript
# BAD - Function only awaits in one branch
func play_batch() -> void:
    if skip_animations:
        _skip_all()  # No await - returns synchronously
    else:
        await _play_all_parallel()  # Awaits
    batch_completed.emit()
# Result: Callers using `await play_batch()` break when skip path is taken
```

```gdscript
# GOOD - All paths await something
func play_batch() -> void:
    if skip_animations:
        _skip_all()
        await get_tree().process_frame  # Ensures coroutine behavior
    else:
        await _play_all_parallel()
    batch_completed.emit()
# Result: Function behaves consistently as a coroutine
```

### Don't use Object.set() with property subpaths in skip()

```gdscript
# BAD - Object.set() doesn't support subpaths
func skip() -> void:
    target.set("position:y", final_value)  # Silently fails!
    target.set("modulate:a", 1.0)          # Also fails!
# Result: Entity stays at initial state (invisible, wrong position)
```

```gdscript
# GOOD - Parse subpaths and set correctly
func skip() -> void:
    _set_property_path(target, property, final_value)

func _set_property_path(obj: Object, prop_path: String, value: Variant) -> void:
    if ":" not in prop_path:
        obj.set(prop_path, value)
        return

    var parts = prop_path.split(":")
    var base_value = obj.get(parts[0])
    base_value[parts[1]] = value
    obj.set(parts[0], base_value)
# Result: Subproperties like position:y and modulate:a work correctly
```

### Don't mix data display and animated properties in one method

```gdscript
# BAD - refresh() updates both labels AND visual properties
func refresh() -> void:
    stock_label.text = "x%d" % instance.current_stock  # Data display -- OK
    sprite.color = Color.ORANGE                         # Animated property -- wrong!
# Result: Color snaps immediately, bypassing animation system.
# Skip mode can't handle this correctly.
```

```gdscript
# GOOD - Separate data display from animated properties
func update_labels() -> void:
    stock_label.text = "x%d" % instance.current_stock  # Data display only

func create_restock_animation() -> QueuedAnimation:
    # Color change is an animated property
    var jump_anim = JumpAnimation.new()
    jump_anim.target = self
    var color_anim = TweenAnimation.new()
    color_anim.target = sprite
    color_anim.property = "color"
    color_anim.final_value = Color.ORANGE
    color_anim.duration = 0.3
    var group = ParallelAnimationGroup.new()
    group.animations = [jump_anim, color_anim]
    return group
# Result: Color transitions smoothly, or snaps correctly in skip mode
```
