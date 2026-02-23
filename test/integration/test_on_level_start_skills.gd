# test/integration/test_on_level_start_skills.gd
extends "res://test/helpers/test_base.gd"


class TestMysticalScrollSummon:
	extends "res://test/helpers/test_base.gd"

	func test_adds_chosen_beast_to_queue():
		var scroll = create_relic("mystical_scroll")
		register_relic(scroll, Vector2i(1, 1))

		# Simulate player having chosen baku via discover UI
		scroll.persistent_state["chosen_beast_id"] = "baku"

		fire("on_level_start", TriggerContext.create("on_level_start"))

		assert_eq(BoardSystem.beast_queue.size(), 1,
			"Beast queue should have one entry")
		assert_eq(BoardSystem.beast_queue[0].id, "baku",
			"Queued beast should be baku")

	func test_queues_correct_beast_among_choices():
		var scroll = create_relic("mystical_scroll")
		register_relic(scroll, Vector2i(1, 1))

		# Simulate player having chosen nine_tailed_fox (not baku)
		scroll.persistent_state["chosen_beast_id"] = "nine_tailed_fox"

		fire("on_level_start", TriggerContext.create("on_level_start"))

		assert_eq(BoardSystem.beast_queue.size(), 1,
			"Beast queue should have one entry")
		assert_eq(BoardSystem.beast_queue[0].id, "nine_tailed_fox",
			"Queued beast should match the chosen beast, not a default")


class TestOxHourBellEarlyMidnight:
	extends "res://test/helpers/test_base.gd"

	func test_sets_midnight_threshold_on_level_start():
		TurnSystem.midnight_threshold_fraction = 0.0
		var relic = create_relic("ox_hour_bell")
		register_relic(relic, Vector2i(1, 1))

		fire("on_level_start", TriggerContext.create("on_level_start"))

		assert_almost_eq(TurnSystem.midnight_threshold_fraction, 0.5, 0.001,
			"Ox Hour Bell should set midnight threshold to 0.5")

	func test_sets_midnight_threshold_on_mid_level_placement():
		TurnSystem.midnight_threshold_fraction = 0.0
		var relic = create_relic("ox_hour_bell")
		register_relic(relic, Vector2i(1, 1))

		# Simulate mid-level placement: fire on_level_start for just this relic
		fire_for("on_level_start", TriggerContext.create("on_level_start"), [relic])

		assert_almost_eq(TurnSystem.midnight_threshold_fraction, 0.5, 0.001,
			"Ox Hour Bell should set midnight threshold when placed mid-level")

	func test_midnight_threshold_not_set_without_relic():
		TurnSystem.midnight_threshold_fraction = 0.0

		fire("on_level_start", TriggerContext.create("on_level_start"))

		assert_almost_eq(TurnSystem.midnight_threshold_fraction, 0.0, 0.001,
			"Midnight threshold should remain 0.0 without relic")
