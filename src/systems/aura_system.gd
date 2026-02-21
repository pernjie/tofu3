# src/systems/aura_system.gd
class_name AuraSystem
extends Node

## Manages spatial aura effects: continuously applies/removes status effects
## based on proximity between aura sources and target entities.
## Aura skills use trigger_type "aura" with parameters:
##   range (int): Manhattan distance (default 1)
##   target_type (String): "stall", "guest", or "all" (default "stall")
##   status_effect_id (String): Status to apply to targets in range
##   exclude_self (bool): Whether source is excluded (default true)

# Tracks which targets each aura source has actively applied statuses to.
# Key: source entity instance_id (String)
# Value: Array of AuraRecord dicts
var _active_auras: Dictionary = {}

signal aura_tiles_changed

# Cached tile sets for UI rendering
var _all_aura_tiles: Dictionary = {}  # Vector2i -> true

# External references (set by game.gd)
var board_system = null
var status_effect_system: StatusEffectSystem = null


func set_board_system(system) -> void:
	board_system = system


func set_status_effect_system(system: StatusEffectSystem) -> void:
	status_effect_system = system


func _ready() -> void:
	EventBus.stall_placed.connect(_on_stall_placed)
	EventBus.stall_upgraded.connect(_on_stall_upgraded)
	EventBus.guest_spawned.connect(_on_guest_spawned)
	EventBus.guest_moved.connect(_on_guest_moved)
	EventBus.guest_ascended.connect(_on_entity_removed)
	EventBus.guest_descended.connect(_on_entity_removed)
	EventBus.guest_banished.connect(_on_entity_removed)
	EventBus.relic_placed.connect(_on_relic_placed)


# =============================================================================
# Public API
# =============================================================================

func get_all_aura_tiles() -> Dictionary:
	## Returns all tile positions affected by any active aura.
	## Dictionary[Vector2i, bool]. Used by BoardVisual for passive overlay.
	return _all_aura_tiles


func get_aura_tiles_for(source: BaseInstance) -> Dictionary:
	## Returns tile positions in range of a specific aura source.
	## Dictionary[Vector2i, bool]. Used by BoardVisual for selected overlay.
	var tiles: Dictionary = {}
	var source_id = source.instance_id
	if not _active_auras.has(source_id):
		return tiles

	for record in _active_auras[source_id]:
		var source_pos = _get_entity_position(record.source)
		if source_pos == Vector2i(-1, -1):
			continue
		var skill: SkillInstance = record.skill
		var aura_range: int = skill.get_parameter("range")
		if aura_range == null:
			aura_range = 1
		# Add all tiles in Manhattan range
		for x in range(source_pos.x - aura_range, source_pos.x + aura_range + 1):
			for y in range(source_pos.y - aura_range, source_pos.y + aura_range + 1):
				var pos = Vector2i(x, y)
				if abs(x - source_pos.x) + abs(y - source_pos.y) <= aura_range:
					tiles[pos] = true
	return tiles


func has_aura(source: BaseInstance) -> bool:
	## Returns true if the given entity is an active aura source.
	return _active_auras.has(source.instance_id)


func register_aura(source: BaseInstance, skill: SkillInstance) -> void:
	## Register an aura skill from an entity. Called when a stall/guest with
	## an aura skill enters the board.
	var source_id = source.instance_id
	if not _active_auras.has(source_id):
		_active_auras[source_id] = []

	var record = {
		"source": source,
		"skill": skill,
		"targets": []  # Array[BaseInstance] currently affected
	}
	_active_auras[source_id].append(record)

	# Initial calculation
	_recalculate_aura(record)
	_rebuild_tile_cache()


func unregister_auras(source: BaseInstance) -> void:
	## Remove all auras from a source entity. Revokes all applied statuses.
	var source_id = source.instance_id
	if not _active_auras.has(source_id):
		return

	for record in _active_auras[source_id]:
		_remove_all_aura_statuses(record)

	_active_auras.erase(source_id)
	_rebuild_tile_cache()


func clear_all() -> void:
	## Remove all auras and their applied statuses. Called on level clear.
	for source_id in _active_auras.keys():
		for record in _active_auras[source_id]:
			_remove_all_aura_statuses(record)
	_active_auras.clear()
	_rebuild_tile_cache()


# =============================================================================
# Recalculation
# =============================================================================

func _recalculate_aura(record: Dictionary) -> void:
	## Recalculate a single aura: diff current targets vs in-range entities,
	## apply to new targets, remove from lost targets.
	var source: BaseInstance = record.source
	var skill: SkillInstance = record.skill
	var old_targets: Array = record.targets.duplicate()

	var aura_range: int = skill.get_parameter("range")
	if aura_range == null:
		aura_range = 1
	var target_type: String = skill.get_parameter("target_type")
	if target_type == null:
		target_type = "stall"
	var status_id = skill.get_parameter("status_effect_id")
	if not status_id:
		push_warning("AuraSystem: aura skill %s has no status_effect_id" % skill.definition.id)
		return
	var exclude_self: bool = skill.get_parameter("exclude_self")
	if exclude_self == null:
		exclude_self = true

	# Find source position
	var source_pos = _get_entity_position(source)
	if source_pos == Vector2i(-1, -1):
		return  # Source not on board

	# Find all valid targets in range
	var new_targets: Array = []
	if target_type == "stall" or target_type == "all":
		for stall in board_system.get_stalls_in_range(source_pos, aura_range):
			if exclude_self and stall == source:
				continue
			new_targets.append(stall)
	if target_type == "guest" or target_type == "all":
		for guest in board_system.get_guests_in_range(source_pos, aura_range):
			if exclude_self and guest == source:
				continue
			new_targets.append(guest)

	# Diff: remove status from entities no longer in range
	for old_target in old_targets:
		if old_target not in new_targets:
			board_system.revoke_status(old_target, status_id)

	# Diff: apply status to new entities in range
	var confirmed_targets: Array = []
	for target in new_targets:
		if target in old_targets:
			# Already has the aura status
			confirmed_targets.append(target)
		else:
			# New target — try to apply
			var result = board_system.inflict_status(target, status_id)
			if result:
				confirmed_targets.append(target)
			# If blocked (null), don't track — will retry on next recalc

	record.targets = confirmed_targets
	_rebuild_tile_cache()


func _recalculate_all_auras() -> void:
	## Recalculate every active aura. Used when broad board state changes.
	for source_id in _active_auras:
		for record in _active_auras[source_id]:
			_recalculate_aura(record)


func _recalculate_auras_near(pos: Vector2i) -> void:
	## Recalculate auras whose source or targets might be affected by
	## a change at the given position. For efficiency, recalculates any aura
	## whose source is within max_range of pos.
	for source_id in _active_auras:
		for record in _active_auras[source_id]:
			var source_pos = _get_entity_position(record.source)
			if source_pos == Vector2i(-1, -1):
				continue
			var skill: SkillInstance = record.skill
			var aura_range: int = skill.get_parameter("range")
			if aura_range == null:
				aura_range = 1
			# Recalc if this aura could possibly reach the changed position
			var dist = abs(source_pos.x - pos.x) + abs(source_pos.y - pos.y)
			if dist <= aura_range:
				_recalculate_aura(record)


func _recalculate_auras_affecting(entity: BaseInstance) -> void:
	## Recalculate all auras that might target this entity.
	## Used when a new entity enters the board and needs to receive aura effects.
	for source_id in _active_auras:
		for record in _active_auras[source_id]:
			if record.source == entity:
				continue  # Don't recalc own auras for this
			_recalculate_aura(record)


# =============================================================================
# Helpers
# =============================================================================

func _rebuild_tile_cache() -> void:
	## Rebuild the cached set of all aura-affected tiles and emit change signal.
	var new_tiles: Dictionary = {}
	for source_id in _active_auras:
		for record in _active_auras[source_id]:
			var source_pos = _get_entity_position(record.source)
			if source_pos == Vector2i(-1, -1):
				continue
			var skill: SkillInstance = record.skill
			var aura_range: int = skill.get_parameter("range")
			if aura_range == null:
				aura_range = 1
			for x in range(source_pos.x - aura_range, source_pos.x + aura_range + 1):
				for y in range(source_pos.y - aura_range, source_pos.y + aura_range + 1):
					var pos = Vector2i(x, y)
					if abs(x - source_pos.x) + abs(y - source_pos.y) <= aura_range:
						new_tiles[pos] = true

	if new_tiles != _all_aura_tiles:
		_all_aura_tiles = new_tiles
		aura_tiles_changed.emit()


func _get_entity_position(entity: BaseInstance) -> Vector2i:
	## Get the board position of an entity.
	if entity is StallInstance:
		return entity.board_position
	elif entity is GuestInstance:
		return entity.current_tile.position if entity.current_tile else Vector2i(-1, -1)
	elif entity is RelicInstance:
		return entity.board_position
	return Vector2i(-1, -1)


func _remove_all_aura_statuses(record: Dictionary) -> void:
	## Remove all statuses this aura has applied to its targets.
	var status_id = record.skill.get_parameter("status_effect_id")
	if not status_id:
		return
	for target in record.targets:
		board_system.revoke_status(target, status_id)
	record.targets.clear()


# =============================================================================
# Event Handlers
# =============================================================================

func _on_stall_placed(stall: StallInstance, _tile) -> void:
	## A stall was placed. Two things to check:
	## 1. Does this stall have aura skills? Register them.
	## 2. Is this stall in range of existing auras? Recalculate those.
	_register_entity_auras(stall)
	_recalculate_auras_affecting(stall)


func _on_stall_upgraded(stall: StallInstance, _new_tier: int) -> void:
	## Stall upgraded — skills may have changed. Unregister old auras,
	## re-register from current skills.
	unregister_auras(stall)
	_register_entity_auras(stall)


func _on_guest_spawned(guest: GuestInstance) -> void:
	## Guest entered the board. Register any auras and check if in range of existing.
	_register_entity_auras(guest)
	_recalculate_auras_affecting(guest)


func _on_guest_moved(guest: GuestInstance, _from_tile, _to_tile) -> void:
	## Guest moved. Recalculate:
	## 1. Auras sourced by this guest (targets changed)
	## 2. All auras that target guests near this guest's new position
	var guest_id = guest.instance_id
	if _active_auras.has(guest_id):
		for record in _active_auras[guest_id]:
			_recalculate_aura(record)

	# Recalculate auras that might now include/exclude this guest
	_recalculate_auras_affecting(guest)


func _on_entity_removed(entity) -> void:
	## Entity left the board. Clean up auras it sourced and remove it
	## from any aura target lists.
	unregister_auras(entity)
	_remove_entity_from_all_targets(entity)


func _on_relic_placed(relic, _tile) -> void:
	## A relic was placed. Register any auras and check nearby auras.
	_register_entity_auras(relic)
	if relic is BaseInstance:
		_recalculate_auras_affecting(relic)


func _remove_entity_from_all_targets(entity: BaseInstance) -> void:
	## Remove an entity from all aura target lists (without revoking status,
	## since the entity is being removed from the board anyway).
	for source_id in _active_auras:
		for record in _active_auras[source_id]:
			record.targets.erase(entity)


func _register_entity_auras(entity: BaseInstance) -> void:
	## Check an entity's skills for aura trigger types and register them.
	for skill in entity.skill_instances:
		if skill.definition and skill.definition.trigger_type == "aura":
			register_aura(entity, skill)
