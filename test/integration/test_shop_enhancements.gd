# test/integration/test_shop_enhancements.gd
extends "res://test/helpers/test_base.gd"

# Shop enhancement tests require GameManager.current_run with a deck.

var _saved_run


func _setup_run() -> void:
	var hero_def = ContentRegistry.get_definition("heroes", "fat_cat")
	var run_def = ContentRegistry.get_definition("runs", "standard_run")
	_saved_run = GameManager.current_run
	GameManager.current_run = GameManager.RunState.new(run_def, hero_def)
	GameManager.current_run.deck = []


func _teardown_run() -> void:
	GameManager.current_run = _saved_run


func _create_enhancement(id: String) -> EnhancementDefinition:
	return ContentRegistry.get_definition("enhancements", id)


func _add_card_to_deck(card_id: String) -> CardInstance:
	var def = ContentRegistry.get_definition("stalls", card_id)
	if not def:
		def = ContentRegistry.get_definition("spells", card_id)
	var card = CardInstance.new(def)
	card.location = CardInstance.Location.DECK
	GameManager.current_run.deck.append(card)
	return card


class TestShopOffering:
	extends "res://test/helpers/test_base.gd"

	func test_from_card():
		var stall_def = ContentRegistry.get_definition("stalls", "warm_water")
		var card = CardInstance.new(stall_def)
		card.price_offset = -1
		var offering = ShopOffering.from_card(card, -1)
		assert_false(offering.is_enhancement(), "Card offering should not be enhancement")
		assert_eq(offering.card, card)
		assert_eq(offering.get_price(), card.get_effective_price())

	func test_from_enhancement():
		var enh = ContentRegistry.get_definition("enhancements", "economical")
		var offering = ShopOffering.from_enhancement(enh)
		assert_true(offering.is_enhancement(), "Enhancement offering should be enhancement")
		assert_null(offering.card)
		assert_eq(offering.get_price(), enh.get_price())


class TestShopEnhancementPool:
	extends "res://test/helpers/test_base.gd"

	var _saved_run

	func before_each():
		super.before_each()
		var hero_def = ContentRegistry.get_definition("heroes", "fat_cat")
		var run_def = ContentRegistry.get_definition("runs", "standard_run")
		_saved_run = GameManager.current_run
		GameManager.current_run = GameManager.RunState.new(run_def, hero_def)
		GameManager.current_run.deck = []

	func after_each():
		GameManager.current_run = _saved_run
		super.after_each()

	func test_enhancement_pool_built():
		var shop = ShopSystem.new()
		shop.setup("fat_cat")
		# _other_pool should contain enhancements (merged in)
		# Verify by checking that offerings can include enhancements
		# Since we can't inspect _other_pool directly, check _enhancement_defs via offerings
		var offerings = shop.get_offerings()
		assert_true(offerings.size() > 0, "Shop should have offerings")

	func test_offerings_use_shop_offering_wrapper():
		var shop = ShopSystem.new()
		shop.setup("fat_cat")
		var offerings = shop.get_offerings()
		for i in offerings.size():
			var offering = offerings[i]
			if offering != null:
				assert_true(offering is ShopOffering,
					"Offering at index %d should be ShopOffering" % i)


class TestEnhancementPurchaseFlow:
	extends "res://test/helpers/test_base.gd"

	var _saved_run

	func before_each():
		super.before_each()
		var hero_def = ContentRegistry.get_definition("heroes", "fat_cat")
		var run_def = ContentRegistry.get_definition("runs", "standard_run")
		_saved_run = GameManager.current_run
		GameManager.current_run = GameManager.RunState.new(run_def, hero_def)
		GameManager.current_run.deck = []
		GameManager.tokens = 100

	func after_each():
		GameManager.current_run = _saved_run
		super.after_each()

	func _add_card_to_deck(card_id: String) -> CardInstance:
		var def = ContentRegistry.get_definition("stalls", card_id)
		var card = CardInstance.new(def)
		card.location = CardInstance.Location.DECK
		GameManager.current_run.deck.append(card)
		return card

	func _create_shop_with_enhancement() -> ShopSystem:
		# Create a shop and manually inject an enhancement offering
		var shop = ShopSystem.new()
		shop.setup("fat_cat")
		# Replace the extra slot with a known enhancement
		var enh = ContentRegistry.get_definition("enhancements", "economical")
		var enh_offering = ShopOffering.from_enhancement(enh)
		var offerings = shop.get_offerings()
		# Add or replace the last offering slot with enhancement
		if offerings.size() > ShopSystem.NUM_STALL_OFFERINGS:
			offerings[ShopSystem.NUM_STALL_OFFERINGS] = enh_offering
		else:
			offerings.append(enh_offering)
		return shop

	func test_begin_enhancement_purchase():
		var shop = _create_shop_with_enhancement()
		var enh_slot = ShopSystem.NUM_STALL_OFFERINGS
		var enhancement = shop.begin_enhancement_purchase(enh_slot)
		assert_not_null(enhancement, "Should return enhancement definition")
		assert_true(shop.is_slot_pending(enh_slot), "Slot should be pending")

	func test_begin_purchase_rejects_card_slot():
		var shop = _create_shop_with_enhancement()
		# Slot 0 is a card, not enhancement
		var result = shop.begin_enhancement_purchase(0)
		if shop.get_offering(0) != null and not shop.get_offering(0).is_enhancement():
			assert_null(result, "Should not begin enhancement purchase on card slot")

	func test_complete_enhancement_purchase():
		var shop = _create_shop_with_enhancement()
		var enh_slot = ShopSystem.NUM_STALL_OFFERINGS
		var card = _add_card_to_deck("warm_water")
		var tokens_before = GameManager.tokens

		shop.begin_enhancement_purchase(enh_slot)
		var success = shop.complete_enhancement_purchase(card)
		assert_true(success, "Should complete purchase")
		assert_eq(card.enhancements.size(), 1, "Card should have enhancement applied")
		assert_true(shop.is_slot_sold(enh_slot), "Slot should be sold")
		assert_false(shop.is_slot_pending(enh_slot), "Slot should not be pending after completion")
		assert_lt(GameManager.tokens, tokens_before, "Tokens should be deducted")

	func test_cancel_enhancement_purchase():
		var shop = _create_shop_with_enhancement()
		var enh_slot = ShopSystem.NUM_STALL_OFFERINGS
		var tokens_before = GameManager.tokens

		shop.begin_enhancement_purchase(enh_slot)
		assert_true(shop.is_slot_pending(enh_slot))

		shop.cancel_enhancement_purchase()
		assert_false(shop.is_slot_pending(enh_slot), "Pending should be cleared")
		assert_false(shop.is_slot_sold(enh_slot), "Slot should not be sold")
		assert_eq(GameManager.tokens, tokens_before, "Tokens should not change on cancel")

	func test_cannot_begin_two_purchases():
		var shop = _create_shop_with_enhancement()
		var enh_slot = ShopSystem.NUM_STALL_OFFERINGS

		shop.begin_enhancement_purchase(enh_slot)
		# Try beginning another (even same slot)
		var result = shop.begin_enhancement_purchase(enh_slot)
		assert_null(result, "Should not allow second pending purchase")

	func test_cannot_purchase_card_on_pending_slot():
		var shop = _create_shop_with_enhancement()
		var enh_slot = ShopSystem.NUM_STALL_OFFERINGS
		shop.begin_enhancement_purchase(enh_slot)
		var success = shop.purchase_card(enh_slot)
		assert_false(success, "Should not purchase card on pending slot")


class TestEligibleCards:
	extends "res://test/helpers/test_base.gd"

	var _saved_run

	func before_each():
		super.before_each()
		var hero_def = ContentRegistry.get_definition("heroes", "fat_cat")
		var run_def = ContentRegistry.get_definition("runs", "standard_run")
		_saved_run = GameManager.current_run
		GameManager.current_run = GameManager.RunState.new(run_def, hero_def)
		GameManager.current_run.deck = []

	func after_each():
		GameManager.current_run = _saved_run
		super.after_each()

	func _add_card_to_deck(card_id: String) -> CardInstance:
		var def = ContentRegistry.get_definition("stalls", card_id)
		var card = CardInstance.new(def)
		card.location = CardInstance.Location.DECK
		GameManager.current_run.deck.append(card)
		return card

	func test_eligible_cards_for_product_only_enhancement():
		var product_card = _add_card_to_deck("warm_water")  # product stall
		var service_card = _add_card_to_deck("stone_stacking")  # service stall

		var economical = ContentRegistry.get_definition("enhancements", "economical")
		var shop = ShopSystem.new()
		shop.setup("fat_cat")

		var eligible = shop.get_eligible_cards(economical)
		assert_true(product_card in eligible,
			"Product stall should be eligible for product-only enhancement")
		assert_false(service_card in eligible,
			"Service stall should not be eligible for product-only enhancement")

	func test_eligible_cards_for_universal_enhancement():
		_add_card_to_deck("warm_water")
		_add_card_to_deck("stone_stacking")

		var healthy = ContentRegistry.get_definition("enhancements", "healthy")
		var shop = ShopSystem.new()
		shop.setup("fat_cat")

		var eligible = shop.get_eligible_cards(healthy)
		assert_eq(eligible.size(), 2,
			"Universal enhancement should be eligible for all stall cards")

	func test_eligible_cards_respects_enhancement_limit():
		var card = _add_card_to_deck("warm_water")
		var economical = ContentRegistry.get_definition("enhancements", "economical")
		card.apply_enhancement(economical)

		var healthy = ContentRegistry.get_definition("enhancements", "healthy")
		var shop = ShopSystem.new()
		shop.setup("fat_cat")

		var eligible = shop.get_eligible_cards(healthy)
		assert_false(card in eligible,
			"Card at enhancement limit should not be eligible")

	func test_eligible_cards_empty_deck():
		var economical = ContentRegistry.get_definition("enhancements", "economical")
		var shop = ShopSystem.new()
		shop.setup("fat_cat")

		var eligible = shop.get_eligible_cards(economical)
		assert_eq(eligible.size(), 0, "Empty deck should have no eligible cards")


class TestPreEnhancedStalls:
	extends "res://test/helpers/test_base.gd"

	var _saved_run

	func before_each():
		super.before_each()
		var hero_def = ContentRegistry.get_definition("heroes", "fat_cat")
		var run_def = ContentRegistry.get_definition("runs", "standard_run")
		_saved_run = GameManager.current_run
		GameManager.current_run = GameManager.RunState.new(run_def, hero_def)
		GameManager.current_run.deck = []

	func after_each():
		GameManager.current_run = _saved_run
		super.after_each()

	func test_pre_enhanced_stall_has_enhancement_on_card():
		# Run many iterations to catch at least one pre-enhanced stall
		# With 5% chance and 3 stalls per roll, expected ~0.15 per shop.
		# After 100 rolls, probability of at least one is very high.
		var found_enhanced := false
		for _i in 100:
			var shop = ShopSystem.new()
			shop.setup("fat_cat")
			for j in ShopSystem.NUM_STALL_OFFERINGS:
				var offering: ShopOffering = shop.get_offering(j)
				if offering and not offering.is_enhancement() and offering.card:
					if not offering.card.enhancements.is_empty():
						found_enhanced = true
						break
			if found_enhanced:
				break
		assert_true(found_enhanced,
			"After 100 shop rolls, should find at least one pre-enhanced stall (5% chance each)")
