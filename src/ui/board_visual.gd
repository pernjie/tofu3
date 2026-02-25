class_name BoardVisual
extends Node2D

## Renders the game board and manages entity visuals.

signal slot_clicked(pos: Vector2i)

const TILE_SIZE := 144
const AURA_PASSIVE_FILL := Color(0.4, 0.2, 0.6, 0.15)
const AURA_PASSIVE_BORDER := Color(0.5, 0.3, 0.7, 0.3)
const AURA_SELECTED_FILL := Color(0.4, 0.2, 0.6, 0.4)
const AURA_SELECTED_BORDER := Color(0.6, 0.3, 0.8, 0.7)

var board: Board
var stall_slots: Array[Vector2i] = []
var placement_mode: bool = false
var occupied_slots: Dictionary = {}  # Vector2i -> bool
var selected_card_def: CardDefinition = null  # For placement validation
var aura_system = null  # Set externally
var _selected_aura_source = null  # BaseInstance or null
var _selected_aura_tiles: Dictionary = {}  # Vector2i -> true

@onready var tile_layer: Node2D = $TileLayer
@onready var slot_layer: Node2D = $SlotLayer
@onready var stall_container: Node2D = $StallContainer
@onready var guest_container: Node2D = $GuestContainer

var guest_scene: PackedScene = preload("res://src/entities/guest/guest.tscn")
var stall_scene: PackedScene = preload("res://src/entities/stall/stall.tscn")
var relic_scene: PackedScene = preload("res://src/entities/relic/relic.tscn")

var guest_entities: Dictionary = {}  # instance_id -> GuestEntity
var stall_entities: Dictionary = {}  # Vector2i -> StallEntity
var relic_entities: Dictionary = {}  # Vector2i -> RelicEntity


func setup(p_board: Board) -> void:
	board = p_board
	stall_slots = board.get_valid_stall_positions()
	occupied_slots.clear()
	queue_redraw()

	# Connect animation systems
	AnimationCoordinator.set_board_visual(self)
	TileOccupancyManager.set_board_visual(self)


func set_placement_mode(enabled: bool, card_def: CardDefinition = null) -> void:
	placement_mode = enabled
	selected_card_def = card_def
	queue_redraw()


func set_aura_system(system) -> void:
	if aura_system and aura_system.aura_tiles_changed.is_connected(queue_redraw):
		aura_system.aura_tiles_changed.disconnect(queue_redraw)
	aura_system = system
	if aura_system:
		aura_system.aura_tiles_changed.connect(queue_redraw)


func _is_valid_placement(slot_pos: Vector2i) -> bool:
	## Check if a stall slot is valid for the currently selected card.
	## Spells: depends on target_type (stall slots handle "stall" and "tile" targets).
	## Relics: valid only on empty slots (no stall, no relic).
	## Stalls: valid on empty slots OR same-type stall that can upgrade.
	if not placement_mode or not selected_card_def:
		return false

	var is_occupied = occupied_slots.get(slot_pos, false)

	if selected_card_def is SpellDefinition:
		var spell_def := selected_card_def as SpellDefinition
		match spell_def.target_type:
			"stall":
				return is_occupied
			"tile":
				return _check_spell_tile_filter(spell_def, slot_pos)
			"guest":
				return not BoardSystem.get_guests_at(slot_pos).is_empty()
			_:
				return false

	if selected_card_def is RelicDefinition:
		# Relics can only go on empty slots
		return not is_occupied

	# Stall placement
	if not is_occupied:
		return true  # Empty slot is always valid

	# Check if occupied by same type stall and upgradeable
	var stall_entity = stall_entities.get(slot_pos)
	if stall_entity and stall_entity.instance:
		var stall_def = selected_card_def as StallDefinition
		if stall_def and stall_entity.instance.definition.id == stall_def.id and stall_entity.instance.can_upgrade():
			return true

	return false


func _is_spell_targeting_tiles() -> bool:
	## Returns true when the current spell needs path tile interaction (tile or guest targeting).
	if not placement_mode or not selected_card_def is SpellDefinition:
		return false
	var spell_def := selected_card_def as SpellDefinition
	return spell_def.target_type in ["tile", "guest"]


func _is_valid_spell_path_tile(pos: Vector2i) -> bool:
	## Check if a path tile is a valid target for the current spell.
	if not _is_spell_targeting_tiles():
		return false
	var spell_def := selected_card_def as SpellDefinition
	if spell_def.target_type == "guest":
		return not BoardSystem.get_guests_at(pos).is_empty()
	# target_type == "tile"
	return _check_spell_tile_filter(spell_def, pos)


func _check_spell_tile_filter(spell_def: SpellDefinition, pos: Vector2i) -> bool:
	## Apply the spell's target_filter to a tile position.
	var filter = spell_def.target_filter
	if filter.is_empty():
		return true
	if filter.has("has_stall"):
		var has_stall = BoardSystem.get_stall_at(pos) != null
		if has_stall != filter["has_stall"]:
			return false
	if filter.has("has_guest"):
		var has_guest = not BoardSystem.get_guests_at(pos).is_empty()
		if has_guest != filter["has_guest"]:
			return false
	return true


func add_guest_entity(guest: GuestInstance) -> GuestEntity:
	var entity = guest_scene.instantiate() as GuestEntity
	guest_container.add_child(entity)
	entity.setup(guest)
	if guest.current_tile:
		var pos = Vector2(guest.current_tile.position) * GuestEntity.TILE_SIZE + Vector2(GuestEntity.TILE_SIZE / 2, GuestEntity.TILE_SIZE / 2)
		entity.set_position_immediate(pos)
		entity.update_last_path_position(pos)
	guest_entities[guest.instance_id] = entity
	return entity


func remove_guest_entity(guest: GuestInstance, _animate: bool = false) -> void:
	## Remove guest entity from the board.
	## Animation is handled by TurnSystem before this is called.
	if guest.instance_id in guest_entities:
		var entity = guest_entities[guest.instance_id]
		entity.queue_free()
		guest_entities.erase(guest.instance_id)


func get_guest_entity(guest: GuestInstance) -> GuestEntity:
	return guest_entities.get(guest.instance_id, null)


func add_stall_entity(stall: StallInstance, pos: Vector2i) -> StallEntity:
	var entity = stall_scene.instantiate() as StallEntity
	stall_container.add_child(entity)
	entity.setup(stall, pos)
	stall_entities[pos] = entity
	occupied_slots[pos] = true
	queue_redraw()  # Redraw to update slot colors
	return entity


func get_stall_entity(pos: Vector2i) -> StallEntity:
	return stall_entities.get(pos, null)


func refresh_stall(pos: Vector2i) -> void:
	var entity = get_stall_entity(pos)
	if entity:
		entity.refresh()


func add_relic_entity(relic: RelicInstance, pos: Vector2i) -> RelicEntity:
	var entity = relic_scene.instantiate() as RelicEntity
	stall_container.add_child(entity)
	entity.setup(relic, pos)
	relic_entities[pos] = entity
	occupied_slots[pos] = true
	queue_redraw()
	return entity


func get_relic_entity(pos: Vector2i) -> RelicEntity:
	return relic_entities.get(pos, null)


func _draw_aura_tiles() -> void:
	if not aura_system:
		return

	var all_tiles = aura_system.get_all_aura_tiles()

	# Draw passive aura tiles (skip any that are in the selected set)
	for pos in all_tiles:
		if _selected_aura_tiles.has(pos):
			continue
		var rect = Rect2(Vector2(pos) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
		draw_rect(rect, AURA_PASSIVE_FILL)
		draw_rect(rect, AURA_PASSIVE_BORDER, false, 2.0)

	# Draw selected aura tiles (prominent)
	for pos in _selected_aura_tiles:
		var rect = Rect2(Vector2(pos) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
		draw_rect(rect, AURA_SELECTED_FILL)
		draw_rect(rect, AURA_SELECTED_BORDER, false, 2.0)


func _draw() -> void:
	if not board:
		return

	# Draw path tiles
	var spell_targets_tiles = _is_spell_targeting_tiles()
	for tile in board.tiles.values():
		var rect = Rect2(
			Vector2(tile.position.x, tile.position.y) * TILE_SIZE,
			Vector2(TILE_SIZE, TILE_SIZE)
		)
		if spell_targets_tiles and _is_valid_spell_path_tile(tile.position):
			draw_rect(rect, Color.DARK_GREEN)
			draw_rect(rect, Color.GREEN, false, 2.0)
		else:
			draw_rect(rect, Color.DIM_GRAY)
			draw_rect(rect, Color.GRAY, false, 2.0)

	# Draw stall slots
	for slot_pos in stall_slots:
		var rect = Rect2(
			Vector2(slot_pos.x, slot_pos.y) * TILE_SIZE,
			Vector2(TILE_SIZE, TILE_SIZE)
		)

		var is_occupied = occupied_slots.get(slot_pos, false)
		var is_valid = _is_valid_placement(slot_pos)
		var fill_color: Color
		var border_color: Color

		if placement_mode and is_valid:
			if is_occupied:
				# Upgradeable stall - blue highlight
				fill_color = Color(0.2, 0.3, 0.5, 0.5)
				border_color = Color.DODGER_BLUE
			else:
				# Empty valid slot - green highlight
				fill_color = Color.DARK_GREEN
				border_color = Color.GREEN
		elif is_occupied:
			fill_color = Color(0.3, 0.3, 0.3, 0.3)
			border_color = Color.DARK_GRAY
		else:
			fill_color = Color(0.2, 0.3, 0.2, 0.5)
			border_color = Color.DARK_GREEN

		draw_rect(rect, fill_color)
		draw_rect(rect, border_color, false, 2.0)

	# Aura range overlay
	_draw_aura_tiles()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Convert global position to local, accounting for board position
			var local_pos = to_local(event.global_position)
			var tile_pos = Vector2i(local_pos / TILE_SIZE)

			# In placement mode: allow clicking valid stall slots or valid path tiles (for spells)
			# Without placement mode: allow clicking any stall slot (for aura selection)
			if placement_mode:
				if tile_pos in stall_slots and _is_valid_placement(tile_pos):
					slot_clicked.emit(tile_pos)
				elif board and board.tiles.has(tile_pos) and _is_valid_spell_path_tile(tile_pos):
					slot_clicked.emit(tile_pos)
			elif tile_pos in stall_slots:
				slot_clicked.emit(tile_pos)


func select_aura_source(source: BaseInstance) -> void:
	## Highlight aura range for a specific source entity.
	_selected_aura_source = source
	if aura_system:
		_selected_aura_tiles = aura_system.get_aura_tiles_for(source)
	queue_redraw()


func clear_aura_selection() -> void:
	## Clear the aura source selection highlight.
	if _selected_aura_source == null:
		return
	_selected_aura_source = null
	_selected_aura_tiles.clear()
	queue_redraw()
