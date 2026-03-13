# test/integration/test_enhancements.gd
extends "res://test/helpers/test_base.gd"


func _create_enhancement(id: String) -> EnhancementDefinition:
	return ContentRegistry.get_definition("enhancements", id)


class TestEnhancementPlacement:
	extends "res://test/helpers/test_base.gd"

	func _create_enhancement(id: String) -> EnhancementDefinition:
		return ContentRegistry.get_definition("enhancements", id)

	func test_economical_modifiers_apply_on_placement():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")
		var card = CardInstance.new(stall_def)
		card.apply_enhancement(_create_enhancement("economical"))

		var stall = BoardSystem.place_stall(stall_def, Vector2i(2, 1), card)
		assert_not_null(stall, "Stall should be placed")
		assert_eq(stall.enhancements.size(), 1, "Stall should have 1 enhancement")

		# economical: -1 value, -1 cost_to_guest (clamped to 0)
		var base_stall = StallInstance.new(stall_def)
		assert_eq(stall.get_value(), maxi(base_stall.get_value() - 1, 0),
			"Value should be decreased by 1 from economical")
		assert_eq(stall.get_cost_to_guest(), maxi(base_stall.get_cost_to_guest() - 1, 0),
			"Cost to guest should be decreased by 1 from economical (clamped to 0)")

	func test_enhancement_not_applied_without_card():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")
		var stall = BoardSystem.place_stall(stall_def, Vector2i(2, 1))
		assert_eq(stall.enhancements.size(), 0, "Stall without card should have no enhancements")


class TestEnhancementUpgradeMerge:
	extends "res://test/helpers/test_base.gd"

	func _create_enhancement(id: String) -> EnhancementDefinition:
		return ContentRegistry.get_definition("enhancements", id)

	func test_enhancements_merge_on_upgrade():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")

		# Place first card with economical
		var card1 = CardInstance.new(stall_def)
		card1.apply_enhancement(_create_enhancement("economical"))
		var stall = BoardSystem.deploy_stall(stall_def, Vector2i(2, 1), card1)
		assert_eq(stall.enhancements.size(), 1, "Stall should start with 1 enhancement")

		# Upgrade with second card that also has economical
		var card2 = CardInstance.new(stall_def)
		card2.apply_enhancement(_create_enhancement("economical"))
		var upgraded = BoardSystem.deploy_stall(stall_def, Vector2i(2, 1), card2)
		assert_eq(upgraded.enhancements.size(), 2,
			"Stall should have 2 enhancements after upgrade merge")
		assert_eq(upgraded.current_tier, 2, "Stall should be tier 2")

	func test_duplicate_enhancements_stack():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")

		# Place with economical
		var card1 = CardInstance.new(stall_def)
		card1.apply_enhancement(_create_enhancement("economical"))
		BoardSystem.deploy_stall(stall_def, Vector2i(2, 1), card1)

		# Upgrade with another economical
		var card2 = CardInstance.new(stall_def)
		card2.apply_enhancement(_create_enhancement("economical"))
		var upgraded = BoardSystem.deploy_stall(stall_def, Vector2i(2, 1), card2)
		assert_eq(upgraded.enhancements.size(), 2,
			"Should have 2 economical enhancements")
		# Both economicals apply -1 value each; compare to tier 2 base
		var base_t2 = StallInstance.new(stall_def)
		base_t2.upgrade()
		assert_eq(upgraded.get_value(), maxi(base_t2.get_value() - 2, 0),
			"Two economical should subtract -2 value total (clamped to 0)")

	func test_upgrade_without_card_has_no_enhancements():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")
		BoardSystem.deploy_stall(stall_def, Vector2i(2, 1))
		var upgraded = BoardSystem.deploy_stall(stall_def, Vector2i(2, 1))
		assert_eq(upgraded.enhancements.size(), 0,
			"Upgrade without card should not add enhancements")

	func test_upgrade_preserves_original_enhancements():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")

		# Place with economical
		var card1 = CardInstance.new(stall_def)
		card1.apply_enhancement(_create_enhancement("economical"))
		BoardSystem.deploy_stall(stall_def, Vector2i(2, 1), card1)

		# Upgrade with no enhancements on second card
		var card2 = CardInstance.new(stall_def)
		var upgraded = BoardSystem.deploy_stall(stall_def, Vector2i(2, 1), card2)
		assert_eq(upgraded.enhancements.size(), 1,
			"Original enhancement should be preserved after upgrade")


class TestEnhancementStatClamping:
	extends "res://test/helpers/test_base.gd"

	func test_stat_clamps_to_zero():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")
		var stall = StallInstance.new(stall_def)

		var modifier = StatModifier.new("value", StatModifier.Operation.ADD, -999, null)
		stall.modifier_stack.add_modifier(modifier)
		assert_eq(stall.get_value(), 0, "Value should clamp to 0, not go negative")

	func test_all_stats_clamp_to_zero():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")
		var stall = StallInstance.new(stall_def)

		for stat_name in ["value", "cost_to_guest", "capacity", "service_duration", "restock_amount", "restock_duration"]:
			var modifier = StatModifier.new(stat_name, StatModifier.Operation.ADD, -999, stall)
			stall.modifier_stack.add_modifier(modifier)

		assert_eq(stall.get_value(), 0, "value should clamp to 0")
		assert_eq(stall.get_cost_to_guest(), 0, "cost_to_guest should clamp to 0")
		assert_eq(stall.get_capacity(), 0, "capacity should clamp to 0")
		assert_eq(stall.get_service_duration(), 0, "service_duration should clamp to 0")
		assert_eq(stall.get_restock_amount(), 0, "restock_amount should clamp to 0")
		assert_eq(stall.get_restock_duration(), 0, "restock_duration should clamp to 0")


class TestCardInstanceEnhancement:
	extends "res://test/helpers/test_base.gd"

	func _create_enhancement(id: String) -> EnhancementDefinition:
		return ContentRegistry.get_definition("enhancements", id)

	func test_apply_enhancement_to_stall_card():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")
		var card = CardInstance.new(stall_def)
		var result = card.apply_enhancement(_create_enhancement("economical"))
		assert_true(result, "Should successfully apply enhancement to stall card")
		assert_eq(card.enhancements.size(), 1)

	func test_reject_enhancement_on_non_stall():
		var spell_def = ContentRegistry.get_definition("spells", "instant_restock")
		if not spell_def:
			pass_test("No spell definition available for test")
			return
		var card = CardInstance.new(spell_def)
		var result = card.apply_enhancement(_create_enhancement("economical"))
		assert_false(result, "Should reject enhancement on non-stall card")

	func test_reject_enhancement_over_limit():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")
		var card = CardInstance.new(stall_def)
		card.apply_enhancement(_create_enhancement("economical"))
		var result = card.apply_enhancement(_create_enhancement("healthy"))
		assert_false(result, "Should reject second enhancement (limit = 1)")
		assert_eq(card.enhancements.size(), 1)

	func test_operation_model_filter():
		# economical is product-only; stone_stacking is a service stall
		var service_def = ContentRegistry.get_definition("stalls", "stone_stacking")
		var card = CardInstance.new(service_def)
		var result = card.apply_enhancement(_create_enhancement("economical"))
		assert_false(result, "economical (product-only) should be rejected on service stall")

	func test_healthy_applies_to_any_operation_model():
		# healthy has empty operation_models = applies to all
		var service_def = ContentRegistry.get_definition("stalls", "stone_stacking")
		var card = CardInstance.new(service_def)
		var result = card.apply_enhancement(_create_enhancement("healthy"))
		assert_true(result, "healthy (any model) should apply to service stall")

	func test_enhanced_stat_preview():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")
		var card = CardInstance.new(stall_def)
		card.apply_enhancement(_create_enhancement("economical"))

		var tier_data = stall_def.tiers[0]
		var preview_value = card.get_enhanced_stat_preview("value", tier_data.value)
		assert_eq(preview_value, tier_data.value - 1,
			"Preview should show -1 value from economical")

	func test_serialization_round_trip():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")
		var card = CardInstance.new(stall_def)
		card.apply_enhancement(_create_enhancement("economical"))

		var ids = card.get_enhancement_ids()
		assert_eq(ids, ["economical"] as Array[String])

		var card2 = CardInstance.new(stall_def)
		card2.load_enhancements_from_ids(ids)
		assert_eq(card2.enhancements.size(), 1)
		assert_eq(card2.enhancements[0].id, "economical")


class TestHealthyEnhancement:
	extends "res://test/helpers/test_base.gd"

	func _create_enhanced_stall(stall_id: String) -> StallInstance:
		var stall = create_stall(stall_id)
		var enhancement = ContentRegistry.get_definition("enhancements", "healthy")
		stall.enhancements = [enhancement]
		stall.apply_enhancements([enhancement])
		return stall

	func test_healthy_adds_cost_modifier():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")
		var base_stall = StallInstance.new(stall_def)
		var enhanced_stall = _create_enhanced_stall("warm_water")

		assert_eq(enhanced_stall.get_cost_to_guest(), base_stall.get_cost_to_guest() + 1,
			"Healthy should add +1 cost_to_guest")

	func test_healthy_removes_one_debuff_on_serve():
		var guest = create_guest("hungry_ghost")
		var stall = _create_enhanced_stall("warm_water")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		BoardSystem.inflict_status(guest, "charmed", 1)
		BoardSystem.inflict_status(guest, "spooked", 1)
		assert_eq(guest.status_effects.size(), 2, "Guest should have 2 debuffs before serve")

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_eq(guest.status_effects.size(), 1,
			"Healthy should remove exactly 1 debuff, not all")

	func test_healthy_does_not_remove_buffs():
		var guest = create_guest("hungry_ghost")
		var stall = _create_enhanced_stall("warm_water")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		BoardSystem.inflict_status(guest, "well_rested", 1)
		BoardSystem.inflict_status(guest, "charmed", 1)

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_true(guest.has_status("well_rested"),
			"Healthy should not remove buff statuses")
		assert_false(guest.has_status("charmed"),
			"Healthy should remove the debuff")

	func test_healthy_no_debuffs_does_not_error():
		var guest = create_guest("hungry_ghost")
		var stall = _create_enhanced_stall("warm_water")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_true(true, "Cleanse with no debuffs should not error")
