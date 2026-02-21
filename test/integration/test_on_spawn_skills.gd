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
