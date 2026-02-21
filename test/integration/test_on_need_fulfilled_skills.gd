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
