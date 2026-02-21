# test/integration/test_on_restock_skills.gd
extends "res://test/helpers/test_base.gd"


class TestGourdDoubleRestock:
	extends "res://test/helpers/test_base.gd"

	func test_doubles_first_restock():
		var gourd = create_relic("gourd")
		register_relic(gourd, Vector2i(1, 1))
		var stall = create_stall("noodle_stand")
		register_stall(stall, Vector2i(2, 1))
		var tier_data = stall.get_current_tier_data()
		var restock_amount = tier_data.restock_amount
		stall.current_stock = restock_amount  # as if just restocked

		# on_restock is global, so fire() works. Context needs the stall.
		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		# bonus_restock adds tier_data.restock_amount again
		assert_eq(stall.current_stock, restock_amount * 2,
			"Gourd should double the first restock")

	func test_does_not_double_second_restock():
		var gourd = create_relic("gourd")
		register_relic(gourd, Vector2i(1, 1))
		var stall = create_stall("noodle_stand")
		register_stall(stall, Vector2i(2, 1))
		var tier_data = stall.get_current_tier_data()
		var restock_amount = tier_data.restock_amount

		# First restock — doubles
		stall.current_stock = restock_amount
		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))
		assert_eq(stall.current_stock, restock_amount * 2,
			"First restock should be doubled")

		# Second restock — state_less_than(restock_count < 1) fails
		stall.current_stock = restock_amount
		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))
		assert_eq(stall.current_stock, restock_amount,
			"Second restock should NOT be doubled")

	func test_skill_state_tracks_restock_count():
		var gourd = create_relic("gourd")
		register_relic(gourd, Vector2i(1, 1))
		var stall = create_stall("noodle_stand")
		register_stall(stall, Vector2i(2, 1))

		# Verify initial state
		var skill = gourd.skill_instances[0]
		assert_eq(skill.get_state("restock_count", -1), 0,
			"Restock count should start at 0")

		# Fire once
		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		assert_eq(skill.get_state("restock_count", -1), 1,
			"Restock count should be 1 after first trigger")


class TestPickleStandSummonKappa:
	extends "res://test/helpers/test_base.gd"

	func test_adds_kappa_to_beast_queue_on_restock():
		var stall = create_stall("pickle_stand")
		register_stall(stall, Vector2i(2, 1))

		assert_eq(BoardSystem.beast_queue.size(), 0,
			"Beast queue should start empty")

		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		assert_eq(BoardSystem.beast_queue.size(), 1,
			"Beast queue should have one entry after restock")
		assert_eq(BoardSystem.beast_queue[0].id, "kappa",
			"Queued beast should be a kappa")

	func test_does_not_add_kappa_when_other_stall_restocks():
		var pickle = create_stall("pickle_stand")
		register_stall(pickle, Vector2i(2, 1))
		var noodle = create_stall("noodle_stand")
		register_stall(noodle, Vector2i(3, 1))

		# Fire restock for the noodle stand — pickle's skill should not fire
		# because on_restock is entity-filtered to the stall's own skills
		fire_for("on_restock", TriggerContext.create("on_restock") \
			.with_stall(noodle).with_source(noodle), [noodle])

		assert_eq(BoardSystem.beast_queue.size(), 0,
			"Pickle stand skill should not fire for other stalls")


class TestRedBeanSpawnCharmed:
	extends "res://test/helpers/test_base.gd"

	func test_spawns_next_guest_from_queue_on_restock():
		var stall = create_stall("red_bean_stand")
		register_stall(stall, Vector2i(2, 1))

		# Seed the guest queue
		var ghost_def = ContentRegistry.get_definition("guests", "hungry_ghost")
		BoardSystem.guest_queue.append(ghost_def)
		assert_eq(BoardSystem.guest_queue.size(), 1, "Queue should have one guest")
		var guests_before = BoardSystem.active_guests.size()

		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		assert_eq(BoardSystem.guest_queue.size(), 0,
			"Guest should be popped from queue")
		assert_eq(BoardSystem.active_guests.size(), guests_before + 1,
			"Spawned guest should be on the board")

	func test_spawned_guest_has_charmed_status():
		var stall = create_stall("red_bean_stand")
		register_stall(stall, Vector2i(2, 1))

		var ghost_def = ContentRegistry.get_definition("guests", "hungry_ghost")
		BoardSystem.guest_queue.append(ghost_def)

		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		var spawned = BoardSystem.active_guests.back()
		assert_true(spawned.has_status("charmed"),
			"Spawned guest should have charmed status")
		assert_eq(spawned.get_status("charmed").stacks, 3,
			"Charmed should have 3 stacks (T1 default)")

	func test_does_nothing_when_queue_is_empty():
		var stall = create_stall("red_bean_stand")
		register_stall(stall, Vector2i(2, 1))

		assert_eq(BoardSystem.guest_queue.size(), 0, "Queue should be empty")
		var guests_before = BoardSystem.active_guests.size()

		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		assert_eq(BoardSystem.active_guests.size(), guests_before,
			"No guest should be spawned from empty queue")

	func test_does_not_fire_when_other_stall_restocks():
		var red_bean = create_stall("red_bean_stand")
		register_stall(red_bean, Vector2i(2, 1))
		var noodle = create_stall("noodle_stand")
		register_stall(noodle, Vector2i(3, 1))

		var ghost_def = ContentRegistry.get_definition("guests", "hungry_ghost")
		BoardSystem.guest_queue.append(ghost_def)

		# Fire restock for the noodle stand only
		fire_for("on_restock", TriggerContext.create("on_restock") \
			.with_stall(noodle).with_source(noodle), [noodle])

		assert_eq(BoardSystem.guest_queue.size(), 1,
			"Red bean skill should not fire for other stalls")


class TestUnagiEscalatingRestock:
	extends "res://test/helpers/test_base.gd"

	func test_first_restock_gives_no_bonus():
		var stall = create_stall("unagi_stand")
		register_stall(stall, Vector2i(2, 1))
		stall.current_stock = 1  # as if just restocked (base amount)

		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		# State starts at 0, so bonus is 0 — stock unchanged
		assert_eq(stall.current_stock, 1,
			"First restock should add no bonus (state starts at 0)")

	func test_second_restock_adds_one_bonus():
		var stall = create_stall("unagi_stand")
		register_stall(stall, Vector2i(2, 1))

		# First restock — primes state to 1
		stall.current_stock = 1
		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		# Second restock — state is 1, so +1 bonus
		stall.current_stock = 1
		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		assert_eq(stall.current_stock, 2,
			"Second restock should add 1 bonus stock (base 1 + bonus 1)")

	func test_escalates_over_multiple_restocks():
		var stall = create_stall("unagi_stand")
		register_stall(stall, Vector2i(2, 1))

		# Simulate 4 restocks and check stock after each
		var expected_stocks = [1, 2, 3, 4]  # base 1 + bonus 0, 1, 2, 3
		for i in range(4):
			stall.current_stock = 1  # base restock
			fire("on_restock", TriggerContext.create("on_restock") \
				.with_stall(stall).with_source(stall))
			assert_eq(stall.current_stock, expected_stocks[i],
				"Restock %d should yield %d stock" % [i + 1, expected_stocks[i]])

	func test_state_tracks_restock_count():
		var stall = create_stall("unagi_stand")
		register_stall(stall, Vector2i(2, 1))

		var skill = stall.skill_instances[0]
		assert_eq(skill.get_state("restock_count", -1), 0,
			"Restock count should start at 0")

		stall.current_stock = 1
		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		assert_eq(skill.get_state("restock_count", -1), 1,
			"Restock count should be 1 after first trigger")

		stall.current_stock = 1
		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		assert_eq(skill.get_state("restock_count", -1), 2,
			"Restock count should be 2 after second trigger")

	func test_does_not_fire_for_other_stalls():
		var unagi = create_stall("unagi_stand")
		register_stall(unagi, Vector2i(2, 1))
		var noodle = create_stall("noodle_stand")
		register_stall(noodle, Vector2i(3, 1))

		noodle.current_stock = 2

		fire_for("on_restock", TriggerContext.create("on_restock") \
			.with_stall(noodle).with_source(noodle), [noodle])

		# Unagi's state should be untouched
		var skill = unagi.skill_instances[0]
		assert_eq(skill.get_state("restock_count", -1), 0,
			"Unagi skill should not fire for other stalls")


class TestVineBasketBonusPlay:
	extends "res://test/helpers/test_base.gd"

	func test_grants_bonus_play_on_restock():
		var vine_basket = create_relic("vine_basket")
		register_relic(vine_basket, Vector2i(1, 1))
		var stall = create_stall("noodle_stand")
		register_stall(stall, Vector2i(2, 1))

		assert_eq(deck_system.max_plays_per_turn, 1,
			"Should start with 1 play per turn")

		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		assert_eq(deck_system.max_plays_per_turn, 2,
			"Should grant bonus play after restock")

	func test_caps_at_one_bonus_per_turn():
		var vine_basket = create_relic("vine_basket")
		register_relic(vine_basket, Vector2i(1, 1))
		var stall_a = create_stall("noodle_stand")
		register_stall(stall_a, Vector2i(2, 1))
		var stall_b = create_stall("noodle_stand")
		register_stall(stall_b, Vector2i(3, 1))

		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall_a).with_source(stall_a))
		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall_b).with_source(stall_b))

		assert_eq(deck_system.max_plays_per_turn, 2,
			"Should cap at 2 (base 1 + 1 bonus), not 3")

	func test_resets_each_turn():
		var vine_basket = create_relic("vine_basket")
		register_relic(vine_basket, Vector2i(1, 1))
		var stall = create_stall("noodle_stand")
		register_stall(stall, Vector2i(2, 1))

		# First turn: restock grants bonus
		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))
		assert_eq(deck_system.max_plays_per_turn, 2,
			"Should have bonus play after first restock")

		# Simulate new turn: DeckSystem resets max_plays, then on_turn_start resets skill state
		deck_system.start_turn()
		fire("on_turn_start", TriggerContext.create("on_turn_start"))

		var bonus_skill = vine_basket.skill_instances[0]
		assert_eq(bonus_skill.get_state("granted_this_turn", -1), 0,
			"granted_this_turn should reset to 0 after on_turn_start")

		# Second turn: restock grants bonus again
		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))
		assert_eq(deck_system.max_plays_per_turn, 2,
			"Should grant bonus play again on new turn")

	func test_no_bonus_without_restock():
		var vine_basket = create_relic("vine_basket")
		register_relic(vine_basket, Vector2i(1, 1))

		assert_eq(deck_system.max_plays_per_turn, 1,
			"Should remain at 1 play when no restock occurs")

	func test_skill_state_tracks_grant():
		var vine_basket = create_relic("vine_basket")
		register_relic(vine_basket, Vector2i(1, 1))
		var stall = create_stall("noodle_stand")
		register_stall(stall, Vector2i(2, 1))

		var bonus_skill = vine_basket.skill_instances[0]
		assert_eq(bonus_skill.get_state("granted_this_turn", -1), 0,
			"granted_this_turn should start at 0")

		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		assert_eq(bonus_skill.get_state("granted_this_turn", -1), 1,
			"granted_this_turn should be 1 after restock")
