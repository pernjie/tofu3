# src/board/path.gd
class_name Path
extends RefCounted

## An ordered sequence of tiles that guests walk along.
## First tile is spawn point, last tile is exit.

var id: String
var tiles: Array[Tile] = []


func _init(path_id: String = "") -> void:
	id = path_id


static func from_dict(data: Dictionary, tile_lookup: Dictionary) -> Path:
	var path = Path.new(data.id)
	for tile_data in data.tiles:
		var pos = Vector2i(tile_data.x, tile_data.y)
		var tile: Tile
		if pos in tile_lookup:
			tile = tile_lookup[pos]
		else:
			tile = Tile.from_dict(tile_data)
			tile_lookup[pos] = tile
		path.tiles.append(tile)

	# Spawn and exit tiles should not have adjacent stalls
	if path.tiles.size() > 0:
		path.tiles[0].add_restriction("no_adjacent_stall")
		path.tiles[-1].add_restriction("no_adjacent_stall")

	return path


func get_spawn_tile() -> Tile:
	return tiles[0] if not tiles.is_empty() else null


func get_exit_tile() -> Tile:
	return tiles[-1] if not tiles.is_empty() else null


func get_tile_at_index(index: int) -> Tile:
	if index >= 0 and index < tiles.size():
		return tiles[index]
	return null


func get_next_index(current_index: int, direction: int = 1) -> int:
	## Get the next index along the path.
	## direction: 1 = forward (spawn->exit), -1 = reverse (exit->spawn)
	## Returns -1 if the next index would be out of bounds.
	var next_index = current_index + direction
	if next_index < 0 or next_index >= tiles.size():
		return -1
	return next_index


func is_valid_index(index: int) -> bool:
	return index >= 0 and index < tiles.size()


func get_length() -> int:
	return tiles.size()


func get_tile_index(tile: Tile) -> int:
	## Find the index of a tile in this path. Returns -1 if not found.
	for i in tiles.size():
		if tiles[i] == tile:
			return i
	return -1
