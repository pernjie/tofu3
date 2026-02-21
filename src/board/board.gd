# src/board/board.gd
class_name Board
extends RefCounted

## Manages the game board grid and provides spatial queries.
## Contains paths and a lookup table for tiles.

var paths: Array[Path] = []
var tiles: Dictionary = {}  # Vector2i -> Tile


static func from_dict(data: Dictionary) -> Board:
	var board = Board.new()
	var tile_lookup: Dictionary = {}

	# Load paths (creates tiles as needed)
	for path_data in data.paths:
		var path = Path.from_dict(path_data, tile_lookup)
		board.paths.append(path)

	board.tiles = tile_lookup
	return board


func get_tile_at(pos: Vector2i) -> Tile:
	return tiles.get(pos, null)


func get_path_by_id(path_id: String) -> Path:
	for path in paths:
		if path.id == path_id:
			return path
	return null


func get_adjacent_positions(pos: Vector2i) -> Array[Vector2i]:
	## Get 4-directional adjacent positions.
	var result: Array[Vector2i] = []
	result.append(pos + Vector2i.UP)
	result.append(pos + Vector2i.DOWN)
	result.append(pos + Vector2i.LEFT)
	result.append(pos + Vector2i.RIGHT)
	return result


func get_adjacent_tiles(pos: Vector2i) -> Array[Tile]:
	## Get tiles adjacent to a position (only returns tiles that exist).
	var result: Array[Tile] = []
	for adj_pos in get_adjacent_positions(pos):
		var tile = get_tile_at(adj_pos)
		if tile:
			result.append(tile)
	return result


func get_distance(from_pos: Vector2i, to_pos: Vector2i) -> int:
	## Manhattan distance for 4-directional grid.
	return abs(from_pos.x - to_pos.x) + abs(from_pos.y - to_pos.y)


func get_positions_in_range(center: Vector2i, range_val: int) -> Array[Vector2i]:
	## Get all positions within Manhattan distance of center.
	var result: Array[Vector2i] = []
	for x in range(center.x - range_val, center.x + range_val + 1):
		for y in range(center.y - range_val, center.y + range_val + 1):
			var pos = Vector2i(x, y)
			if get_distance(center, pos) <= range_val:
				result.append(pos)
	return result


func get_tiles_in_range(center: Vector2i, range_val: int) -> Array[Tile]:
	## Get all tiles within range (only returns tiles that exist).
	var result: Array[Tile] = []
	for pos in get_positions_in_range(center, range_val):
		var tile = get_tile_at(pos)
		if tile:
			result.append(tile)
	return result


func get_all_path_positions() -> Array[Vector2i]:
	## Get all positions that are part of any path.
	var result: Array[Vector2i] = []
	for pos in tiles.keys():
		result.append(pos)
	return result


func get_valid_stall_positions() -> Array[Vector2i]:
	## Get all positions where a stall could be placed.
	## By default: adjacent to path tiles, not on path tiles.
	var result: Array[Vector2i] = []
	var checked: Dictionary = {}

	for tile in tiles.values():
		for adj_pos in get_adjacent_positions(tile.position):
			if adj_pos in checked:
				continue
			checked[adj_pos] = true

			# Skip if it's a path tile itself
			if adj_pos in tiles:
				continue

			# Check restrictions on the adjacent path tile
			if not tile.has_restriction("no_adjacent_stall"):
				if adj_pos not in result:
					result.append(adj_pos)

	return result


func can_place_at(pos: Vector2i) -> bool:
	## Check if a stall can be placed at this position.
	# Can't place on path tiles
	if pos in tiles:
		return false

	# Must be adjacent to at least one path tile
	var adjacent_to_path = false
	for adj_pos in get_adjacent_positions(pos):
		var adj_tile = get_tile_at(adj_pos)
		if adj_tile:
			adjacent_to_path = true
			# Check if that tile forbids adjacent stalls
			if adj_tile.has_restriction("no_adjacent_stall"):
				return false

	return adjacent_to_path


func get_path_tiles_adjacent_to(pos: Vector2i) -> Array[Tile]:
	## Get path tiles adjacent to a non-path position.
	## Useful for determining which path a stall serves.
	var result: Array[Tile] = []
	for adj_pos in get_adjacent_positions(pos):
		var tile = get_tile_at(adj_pos)
		if tile:
			result.append(tile)
	return result
