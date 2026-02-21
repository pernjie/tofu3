extends Node

func _ready() -> void:
	print("")
	print("=== Debug Scene: Testing ContentRegistry ===")
	print("")

	# Test get_definition
	var guest = ContentRegistry.get_definition("guests", "hungry_ghost")
	if guest:
		print("✓ Loaded guest: ", guest.id)
		print("  - Display name key: ", guest.display_name_key)
		print("  - Rarity: ", guest.rarity)
		print("  - Base needs: ", guest.base_needs)
		print("  - Base money: ", guest.base_money)
		print("  - Skills: ", guest.skill_data)
	else:
		print("✗ Failed to load hungry_ghost")

	print("")

	var stall = ContentRegistry.get_definition("stalls", "noodle_stand")
	if stall:
		print("✓ Loaded stall: ", stall.id)
		print("  - Operation model: ", stall.operation_model)
		print("  - Need type: ", stall.need_type)
		print("  - Tiers: ", stall.tiers.size())
		if stall.tiers.size() > 0:
			print("  - Tier 1 value: ", stall.tiers[0].value)
	else:
		print("✗ Failed to load noodle_stand")

	print("")

	var status = ContentRegistry.get_definition("status_effects", "charmed")
	if status:
		print("✓ Loaded status effect: ", status.id)
		print("  - Effect type: ", status.effect_type)
		print("  - Stack type: ", status.stack_type)
		print("  - Max stacks: ", status.max_stacks)
	else:
		print("✗ Failed to load charmed")

	print("")

	# Test get_by_tag
	var food_stalls = ContentRegistry.get_by_tag("stalls", "food_stall")
	print("Stalls with 'food_stall' tag: ", food_stalls.size())

	var spirit_guests = ContentRegistry.get_by_tag("guests", "spirit")
	print("Guests with 'spirit' tag: ", spirit_guests.size())

	# Test instance classes
	_test_modifier_stack()
	_test_guest_instance()
	_test_stall_instance()
	_test_card_instance()

	# Test board system
	_test_board_system()

	# Test new systems layer
	_test_skill_effect_system()
	_test_trigger_system()
	_test_systems_integration()

	print("")
	print("=== Debug Scene Complete ===")
	print("")

	# Quit after testing in headless mode
	if DisplayServer.get_name() == "headless":
		get_tree().quit()


func _test_modifier_stack() -> void:
	print("\n=== Testing ModifierStack ===")

	var stack = ModifierStack.new()

	# Test basic add
	var add_mod = StatModifier.new("damage", StatModifier.Operation.ADD, 5, null)
	stack.add_modifier(add_mod)
	var result = stack.calculate_stat("damage", 10)
	print("  10 + 5 = %d (expected: 15)" % result)
	assert(result == 15, "Add modifier failed")

	# Test multiply
	var mult_mod = StatModifier.new("damage", StatModifier.Operation.MULTIPLY, 2.0, null)
	stack.add_modifier(mult_mod)
	result = stack.calculate_stat("damage", 10)
	print("  (10 + 5) * 2 = %d (expected: 30)" % result)
	assert(result == 30, "Multiply modifier failed")

	# Test add_final
	var final_mod = StatModifier.new("damage", StatModifier.Operation.ADD_FINAL, 3, null)
	stack.add_modifier(final_mod)
	result = stack.calculate_stat("damage", 10)
	print("  ((10 + 5) * 2) + 3 = %d (expected: 33)" % result)
	assert(result == 33, "Add final modifier failed")

	# Test removal by source
	var source_obj = RefCounted.new()
	var sourced_mod = StatModifier.new("damage", StatModifier.Operation.ADD, 100, source_obj)
	stack.add_modifier(sourced_mod)
	result = stack.calculate_stat("damage", 10)
	print("  With sourced +100: %d" % result)

	stack.remove_modifiers_from_source(source_obj)
	result = stack.calculate_stat("damage", 10)
	print("  After removing sourced: %d (expected: 33)" % result)
	assert(result == 33, "Remove by source failed")

	print("  ModifierStack tests PASSED")


func _test_guest_instance() -> void:
	print("\n=== Testing GuestInstance ===")

	var guest_def = ContentRegistry.get_definition("guests", "hungry_ghost")
	if not guest_def:
		print("  SKIP: hungry_ghost not found")
		return

	var guest = GuestInstance.new(guest_def)

	print("  Instance ID: %s" % guest.instance_id)
	print("  Entity type: %s" % guest.get_entity_type())
	print("  Current needs: %s" % str(guest.current_needs))
	print("  Current money: %d" % guest.current_money)
	print("  Movement speed: %d" % guest.get_movement_speed())
	print("  Is core guest: %s" % guest.is_core_guest())
	print("  All needs fulfilled: %s" % guest.are_all_needs_fulfilled())

	# Test need fulfillment
	var fulfilled = guest.fulfill_need("food", 2)
	print("  Fulfilled 2 food, actual: %d" % fulfilled)
	print("  Remaining food need: %d" % guest.get_remaining_need("food"))

	# Test money modifier
	var money_debuff = StatModifier.new("money", StatModifier.Operation.MULTIPLY, 0.5, null)
	guest.modifier_stack.add_modifier(money_debuff)
	print("  Effective money with 0.5x debuff: %d (base: %d)" % [guest.get_effective_money(), guest.current_money])

	print("  GuestInstance tests PASSED")


func _test_stall_instance() -> void:
	print("\n=== Testing StallInstance ===")

	var stall_def = ContentRegistry.get_definition("stalls", "noodle_stand")
	if not stall_def:
		print("  SKIP: noodle_stand not found")
		return

	var stall = StallInstance.new(stall_def)

	print("  Instance ID: %s" % stall.instance_id)
	print("  Entity type: %s" % stall.get_entity_type())
	print("  Operation model: %s" % stall.get_operation_model())
	print("  Need type: %s" % stall.get_need_type())
	print("  Current tier: %d" % stall.current_tier)
	print("  Cost to guest: %d" % stall.get_cost_to_guest())
	print("  Value: %d" % stall.get_value())
	print("  Current stock: %d" % stall.current_stock)
	print("  Can upgrade: %s" % stall.can_upgrade())

	# Test upgrade
	if stall.upgrade():
		print("  After upgrade - tier: %d, cost: %d, value: %d" % [
			stall.current_tier,
			stall.get_cost_to_guest(),
			stall.get_value()
		])

	# Test stock usage
	stall.use_stock(1)
	print("  After using 1 stock: %d" % stall.current_stock)

	print("  StallInstance tests PASSED")


func _test_card_instance() -> void:
	print("\n=== Testing CardInstance ===")

	var stall_def = ContentRegistry.get_definition("stalls", "noodle_stand")
	if not stall_def:
		print("  SKIP: noodle_stand not found")
		return

	var card = CardInstance.new(stall_def)

	print("  Instance ID: %s" % card.instance_id)
	print("  Card type: %s" % card.get_card_type())
	print("  Location: %s" % card.get_location_string())
	print("  Base price: %d" % card.definition.get_price())
	print("  Effective price: %d" % card.get_effective_price())

	# Test location change
	card.location = CardInstance.Location.HAND
	print("  After moving to hand: %s" % card.get_location_string())

	# Test price modifier
	var discount = StatModifier.new("price", StatModifier.Operation.MULTIPLY, 0.8, null)
	card.modifier_stack.add_modifier(discount)
	print("  Price with 20%% discount: %d" % card.get_effective_price())

	print("  CardInstance tests PASSED")


func _test_board_system() -> void:
	print("\n=== Testing Board System ===")

	# Test 1: Load a board from dict
	var board_data = {
		"paths": [{
			"id": "main_path",
			"tiles": [
				{"x": 0, "y": 0},
				{"x": 1, "y": 0},
				{"x": 2, "y": 0},
				{"x": 3, "y": 0},
			]
		}]
	}
	var board = Board.from_dict(board_data)
	assert(board.paths.size() == 1, "Should have 1 path")
	assert(board.tiles.size() == 4, "Should have 4 tiles")
	print("  Board loading: PASSED")

	# Test 2: Path spawn/exit
	var path = board.paths[0]
	assert(path.get_spawn_tile().position == Vector2i(0, 0), "Spawn should be at (0,0)")
	assert(path.get_exit_tile().position == Vector2i(3, 0), "Exit should be at (3,0)")
	assert(path.get_length() == 4, "Path length should be 4")
	print("  Path spawn/exit: PASSED")

	# Test 3: Path navigation
	assert(path.get_tile_at_index(1).position == Vector2i(1, 0), "Index 1 should be (1,0)")
	assert(path.get_next_index(1, 1) == 2, "Next index forward from 1 should be 2")
	assert(path.get_next_index(1, -1) == 0, "Next index backward from 1 should be 0")
	assert(path.is_valid_index(3), "Index 3 should be valid")
	assert(not path.is_valid_index(4), "Index 4 should be invalid")
	print("  Path navigation: PASSED")

	# Test 4: Tile lookup
	var tile = board.get_tile_at(Vector2i(2, 0))
	assert(tile != null, "Should find tile at (2,0)")
	assert(tile.position == Vector2i(2, 0), "Tile position should match")
	assert(board.get_tile_at(Vector2i(5, 5)) == null, "Should not find tile at (5,5)")
	print("  Tile lookup: PASSED")

	# Test 5: Adjacency
	var adj = board.get_adjacent_tiles(Vector2i(1, 0))
	assert(adj.size() == 2, "Tile (1,0) should have 2 adjacent path tiles")
	print("  Adjacency: PASSED")

	# Test 6: Manhattan distance
	assert(board.get_distance(Vector2i(0, 0), Vector2i(2, 1)) == 3, "Distance (0,0) to (2,1) should be 3")
	assert(board.get_distance(Vector2i(1, 1), Vector2i(1, 1)) == 0, "Distance to self should be 0")
	print("  Distance: PASSED")

	# Test 7: Range query
	var in_range = board.get_tiles_in_range(Vector2i(1, 0), 1)
	assert(in_range.size() == 3, "3 tiles should be within range 1 of (1,0)")
	print("  Range query: PASSED")

	# Test 8: Placement validation
	var valid = board.get_valid_stall_positions()
	assert(Vector2i(1, 1) in valid, "(1,1) should be valid for stall placement")
	assert(Vector2i(1, -1) in valid, "(1,-1) should be valid for stall placement")
	assert(Vector2i(1, 0) not in valid, "(1,0) is a path tile, not valid for stall")
	assert(board.can_place_at(Vector2i(1, 1)), "can_place_at (1,1) should return true")
	assert(not board.can_place_at(Vector2i(1, 0)), "can_place_at (1,0) should return false")
	print("  Placement validation: PASSED")

	# Test 9: Placement restrictions
	var spawn_tile = path.get_spawn_tile()
	spawn_tile.add_restriction("no_adjacent_stall")
	assert(not board.can_place_at(Vector2i(0, 1)), "Can't place adjacent to restricted tile")
	assert(not board.can_place_at(Vector2i(-1, 0)), "Can't place adjacent to restricted tile")
	assert(board.can_place_at(Vector2i(1, 1)), "Can still place away from restricted tile")
	print("  Placement restrictions: PASSED")

	# Test 10: Path tiles adjacent to placement
	var adjacent_paths = board.get_path_tiles_adjacent_to(Vector2i(2, 1))
	assert(adjacent_paths.size() == 1, "Position (2,1) should be adjacent to 1 path tile")
	assert(adjacent_paths[0].position == Vector2i(2, 0), "Adjacent path tile should be (2,0)")
	print("  Adjacent path query: PASSED")

	print("  Board System tests PASSED")


func _test_skill_effect_system() -> void:
	print("\n=== Testing Skill Effect System ===")

	# Test parameter resolution
	var skill_def = ContentRegistry.get_definition("skills", "charmed_block_fulfillment")
	if not skill_def:
		print("  SKIP: charmed_block_fulfillment not found")
		return

	var guest_def = ContentRegistry.get_definition("guests", "hungry_ghost")
	var guest = GuestInstance.new(guest_def)
	var skill = SkillInstance.new(skill_def, guest)

	print("  Skill ID: %s" % skill.definition.id)
	print("  Trigger type: %s" % skill.definition.trigger_type)
	print("  Parameter 'chance': %s" % skill.get_parameter("chance"))

	# Test condition creation and evaluation
	var conditions = SkillConditionFactory.create_all(skill.definition.conditions)
	print("  Created %d conditions" % conditions.size())

	# Empty conditions should evaluate to true
	var context = TriggerContext.create("on_pre_serve")
	context.with_guest(guest)

	var all_pass = SkillConditionFactory.evaluate_all(conditions, context, skill)
	print("  All conditions pass (empty): %s" % all_pass)
	assert(all_pass, "Empty conditions should pass")

	# Test effect creation
	var effects = SkillEffectFactory.create_all(skill.definition.effects)
	print("  Created %d effects" % effects.size())

	for effect in effects:
		print("  Effect type: %s" % effect.get_effect_type())

	print("  Skill Effect System tests PASSED")


func _test_trigger_system() -> void:
	print("\n=== Testing TriggerSystem ===")

	# Test skill registration
	var skill_def = ContentRegistry.get_definition("skills", "charmed_block_fulfillment")
	if not skill_def:
		print("  SKIP: charmed_block_fulfillment not found")
		return

	var guest_def = ContentRegistry.get_definition("guests", "hungry_ghost")
	var guest = GuestInstance.new(guest_def)
	var skill = SkillInstance.new(skill_def, guest)

	TriggerSystem.register_skill(skill)
	print("  Registered skill: %s" % skill.definition.id)

	# Test triggering
	var context = TriggerContext.create("on_pre_serve")
	context.with_guest(guest)

	var results = TriggerSystem.trigger_skills("on_pre_serve", context)
	print("  Triggered on_pre_serve, got %d results" % results.size())

	for result in results:
		print("  Result success: %s" % result.success)

	TriggerSystem.unregister_skill(skill)
	print("  Unregistered skill")

	# Verify empty after unregister
	results = TriggerSystem.trigger_skills("on_pre_serve", context)
	print("  After unregister: %d results" % results.size())
	assert(results.size() == 0, "Should have no results after unregister")

	print("  TriggerSystem tests PASSED")


func _test_systems_integration() -> void:
	print("\n=== Testing Systems Integration ===")

	# Create a simple test level
	var board_data = {
		"paths": [{
			"id": "main_path",
			"tiles": [
				{"x": 0, "y": 0},
				{"x": 1, "y": 0},
				{"x": 2, "y": 0},
				{"x": 3, "y": 0},
			]
		}]
	}

	# Set up level via BoardSystem
	var level_def = LevelDefinition.new()
	level_def.board = board_data
	BoardSystem.setup_level(level_def)

	# Connect BoardSystem to TriggerSystem
	BoardSystem.set_trigger_system(TriggerSystem)

	print("  Level set up with %d path tiles" % BoardSystem.board.tiles.size())

	# Test stall placement
	var stall_def = ContentRegistry.get_definition("stalls", "noodle_stand")
	if not stall_def:
		print("  SKIP: noodle_stand not found")
		return

	var stall = BoardSystem.place_stall(stall_def, Vector2i(1, 1))
	if stall:
		print("  Placed stall at (1,1)")
		print("  Stall skills registered: %d" % stall.skill_instances.size())
	else:
		print("  Failed to place stall")
		return

	# Test guest spawning
	var guest_def = ContentRegistry.get_definition("guests", "hungry_ghost")
	if not guest_def:
		print("  SKIP: hungry_ghost not found")
		return

	var guest = BoardSystem.spawn_guest(guest_def)
	if guest:
		print("  Spawned guest: %s" % guest.definition.id)
		print("  Guest position: %s" % guest.current_tile.position)
		print("  Guest skills registered: %d" % guest.skill_instances.size())

	# Test entity queries
	var guests_at_spawn = BoardSystem.get_guests_at(Vector2i(0, 0))
	print("  Guests at (0,0): %d" % guests_at_spawn.size())

	var adjacent_stalls = BoardSystem.get_stalls_adjacent_to(Vector2i(1, 0))
	print("  Stalls adjacent to (1,0): %d" % adjacent_stalls.size())

	# Test guest movement
	var path = BoardSystem.board.paths[0]
	var moved = BoardSystem.advance_guest_on_path(guest, path, 1)
	print("  Advanced guest, now at: %s" % guest.current_tile.position)
	assert(guest.current_tile.position == Vector2i(1, 0), "Guest should be at (1,0)")

	# Test token tracking
	var old_tokens = BoardSystem.tokens
	BoardSystem.add_tokens(10)
	print("  Added 10 tokens: %d -> %d" % [old_tokens, BoardSystem.tokens])
	assert(BoardSystem.tokens == old_tokens + 10, "Tokens should increase by 10")

	# Clean up
	BoardSystem.clear_level()
	TriggerSystem.clear_all()

	print("  Systems Integration tests PASSED")
