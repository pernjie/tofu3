# test/integration/test_on_midnight_skills.gd
extends "res://test/helpers/test_base.gd"


class TestMooncakeStandMidnightFeast:
	extends "res://test/helpers/test_base.gd"

	func test_doubles_value_after_midnight():
		var stall = create_stall("mooncake_stand")
		register_stall(stall, Vector2i(2, 1))

		var value_before = stall.get_value()

		fire("on_midnight", TriggerContext.create("on_midnight"))

		assert_eq(stall.get_value(), value_before * 2,
			"Value should double after midnight")

	func test_cost_becomes_zero_after_midnight():
		var stall = create_stall("mooncake_stand")
		register_stall(stall, Vector2i(2, 1))

		assert_gt(stall.get_cost_to_guest(), 0,
			"Cost should be positive before midnight")

		fire("on_midnight", TriggerContext.create("on_midnight"))

		assert_eq(stall.get_cost_to_guest(), 0,
			"Cost to guest should be 0 after midnight")

	func test_no_effect_before_midnight():
		var stall = create_stall("mooncake_stand")
		register_stall(stall, Vector2i(2, 1))

		var tier_data = stall.get_current_tier_data()
		assert_eq(stall.get_value(), tier_data.value,
			"Value should be base tier value before midnight")
		assert_eq(stall.get_cost_to_guest(), tier_data.cost_to_guest,
			"Cost should be base tier cost before midnight")

	func test_placed_after_midnight_gets_no_buff():
		# Fire midnight before stall exists
		fire("on_midnight", TriggerContext.create("on_midnight"))

		var stall = create_stall("mooncake_stand")
		register_stall(stall, Vector2i(2, 1))

		var tier_data = stall.get_current_tier_data()
		assert_eq(stall.get_value(), tier_data.value,
			"Stall placed after midnight should have base value")
		assert_eq(stall.get_cost_to_guest(), tier_data.cost_to_guest,
			"Stall placed after midnight should have base cost")


class TestRestHouseCloseOnMidnight:
	extends "res://test/helpers/test_base.gd"

	func test_rest_house_gets_closed_status_on_midnight():
		var stall = create_stall("rest_house")
		register_stall(stall, Vector2i(2, 1))

		assert_false(stall.has_status("closed"),
			"Rest house should not be closed before midnight")

		fire("on_midnight", TriggerContext.create("on_midnight"))

		assert_true(stall.has_status("closed"),
			"Rest house should be closed after midnight")

	func test_closed_status_is_permanent():
		var stall = create_stall("rest_house")
		register_stall(stall, Vector2i(2, 1))

		fire("on_midnight", TriggerContext.create("on_midnight"))

		var status = stall.get_status("closed")
		assert_not_null(status, "Closed status should exist")
		assert_eq(status.definition.stack_type, "passive",
			"Closed status should be passive (permanent)")

	func test_rest_house_placed_after_midnight_not_closed():
		fire("on_midnight", TriggerContext.create("on_midnight"))

		var stall = create_stall("rest_house")
		register_stall(stall, Vector2i(2, 1))

		assert_false(stall.has_status("closed"),
			"Rest house placed after midnight should not be closed")


class TestSilkMarketMidnightShift:
	extends "res://test/helpers/test_base.gd"

	func test_switches_need_type_to_food_on_midnight():
		var stall = create_stall("silk_market")
		register_stall(stall, Vector2i(2, 1))

		assert_eq(stall.get_need_type(), "joy",
			"Silk Market should serve joy before midnight")

		fire("on_midnight", TriggerContext.create("on_midnight"))

		assert_eq(stall.get_need_type(), "food",
			"Silk Market should serve food after midnight")

	func test_serves_joy_before_midnight():
		var stall = create_stall("silk_market")
		register_stall(stall, Vector2i(2, 1))

		var guest_with_joy = create_guest("spider_lady")
		register_guest(guest_with_joy, Vector2i(2, 0))

		assert_true(stall.can_serve_guest(guest_with_joy),
			"Should be able to serve a guest with joy needs before midnight")

	func test_cannot_serve_food_needs_before_midnight():
		var stall = create_stall("silk_market")
		register_stall(stall, Vector2i(2, 1))

		var guest_with_food = create_guest("hungry_ghost")
		register_guest(guest_with_food, Vector2i(2, 0))

		assert_false(stall.can_serve_guest(guest_with_food),
			"Should not serve food-only guests before midnight")

	func test_serves_food_after_midnight():
		var stall = create_stall("silk_market")
		register_stall(stall, Vector2i(2, 1))

		fire("on_midnight", TriggerContext.create("on_midnight"))

		var guest_with_food = create_guest("hungry_ghost")
		register_guest(guest_with_food, Vector2i(2, 0))

		assert_true(stall.can_serve_guest(guest_with_food),
			"Should serve food-needing guests after midnight")

	func test_placed_after_midnight_serves_joy():
		fire("on_midnight", TriggerContext.create("on_midnight"))

		var stall = create_stall("silk_market")
		register_stall(stall, Vector2i(2, 1))

		assert_eq(stall.get_need_type(), "joy",
			"Stall placed after midnight should still serve joy (skill didn't fire)")


class TestSpiderLadyTransform:
	extends "res://test/helpers/test_base.gd"

	func test_transforms_joy_to_food_on_midnight():
		var guest = create_guest("spider_lady")
		register_guest(guest, Vector2i(1, 0))

		assert_eq(guest.get_remaining_need("joy"), 8,
			"Should start with 8 joy needs")
		assert_eq(guest.get_remaining_need("food"), 0,
			"Should start with 0 food needs")

		fire("on_midnight", TriggerContext.create("on_midnight"))

		assert_eq(guest.get_remaining_need("joy"), 0,
			"Joy needs should be 0 after midnight transform")
		assert_eq(guest.get_remaining_need("food"), 8,
			"Food needs should be 8 after midnight transform")

	func test_transforms_only_remaining_joy():
		var guest = create_guest("spider_lady")
		register_guest(guest, Vector2i(1, 0))

		# Fulfill 3 joy needs before midnight
		guest.fulfill_need("joy", 3)
		assert_eq(guest.get_remaining_need("joy"), 5,
			"Should have 5 joy remaining after fulfilling 3")

		fire("on_midnight", TriggerContext.create("on_midnight"))

		assert_eq(guest.get_remaining_need("joy"), 0,
			"Joy needs should be 0 after transform")
		assert_eq(guest.get_remaining_need("food"), 5,
			"Only remaining 5 joy should become food")

	func test_initial_needs_updated_for_display():
		var guest = create_guest("spider_lady")
		register_guest(guest, Vector2i(1, 0))

		guest.fulfill_need("joy", 3)

		fire("on_midnight", TriggerContext.create("on_midnight"))

		assert_eq(guest.initial_needs.get("food", 0), 5,
			"Initial food needs should reflect transformed amount")
		assert_eq(guest.initial_needs.get("joy", 0), 3,
			"Initial joy should reflect only the already-fulfilled portion")

	func test_no_transform_if_joy_fully_served():
		var guest = create_guest("spider_lady")
		register_guest(guest, Vector2i(1, 0))

		# Fulfill all joy before midnight
		guest.fulfill_need("joy", 8)
		assert_eq(guest.get_remaining_need("joy"), 0,
			"All joy should be fulfilled")

		fire("on_midnight", TriggerContext.create("on_midnight"))

		assert_eq(guest.get_remaining_need("food"), 0,
			"No food needs should be added when joy was already fulfilled")

	func test_spawned_after_midnight_no_transform():
		# Fire midnight before guest exists
		fire("on_midnight", TriggerContext.create("on_midnight"))

		var guest = create_guest("spider_lady")
		register_guest(guest, Vector2i(1, 0))

		assert_eq(guest.get_remaining_need("joy"), 8,
			"Guest spawned after midnight should keep original joy needs")
		assert_eq(guest.get_remaining_need("food"), 0,
			"Guest spawned after midnight should have no food needs")
