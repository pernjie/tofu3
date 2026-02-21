# test/integration/test_on_encounter_skills.gd
extends "res://test/helpers/test_base.gd"


# --- on_encounter triggers (beast skills that fire when encountering regular guests) ---

class TestNineTailedFoxEncounter:
	extends "res://test/helpers/test_base.gd"

	func test_fulfills_joy_on_encounter():
		var fox = create_guest("nine_tailed_fox")
		var target = create_guest("playful_spirit")  # needs: joy 2
		register_guest(fox, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))  # same tile
		var joy_before = target.current_needs.get("joy", 0)
		assert_gt(joy_before, 0, "Target should have joy need")

		# on_encounter: beast=source, regular guest=target
		fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(fox).with_target(target), [fox])

		assert_eq(target.current_needs.get("joy", 0), joy_before - 2,
			"Fox should fulfill 2 joy on encounter")

	func test_no_fulfillment_when_need_already_met():
		var fox = create_guest("nine_tailed_fox")
		var target = create_guest("playful_spirit")
		register_guest(fox, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))
		target.current_needs["joy"] = 0  # already fulfilled

		var results = fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(fox).with_target(target), [fox])

		# The need_threshold condition (joy > 0) should fail
		var any_succeeded = false
		for result in results:
			if result.success:
				any_succeeded = true
		assert_false(any_succeeded,
			"Fox encounter_fulfill_need should not fire when joy is already 0")


class TestTanukiEncounter:
	extends "res://test/helpers/test_base.gd"

	func test_fulfills_food_on_encounter():
		var tanuki = create_guest("tanuki")
		var target = create_guest("hungry_ghost")  # needs: food 2
		register_guest(tanuki, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))
		var food_before = target.current_needs.get("food", 0)
		assert_gt(food_before, 0, "Target should have food need")

		fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(tanuki).with_target(target), [tanuki])

		assert_eq(target.current_needs.get("food", 0), food_before - 2,
			"Tanuki should fulfill 2 food on encounter")

	func test_applies_lost_status_on_encounter():
		var tanuki = create_guest("tanuki")
		var target = create_guest("hungry_ghost")
		register_guest(tanuki, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))

		fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(tanuki).with_target(target), [tanuki])

		var status = target.get_status("lost")
		assert_not_null(status, "Tanuki should apply lost status on encounter")
		assert_eq(status.stacks, 5, "Lost should have 5 stacks")


class TestBakuEncounter:
	extends "res://test/helpers/test_base.gd"

	func test_removes_debuff_and_fulfills_need():
		var baku = create_guest("baku")
		var target = create_guest("hungry_ghost")
		register_guest(baku, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))
		# Apply a debuff to the target
		BoardSystem.inflict_status(target, "charmed", 3)
		assert_not_null(target.get_status("charmed"), "Target should have charmed debuff")
		var total_needs_before = target.get_total_remaining_needs()

		fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(baku).with_target(target), [baku])

		# Debuff should be removed
		assert_null(target.get_status("charmed"),
			"Baku should remove charmed debuff")
		# A random need should be fulfilled by 1
		assert_lt(target.get_total_remaining_needs(), total_needs_before,
			"Baku should fulfill a random need after consuming debuff")

	func test_no_effect_without_debuff():
		var baku = create_guest("baku")
		var target = create_guest("hungry_ghost")
		register_guest(baku, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))
		# No debuff on target
		var total_needs_before = target.get_total_remaining_needs()

		var results = fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(baku).with_target(target), [baku])

		# has_debuff condition should fail — no effects fire
		assert_eq(target.get_total_remaining_needs(), total_needs_before,
			"Baku should not fulfill needs without debuff on target")


class TestHanzakiEncounter:
	extends "res://test/helpers/test_base.gd"

	func test_banishes_weaker_guest():
		var hanzaki = create_guest("hanzaki")  # needs: interact 3
		var target = create_guest("playful_spirit")  # needs: joy 2
		register_guest(hanzaki, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))
		# target total needs (2) <= hanzaki total needs (3) → condition passes

		fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(hanzaki).with_target(target), [hanzaki])

		assert_true(target.is_banished,
			"Hanzaki should banish guest with fewer or equal total needs")
		assert_true(target.is_exiting,
			"Banished guest should be marked as exiting")

	func test_does_not_banish_stronger_guest():
		var hanzaki = create_guest("hanzaki")  # needs: interact 3
		var target = create_guest("hungry_ghost")  # needs: food 2
		register_guest(hanzaki, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))
		# Increase target needs so they exceed hanzaki's
		target.current_needs["food"] = 5  # total 5 > hanzaki's 3

		fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(hanzaki).with_target(target), [hanzaki])

		assert_false(target.is_banished,
			"Hanzaki should not banish guest with more total needs")


class TestKappaEncounter:
	extends "res://test/helpers/test_base.gd"

	func test_steals_money_on_encounter():
		var kappa = create_guest("kappa")
		var target = create_guest("hungry_ghost")
		register_guest(kappa, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))
		var money_before = target.current_money
		assert_gt(money_before, 0, "Target should have money")

		fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(kappa).with_target(target), [kappa])

		assert_eq(target.current_money, money_before - 1,
			"Kappa should steal 1 money from target")
		assert_eq(kappa.current_money, 1,
			"Kappa should receive the stolen money")

	func test_no_steal_when_target_has_no_money():
		var kappa = create_guest("kappa")
		var target = create_guest("hungry_ghost")
		register_guest(kappa, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))
		target.current_money = 0  # no money

		var results = fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(kappa).with_target(target), [kappa])

		var any_succeeded = false
		for result in results:
			if result.success:
				any_succeeded = true
		assert_false(any_succeeded,
			"Kappa should not interact with guest that has no money")
		assert_eq(kappa.current_money, 0,
			"Kappa should not gain money from failed encounter")


# --- on_interact triggers (fire after encounter succeeds, via beast_interacted event) ---

class TestNineTailedFoxInteract:
	extends "res://test/helpers/test_base.gd"

	func test_applies_charmed_on_interact():
		var fox = create_guest("nine_tailed_fox")
		var target = create_guest("hungry_ghost")
		register_guest(fox, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))

		fire_for("on_interact", TriggerContext.create("on_interact") \
			.with_guest(target).with_source(fox).with_target(target),
			[fox, target])

		var status = target.get_status("charmed")
		assert_not_null(status, "Fox should apply charmed on interact")
		assert_eq(status.stacks, 8, "Charmed should have 8 stacks")


class TestTanukiEncounterApplyStatus:
	extends "res://test/helpers/test_base.gd"

	func test_lost_stacks_accumulate_on_repeated_encounters():
		var tanuki = create_guest("tanuki")
		var target = create_guest("hungry_ghost")
		register_guest(tanuki, Vector2i(2, 0))
		register_guest(target, Vector2i(2, 0))

		fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(tanuki).with_target(target), [tanuki])

		assert_eq(target.get_status("lost").stacks, 5, "First encounter: 5 stacks")

		fire_for("on_encounter", TriggerContext.create("on_encounter") \
			.with_guest(target).with_source(tanuki).with_target(target), [tanuki])

		assert_eq(target.get_status("lost").stacks, 10,
			"Second encounter should accumulate to max stacks (10)")
