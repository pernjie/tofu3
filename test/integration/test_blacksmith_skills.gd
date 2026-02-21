# test/integration/test_blacksmith_skills.gd
extends "res://test/helpers/test_base.gd"

## Tests for blacksmith stall skill:
##   - blacksmith_status_immunity (on_pre_status): blocks ALL statuses (buffs and debuffs)


class TestBlacksmithStatusImmunity:
	extends "res://test/helpers/test_base.gd"

	var stall: StallInstance

	func before_each():
		super.before_each()
		stall = create_stall("blacksmith")
		register_stall(stall, Vector2i(2, 1))

	func test_blocks_debuff_status():
		var result = BoardSystem.inflict_status(stall, "smelly", 1)

		assert_null(result, "inflict_status should return null when blocked")
		assert_false(stall.has_status("smelly"),
			"Blacksmith should not have smelly status")

	func test_blocks_closed_debuff_status():
		var result = BoardSystem.inflict_status(stall, "closed", 1)

		assert_null(result, "inflict_status should return null when blocked")
		assert_false(stall.has_status("closed"),
			"Blacksmith should not have closed status")

	func test_blocks_buff_status():
		# Create a synthetic buff applicable to stalls since no stall buff exists in data
		var buff_def = StatusEffectDefinition.new()
		buff_def.id = "test_stall_buff"
		buff_def.effect_type = "buff"

		var context = TriggerContext.create("on_pre_status") \
			.with_target(stall).with_stall(stall) \
			.with_extra("status_definition", buff_def) \
			.with_status_result()
		fire_for("on_pre_status", context, [stall])

		assert_true(context.status_result.get("blocked", false),
			"Buff status should also be blocked by total immunity")

	func test_blocks_via_pre_trigger_context():
		var status_def = ContentRegistry.get_definition("status_effects", "smelly")

		var context = TriggerContext.create("on_pre_status") \
			.with_target(stall).with_stall(stall) \
			.with_extra("status_definition", status_def) \
			.with_status_result()
		fire_for("on_pre_status", context, [stall])

		assert_true(context.status_result["blocked"],
			"status_result.blocked should be true after immunity fires")

	func test_stall_has_immunity_skill():
		var skill_ids: Array[String] = []
		for skill in stall.skill_instances:
			skill_ids.append(skill.definition.id)

		assert_true("blacksmith_status_immunity" in skill_ids,
			"Blacksmith should have status immunity skill")

	func test_immunity_persists_after_upgrade():
		# Upgrade to tier 2
		BoardSystem.upgrade_stall(stall)

		var result = BoardSystem.inflict_status(stall, "smelly", 1)

		assert_null(result, "inflict_status should return null when blocked at T2")
		assert_false(stall.has_status("smelly"),
			"Blacksmith T2 should still block statuses")

	func test_other_stall_still_receives_status():
		# Verify a normal stall IS affected (negative test)
		var game_booth = create_stall("game_booth")
		register_stall(game_booth, Vector2i(3, 1))

		var result = BoardSystem.inflict_status(game_booth, "smelly", 1)

		assert_not_null(result, "Normal stall should receive status")
		assert_true(game_booth.has_status("smelly"),
			"Game booth should have smelly status")
