class_name ShopSystem
extends RefCounted

## Ephemeral shop logic for a single interlude visit.
## Created by interlude screen, garbage collected when it closes.

const RARITY_WEIGHTS: Dictionary = {
	"common": 60,
	"rare": 30,
	"epic": 8,
	"legendary": 2,
}
const REROLL_BASE_COST: int = 1
const REROLL_COST_MULTIPLIER: int = 2
const NUM_OFFERINGS: int = 3
const PRICE_OFFSETS: Array[int] = [-2, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
const REMOVE_CARD_COST: int = 2

var _hero_id: String
var _pool: Array[CardDefinition]
var _reroll_count: int = 0
var _offerings: Array  # CardInstance per slot, null = purchased/empty
var _card_removed: bool = false


func setup(hero_id: String) -> void:
	_hero_id = hero_id
	_reroll_count = 0
	_pool = _build_pool(hero_id)
	_generate_offerings()


func get_offerings() -> Array:
	return _offerings


func purchase_card(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _offerings.size():
		return false

	var card: CardInstance = _offerings[slot_index]
	if card == null:
		return false

	var price: int = card.get_effective_price()
	if not GameManager.spend_tokens(price):
		return false

	card.location = CardInstance.Location.DECK
	GameManager.current_run.deck.append(card)
	_offerings[slot_index] = null
	EventBus.card_purchased.emit(card)
	return true


func reroll() -> bool:
	var cost := get_reroll_cost()
	if not GameManager.spend_tokens(cost):
		return false

	_reroll_count += 1

	# Collect definitions of cards still on offer (to exclude from new rolls)
	var kept_defs: Array[CardDefinition] = []
	for i in _offerings.size():
		if _offerings[i] != null:
			kept_defs.append(_offerings[i].definition)

	# Build available pool excluding kept cards
	var available: Array = []
	for def in _pool:
		if def not in kept_defs:
			available.append(def)

	# Re-roll only non-null (non-purchased) slots
	for i in _offerings.size():
		if _offerings[i] != null:
			if available.is_empty():
				_offerings[i] = null
			else:
				var selected = WeightedRandom.select_by_rarity(available, RARITY_WEIGHTS)
				if selected:
					_offerings[i] = CardInstance.new(selected)
					_offerings[i].location = CardInstance.Location.SHOP
					_offerings[i].price_offset = PRICE_OFFSETS.pick_random()
					available.erase(selected)
				else:
					_offerings[i] = null

	return true


func get_reroll_cost() -> int:
	return REROLL_BASE_COST * int(pow(REROLL_COST_MULTIPLIER, _reroll_count))


func can_afford_reroll() -> bool:
	return GameManager.tokens >= get_reroll_cost()


func can_afford_card(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _offerings.size():
		return false
	var card: CardInstance = _offerings[slot_index]
	if card == null:
		return false
	return GameManager.tokens >= card.get_effective_price()


func can_remove_card() -> bool:
	return not _card_removed and GameManager.tokens >= REMOVE_CARD_COST


func remove_card(card: CardInstance) -> bool:
	if _card_removed:
		return false
	if not GameManager.spend_tokens(REMOVE_CARD_COST):
		return false
	GameManager.current_run.deck.erase(card)
	card.location = CardInstance.Location.REMOVED
	_card_removed = true
	return true


func has_removed_card() -> bool:
	return _card_removed


func has_offerings() -> bool:
	for offering in _offerings:
		if offering != null:
			return true
	return false


func _build_pool(hero_id: String) -> Array[CardDefinition]:
	var pool: Array[CardDefinition] = []
	for type in ["stalls", "spells", "relics"]:
		for def in ContentRegistry.get_all_of_type(type):
			if not def.shopable:
				continue
			if def.hero_id == hero_id or def.hero_id == "":
				pool.append(def as CardDefinition)
	return pool


func _generate_offerings() -> void:
	var selected_defs: Array = WeightedRandom.select_multiple(_pool, NUM_OFFERINGS, RARITY_WEIGHTS)
	_offerings = []
	for def in selected_defs:
		var card := CardInstance.new(def)
		card.location = CardInstance.Location.SHOP
		card.price_offset = PRICE_OFFSETS.pick_random()
		_offerings.append(card)
	# Fill remaining slots with null if pool was too small
	while _offerings.size() < NUM_OFFERINGS:
		_offerings.append(null)
