# test/helpers/test_base.gd
extends GutTest

var status_effect_system: StatusEffectSystem
var deck_system: DeckSystem

func before_each():
	# Skip animations — action methods still mutate state
	AnimationCoordinator.skip_animations = true
	AnimationCoordinator.clear_batch()

	# Clear game state
	BoardSystem.clear_level()
	BoardSystem.relics.clear()
	TriggerSystem.clear_all()

	# Direct state reset — no start_run() needed
	GameManager.tokens = 100
	GameManager.reputation = 10

	# Wire non-autoload systems (mirrors game.gd setup)
	status_effect_system = StatusEffectSystem.new()
	add_child(status_effect_system)
	status_effect_system.set_trigger_system(TriggerSystem)
	BoardSystem.set_status_effect_system(status_effect_system)
	BoardSystem.set_trigger_system(TriggerSystem)

	# Wire DeckSystem (mirrors game.gd setup)
	deck_system = DeckSystem.new()
	add_child(deck_system)
	BoardSystem.set_deck_system(deck_system)

	# Minimal board for adjacency queries
	_setup_default_board()

func after_each():
	BoardSystem.set_deck_system(null)
	if deck_system:
		remove_child(deck_system)
		deck_system.free()
		deck_system = null
	BoardSystem.set_status_effect_system(null)
	BoardSystem.set_trigger_system(null)
	if status_effect_system:
		remove_child(status_effect_system)
		status_effect_system.free()
		status_effect_system = null

func _setup_default_board() -> void:
	var board_data = {
		"paths": [{
			"id": "main",
			"tiles": [
				{"x": 0, "y": 0},
				{"x": 1, "y": 0},
				{"x": 2, "y": 0},
				{"x": 3, "y": 0},
				{"x": 4, "y": 0}
			]
		}]
	}
	BoardSystem.board = Board.from_dict(board_data)

# --- Instance Helpers ---

func create_guest(guest_id: String) -> GuestInstance:
	var def = ContentRegistry.get_definition("guests", guest_id)
	return GuestInstance.new(def)

func create_stall(stall_id: String) -> StallInstance:
	var def = ContentRegistry.get_definition("stalls", stall_id)
	return StallInstance.new(def)

func register_guest(guest: GuestInstance, position: Vector2i) -> void:
	guest.current_tile = BoardSystem.board.get_tile_at(position)
	# Set path_index so effects that need path context (e.g. summon_guest) work
	for path in BoardSystem.board.paths:
		var idx = path.get_tile_index(guest.current_tile)
		if idx >= 0:
			guest.path_index = idx
			break
	BoardSystem.active_guests.append(guest)
	TriggerSystem.register_entity_skills(guest)

func register_stall(stall: StallInstance, position: Vector2i) -> void:
	stall.board_position = position
	BoardSystem.stalls[position] = stall
	TriggerSystem.register_entity_skills(stall)

func create_relic(relic_id: String) -> RelicInstance:
	var def = ContentRegistry.get_definition("relics", relic_id)
	return RelicInstance.new(def)

func register_relic(relic: RelicInstance, position: Vector2i) -> void:
	relic.board_position = position
	relic.tile = Tile.new()
	relic.tile.position = position
	BoardSystem.relics[position] = relic
	TriggerSystem.register_entity_skills(relic)

func fire(trigger_type: String, context: TriggerContext) -> Array[SkillEffectResult]:
	return TriggerSystem.trigger_skills(trigger_type, context)

func fire_for(trigger_type: String, context: TriggerContext, entities: Array) -> Array[SkillEffectResult]:
	return TriggerSystem.trigger_entity_skills(trigger_type, context, entities)
