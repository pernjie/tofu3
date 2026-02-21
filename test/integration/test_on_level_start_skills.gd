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
