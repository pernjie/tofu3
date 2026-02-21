# test/integration/test_status_effects.gd
extends "res://test/helpers/test_base.gd"


class TestCharmedStatus:
	extends "res://test/helpers/test_base.gd"

	func test_charmed_registers_block_service_skill():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))

		BoardSystem.inflict_status(guest, "charmed", 8)

		var status = guest.get_status("charmed")
		assert_not_null(status, "Guest should have charmed status")
		assert_eq(status.stacks, 8)
		# Verify the granted skill exists on the guest
		var has_block_skill = false
		for skill in guest.skill_instances:
			if skill.definition.id == "charmed_block_fulfillment":
				has_block_skill = true
				break
		assert_true(has_block_skill,
			"Charmed should grant charmed_block_fulfillment skill")

	func test_charmed_stacks_accumulate():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))

		BoardSystem.inflict_status(guest, "charmed", 2)
		assert_eq(guest.get_status("charmed").stacks, 2)

		BoardSystem.inflict_status(guest, "charmed", 3)
		assert_eq(guest.get_status("charmed").stacks, 5,
			"Charmed stacks should accumulate")

	func test_charmed_stacks_capped_at_max():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))

		# Charmed max_stacks is 10
		BoardSystem.inflict_status(guest, "charmed", 10)
		BoardSystem.inflict_status(guest, "charmed", 5)

		assert_true(guest.get_status("charmed").stacks <= 10,
			"Charmed stacks should not exceed max_stacks")

	func test_charmed_removal_revokes_granted_skill():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))

		BoardSystem.inflict_status(guest, "charmed", 4)
		# Verify skill was granted
		var has_skill_before = false
		for skill in guest.skill_instances:
			if skill.definition.id == "charmed_block_fulfillment":
				has_skill_before = true
				break
		assert_true(has_skill_before, "Skill should exist before removal")

		BoardSystem.remove_status_effect(guest, "charmed")

		assert_null(guest.get_status("charmed"),
			"Charmed should be removed")
		var has_skill_after = false
		for skill in guest.skill_instances:
			if skill.definition.id == "charmed_block_fulfillment":
				has_skill_after = true
				break
		assert_false(has_skill_after,
			"Charmed removal should revoke charmed_block_fulfillment skill")

	func test_charmed_does_not_duplicate_skill_on_stack():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))

		BoardSystem.inflict_status(guest, "charmed", 2)
		var skill_count_first = 0
		for skill in guest.skill_instances:
			if skill.definition.id == "charmed_block_fulfillment":
				skill_count_first += 1

		BoardSystem.inflict_status(guest, "charmed", 3)
		var skill_count_second = 0
		for skill in guest.skill_instances:
			if skill.definition.id == "charmed_block_fulfillment":
				skill_count_second += 1

		assert_eq(skill_count_first, 1,
			"First application should grant exactly one skill")
		assert_eq(skill_count_second, 1,
			"Stacking should not duplicate the granted skill")


class TestLostStatus:
	extends "res://test/helpers/test_base.gd"

	func test_lost_registers_reverse_movement_skill():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))

		BoardSystem.inflict_status(guest, "lost", 5)

		var status = guest.get_status("lost")
		assert_not_null(status, "Guest should have lost status")
		assert_eq(status.stacks, 5)
		var has_reverse_skill = false
		for skill in guest.skill_instances:
			if skill.definition.id == "lost_reverse_movement":
				has_reverse_skill = true
				break
		assert_true(has_reverse_skill,
			"Lost should grant lost_reverse_movement skill")

	func test_lost_removal_revokes_granted_skill():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))

		BoardSystem.inflict_status(guest, "lost", 3)
		BoardSystem.remove_status_effect(guest, "lost")

		assert_null(guest.get_status("lost"),
			"Lost should be removed")
		var has_skill_after = false
		for skill in guest.skill_instances:
			if skill.definition.id == "lost_reverse_movement":
				has_skill_after = true
				break
		assert_false(has_skill_after,
			"Lost removal should revoke lost_reverse_movement skill")

	func test_on_pre_move_reverses_direction_when_lost():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))

		# Apply lost with chance override of 1.0 to make deterministic
		BoardSystem.inflict_status(guest, "lost", 5)
		# Override the granted skill's chance to 1.0
		for skill in guest.skill_instances:
			if skill.definition.id == "lost_reverse_movement":
				skill.parameter_overrides["chance"] = 1.0

		var context = TriggerContext.create("on_pre_move") \
			.with_guest(guest).with_source(guest).with_target(guest) \
			.with_movement_result()
		fire_for("on_pre_move", context, [guest])

		assert_eq(context.movement_result["direction"], -1,
			"Lost skill should reverse movement direction")

	func test_on_pre_move_no_effect_without_lost():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))
		# No lost status applied

		var context = TriggerContext.create("on_pre_move") \
			.with_guest(guest).with_source(guest).with_target(guest) \
			.with_movement_result()
		fire_for("on_pre_move", context, [guest])

		assert_eq(context.movement_result["direction"], 1,
			"Without lost status, direction should remain forward")
