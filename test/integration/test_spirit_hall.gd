# test/integration/test_spirit_hall.gd
extends "res://test/helpers/test_base.gd"


class TestSpiritHallAppliesStatus:
	extends "res://test/helpers/test_base.gd"

	func test_applies_spirit_attuned_on_serve():
		var stall = create_stall("spirit_hall")
		register_stall(stall, Vector2i(2, 1))

		var guest = create_guest("playful_spirit")
		register_guest(guest, Vector2i(1, 0))

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall).with_target(guest),
			[stall, guest])

		var status = guest.get_status("spirit_attuned")
		assert_not_null(status, "Spirit Hall should apply spirit_attuned on serve")
		assert_eq(status.stacks, 1, "spirit_attuned should have 1 stack")

	func test_spirit_attuned_grants_two_skills():
		var guest = create_guest("playful_spirit")
		register_guest(guest, Vector2i(1, 0))

		BoardSystem.inflict_status(guest, "spirit_attuned", 1)

		# Check that the granted skills were registered
		var has_block_entry = false
		var has_double_encounter = false
		for skill in guest.skill_instances:
			if skill.definition.id == "spirit_attuned_block_entry":
				has_block_entry = true
			if skill.definition.id == "spirit_attuned_double_encounter":
				has_double_encounter = true

		assert_true(has_block_entry, "spirit_attuned should grant block_entry skill")
		assert_true(has_double_encounter, "spirit_attuned should grant double_encounter skill")


class TestSpiritAttunedBlocksEntry:
	extends "res://test/helpers/test_base.gd"

	func test_blocks_stall_entry():
		var guest = create_guest("playful_spirit")
		register_guest(guest, Vector2i(1, 0))

		BoardSystem.inflict_status(guest, "spirit_attuned", 1)

		var stall = create_stall("game_booth")
		register_stall(stall, Vector2i(2, 1))

		var context = TriggerContext.create("on_pre_enter_stall")
		context.with_guest(guest).with_stall(stall).with_source(guest).with_target(guest)
		context.with_entry_result()

		fire_for("on_pre_enter_stall", context, [guest, stall])

		assert_true(context.entry_result.get("blocked", false),
			"Spirit attuned guest should be blocked from entering stalls")


class TestSpiritAttunedDoubleEncounter:
	extends "res://test/helpers/test_base.gd"

	func test_doubles_joy_fulfillment_from_fox():
		var fox = create_guest("nine_tailed_fox")
		var guest = create_guest("playful_spirit")  # needs: joy 2
		register_guest(fox, Vector2i(2, 0))
		register_guest(guest, Vector2i(2, 0))

		BoardSystem.inflict_status(guest, "spirit_attuned", 1)

		var joy_before: int = guest.current_needs.get("joy", 0)
		assert_gt(joy_before, 0, "Guest should have joy need")

		# Fire on_pre_encounter to get encounter_result with multiplier
		var pre_context = TriggerContext.create("on_pre_encounter")
		pre_context.with_guest(guest).with_source(fox).with_target(guest)
		pre_context.with_encounter_result()
		fire_for("on_pre_encounter", pre_context, [guest])

		assert_eq(pre_context.encounter_result.get("benefit_multiplier", 1.0), 2.0,
			"Spirit attuned should set benefit_multiplier to 2.0")

		# Fire on_encounter with the encounter_result carried over
		var context = TriggerContext.create("on_encounter")
		context.with_guest(guest).with_source(fox).with_target(guest)
		context.encounter_result = pre_context.encounter_result

		fire_for("on_encounter", context, [fox])

		# Fox fulfills 2 joy, doubled to 4 — needs can go negative (overfulfilled)
		var joy_after: int = guest.current_needs.get("joy", 0)
		assert_eq(joy_after, joy_before - 4,
			"Fox should fulfill doubled joy (2 * 2.0 = 4) on spirit attuned guest")


class TestSpiritAttunedDoubleDebuffRemoval:
	extends "res://test/helpers/test_base.gd"

	func test_doubles_debuff_removal_from_baku():
		var baku = create_guest("baku")
		var guest = create_guest("hungry_ghost")  # needs: food 2
		register_guest(baku, Vector2i(2, 0))
		register_guest(guest, Vector2i(2, 0))

		# Apply 2 debuffs
		BoardSystem.inflict_status(guest, "charmed", 3)
		BoardSystem.inflict_status(guest, "spooked", 2)

		BoardSystem.inflict_status(guest, "spirit_attuned", 1)

		assert_eq(guest.status_effects.filter(func(s): return s.definition.effect_type == "debuff").size(), 2,
			"Guest should have 2 debuffs")

		# Fire on_pre_encounter
		var pre_context = TriggerContext.create("on_pre_encounter")
		pre_context.with_guest(guest).with_source(baku).with_target(guest)
		pre_context.with_encounter_result()
		fire_for("on_pre_encounter", pre_context, [guest])

		# Fire on_encounter with multiplied encounter_result
		var context = TriggerContext.create("on_encounter")
		context.with_guest(guest).with_source(baku).with_target(guest)
		context.encounter_result = pre_context.encounter_result

		fire_for("on_encounter", context, [baku])

		# Baku removes 1 debuff, doubled to 2 — both debuffs removed
		var remaining_debuffs = guest.status_effects.filter(func(s): return s.definition.effect_type == "debuff").size()
		assert_eq(remaining_debuffs, 0,
			"Baku should remove 2 debuffs (1 * 2.0 = 2) on spirit attuned guest")


class TestNegativeEffectsNotDoubled:
	extends "res://test/helpers/test_base.gd"

	func test_steal_money_not_doubled():
		var kappa = create_guest("kappa")
		var guest = create_guest("hungry_ghost")
		register_guest(kappa, Vector2i(2, 0))
		register_guest(guest, Vector2i(2, 0))

		BoardSystem.inflict_status(guest, "spirit_attuned", 1)

		var money_before = guest.current_money
		assert_gt(money_before, 0, "Guest should have money")

		# Fire on_pre_encounter + on_encounter
		var pre_context = TriggerContext.create("on_pre_encounter")
		pre_context.with_guest(guest).with_source(kappa).with_target(guest)
		pre_context.with_encounter_result()
		fire_for("on_pre_encounter", pre_context, [guest])

		var context = TriggerContext.create("on_encounter")
		context.with_guest(guest).with_source(kappa).with_target(guest)
		context.encounter_result = pre_context.encounter_result

		fire_for("on_encounter", context, [kappa])

		# Kappa steals 1 money — NOT doubled (steal_money doesn't read encounter_result)
		assert_eq(guest.current_money, money_before - 1,
			"Kappa steal should NOT be doubled by spirit_attuned")


class TestNonAttunedUnaffected:
	extends "res://test/helpers/test_base.gd"

	func test_default_multiplier_without_status():
		var fox = create_guest("nine_tailed_fox")
		var guest = create_guest("playful_spirit")  # needs: joy 2
		register_guest(fox, Vector2i(2, 0))
		register_guest(guest, Vector2i(2, 0))

		var joy_before: int = guest.current_needs.get("joy", 0)

		# Fire on_pre_encounter — no spirit_attuned, so multiplier stays 1.0
		var pre_context = TriggerContext.create("on_pre_encounter")
		pre_context.with_guest(guest).with_source(fox).with_target(guest)
		pre_context.with_encounter_result()
		fire_for("on_pre_encounter", pre_context, [guest])

		assert_eq(pre_context.encounter_result.get("benefit_multiplier", 1.0), 1.0,
			"Non-attuned guest should have default 1.0 multiplier")

		# Fire on_encounter — normal fulfillment
		var context = TriggerContext.create("on_encounter")
		context.with_guest(guest).with_source(fox).with_target(guest)
		context.encounter_result = pre_context.encounter_result

		fire_for("on_encounter", context, [fox])

		var joy_after: int = guest.current_needs.get("joy", 0)
		assert_eq(joy_after, joy_before - 2,
			"Fox should fulfill normal 2 joy without spirit_attuned")
