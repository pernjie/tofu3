# test/integration/test_on_place_skills.gd
extends "res://test/helpers/test_base.gd"


class TestMysticalScrollDiscover:
	extends "res://test/helpers/test_base.gd"

	var beast_pool: Array = ["baku", "nine_tailed_fox", "hanzaki", "tanuki"]

	func test_produces_deferred_discover_request():
		var scroll = create_relic("mystical_scroll")
		register_relic(scroll, Vector2i(1, 1))

		fire_for("on_place", TriggerContext.create("on_place") \
			.with_tile(scroll.tile).with_source(scroll), [scroll])

		assert_eq(TriggerSystem.pending_deferred_requests.size(), 1,
			"Should produce one deferred request")

		var request = TriggerSystem.pending_deferred_requests[0]
		assert_eq(request["type"], "discover",
			"Request type should be 'discover'")
		assert_eq(request["store_key"], "chosen_beast_id",
			"Store key should be 'chosen_beast_id'")

	func test_request_contains_options_from_pool():
		var scroll = create_relic("mystical_scroll")
		register_relic(scroll, Vector2i(1, 1))

		fire_for("on_place", TriggerContext.create("on_place") \
			.with_tile(scroll.tile).with_source(scroll), [scroll])

		var request = TriggerSystem.pending_deferred_requests[0]
		var options = request["options"]
		assert_eq(options.size(), 3,
			"Should present 3 options (default count)")

		for option in options:
			assert_has(beast_pool, option["data"],
				"Option '%s' should be from the beast pool" % option["data"])
