# Patrons of the Night

A roguelike deckbuilding tower-defense game built with Godot 4.5.

## Project Overview

Players manage a night market, placing stalls (cards) to serve supernatural guests. Guests walk paths across the board, stopping at stalls to fulfill needs (food, fun). The goal is to fulfill guests' needs before they leave while managing tokens (currency) and reputation.

## Architecture

### Data Flow
```
JSON files → ContentRegistry (autoload) → Definition classes (Resources)
                                              ↓
                                       Instance classes (runtime)
```

### Key Directories
- `data/` - JSON content definitions (guests, stalls, skills, etc.)
- `src/definitions/` - Resource classes that parse JSON into typed data
- `src/instances/` - Runtime instances created from definitions
- `src/autoload/` - Singletons (EventBus, ContentRegistry)
- `src/board/` - Spatial primitives (Tile, Path, Board)
- `src/skills/`, `src/skill_effects/`, `src/skill_conditions/` - Skill system

### Autoloads
- `EventBus` - Pure signal hub for decoupled communication
- `ContentRegistry` - Loads and indexes all definitions from JSON

### Non-Autoload Systems (child nodes of game scene)
- `StatusEffectSystem` - Buff/debuff lifecycle (apply, tick, remove)
- `AuraSystem` - Proximity-based status effects (see `docs/aura-system.md`)
- `DeckSystem` - Card draw, play, and deck management

## Coding Conventions

### GDScript Style
- Use `snake_case` for variables, functions, files
- Use `PascalCase` for class names
- Use `SCREAMING_SNAKE_CASE` for constants
- Prefer typed variables: `var count: int = 0`
- Prefer typed arrays: `Array[String]` over `Array`

### Definition Classes
- All definitions extend `BaseDefinition` (Resource)
- Implement `static func from_dict(data: Dictionary) -> BaseDefinition`
- Properties should have explicit types
- Use `@export` sparingly (definitions load from JSON, not editor)

### Instance Classes
- All instances extend `BaseInstance` (RefCounted) except `CardInstance`
- Instances hold mutable runtime state
- Reference immutable Definition classes
- Use `ModifierStack` for stat calculations

**Creating instances:**
```gdscript
var guest = GuestInstance.new(guest_def)
var stall = StallInstance.new(stall_def)
var card = CardInstance.new(card_def)
```

**Getting modified stats:**
```gdscript
guest.get_effective_money()  # Returns money with modifiers applied
stall.get_value()            # Returns service value with modifiers
guest.get_stat("speed", base_value)  # Generic stat calculation
```

**Instance classes:**
- `GuestInstance` - Runtime guest state (needs, money, position, service state)
- `StallInstance` - Runtime stall state (tier, stock, occupants, enhancement)
- `CardInstance` - Runtime card state (location, enhancement, temporary modifiers)
- `SkillInstance` - Per-entity skill state (counters, flags)
- `StatusEffectInstance` - Runtime buff/debuff (stacks, applied modifiers)

**Modifier system:**
- `StatModifier` - Single stat modification (ADD, MULTIPLY, SET, ADD_FINAL)
- `ModifierStack` - Manages modifiers and calculates final values

### Board System
- `Tile` - Position and placement restrictions (pure spatial data)
- `Path` - Ordered sequence of tiles (spawn at index 0, exit at last index)
- `Board` - Manages paths and provides spatial queries

**Creating a board:**
```gdscript
var board = Board.from_dict(level_data.board)
```

**Spatial queries:**
```gdscript
board.get_tile_at(Vector2i(1, 0))           # Get tile at position
board.get_adjacent_tiles(pos)                # Get 4-directional neighbors
board.get_distance(from_pos, to_pos)         # Manhattan distance
board.get_tiles_in_range(center, range_val)  # All tiles within range
board.can_place_at(pos)                      # Check stall placement validity
```

**Path navigation:**
```gdscript
path.get_spawn_tile()                        # First tile (index 0)
path.get_exit_tile()                         # Last tile
path.get_tile_at_index(index)                # Tile at specific index
path.get_next_index(current, direction)      # Next index (1=forward, -1=reverse)
```

### JSON Data Files
- Each type has a `_schema.json` for validation
- Use `id` as the unique identifier (matches filename without extension)
- Use `_key` suffix for localization keys: `display_name_key`, `description_key`

### Events
- Emit signals through `EventBus` singleton
- Keep EventBus as pure signal hub (no logic)
- Signal names use past tense: `guest_served`, `card_played`

## Common Patterns

### Loading a Definition
```gdscript
var guest_def = ContentRegistry.get_definition("guests", "hungry_ghost")
```

### Creating an Instance
```gdscript
var guest = GuestInstance.new(guest_def)
```

### Emitting Events
```gdscript
EventBus.guest_served.emit(guest, stall)
```

## Testing

Run the project to see console output from ContentRegistry showing:
- Number of definitions loaded per type
- Any parsing errors or warnings

The debug scene (`src/debug/debug_scene.tscn`) also tests instance classes:
- Creates instances from definitions
- Tests modifier stacks and stat calculations
- Verifies instance state management

## File Naming
- Definition classes: `<type>_definition.gd` (e.g., `guest_definition.gd`)
- Instance classes: `<type>_instance.gd` (e.g., `guest_instance.gd`)
- JSON data: `<id>.json` (e.g., `hungry_ghost.json`)
- Schemas: `_schema.json` in each data subdirectory

## Documentation
- Use the context7 MCP to look up latest documentation or best practices when needed

## Behavior
- Call out things that don't make sense when requested
- Don't implement hacky fixes, proactively recommend refactors, restructuring, or renaming if there are better ways (but confirm first)