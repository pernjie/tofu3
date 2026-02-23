# test/integration/test_on_need_fulfilled_skills.gd
extends "res://test/helpers/test_base.gd"


class TestSeamstressPerfectionist:
	extends "res://test/helpers/test_base.gd"

	func test_force_ascend_when_fulfilled_by_exact_amount():
		var seamstress = create_guest("seamstress")  # needs: food 3, joy 3
		register_guest(seamstress, Vector2i(2, 0))

		# Simulate a fulfillment of exactly 2 (the required_amount)
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(seamstress).with_source(seamstress) \
			.with_need_type("food").with_amount(2), [seamstress])

		assert_true(seamstress.force_ascend,
			"Seamstress should force ascend when fulfilled by exactly 2")

	func test_no_force_ascend_when_fulfilled_by_wrong_amount():
		var seamstress = create_guest("seamstress")
		register_guest(seamstress, Vector2i(2, 0))

		# Fulfillment of 1 — does not match required_amount of 2
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(seamstress).with_source(seamstress) \
			.with_need_type("food").with_amount(1), [seamstress])

		assert_false(seamstress.force_ascend,
			"Seamstress should not force ascend when fulfilled by 1")

	func test_no_force_ascend_when_fulfilled_by_larger_amount():
		var seamstress = create_guest("seamstress")
		register_guest(seamstress, Vector2i(2, 0))

		# Fulfillment of 3 — exceeds required_amount of 2
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(seamstress).with_source(seamstress) \
			.with_need_type("joy").with_amount(3), [seamstress])

		assert_false(seamstress.force_ascend,
			"Seamstress should not force ascend when fulfilled by 3")


class TestMonkeyKingClone:
	extends "res://test/helpers/test_base.gd"

	func test_clone_spawns_on_partial_fulfillment():
		var mk = create_guest("monkey_king")  # needs: food 3, joy 3, money 6
		register_guest(mk, Vector2i(2, 0))

		# Fulfill 1 food — still has remaining needs
		mk.current_needs["food"] -= 1
		var guest_count_before = BoardSystem.active_guests.size()

		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(mk).with_source(mk) \
			.with_need_type("food").with_amount(1), [mk])

		assert_eq(BoardSystem.active_guests.size(), guest_count_before + 1,
			"A clone should have been spawned")

		# Verify clone has owner's current remaining needs and money
		var clone = BoardSystem.active_guests.back()
		assert_ne(clone, mk, "Clone should be a different instance")
		assert_eq(clone.current_needs.get("food", 0), 2,
			"Clone should have 2 food remaining (same as owner)")
		assert_eq(clone.current_needs.get("joy", 0), 3,
			"Clone should have 3 joy remaining (same as owner)")
		assert_eq(clone.current_money, 6,
			"Clone should have same money as owner")

	func test_no_clone_when_fully_fulfilled():
		var mk = create_guest("monkey_king")
		register_guest(mk, Vector2i(2, 0))

		# Set needs so only 1 food remains, no joy
		mk.current_needs["food"] = 1
		mk.current_needs["joy"] = 0

		# Fulfill the last food — all needs now met
		mk.current_needs["food"] = 0
		var guest_count_before = BoardSystem.active_guests.size()

		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(mk).with_source(mk) \
			.with_need_type("food").with_amount(1), [mk])

		assert_eq(BoardSystem.active_guests.size(), guest_count_before,
			"No clone should spawn when all needs are fulfilled")

	func test_clone_inherits_skill_and_can_clone():
		var mk = create_guest("monkey_king")
		register_guest(mk, Vector2i(2, 0))

		# Fulfill 1 food to trigger first clone
		mk.current_needs["food"] -= 1

		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(mk).with_source(mk) \
			.with_need_type("food").with_amount(1), [mk])

		assert_eq(BoardSystem.active_guests.size(), 2,
			"First clone should have spawned")

		# Now fulfill 1 food on the clone — it should also clone
		var clone = BoardSystem.active_guests.back()
		clone.current_needs["food"] -= 1
		var guest_count_before = BoardSystem.active_guests.size()

		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(clone).with_source(clone) \
			.with_need_type("food").with_amount(1), [clone])

		assert_eq(BoardSystem.active_guests.size(), guest_count_before + 1,
			"Clone should be able to clone itself")


class TestTenguTransform:
	extends "res://test/helpers/test_base.gd"

	func test_joy_fulfillment_transforms_remaining_to_food():
		var tengu = create_guest("tengu")
		register_guest(tengu, Vector2i(1, 0))

		assert_eq(tengu.get_remaining_need("joy"), 7,
			"Should start with 7 joy needs")

		# Fulfill 3 joy, then fire on_need_fulfilled
		tengu.fulfill_need("joy", 3)

		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(3), [tengu])

		assert_eq(tengu.get_remaining_need("joy"), 0,
			"Joy needs should be 0 after transform")
		assert_eq(tengu.get_remaining_need("food"), 4,
			"Remaining 4 joy should have become food")

	func test_food_fulfillment_transforms_remaining_to_joy():
		var tengu = create_guest("tengu")
		register_guest(tengu, Vector2i(1, 0))

		# First: transform to food form
		tengu.fulfill_need("joy", 3)
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(3), [tengu])

		# Now fulfill 2 food, fire on_need_fulfilled
		tengu.fulfill_need("food", 2)

		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("food").with_amount(2), [tengu])

		assert_eq(tengu.get_remaining_need("food"), 0,
			"Food needs should be 0 after transform back")
		assert_eq(tengu.get_remaining_need("joy"), 2,
			"Remaining 2 food should have become joy")

	func test_full_alternation_cycle():
		var tengu = create_guest("tengu")
		register_guest(tengu, Vector2i(1, 0))

		# Cycle 1: fulfill 3 joy -> 4 food
		tengu.fulfill_need("joy", 3)
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(3), [tengu])
		assert_eq(tengu.get_remaining_need("food"), 4, "Cycle 1: 4 food remaining")

		# Cycle 2: fulfill 2 food -> 2 joy
		tengu.fulfill_need("food", 2)
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("food").with_amount(2), [tengu])
		assert_eq(tengu.get_remaining_need("joy"), 2, "Cycle 2: 2 joy remaining")

		# Cycle 3: fulfill all joy -> ascend-ready
		tengu.fulfill_need("joy", 2)
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(2), [tengu])

		assert_true(tengu.are_all_needs_fulfilled(),
			"Tengu should be fully fulfilled after complete cycle")

	func test_no_transform_when_all_needs_fulfilled():
		var tengu = create_guest("tengu")
		register_guest(tengu, Vector2i(1, 0))

		# Fulfill all 7 joy at once (overfulfill scenario)
		tengu.fulfill_need("joy", 7)

		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(9), [tengu])

		assert_eq(tengu.get_remaining_need("food"), 0,
			"No food needs should appear when joy was fully fulfilled")
		assert_true(tengu.are_all_needs_fulfilled(),
			"Tengu should be fully fulfilled")

	func test_initial_needs_updated_for_display():
		var tengu = create_guest("tengu")
		register_guest(tengu, Vector2i(1, 0))

		tengu.fulfill_need("joy", 3)
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(3), [tengu])

		assert_eq(tengu.initial_needs.get("food", 0), 4,
			"Initial food should reflect transformed amount for display")
		assert_eq(tengu.initial_needs.get("joy", 0), 3,
			"Initial joy should reflect only the already-fulfilled portion")
