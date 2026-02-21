# test/integration/test_skill_conditions.gd
#
# Tests for skill conditions in isolation — creates conditions directly
# and evaluates them against crafted contexts and skill instances.
extends "res://test/helpers/test_base.gd"


class TestStallStockCheck:
	extends "res://test/helpers/test_base.gd"

	var _stall: StallInstance
	var _skill: SkillInstance

	func before_each():
		super.before_each()
		_stall = create_stall("noodle_stand")
		register_stall(_stall, Vector2i(2, 1))
		# Create a dummy skill for parameter resolution
		var skill_def = ContentRegistry.get_definition("skills", "restock_on_deplete")
		var guest = create_guest("apothecary")
		_skill = SkillInstance.new(skill_def, guest)

	func test_equal_zero_passes_when_empty():
		_stall.current_stock = 0
		var condition = StallStockCheckCondition.new({
			"type": "stall_stock_check", "comparison": "equal", "value": 0
		})
		var ctx = TriggerContext.create("on_serve").with_stall(_stall)
		assert_true(condition.evaluate(ctx, _skill),
			"stall_stock_check equal 0 should pass when stock is 0")

	func test_equal_zero_fails_when_stocked():
		_stall.current_stock = 3
		var condition = StallStockCheckCondition.new({
			"type": "stall_stock_check", "comparison": "equal", "value": 0
		})
		var ctx = TriggerContext.create("on_serve").with_stall(_stall)
		assert_false(condition.evaluate(ctx, _skill),
			"stall_stock_check equal 0 should fail when stock is 3")

	func test_greater_than():
		_stall.current_stock = 5
		var condition = StallStockCheckCondition.new({
			"type": "stall_stock_check", "comparison": "greater_than", "value": 2
		})
		var ctx = TriggerContext.create("on_serve").with_stall(_stall)
		assert_true(condition.evaluate(ctx, _skill),
			"stall_stock_check greater_than 2 should pass when stock is 5")


class TestHasDebuff:
	extends "res://test/helpers/test_base.gd"

	func test_passes_with_debuff():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))
		BoardSystem.inflict_status(guest, "charmed", 1)

		var skill_def = ContentRegistry.get_definition("skills", "restorative_yoga")
		var stall = create_stall("yoga_mats")
		var skill = SkillInstance.new(skill_def, stall)

		var condition = HasDebuffCondition.new({
			"type": "has_debuff", "target": "guest"
		})
		var ctx = TriggerContext.create("on_pre_serve").with_guest(guest)
		assert_true(condition.evaluate(ctx, skill),
			"has_debuff should pass when guest has charmed (debuff)")

	func test_fails_without_debuff():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))
		# No debuff applied

		var skill_def = ContentRegistry.get_definition("skills", "restorative_yoga")
		var stall = create_stall("yoga_mats")
		var skill = SkillInstance.new(skill_def, stall)

		var condition = HasDebuffCondition.new({
			"type": "has_debuff", "target": "guest"
		})
		var ctx = TriggerContext.create("on_pre_serve").with_guest(guest)
		assert_false(condition.evaluate(ctx, skill),
			"has_debuff should fail when guest has no debuff")


class TestNeedThreshold:
	extends "res://test/helpers/test_base.gd"

	func test_greater_than_passes():
		var guest = create_guest("playful_spirit")  # joy: 2
		register_guest(guest, Vector2i(2, 0))
		var skill_def = ContentRegistry.get_definition("skills", "encounter_fulfill_need")
		var fox = create_guest("nine_tailed_fox")
		var skill = SkillInstance.new(skill_def, fox)
		skill.parameter_overrides["need_type"] = "joy"

		var condition = NeedThresholdCondition.new({
			"type": "need_threshold", "target": "target",
			"need_type": "{need_type}", "comparison": "greater_than", "value": 0
		})
		var ctx = TriggerContext.create("on_encounter") \
			.with_guest(guest).with_target(guest)
		assert_true(condition.evaluate(ctx, skill),
			"need_threshold joy > 0 should pass when joy is 2")

	func test_greater_than_fails_when_zero():
		var guest = create_guest("playful_spirit")
		register_guest(guest, Vector2i(2, 0))
		guest.current_needs["joy"] = 0
		var skill_def = ContentRegistry.get_definition("skills", "encounter_fulfill_need")
		var fox = create_guest("nine_tailed_fox")
		var skill = SkillInstance.new(skill_def, fox)
		skill.parameter_overrides["need_type"] = "joy"

		var condition = NeedThresholdCondition.new({
			"type": "need_threshold", "target": "target",
			"need_type": "{need_type}", "comparison": "greater_than", "value": 0
		})
		var ctx = TriggerContext.create("on_encounter") \
			.with_guest(guest).with_target(guest)
		assert_false(condition.evaluate(ctx, skill),
			"need_threshold joy > 0 should fail when joy is 0")


class TestCompareNeeds:
	extends "res://test/helpers/test_base.gd"

	func test_less_or_equal_passes():
		var hanzaki = create_guest("hanzaki")  # interact: 3
		var target = create_guest("playful_spirit")  # joy: 2
		register_guest(hanzaki, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))

		var skill_def = ContentRegistry.get_definition("skills", "encounter_banish")
		var skill = SkillInstance.new(skill_def, hanzaki)

		var condition = CompareNeedsCondition.new({
			"type": "compare_needs", "target": "target",
			"compare_to": "source", "comparison": "less_or_equal"
		})
		var ctx = TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(hanzaki).with_target(target)
		# target(2) <= source(3) → true
		assert_true(condition.evaluate(ctx, skill),
			"compare_needs less_or_equal should pass when target(2) <= source(3)")

	func test_less_or_equal_fails():
		var hanzaki = create_guest("hanzaki")  # interact: 3
		var target = create_guest("hungry_ghost")
		register_guest(hanzaki, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))
		target.current_needs["food"] = 5  # total 5 > 3

		var skill_def = ContentRegistry.get_definition("skills", "encounter_banish")
		var skill = SkillInstance.new(skill_def, hanzaki)

		var condition = CompareNeedsCondition.new({
			"type": "compare_needs", "target": "target",
			"compare_to": "source", "comparison": "less_or_equal"
		})
		var ctx = TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(hanzaki).with_target(target)
		# target(5) <= source(3) → false
		assert_false(condition.evaluate(ctx, skill),
			"compare_needs less_or_equal should fail when target(5) > source(3)")


class TestAmountCheck:
	extends "res://test/helpers/test_base.gd"

	func test_equal_passes():
		var seamstress = create_guest("seamstress")
		var skill_def = ContentRegistry.get_definition("skills", "perfectionist")
		var skill = SkillInstance.new(skill_def, seamstress)
		# Default required_amount is 2

		var condition = AmountCheckCondition.new({
			"type": "amount_check", "comparison": "equal", "value": "{required_amount}"
		})
		var ctx = TriggerContext.create("on_need_fulfilled").with_amount(2)
		assert_true(condition.evaluate(ctx, skill),
			"amount_check equal 2 should pass when amount is 2")

	func test_equal_fails():
		var seamstress = create_guest("seamstress")
		var skill_def = ContentRegistry.get_definition("skills", "perfectionist")
		var skill = SkillInstance.new(skill_def, seamstress)

		var condition = AmountCheckCondition.new({
			"type": "amount_check", "comparison": "equal", "value": "{required_amount}"
		})
		var ctx = TriggerContext.create("on_need_fulfilled").with_amount(1)
		assert_false(condition.evaluate(ctx, skill),
			"amount_check equal 2 should fail when amount is 1")


class TestStateLessThan:
	extends "res://test/helpers/test_base.gd"

	func test_passes_when_below_threshold():
		var relic = create_relic("gourd")
		register_relic(relic, Vector2i(1, 1))
		var skill = relic.skill_instances[0]

		var condition = StateLessThanCondition.new({
			"type": "state_less_than", "state_key": "restock_count", "value": 1
		})
		var ctx = TriggerContext.create("on_restock")
		# state starts at 0, threshold is 1 → 0 < 1 → true
		assert_true(condition.evaluate(ctx, skill),
			"state_less_than should pass when state(0) < threshold(1)")

	func test_fails_when_at_threshold():
		var relic = create_relic("gourd")
		register_relic(relic, Vector2i(1, 1))
		var skill = relic.skill_instances[0]
		skill.set_state("restock_count", 1)

		var condition = StateLessThanCondition.new({
			"type": "state_less_than", "state_key": "restock_count", "value": 1
		})
		var ctx = TriggerContext.create("on_restock")
		# state is 1, threshold is 1 → 1 < 1 → false
		assert_false(condition.evaluate(ctx, skill),
			"state_less_than should fail when state(1) == threshold(1)")

	func test_fails_when_above_threshold():
		var relic = create_relic("gourd")
		register_relic(relic, Vector2i(1, 1))
		var skill = relic.skill_instances[0]
		skill.set_state("restock_count", 3)

		var condition = StateLessThanCondition.new({
			"type": "state_less_than", "state_key": "restock_count", "value": 1
		})
		var ctx = TriggerContext.create("on_restock")
		assert_false(condition.evaluate(ctx, skill),
			"state_less_than should fail when state(3) > threshold(1)")
