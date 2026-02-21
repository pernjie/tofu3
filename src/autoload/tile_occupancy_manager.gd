# src/autoload/tile_occupancy_manager.gd
extends Node

## Calculates and queues guest repositioning animations.
## Called by TurnSystem after state changes, before animation playback.

# Configuration
@export var path_tile_spacing: float = 32.0
@export var stall_spacing: float = 32.0

const TILE_SIZE := 144

var board_visual: BoardVisual = null


func set_board_visual(visual: BoardVisual) -> void:
	board_visual = visual


func queue_all_repositions(skip_guests: Array[GuestInstance] = []) -> void:
	## Queue repositioning animations for all guests based on current state.
	## Call this after logical state changes, before AnimationCoordinator.play_batch().
	## skip_guests: Guests to exclude (e.g., those with move animations already queued).
	if not board_visual:
		return
	_queue_path_tile_repositions(skip_guests)
	_queue_stall_repositions(skip_guests)


func get_slot_position_for_guest(guest: GuestInstance, tile_pos: Vector2i) -> Vector2:
	## Calculate the slot position for a specific guest at a tile.
	## Used by TurnSystem to set move animation targets directly to slot positions.
	var occupants: Array[GuestInstance] = []

	for g in BoardSystem.active_guests:
		if g.is_exiting or g.is_in_stall:
			continue
		if g.current_tile and g.current_tile.position == tile_pos:
			occupants.append(g)

	var slots = _calculate_path_tile_slots(occupants.size())
	var tile_world_pos = _tile_to_world(tile_pos)

	# Find this guest's index in the occupants list
	var guest_index = occupants.find(guest)
	if guest_index == -1:
		# Guest not found, return tile center
		return tile_world_pos + Vector2(72, 72)

	var slot_offset = slots[guest_index] if guest_index < slots.size() else Vector2(72, 72)
	return tile_world_pos + slot_offset


func get_stall_slot_position_for_guest(guest: GuestInstance, stall: StallInstance) -> Vector2:
	## Calculate the slot position for a specific guest in a stall.
	## Used by TurnSystem to set stall entry animation targets directly to slot positions.
	var occupants: Array[GuestInstance] = []

	for g in stall.current_occupants:
		if not g.is_exiting:
			occupants.append(g)

	var slots = _calculate_stall_slots(occupants.size())
	var stall_world_pos = _tile_to_world(stall.board_position)

	# Find this guest's index in the occupants list
	var guest_index = occupants.find(guest)
	if guest_index == -1:
		# Guest not found, return stall center
		return stall_world_pos + Vector2(72, 72)

	var slot_offset = slots[guest_index] if guest_index < slots.size() else Vector2(72, 72)
	return stall_world_pos + slot_offset


func _queue_path_tile_repositions(skip_guests: Array[GuestInstance]) -> void:
	## Queue repositions for all path tiles with multiple guests.
	## skip_guests: Guests to exclude from repositioning.
	# Group guests by tile
	var tile_occupants: Dictionary = {}  # Vector2i -> Array[GuestInstance]

	for guest in BoardSystem.active_guests:
		if guest.is_exiting or guest.is_in_stall:
			continue
		if not guest.current_tile:
			continue

		var pos = guest.current_tile.position
		if not tile_occupants.has(pos):
			tile_occupants[pos] = []
		tile_occupants[pos].append(guest)

	# Queue repositions for each tile
	for tile_pos in tile_occupants:
		var occupants: Array = tile_occupants[tile_pos]
		if occupants.is_empty():
			continue

		var slots = _calculate_path_tile_slots(occupants.size())
		var tile_world_pos = _tile_to_world(tile_pos)

		for i in occupants.size():
			var guest = occupants[i]
			# Skip guests that already have move animations
			if guest in skip_guests:
				continue
			var slot_offset = slots[i] if i < slots.size() else Vector2(72, 72)
			var target_pos = tile_world_pos + slot_offset

			var entity = board_visual.get_guest_entity(guest)
			if entity:
				var anim = entity.create_reposition_animation(target_pos)
				AnimationCoordinator.queue(anim)


func _queue_stall_repositions(skip_guests: Array[GuestInstance]) -> void:
	## Queue repositions for all stalls with multiple guests.
	## skip_guests: Guests to exclude from repositioning.
	for stall in BoardSystem.get_all_stalls():
		var occupants: Array[GuestInstance] = []
		for guest in stall.current_occupants:
			if not guest.is_exiting:
				occupants.append(guest)

		if occupants.is_empty():
			continue

		var slots = _calculate_stall_slots(occupants.size())
		var stall_world_pos = _tile_to_world(stall.board_position)

		for i in occupants.size():
			var guest = occupants[i]
			# Skip guests that already have move animations
			if guest in skip_guests:
				continue
			var slot_offset = slots[i] if i < slots.size() else Vector2(72, 72)
			var target_pos = stall_world_pos + slot_offset

			var entity = board_visual.get_guest_entity(guest)
			if entity:
				var anim = entity.create_reposition_animation(target_pos)
				AnimationCoordinator.queue(anim)


func _tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x, tile_pos.y) * TILE_SIZE


# =============================================================================
# Slot Calculation (unchanged)
# =============================================================================

func _calculate_path_tile_slots(count: int) -> Array[Vector2]:
	if count == 0:
		return []
	if count == 1:
		return [Vector2(72, 72)]

	var slots: Array[Vector2] = []
	var rows = _get_row_distribution(count)
	var num_rows = rows.size()
	var total_height = (num_rows - 1) * path_tile_spacing
	var start_y = (TILE_SIZE - total_height) / 2.0

	for row_idx in num_rows:
		var guests_in_row = rows[row_idx]
		var row_width = (guests_in_row - 1) * path_tile_spacing
		var start_x = (TILE_SIZE - row_width) / 2.0
		var y = start_y + row_idx * path_tile_spacing

		for col in guests_in_row:
			var x = start_x + col * path_tile_spacing
			slots.append(Vector2(x, y))

	return slots


func _calculate_stall_slots(count: int) -> Array[Vector2]:
	if count == 0:
		return []
	if count == 1:
		return [Vector2(72, 72)]

	var slots: Array[Vector2] = []
	var row_width = (count - 1) * stall_spacing
	var start_x = (TILE_SIZE - row_width) / 2.0
	var y = TILE_SIZE / 2.0

	for i in count:
		slots.append(Vector2(start_x + i * stall_spacing, y))

	return slots


func _get_row_distribution(count: int) -> Array[int]:
	var num_rows = ceili(sqrt(float(count)))
	var rows: Array[int] = []
	rows.resize(num_rows)

	var base_per_row = count / num_rows
	var extras = count % num_rows

	for i in num_rows:
		rows[i] = base_per_row

	var middle = num_rows / 2
	for i in extras:
		var offset = (i + 1) / 2
		var target_row: int
		if i % 2 == 0:
			target_row = mini(middle + offset, num_rows - 1)
		else:
			target_row = maxi(middle - offset, 0)
		rows[target_row] += 1

	return rows
