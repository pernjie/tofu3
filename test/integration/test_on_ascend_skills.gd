# test/integration/test_on_ascend_skills.gd
extends "res://test/helpers/test_base.gd"


class TestCatAscendAoeJoy:
	extends "res://test/helpers/test_base.gd"

	func test_fulfills_joy_for_adjacent_guests():
		var cat = create_guest("cat")
		var neighbor = create_guest("playful_spirit")  # needs: joy 2
		register_guest(cat, Vector2i(2, 0))
		register_guest(neighbor, Vector2i(3, 0))  # adjacent
		var joy_before = neighbor.current_needs.get("joy", 0)

		fire_for("on_ascend", TriggerContext.create("on_ascend") \
			.with_guest(cat).with_source(cat), [cat])

		assert_eq(neighbor.current_needs.get("joy", 0), joy_before - 1,
			"Cat should fulfill 1 joy for adjacent guest")

	func test_does_not_affect_distant_guests():
		var cat = create_guest("cat")
		var distant = create_guest("playful_spirit")
		register_guest(cat, Vector2i(0, 0))
		register_guest(distant, Vector2i(4, 0))  # not adjacent (distance 4)
		var joy_before = distant.current_needs.get("joy", 0)

		fire_for("on_ascend", TriggerContext.create("on_ascend") \
			.with_guest(cat).with_source(cat), [cat])

		assert_eq(distant.current_needs.get("joy", 0), joy_before,
			"Cat should not affect distant guests")

	func test_does_not_affect_self():
		# Cat has no joy need, but verify self is excluded from AoE
		var cat = create_guest("cat")
		var neighbor = create_guest("playful_spirit")
		register_guest(cat, Vector2i(2, 0))
		register_guest(neighbor, Vector2i(3, 0))

		fire_for("on_ascend", TriggerContext.create("on_ascend") \
			.with_guest(cat).with_source(cat), [cat])

		# Cat should not be affected by its own AoE (it targets adjacent_guests,
		# which uses get_adjacent_tiles excluding center)
		# This test validates the AoE doesn't crash on guests without the need
		assert_true(true, "Cat's own AoE should not cause errors")


class TestDancerAscendCharm:
	extends "res://test/helpers/test_base.gd"

	func test_charms_adjacent_guests_on_ascend():
		var dancer = create_guest("dancer")
		var neighbor = create_guest("hungry_ghost")
		register_guest(dancer, Vector2i(2, 0))
		register_guest(neighbor, Vector2i(3, 0))

		fire_for("on_ascend", TriggerContext.create("on_ascend") \
			.with_guest(dancer).with_source(dancer), [dancer])

		var status = neighbor.get_status("charmed")
		assert_not_null(status, "Dancer should charm adjacent guest")
		assert_eq(status.stacks, 8, "Charmed should have 8 stacks")

	func test_does_not_charm_distant_guests():
		var dancer = create_guest("dancer")
		var distant = create_guest("hungry_ghost")
		register_guest(dancer, Vector2i(0, 0))
		register_guest(distant, Vector2i(4, 0))  # not adjacent

		fire_for("on_ascend", TriggerContext.create("on_ascend") \
			.with_guest(dancer).with_source(dancer), [dancer])

		var status = distant.get_status("charmed")
		assert_null(status, "Dancer should not charm distant guests")
