class_name ShopOffering
extends RefCounted

## Lightweight wrapper for shop offerings — holds either a card or an enhancement.
## Allows the shop to hold both types without type lies.

var card: CardInstance          # Non-null for stall/spell/relic offerings
var enhancement: EnhancementDefinition  # Non-null for enhancement offerings
var price_offset: int = 0


static func from_card(card_instance: CardInstance, offset: int = 0) -> ShopOffering:
	var offering = ShopOffering.new()
	offering.card = card_instance
	offering.price_offset = offset
	return offering


static func from_enhancement(enhancement_def: EnhancementDefinition) -> ShopOffering:
	var offering = ShopOffering.new()
	offering.enhancement = enhancement_def
	return offering


func get_price() -> int:
	if card:
		return card.get_effective_price()
	if enhancement:
		return maxi(enhancement.get_price() + price_offset, 1)
	return 0


func is_enhancement() -> bool:
	return enhancement != null
