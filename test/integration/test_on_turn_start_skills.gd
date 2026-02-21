# test/integration/test_on_turn_start_skills.gd
extends "res://test/helpers/test_base.gd"


class TestBeastShrineValue:
	extends "res://test/helpers/test_base.gd"

	func test_value_scales_with_beasts_on_board():
		var stall = create_stall("beast_shrine")
		register_stall(stall, Vector2i(2, 1))

		# Place 2 beasts on the board
		var baku = create_guest("baku")
		register_guest(baku, Vector2i(0, 0))
		var tanuki = create_guest("tanuki")
		register_guest(tanuki, Vector2i(1, 0))

		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [stall])

		assert_eq(stall.get_value(), 2,
			"Value should be 2 with 2 beasts on board (2 x 1 per_beast)")

	func test_value_scales_with_beasts_in_queue():
		var stall = create_stall("beast_shrine")
		register_stall(stall, Vector2i(2, 1))

		# Add 3 beasts to queue
		var baku_def = ContentRegistry.get_definition("guests", "baku")
		BoardSystem.beast_queue.append(baku_def)
		BoardSystem.beast_queue.append(baku_def)
		BoardSystem.beast_queue.append(baku_def)

		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [stall])

		assert_eq(stall.get_value(), 3,
			"Value should be 3 with 3 beasts in queue (3 x 1 per_beast)")

	func test_value_counts_both_queue_and_board():
		var stall = create_stall("beast_shrine")
		register_stall(stall, Vector2i(2, 1))

		# 1 beast on board
		var baku = create_guest("baku")
		register_guest(baku, Vector2i(0, 0))

		# 2 beasts in queue
		var tanuki_def = ContentRegistry.get_definition("guests", "tanuki")
		BoardSystem.beast_queue.append(tanuki_def)
		BoardSystem.beast_queue.append(tanuki_def)

		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [stall])

		assert_eq(stall.get_value(), 3,
			"Value should be 3 with 1 on board + 2 in queue (3 x 1 per_beast)")

	func test_value_zero_with_no_beasts():
		var stall = create_stall("beast_shrine")
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [stall])

		assert_eq(stall.get_value(), 0,
			"Value should be 0 with no beasts anywhere")

	func test_does_not_count_regular_guests():
		var stall = create_stall("beast_shrine")
		register_stall(stall, Vector2i(2, 1))

		# Place a regular guest (not a beast)
		var ghost = create_guest("hungry_ghost")
		register_guest(ghost, Vector2i(0, 0))

		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [stall])

		assert_eq(stall.get_value(), 0,
			"Value should be 0 — regular guests don't count")

	func test_modifier_refreshes_each_turn():
		var stall = create_stall("beast_shrine")
		register_stall(stall, Vector2i(2, 1))

		# Turn 1: 2 beasts
		var baku = create_guest("baku")
		register_guest(baku, Vector2i(0, 0))
		var tanuki = create_guest("tanuki")
		register_guest(tanuki, Vector2i(1, 0))

		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [stall])
		assert_eq(stall.get_value(), 2, "Turn 1: value should be 2")

		# Turn 2: remove one beast from board
		BoardSystem.active_guests.erase(baku)

		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [stall])
		assert_eq(stall.get_value(), 1,
			"Turn 2: value should drop to 1 after beast removed")


class TestShadowPuppetsAverageAdjacentValue:
	extends "res://test/helpers/test_base.gd"

	func test_averages_two_adjacent_stalls():
		var shadow = create_stall("shadow_puppets")
		register_stall(shadow, Vector2i(2, 1))

		# Place two adjacent stalls with known values
		var noodle = create_stall("noodle_stand")  # value 1
		register_stall(noodle, Vector2i(1, 1))
		var game = create_stall("game_booth")  # value 2
		register_stall(game, Vector2i(3, 1))

		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [shadow])

		# (1 + 2) / 2 = 1 (floor)
		assert_eq(shadow.get_value(), 1,
			"Value should be floor of average: (1 + 2) / 2 = 1")

	func test_value_zero_with_no_adjacent_stalls():
		var shadow = create_stall("shadow_puppets")
		register_stall(shadow, Vector2i(2, 1))

		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [shadow])

		assert_eq(shadow.get_value(), 0,
			"Value should be 0 with no adjacent stalls")

	func test_averages_single_adjacent_stall():
		var shadow = create_stall("shadow_puppets")
		register_stall(shadow, Vector2i(2, 1))

		var game = create_stall("game_booth")  # value 2
		register_stall(game, Vector2i(1, 1))

		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [shadow])

		assert_eq(shadow.get_value(), 2,
			"Value should equal the single adjacent stall's value: 2")

	func test_floors_fractional_average():
		var shadow = create_stall("shadow_puppets")
		register_stall(shadow, Vector2i(2, 1))

		# noodle_stand value=1, game_booth value=2
		var noodle = create_stall("noodle_stand")  # value 1
		register_stall(noodle, Vector2i(1, 1))
		var game = create_stall("game_booth")  # value 2
		register_stall(game, Vector2i(3, 1))

		# Average of (1 + 2) / 2 = 1.5, should floor to 1
		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [shadow])

		assert_eq(shadow.get_value(), 1,
			"Value should floor fractional average: (1 + 2) / 2 = 1")

	func test_modifier_refreshes_each_turn():
		var shadow = create_stall("shadow_puppets")
		register_stall(shadow, Vector2i(2, 1))

		var game = create_stall("game_booth")  # value 2
		register_stall(game, Vector2i(1, 1))

		# Turn 1: one adjacent stall with value 2
		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [shadow])
		assert_eq(shadow.get_value(), 2, "Turn 1: value should be 2")

		# Turn 2: add a second adjacent stall with value 1
		var noodle = create_stall("noodle_stand")  # value 1
		register_stall(noodle, Vector2i(3, 1))

		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [shadow])
		assert_eq(shadow.get_value(), 1,
			"Turn 2: value should drop to floor((2 + 1) / 2) = 1")

	func test_does_not_include_self_in_average():
		# Shadow puppets should never count itself — it queries adjacent positions,
		# and a stall is never adjacent to its own position.
		var shadow = create_stall("shadow_puppets")
		register_stall(shadow, Vector2i(2, 1))

		# No other stalls — value should stay 0, not average its own value
		fire_for("on_turn_start", TriggerContext.create("on_turn_start"), [shadow])
		assert_eq(shadow.get_value(), 0,
			"Should not include self in average")
