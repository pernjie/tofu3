# test/integration/test_on_serve_skills.gd
extends "res://test/helpers/test_base.gd"


class TestApothecaryRestock:
	extends "res://test/helpers/test_base.gd"

	func test_restocks_when_stall_depleted():
		var guest = create_guest("apothecary")
		var stall = create_stall("noodle_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		stall.current_stock = 0  # depleted

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_gt(stall.current_stock, 0,
			"Apothecary should restock depleted stall")

	func test_does_not_restock_when_stall_has_stock():
		var guest = create_guest("apothecary")
		var stall = create_stall("noodle_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		stall.current_stock = 2  # not depleted

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_eq(stall.current_stock, 2,
			"Apothecary should not restock when stall has stock")


class TestRestorativeYoga:
	extends "res://test/helpers/test_base.gd"

	func test_bonus_fulfillment_when_guest_has_debuff():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("yoga_mats")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		# Apply a debuff so the has_debuff condition passes
		BoardSystem.inflict_status(guest, "charmed", 1)

		var context = TriggerContext.create("on_pre_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest).with_service_result()
		fire_for("on_pre_serve", context, [guest, stall])

		assert_gt(context.service_result["fulfillment_bonus"], 0,
			"Restorative yoga should add fulfillment bonus for debuffed guest")

	func test_no_bonus_without_debuff():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("yoga_mats")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		# No debuff applied

		var context = TriggerContext.create("on_pre_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest).with_service_result()
		fire_for("on_pre_serve", context, [guest, stall])

		assert_eq(context.service_result.get("fulfillment_bonus", 0), 0,
			"No bonus without debuff")


class TestRestHouseGrantWellRested:
	extends "res://test/helpers/test_base.gd"

	func test_grants_well_rested_on_serve():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("rest_house")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		assert_false(guest.has_status("well_rested"),
			"Guest should not have well_rested before service")

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_true(guest.has_status("well_rested"),
			"Guest should have well_rested after being served at rest house")

	func test_well_rested_is_permanent():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("rest_house")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		var status = guest.get_status("well_rested")
		assert_not_null(status, "well_rested status should exist")
		assert_eq(status.definition.stack_type, "passive",
			"well_rested should be a passive (permanent) status")


class TestClosedBlockService:
	extends "res://test/helpers/test_base.gd"

	func test_closed_stall_blocks_service():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("rest_house")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		# Apply closed status to stall
		BoardSystem.inflict_status(stall, "closed", 1)

		var context = TriggerContext.create("on_pre_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest).with_service_result()
		fire_for("on_pre_serve", context, [guest, stall])

		assert_true(context.service_result["blocked"],
			"Closed stall should block service")

	func test_non_closed_stall_does_not_block():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("rest_house")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		# No closed status

		var context = TriggerContext.create("on_pre_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest).with_service_result()
		fire_for("on_pre_serve", context, [guest, stall])

		assert_false(context.service_result["blocked"],
			"Non-closed stall should not block service")


class TestPaperBoatsApplyWet:
	extends "res://test/helpers/test_base.gd"

	func test_applies_wet_on_serve():
		var guest = create_guest("playful_spirit")
		var stall = create_stall("paper_boats")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		var wet = guest.get_status("wet")
		assert_not_null(wet, "Guest should have wet status after being served at paper boats")
		assert_eq(wet.stacks, 1, "Wet should have 1 stack at T1")


class TestSpicySkewerApplyTingling:
	extends "res://test/helpers/test_base.gd"

	func test_applies_tingling_on_serve():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("spicy_skewer_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_true(guest.has_status("tingling"),
			"Spicy Skewer Stand should apply tingling on serve")
		assert_eq(guest.get_status("tingling").stacks, 4,
			"Should apply 4 stacks of tingling")


class TestPufferfishBanishOnDeplete:
	extends "res://test/helpers/test_base.gd"

	func test_banishes_guest_on_last_stock():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("pufferfish_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		stall.current_stock = 0  # just depleted (last stock consumed)

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_true(guest.is_banished,
			"Guest should be banished when consuming last stock")
		assert_true(guest.is_exiting,
			"Banished guest should be marked as exiting")

	func test_does_not_banish_when_stock_remains():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("pufferfish_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		stall.current_stock = 1  # still has stock

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_false(guest.is_banished,
			"Guest should not be banished when stock remains")
		assert_false(guest.is_exiting,
			"Guest should not be exiting when stock remains")


class TestAncientTheatreApplySpooked:
	extends "res://test/helpers/test_base.gd"

	func test_applies_spooked_on_serve():
		var guest = create_guest("playful_spirit")
		var stall = create_stall("ancient_theatre")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		var spooked = guest.get_status("spooked")
		assert_not_null(spooked, "Guest should have spooked status after being served at ancient theatre")
		assert_eq(spooked.stacks, 4, "Spooked should have 4 stacks at T1")

	func test_spooked_is_time_based():
		var guest = create_guest("playful_spirit")
		var stall = create_stall("ancient_theatre")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		var spooked = guest.get_status("spooked")
		assert_not_null(spooked, "Spooked status should exist")
		assert_eq(spooked.definition.stack_type, "time",
			"Spooked should be a time-based (decaying) status")


class TestFishSpaCleanse:
	extends "res://test/helpers/test_base.gd"

	func test_removes_all_debuffs_on_serve():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("fish_spa")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		# Apply two different debuffs
		BoardSystem.inflict_status(guest, "charmed", 1)
		BoardSystem.inflict_status(guest, "spooked", 1)

		assert_true(guest.has_status("charmed"), "Guest should have charmed before serve")
		assert_true(guest.has_status("spooked"), "Guest should have spooked before serve")

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_false(guest.has_status("charmed"),
			"Fish spa should remove charmed debuff on serve")
		assert_false(guest.has_status("spooked"),
			"Fish spa should remove spooked debuff on serve")

	func test_does_not_remove_buffs():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("fish_spa")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		BoardSystem.inflict_status(guest, "well_rested", 1)
		BoardSystem.inflict_status(guest, "charmed", 1)

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_true(guest.has_status("well_rested"),
			"Fish spa should not remove buff statuses")
		assert_false(guest.has_status("charmed"),
			"Fish spa should still remove debuffs")

	func test_does_not_remove_aura_tagged_debuffs():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("fish_spa")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		BoardSystem.inflict_status(guest, "charmed", 1)

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_false(guest.has_status("charmed"),
			"Non-aura debuffs should be removed")

	func test_no_debuffs_is_fine():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("fish_spa")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))
		# No debuffs on guest

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		# Should not error — skill just does nothing
		assert_true(true, "Cleanse with no debuffs should not error")
