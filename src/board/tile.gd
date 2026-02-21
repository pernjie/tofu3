# src/board/tile.gd
class_name Tile
extends RefCounted

## A single position on the game board.
## Tiles are pure spatial data - runtime state (occupants, stalls) is tracked elsewhere.

var position: Vector2i
var placement_restrictions: Array[String] = []


func _init(pos: Vector2i = Vector2i.ZERO) -> void:
	position = pos


static func from_dict(data: Dictionary) -> Tile:
	var tile = Tile.new(Vector2i(data.x, data.y))
	if data.has("restrictions"):
		for restriction in data.restrictions:
			tile.placement_restrictions.append(restriction)
	return tile


func has_restriction(restriction: String) -> bool:
	return restriction in placement_restrictions


func add_restriction(restriction: String) -> void:
	if restriction not in placement_restrictions:
		placement_restrictions.append(restriction)


func remove_restriction(restriction: String) -> void:
	placement_restrictions.erase(restriction)
