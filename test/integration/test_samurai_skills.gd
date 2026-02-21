# test/integration/test_samurai_skills.gd
extends "res://test/helpers/test_base.gd"

## Tests for samurai guest skills:
##   - samurai_status_immunity (on_pre_status): blocks ALL statuses (buffs and debuffs)
##   - samurai_banish_immunity (on_pre_banish): blocks banishment


class TestSamuraiStatusImmunity:
	extends "res://test/helpers/test_base.gd"

	var samurai: GuestInstance

	func before_each():
		super.before_each()
		samurai = create_guest("samurai")
		register_guest(samurai, Vector2i(2, 0))

	func test_blocks_debuff_status():
		var result = BoardSystem.inflict_status(samurai, "charmed", 3)

		assert_null(result, "inflict_status should return null when blocked")
		assert_false(samurai.has_status("charmed"),
			"Samurai should not have charmed status")

	func test_blocks_lost_debuff_status():
		var result = BoardSystem.inflict_status(samurai, "lost", 2)

		assert_null(result, "inflict_status should return null when blocked")
		assert_false(samurai.has_status("lost"),
			"Samurai should not have lost status")

	func test_blocks_buff_status():
		var buff_def = StatusEffectDefinition.new()
		buff_def.id = "test_buff"
		buff_def.effect_type = "buff"

		var context = TriggerContext.create("on_pre_status") \
			.with_target(samurai).with_guest(samurai) \
			.with_extra("status_definition", buff_def) \
			.with_status_result()
		fire_for("on_pre_status", context, [samurai])

		assert_true(context.status_result.get("blocked", false),
			"Buff status should also be blocked by total immunity")

	func test_blocks_via_pre_trigger_context():
		var status_def = ContentRegistry.get_definition("status_effects", "charmed")

		var context = TriggerContext.create("on_pre_status") \
			.with_target(samurai).with_guest(samurai) \
			.with_extra("status_definition", status_def) \
			.with_status_result()
		fire_for("on_pre_status", context, [samurai])

		assert_true(context.status_result["blocked"],
			"status_result.blocked should be true after immunity fires")


class TestSamuraiBanishImmunity:
	extends "res://test/helpers/test_base.gd"

	var samurai: GuestInstance

	func before_each():
		super.before_each()
		samurai = create_guest("samurai")
		register_guest(samurai, Vector2i(2, 0))

	func test_blocks_banishment():
		var result = BoardSystem.banish_guest(samurai)

		assert_false(result, "banish_guest should return false when blocked")
		assert_false(samurai.is_banished, "Samurai should not be banished")
		assert_false(samurai.is_exiting, "Samurai should not be exiting")

	func test_remains_on_board_after_banish_attempt():
		BoardSystem.banish_guest(samurai)

		assert_true(samurai in BoardSystem.active_guests,
			"Samurai should still be in active_guests after blocked banish")

	func test_blocks_via_pre_trigger_context():
		var context = TriggerContext.create("on_pre_banish") \
			.with_guest(samurai).with_source(samurai) \
			.with_banish_result()
		fire_for("on_pre_banish", context, [samurai])

		assert_true(context.banish_result["blocked"],
			"banish_result.blocked should be true after banish immunity fires")


class TestSamuraiBothImmunities:
	extends "res://test/helpers/test_base.gd"

	func test_samurai_has_both_skills():
		var samurai = create_guest("samurai")
		register_guest(samurai, Vector2i(2, 0))

		var skill_ids: Array[String] = []
		for skill in samurai.skill_instances:
			skill_ids.append(skill.definition.id)

		assert_true("samurai_status_immunity" in skill_ids,
			"Samurai should have status immunity skill")
		assert_true("samurai_banish_immunity" in skill_ids,
			"Samurai should have banish immunity skill")

	func test_debuff_and_banish_both_blocked():
		var samurai = create_guest("samurai")
		register_guest(samurai, Vector2i(2, 0))

		# Try debuff
		var status_result = BoardSystem.inflict_status(samurai, "charmed", 1)
		assert_null(status_result, "Debuff should be blocked")

		# Try banish
		var banish_result = BoardSystem.banish_guest(samurai)
		assert_false(banish_result, "Banish should be blocked")

		# Samurai unaffected
		assert_false(samurai.has_status("charmed"), "No charmed status")
		assert_false(samurai.is_banished, "Not banished")
		assert_true(samurai in BoardSystem.active_guests, "Still on board")
