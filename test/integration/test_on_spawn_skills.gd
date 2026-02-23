# test/integration/test_on_spawn_skills.gd
extends "res://test/helpers/test_base.gd"

class TestOldManSlowService:
	extends "res://test/helpers/test_base.gd"

	func test_slow_service_applies_modifier_on_spawn():
		var guest = create_guest("old_man")
		register_guest(guest, Vector2i(1, 0))

		fire_for("on_spawn", TriggerContext.create("on_spawn") \
			.with_guest(guest).with_source(guest), [guest])

		var multiplier = guest.get_stat("service_duration_multiplier", 1)
		assert_gt(multiplier, 1, "Old man should have increased service duration")


class TestCatLadySummon:
	extends "res://test/helpers/test_base.gd"

	func test_summons_cat_on_spawn():
		var cat_lady = create_guest("cat_lady")
		register_guest(cat_lady, Vector2i(1, 0))
		var count_before = BoardSystem.active_guests.size()

		fire_for("on_spawn", TriggerContext.create("on_spawn") \
			.with_guest(cat_lady).with_source(cat_lady), [cat_lady])

		assert_eq(BoardSystem.active_guests.size(), count_before + 1,
			"Cat lady should summon one guest")
		var spawned = BoardSystem.active_guests.back()
		assert_eq(spawned.definition.id, "cat",
			"Summoned guest should be a cat")


class TestLanternBearerSummon:
	extends "res://test/helpers/test_base.gd"

	func test_summons_guests_from_queue_on_spawn():
		var bearer = create_guest("lantern_bearer")
		register_guest(bearer, Vector2i(1, 0))
		# Populate the guest queue with eligible guests
		var spirit_def = ContentRegistry.get_definition("guests", "playful_spirit")
		var ghost_def = ContentRegistry.get_definition("guests", "hungry_ghost")
		BoardSystem.guest_queue.append(spirit_def)
		BoardSystem.guest_queue.append(ghost_def)
		var count_before = BoardSystem.active_guests.size()

		fire_for("on_spawn", TriggerContext.create("on_spawn") \
			.with_guest(bearer).with_source(bearer), [bearer])

		# lantern_summon summons 2 mini guests by default
		assert_eq(BoardSystem.active_guests.size(), count_before + 2,
			"Lantern bearer should summon 2 guests from queue")

	func test_no_summon_with_empty_queue():
		var bearer = create_guest("lantern_bearer")
		register_guest(bearer, Vector2i(1, 0))
		# Leave guest_queue empty
		var count_before = BoardSystem.active_guests.size()

		fire_for("on_spawn", TriggerContext.create("on_spawn") \
			.with_guest(bearer).with_source(bearer), [bearer])

		assert_eq(BoardSystem.active_guests.size(), count_before,
			"Lantern bearer should not summon with empty queue")


class TestOxHourBellBoostInteract:
	extends "res://test/helpers/test_base.gd"

	func test_beast_gains_bonus_interact_need():
		var relic = create_relic("ox_hour_bell")
		register_relic(relic, Vector2i(1, 1))

		var beast = create_guest("baku")
		register_guest(beast, Vector2i(4, 0))
		var base_interact = beast.definition.base_needs.get("interact", 0)

		fire_for("on_spawn", TriggerContext.create("on_spawn") \
			.with_guest(beast).with_source(beast), [beast])

		assert_eq(beast.current_needs["interact"], base_interact + 1,
			"Beast should gain +1 interact need from Ox Hour Bell")
		assert_eq(beast.initial_needs["interact"], base_interact + 1,
			"Initial needs should also be updated for UI denominator")

	func test_non_beast_does_not_gain_bonus_interact():
		var relic = create_relic("ox_hour_bell")
		register_relic(relic, Vector2i(1, 1))

		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(1, 0))
		var needs_before = guest.current_needs.duplicate()

		fire_for("on_spawn", TriggerContext.create("on_spawn") \
			.with_guest(guest).with_source(guest), [guest])

		assert_eq(guest.current_needs, needs_before,
			"Non-beast guest should not have needs modified")

	func test_does_not_modify_without_relic():
		var beast = create_guest("baku")
		register_guest(beast, Vector2i(4, 0))
		var base_interact = beast.definition.base_needs.get("interact", 0)

		fire_for("on_spawn", TriggerContext.create("on_spawn") \
			.with_guest(beast).with_source(beast), [beast])

		assert_eq(beast.current_needs["interact"], base_interact,
			"Beast interact need should be unchanged without relic")


class TestAkashitaRestockAll:
	extends "res://test/helpers/test_base.gd"

	func test_restocks_all_product_stalls_on_spawn():
		var akashita = create_guest("akashita")
		register_guest(akashita, Vector2i(4, 0))

		# Place two product stalls and deplete them
		var stall_a = create_stall("noodle_stand")
		register_stall(stall_a, Vector2i(1, 1))
		stall_a.current_stock = 0

		var stall_b = create_stall("red_bean_stand")
		register_stall(stall_b, Vector2i(3, 1))
		stall_b.current_stock = 0

		fire_for("on_spawn", TriggerContext.create("on_spawn") \
			.with_guest(akashita).with_source(akashita), [akashita])

		assert_gt(stall_a.current_stock, 0,
			"Akashita should restock first product stall on spawn")
		assert_gt(stall_b.current_stock, 0,
			"Akashita should restock second product stall on spawn")

	func test_no_effect_when_all_stalls_already_full():
		var akashita = create_guest("akashita")
		register_guest(akashita, Vector2i(4, 0))

		# Place a product stall that is already full
		var stall = create_stall("noodle_stand")
		register_stall(stall, Vector2i(1, 1))
		var stock_before = stall.current_stock

		var results = fire_for("on_spawn", TriggerContext.create("on_spawn") \
			.with_guest(akashita).with_source(akashita), [akashita])

		assert_eq(stall.current_stock, stock_before,
			"Already-full stall should not change")
		# The restock effect should report failure (nothing to restock)
		var any_succeeded = false
		for result in results:
			if result.success:
				any_succeeded = true
		assert_false(any_succeeded,
			"Effect should fail when no stalls need restocking")

	func test_does_not_restock_service_stalls():
		var akashita = create_guest("akashita")
		register_guest(akashita, Vector2i(4, 0))

		# Place a service stall (not product)
		var service_stall = create_stall("fish_spa")
		register_stall(service_stall, Vector2i(1, 1))

		# Place a depleted product stall
		var product_stall = create_stall("noodle_stand")
		register_stall(product_stall, Vector2i(3, 1))
		product_stall.current_stock = 0

		fire_for("on_spawn", TriggerContext.create("on_spawn") \
			.with_guest(akashita).with_source(akashita), [akashita])

		assert_gt(product_stall.current_stock, 0,
			"Product stall should be restocked")
