extends GutTest

# Tests for guest movement, particularly multi-tile movement (speed > 1).
# Uses BoardSystem.advance_guest_on_path() directly — the same method TurnSystem calls.


class TestPathEndExit:
	extends "res://test/helpers/test_base.gd"

	# Regression: guests already at the last tile must be classified for exit.
	# The movement phase uses advance_guest_on_path() then checks reached_end
	# to decide if the guest should exit. A guest already at the end doesn't
	# move (from == to), but must still exit.

	func _classify_movement(guest: GuestInstance) -> Dictionary:
		## Replicates turn_system's movement-phase classification logic.
		var path = BoardSystem.board.paths[0]
		var from_tile = guest.current_tile
		var reached_end = not BoardSystem.advance_guest_on_path(guest, path, guest.get_movement_speed())
		var to_tile = guest.current_tile
		return {"from": from_tile, "to": to_tile, "reached_end": reached_end}

	func test_guest_already_at_last_tile_is_classified_for_exit():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(4, 0))
		guest.path_index = 4

		var result = _classify_movement(guest)

		assert_true(result.reached_end, "Guest at last tile should report reached_end")
		assert_eq(result.from, result.to, "Guest should not have moved")
		# The bug was: reached_end=true but from==to caused guest to be skipped for exit

	func test_guest_arrives_at_last_tile_then_exits_next_turn():
		# A speed-1 guest at index 3 moves to index 4 (last tile) on turn 1.
		# advance_guest_on_path returns true (moved successfully, not yet stuck).
		# On turn 2, the guest can't move further — reached_end fires.
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(3, 0))
		guest.path_index = 3

		var result_turn_1 = _classify_movement(guest)
		assert_false(result_turn_1.reached_end, "Guest moved to last tile — not stuck yet")
		assert_eq(result_turn_1.to.position, Vector2i(4, 0), "Guest should be at last tile")

		var result_turn_2 = _classify_movement(guest)
		assert_true(result_turn_2.reached_end, "Guest at last tile can't move — reached_end")
		assert_eq(result_turn_2.from, result_turn_2.to, "Guest should not have moved")


class TestMultiTileMovement:
	extends "res://test/helpers/test_base.gd"

	func test_speed_1_advances_one_tile():
		var guest = create_guest("hungry_ghost")  # speed 1
		register_guest(guest, Vector2i(0, 0))
		var path = BoardSystem.board.paths[0]

		var can_continue = BoardSystem.advance_guest_on_path(guest, path, 1)

		assert_true(can_continue, "Should not have reached end")
		assert_eq(guest.path_index, 1)
		assert_eq(guest.current_tile.position, Vector2i(1, 0))

	func test_speed_2_advances_two_tiles():
		var guest = create_guest("ninja")  # speed 2
		register_guest(guest, Vector2i(0, 0))
		var path = BoardSystem.board.paths[0]

		var speed = guest.get_movement_speed()
		assert_eq(speed, 2, "Ninja base speed should be 2")

		var can_continue = BoardSystem.advance_guest_on_path(guest, path, speed)

		assert_true(can_continue, "Should not have reached end")
		assert_eq(guest.path_index, 2)
		assert_eq(guest.current_tile.position, Vector2i(2, 0))

	func test_speed_2_two_turns_reaches_tile_4():
		var guest = create_guest("ninja")
		register_guest(guest, Vector2i(0, 0))
		var path = BoardSystem.board.paths[0]
		var speed = guest.get_movement_speed()

		BoardSystem.advance_guest_on_path(guest, path, speed)
		var can_continue = BoardSystem.advance_guest_on_path(guest, path, speed)

		assert_true(can_continue, "Should not have reached end at index 4")
		assert_eq(guest.path_index, 4)
		assert_eq(guest.current_tile.position, Vector2i(4, 0))

	func test_speed_2_stops_at_path_end():
		# Path is 5 tiles (indices 0-4). Start at index 3, speed 2 would overshoot.
		var guest = create_guest("ninja")
		register_guest(guest, Vector2i(3, 0))
		guest.path_index = 3
		var path = BoardSystem.board.paths[0]

		var can_continue = BoardSystem.advance_guest_on_path(guest, path, 2)

		assert_false(can_continue, "Should have reached end of path")
		assert_eq(guest.path_index, 4, "Should stop at last tile index")
		assert_eq(guest.current_tile.position, Vector2i(4, 0))

	func test_speed_2_at_last_tile_returns_reached_end():
		var guest = create_guest("ninja")
		register_guest(guest, Vector2i(4, 0))
		guest.path_index = 4
		var path = BoardSystem.board.paths[0]

		var can_continue = BoardSystem.advance_guest_on_path(guest, path, 2)

		assert_false(can_continue, "Already at end, should report reached_end")
		assert_eq(guest.path_index, 4, "Should stay at last index")

	func test_speed_modifier_increases_movement():
		# A speed-1 guest with a +1 modifier should move 2 tiles
		var guest = create_guest("hungry_ghost")  # speed 1
		register_guest(guest, Vector2i(0, 0))
		var path = BoardSystem.board.paths[0]

		guest.modifier_stack.add_modifier(StatModifier.new("movement_speed", StatModifier.Operation.ADD, 1, null))
		var speed = guest.get_movement_speed()
		assert_eq(speed, 2, "Modified speed should be 2")

		var can_continue = BoardSystem.advance_guest_on_path(guest, path, speed)

		assert_true(can_continue)
		assert_eq(guest.path_index, 2)
		assert_eq(guest.current_tile.position, Vector2i(2, 0))

	func test_speed_1_vs_speed_2_coverage():
		# Speed 1 guest takes 4 turns to traverse 5-tile path (0->1->2->3->4)
		# Speed 2 guest takes 2 turns (0->2->4)
		var slow = create_guest("hungry_ghost")
		var fast = create_guest("ninja")
		register_guest(slow, Vector2i(0, 0))
		register_guest(fast, Vector2i(0, 0))
		var path = BoardSystem.board.paths[0]

		var slow_turns = 0
		while BoardSystem.advance_guest_on_path(slow, path, slow.get_movement_speed()):
			slow_turns += 1

		# Reset fast guest to start
		fast.path_index = 0
		fast.current_tile = path.get_tile_at_index(0)
		var fast_turns = 0
		while BoardSystem.advance_guest_on_path(fast, path, fast.get_movement_speed()):
			fast_turns += 1

		assert_eq(slow_turns, 4, "Speed 1 should take 4 moves on 5-tile path")
		assert_eq(fast_turns, 2, "Speed 2 should take 2 moves on 5-tile path")
