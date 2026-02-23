# test/integration/test_on_upgrade_skills.gd
extends "res://test/helpers/test_base.gd"


class TestLuckyFrogUpgradeBonus:
	extends "res://test/helpers/test_base.gd"

	func test_applies_value_buff_on_first_upgrade():
		var frog = create_relic("lucky_frog")
		register_relic(frog, Vector2i(1, 1))
		var stall = create_stall("noodle_stand")
		register_stall(stall, Vector2i(2, 1))

		var value_before = stall.get_value()

		# on_upgrade is global, so fire() works
		fire("on_upgrade", TriggerContext.create("on_upgrade") \
			.with_stall(stall).with_source(stall).with_amount(2))

		assert_true(stall.has_status("lucky_frog_buff"),
			"Stall should have lucky_frog_buff after upgrade")
		assert_eq(stall.get_value(), value_before + 1,
			"Stall value should increase by 1")

	func test_does_not_apply_on_second_upgrade():
		var frog = create_relic("lucky_frog")
		register_relic(frog, Vector2i(1, 1))
		var stall_a = create_stall("noodle_stand")
		register_stall(stall_a, Vector2i(2, 1))
		var stall_b = create_stall("noodle_stand")
		register_stall(stall_b, Vector2i(3, 1))

		# First upgrade — should apply buff
		fire("on_upgrade", TriggerContext.create("on_upgrade") \
			.with_stall(stall_a).with_source(stall_a).with_amount(2))
		assert_true(stall_a.has_status("lucky_frog_buff"),
			"First upgraded stall should have buff")

		# Second upgrade — should NOT apply buff
		fire("on_upgrade", TriggerContext.create("on_upgrade") \
			.with_stall(stall_b).with_source(stall_b).with_amount(2))
		assert_false(stall_b.has_status("lucky_frog_buff"),
			"Second upgraded stall should NOT have buff")

	func test_skill_state_tracks_fire_count():
		var frog = create_relic("lucky_frog")
		register_relic(frog, Vector2i(1, 1))
		var stall = create_stall("noodle_stand")
		register_stall(stall, Vector2i(2, 1))

		var skill = frog.skill_instances[0]
		assert_eq(skill.get_state("times_fired", -1), 0,
			"times_fired should start at 0")

		fire("on_upgrade", TriggerContext.create("on_upgrade") \
			.with_stall(stall).with_source(stall).with_amount(2))

		assert_eq(skill.get_state("times_fired", -1), 1,
			"times_fired should be 1 after first upgrade")

	func test_no_effect_without_upgrade():
		var frog = create_relic("lucky_frog")
		register_relic(frog, Vector2i(1, 1))
		var stall = create_stall("noodle_stand")
		register_stall(stall, Vector2i(2, 1))

		assert_false(stall.has_status("lucky_frog_buff"),
			"Stall should not have buff without upgrade")
