# test/integration/test_on_pre_fulfill_skills.gd
extends "res://test/helpers/test_base.gd"


class TestWellRestedDoubleFulfillment:
	extends "res://test/helpers/test_base.gd"

	func test_doubles_fulfillment_for_well_rested_guest():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("noodle_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		# Grant well_rested status
		BoardSystem.inflict_status(guest, "well_rested", 1)

		var context = TriggerContext.create("on_pre_fulfill") \
			.with_guest(guest).with_need_type("food").with_amount(2) \
			.with_target(guest).with_source(stall).with_fulfillment_result()
		fire_for("on_pre_fulfill", context, [guest])

		assert_eq(context.fulfillment_result["fulfillment_multiplier"], 2.0,
			"Well rested should double fulfillment multiplier")

	func test_no_multiplier_without_well_rested():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("noodle_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		# No well_rested status

		var context = TriggerContext.create("on_pre_fulfill") \
			.with_guest(guest).with_need_type("food").with_amount(2) \
			.with_target(guest).with_source(stall).with_fulfillment_result()
		fire_for("on_pre_fulfill", context, [guest])

		assert_eq(context.fulfillment_result["fulfillment_multiplier"], 1.0,
			"Fulfillment multiplier should be unchanged without well_rested")

	func test_well_rested_doubles_joy_fulfillment_too():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("game_booth")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		BoardSystem.inflict_status(guest, "well_rested", 1)

		var context = TriggerContext.create("on_pre_fulfill") \
			.with_guest(guest).with_need_type("joy").with_amount(2) \
			.with_target(guest).with_source(stall).with_fulfillment_result()
		fire_for("on_pre_fulfill", context, [guest])

		assert_eq(context.fulfillment_result["fulfillment_multiplier"], 2.0,
			"Well rested should double joy fulfillment too")


class TestSpookedReduceJoy:
	extends "res://test/helpers/test_base.gd"

	func test_reduces_joy_fulfillment_for_spooked_guest():
		var guest = create_guest("playful_spirit")
		var stall = create_stall("game_booth")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		BoardSystem.inflict_status(guest, "spooked", 4)

		var context = TriggerContext.create("on_pre_fulfill") \
			.with_guest(guest).with_need_type("joy").with_amount(2) \
			.with_target(guest).with_source(stall).with_fulfillment_result()
		fire_for("on_pre_fulfill", context, [guest])

		assert_eq(context.fulfillment_result["fulfillment_bonus"], -1,
			"Spooked should reduce joy fulfillment by 1")

	func test_spooked_does_not_reduce_food_fulfillment():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("noodle_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		BoardSystem.inflict_status(guest, "spooked", 4)

		var context = TriggerContext.create("on_pre_fulfill") \
			.with_guest(guest).with_need_type("food").with_amount(2) \
			.with_target(guest).with_source(stall).with_fulfillment_result()
		fire_for("on_pre_fulfill", context, [guest])

		assert_eq(context.fulfillment_result.get("fulfillment_bonus", 0), 0,
			"Spooked should NOT reduce food fulfillment")

	func test_no_reduction_without_spooked():
		var guest = create_guest("playful_spirit")
		var stall = create_stall("game_booth")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		# No spooked status

		var context = TriggerContext.create("on_pre_fulfill") \
			.with_guest(guest).with_need_type("joy").with_amount(2) \
			.with_target(guest).with_source(stall).with_fulfillment_result()
		fire_for("on_pre_fulfill", context, [guest])

		assert_eq(context.fulfillment_result.get("fulfillment_bonus", 0), 0,
			"Joy fulfillment should be unchanged without spooked")


class TestTinglingReduceFood:
	extends "res://test/helpers/test_base.gd"

	func test_reduces_food_fulfillment_for_tingling_guest():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))
		BoardSystem.inflict_status(guest, "tingling", 3)

		var context = TriggerContext.create("on_pre_fulfill") \
			.with_guest(guest).with_need_type("food").with_amount(2) \
			.with_target(guest).with_fulfillment_result()
		fire_for("on_pre_fulfill", context, [guest])

		assert_eq(context.fulfillment_result["fulfillment_bonus"], -1,
			"Tingling should reduce food fulfillment by 1")

	func test_tingling_does_not_reduce_joy_fulfillment():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))
		BoardSystem.inflict_status(guest, "tingling", 3)

		var context = TriggerContext.create("on_pre_fulfill") \
			.with_guest(guest).with_need_type("joy").with_amount(2) \
			.with_target(guest).with_fulfillment_result()
		fire_for("on_pre_fulfill", context, [guest])

		assert_eq(context.fulfillment_result["fulfillment_bonus"], 0,
			"Tingling should not affect joy fulfillment")

	func test_no_reduction_without_tingling():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))
		# No tingling applied

		var context = TriggerContext.create("on_pre_fulfill") \
			.with_guest(guest).with_need_type("food").with_amount(2) \
			.with_target(guest).with_fulfillment_result()
		fire_for("on_pre_fulfill", context, [guest])

		assert_eq(context.fulfillment_result["fulfillment_bonus"], 0,
			"Without tingling, food fulfillment should not be reduced")


class TestFulfillGuestNeedIntegration:
	extends "res://test/helpers/test_base.gd"

	func test_fulfill_guest_need_applies_pre_fulfill_modifiers():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))
		BoardSystem.inflict_status(guest, "tingling", 3)

		# Directly call fulfill_guest_need — it should fire on_pre_fulfill internally
		var fulfilled = BoardSystem.fulfill_guest_need(guest, "food", 2)

		# With tingling (-1 bonus), fulfilling 2 food should become 1
		assert_eq(fulfilled, 1,
			"fulfill_guest_need should apply tingling reduction (2 - 1 = 1)")

	func test_fulfill_guest_need_floors_at_zero():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))
		BoardSystem.inflict_status(guest, "tingling", 3)

		# Fulfilling 1 food with -1 bonus should floor at 0, not go negative
		var fulfilled = BoardSystem.fulfill_guest_need(guest, "food", 1)

		assert_eq(fulfilled, 0,
			"fulfill_guest_need should floor modified amount at 0")

	func test_fulfill_guest_need_passes_source_to_trigger():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("noodle_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		BoardSystem.inflict_status(guest, "tingling", 3)

		# Pass stall as source — trigger should still fire on guest's skills
		var fulfilled = BoardSystem.fulfill_guest_need(guest, "food", 2, stall)

		assert_eq(fulfilled, 1,
			"Tingling reduction should work when source is provided")
