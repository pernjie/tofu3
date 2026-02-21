# test/integration/test_on_bulk_serve_skills.gd
extends "res://test/helpers/test_base.gd"


class TestBanishWeakestAfterBulk:
	extends "res://test/helpers/test_base.gd"

	func _create_bulk_serve_context(stall: StallInstance, guests: Array) -> TriggerContext:
		return TriggerContext.create("on_bulk_serve") \
			.with_stall(stall).with_guests(guests).with_source(stall)

	func test_banishes_guest_with_least_remaining_need():
		var guest_a = create_guest("playful_spirit")
		var guest_b = create_guest("playful_spirit")
		var stall = create_stall("dojo")
		register_guest(guest_a, Vector2i(2, 0))
		register_guest(guest_b, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		# guest_a has less remaining joy need (weaker)
		guest_a.current_needs["joy"] = 1
		guest_b.current_needs["joy"] = 3

		fire_for("on_bulk_serve", _create_bulk_serve_context(stall, [guest_a, guest_b]), [stall])

		assert_true(guest_a.is_banished,
			"Guest with less remaining need should be banished")
		assert_false(guest_b.is_banished,
			"Guest with more remaining need should not be banished")

	func test_tiebreaker_banishes_last_arrived():
		var guest_a = create_guest("playful_spirit")
		var guest_b = create_guest("playful_spirit")
		var stall = create_stall("dojo")
		register_guest(guest_a, Vector2i(2, 0))
		register_guest(guest_b, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		# Both have same remaining need — tie
		guest_a.current_needs["joy"] = 2
		guest_b.current_needs["joy"] = 2

		# guest_b is last in array (arrived later)
		fire_for("on_bulk_serve", _create_bulk_serve_context(stall, [guest_a, guest_b]), [stall])

		assert_false(guest_a.is_banished,
			"Earlier arrival should survive the tie")
		assert_true(guest_b.is_banished,
			"Later arrival should be banished on tie")

	func test_single_guest_not_banished():
		var guest = create_guest("playful_spirit")
		var stall = create_stall("dojo")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_bulk_serve", _create_bulk_serve_context(stall, [guest]), [stall])

		assert_false(guest.is_banished,
			"Single guest should not be banished")

	func test_three_guests_tiebreaker_among_tied():
		var guest_a = create_guest("playful_spirit")
		var guest_b = create_guest("playful_spirit")
		var guest_c = create_guest("playful_spirit")
		var stall = create_stall("dojo")
		register_guest(guest_a, Vector2i(2, 0))
		register_guest(guest_b, Vector2i(2, 0))
		register_guest(guest_c, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		# guest_a is strongest, guest_b and guest_c tie for weakest
		guest_a.current_needs["joy"] = 3
		guest_b.current_needs["joy"] = 1
		guest_c.current_needs["joy"] = 1

		fire_for("on_bulk_serve", _create_bulk_serve_context(stall, [guest_a, guest_b, guest_c]), [stall])

		assert_false(guest_a.is_banished,
			"Strongest guest should not be banished")
		assert_false(guest_b.is_banished,
			"Earlier tied guest should survive")
		assert_true(guest_c.is_banished,
			"Later tied guest should be banished")

	func test_only_one_banished_with_three_guests():
		var guest_a = create_guest("playful_spirit")
		var guest_b = create_guest("playful_spirit")
		var guest_c = create_guest("playful_spirit")
		var stall = create_stall("dojo")
		register_guest(guest_a, Vector2i(2, 0))
		register_guest(guest_b, Vector2i(2, 0))
		register_guest(guest_c, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		guest_a.current_needs["joy"] = 1
		guest_b.current_needs["joy"] = 2
		guest_c.current_needs["joy"] = 3

		fire_for("on_bulk_serve", _create_bulk_serve_context(stall, [guest_a, guest_b, guest_c]), [stall])

		var banish_count = 0
		if guest_a.is_banished: banish_count += 1
		if guest_b.is_banished: banish_count += 1
		if guest_c.is_banished: banish_count += 1

		assert_eq(banish_count, 1,
			"Exactly one guest should be banished")
		assert_true(guest_a.is_banished,
			"Guest with least remaining need should be the one banished")

	func test_exiting_guest_not_banished():
		var guest_a = create_guest("playful_spirit")
		var guest_b = create_guest("playful_spirit")
		var stall = create_stall("dojo")
		register_guest(guest_a, Vector2i(2, 0))
		register_guest(guest_b, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		guest_a.current_needs["joy"] = 1
		guest_b.current_needs["joy"] = 3
		guest_a.is_exiting = true  # already exiting

		fire_for("on_bulk_serve", _create_bulk_serve_context(stall, [guest_a, guest_b]), [stall])

		assert_false(guest_a.is_banished,
			"Already exiting guest should not be banished")
