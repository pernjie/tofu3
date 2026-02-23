# test/integration/test_magic_mochi_stand.gd
extends "res://test/helpers/test_base.gd"


class TestMochiStandBonusValue:
	extends "res://test/helpers/test_base.gd"

	func before_each():
		super.before_each()
		GameManager.persistent_data = {}

	func test_no_bonus_when_persistent_data_empty():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("magic_mochi_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		var context = TriggerContext.create("on_pre_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest).with_service_result()
		fire_for("on_pre_serve", context, [guest, stall])

		assert_eq(context.service_result["fulfillment_bonus"], 0,
			"No bonus when persistent data is empty")

	func test_applies_accumulated_bonus():
		var guest = create_guest("hungry_ghost")
		var stall = create_stall("magic_mochi_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		# Pre-seed persistent data as if growth happened in prior levels
		GameManager.persistent_data["magic_mochi_stand"] = { "bonus_value": 3 }

		var context = TriggerContext.create("on_pre_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest).with_service_result()
		fire_for("on_pre_serve", context, [guest, stall])

		assert_eq(context.service_result["fulfillment_bonus"], 3,
			"Should apply accumulated bonus from persistent data")


class TestMochiStandPermanentGrowth:
	extends "res://test/helpers/test_base.gd"

	func before_each():
		super.before_each()
		GameManager.persistent_data = {}

	func test_no_growth_before_midnight():
		var stall = create_stall("magic_mochi_stand")
		register_stall(stall, Vector2i(2, 1))

		# Midnight has NOT been reached
		TurnSystem._midnight_emitted = false

		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		var store = GameManager.persistent_data.get("magic_mochi_stand", {})
		assert_eq(store.get("bonus_value", 0), 0,
			"No growth before midnight")

	func test_grows_on_restock_after_midnight():
		var stall = create_stall("magic_mochi_stand")
		register_stall(stall, Vector2i(2, 1))

		# Midnight HAS been reached
		TurnSystem._midnight_emitted = true

		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		var store = GameManager.persistent_data.get("magic_mochi_stand", {})
		assert_eq(store.get("bonus_value", 0), 1,
			"Should gain +1 bonus on restock after midnight")

	func test_accumulates_over_multiple_restocks():
		var stall = create_stall("magic_mochi_stand")
		register_stall(stall, Vector2i(2, 1))
		TurnSystem._midnight_emitted = true

		for i in range(3):
			fire("on_restock", TriggerContext.create("on_restock") \
				.with_stall(stall).with_source(stall))

		var store = GameManager.persistent_data["magic_mochi_stand"]
		assert_eq(store["bonus_value"], 3,
			"Should accumulate +1 per restock after midnight")

	func test_two_stands_share_persistent_state():
		var stall_a = create_stall("magic_mochi_stand")
		register_stall(stall_a, Vector2i(2, 1))
		var stall_b = create_stall("magic_mochi_stand")
		register_stall(stall_b, Vector2i(3, 1))
		TurnSystem._midnight_emitted = true

		# Each stand restocks once
		fire_for("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall_a).with_source(stall_a), [stall_a])
		fire_for("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall_b).with_source(stall_b), [stall_b])

		var store = GameManager.persistent_data["magic_mochi_stand"]
		assert_eq(store["bonus_value"], 2,
			"Both stands should contribute to shared bonus")

	func test_growth_persists_across_clear():
		var stall = create_stall("magic_mochi_stand")
		register_stall(stall, Vector2i(2, 1))
		TurnSystem._midnight_emitted = true

		fire("on_restock", TriggerContext.create("on_restock") \
			.with_stall(stall).with_source(stall))

		# Simulate level clear — persistent_data survives but stall is gone
		BoardSystem.clear_level()
		TriggerSystem.clear_all()
		_setup_default_board()

		# Re-place stall in new level and check bonus applies
		var new_stall = create_stall("magic_mochi_stand")
		register_stall(new_stall, Vector2i(2, 1))
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))

		var context = TriggerContext.create("on_pre_serve") \
			.with_guest(guest).with_stall(new_stall).with_source(new_stall) \
			.with_target(guest).with_service_result()
		fire_for("on_pre_serve", context, [guest, new_stall])

		assert_eq(context.service_result["fulfillment_bonus"], 1,
			"Bonus should persist after level clear")


class TestAfterMidnightCondition:
	extends "res://test/helpers/test_base.gd"

	func test_returns_false_before_midnight():
		TurnSystem._midnight_emitted = false
		var condition = AfterMidnightCondition.new({})
		var context = TriggerContext.create("on_restock")
		var skill = _make_dummy_skill()
		assert_false(condition.evaluate(context, skill),
			"Should return false before midnight")

	func test_returns_true_after_midnight():
		TurnSystem._midnight_emitted = true
		var condition = AfterMidnightCondition.new({})
		var context = TriggerContext.create("on_restock")
		var skill = _make_dummy_skill()
		assert_true(condition.evaluate(context, skill),
			"Should return true after midnight")

	func _make_dummy_skill() -> SkillInstance:
		var def = ContentRegistry.get_definition("skills", "mochi_stand_permanent_growth")
		var stall = create_stall("magic_mochi_stand")
		return SkillInstance.new(def, stall)
