# test/integration/test_on_enter_stall_skills.gd
extends "res://test/helpers/test_base.gd"


class TestDrunkardDisruptiveEntrance:
	extends "res://test/helpers/test_base.gd"

	func test_resets_service_durations_for_other_guests():
		var drunkard = create_guest("drunkard")
		var other = create_guest("playful_spirit")
		var stall = create_stall("game_booth")
		register_guest(drunkard, Vector2i(2, 0))
		register_guest(other, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		# Simulate other guest mid-service
		other.is_in_stall = true
		other.current_stall = stall
		stall.add_occupant(other)
		other.service_turns_remaining = 1  # almost done

		fire_for("on_enter_stall", TriggerContext.create("on_enter_stall") \
			.with_guest(drunkard).with_stall(stall).with_source(drunkard),
			[drunkard, stall])

		# Service timer should be reset to full duration (base * multiplier)
		var base_duration = stall.get_service_duration()
		var multiplier = other.get_stat("service_duration_multiplier", 1)
		var expected = int(base_duration * multiplier)
		assert_eq(other.service_turns_remaining, expected,
			"Drunkard should reset other guests' service timers")

	func test_does_not_reset_triggering_guest():
		var drunkard = create_guest("drunkard")
		var stall = create_stall("game_booth")
		register_guest(drunkard, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		# Drunkard is the one entering — should not be affected
		drunkard.is_in_stall = true
		drunkard.current_stall = stall
		stall.add_occupant(drunkard)
		drunkard.service_turns_remaining = 1

		fire_for("on_enter_stall", TriggerContext.create("on_enter_stall") \
			.with_guest(drunkard).with_stall(stall).with_source(drunkard),
			[drunkard, stall])

		# Drunkard's timer should NOT be reset (the effect skips context.guest)
		assert_eq(drunkard.service_turns_remaining, 1,
			"Drunkard should not reset own service timer")


class TestBlockEntry:
	extends "res://test/helpers/test_base.gd"

	func test_block_entry_effect_sets_blocked():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("noodle_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		# Apply wet status to guest (grants wet_block_entry skill)
		BoardSystem.inflict_status(guest, "wet", 1)

		var context = TriggerContext.create("on_pre_enter_stall") \
			.with_guest(guest).with_stall(stall).with_source(guest) \
			.with_target(guest).with_entry_result()
		fire_for("on_pre_enter_stall", context, [guest, stall])

		assert_true(context.entry_result["blocked"],
			"Wet guest should have entry blocked")

	func test_non_wet_guest_not_blocked():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("noodle_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		# No wet status

		var context = TriggerContext.create("on_pre_enter_stall") \
			.with_guest(guest).with_stall(stall).with_source(guest) \
			.with_target(guest).with_entry_result()
		fire_for("on_pre_enter_stall", context, [guest, stall])

		assert_false(context.entry_result["blocked"],
			"Non-wet guest should not have entry blocked")

	func test_wet_guest_can_enter_after_expiry():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("noodle_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		# Apply wet with 1 stack
		BoardSystem.inflict_status(guest, "wet", 1)

		# Revoke to simulate expiry (status removed, granted skill revoked)
		BoardSystem.revoke_status(guest, "wet")

		# After expiry, entry should NOT be blocked
		var context = TriggerContext.create("on_pre_enter_stall") \
			.with_guest(guest).with_stall(stall).with_source(guest) \
			.with_target(guest).with_entry_result()
		fire_for("on_pre_enter_stall", context, [guest, stall])

		assert_false(context.entry_result.get("blocked", false),
			"Guest should enter stall after wet expires")
