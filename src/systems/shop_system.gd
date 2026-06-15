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
const NUM_STALL_OFFERINGS: int = 3
const PRICE_OFFSETS: Array[int] = [-2, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
const REMOVE_CARD_COST: int = 2
const PRE_ENHANCED_CHANCE: float = 0.05

var _hero_id: String
var _stall_pool: Array[CardDefinition]
var _spell_pool: Array[CardDefinition]
var _relic_pool: Array[CardDefinition]
var _shopable_enhancements: Array[EnhancementDefinition]
var _enhancement_defs: Array[EnhancementDefinition]  # Full list for pre-enhanced rolls
var _reroll_count: int = 0
var _offerings: Array  # ShopOffering per slot, null = empty
var _sold_indices: Array[int] = []
var _card_removed: bool = false
var _pending_slot: int = -1  # Slot index in pending state during enhancement purchase


func setup(hero_id: String) -> void:
	_hero_id = hero_id
	_reroll_count = 0
	_build_pool(hero_id)
	_generate_offerings()


func get_offerings() -> Array:
	return _offerings


func get_offering(slot_index: int) -> ShopOffering:
	if slot_index < 0 or slot_index >= _offerings.size():
		return null
	return _offerings[slot_index]


func purchase_card(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _offerings.size():
		return false
	if is_slot_sold(slot_index) or is_slot_pending(slot_index):
		return false

	var offering: ShopOffering = _offerings[slot_index]
	if offering == null or offering.is_enhancement():
		return false

	var price: int = offering.get_price()
	if not GameManager.spend_tokens(price):
		return false

	offering.card.location = CardInstance.Location.DECK
	GameManager.current_run.deck.append(offering.card)
	_sold_indices.append(slot_index)
	EventBus.card_purchased.emit(offering.card)
	return true


func is_slot_sold(slot_index: int) -> bool:
	return slot_index in _sold_indices


func is_slot_pending(slot_index: int) -> bool:
	return _pending_slot == slot_index


func begin_enhancement_purchase(slot_index: int) -> EnhancementDefinition:
	if slot_index < 0 or slot_index >= _offerings.size():
		return null
	if is_slot_sold(slot_index) or _pending_slot >= 0:
		return null

	var offering: ShopOffering = _offerings[slot_index]
	if offering == null or not offering.is_enhancement():
		return null
	if GameManager.tokens < offering.get_price():
		return null

	_pending_slot = slot_index
	return offering.enhancement


func complete_enhancement_purchase(card: CardInstance) -> bool:
	if _pending_slot < 0:
		return false

	var offering: ShopOffering = _offerings[_pending_slot]
	if offering == null or not offering.is_enhancement():
		cancel_enhancement_purchase()
		return false

	if not card.apply_enhancement(offering.enhancement):
		cancel_enhancement_purchase()
		return false

	if not GameManager.spend_tokens(offering.get_price()):
		# Undo the enhancement we just applied
		card.enhancements.pop_back()
		cancel_enhancement_purchase()
		return false

	_sold_indices.append(_pending_slot)
	_pending_slot = -1
	return true


func cancel_enhancement_purchase() -> void:
	_pending_slot = -1


func get_eligible_cards(enhancement: EnhancementDefinition) -> Array[CardInstance]:
	var eligible: Array[CardInstance] = []
	for card in GameManager.current_run.deck:
		if card.get_card_type() != "stall":
			continue
		if card.enhancements.size() >= card.get_enhancement_limit():
			continue
		var stall_def := card.definition as StallDefinition
		var allowed_models: Array = enhancement.applicable_to.get("operation_models", [])
		if not allowed_models.is_empty() and stall_def.operation_model not in allowed_models:
			continue
		eligible.append(card)
	return eligible


func reroll() -> bool:
	var cost := get_reroll_cost()
	if not GameManager.spend_tokens(cost):
		return false

	_reroll_count += 1
	_generate_offerings()
	return true


func get_reroll_cost() -> int:
	return REROLL_BASE_COST * int(pow(REROLL_COST_MULTIPLIER, _reroll_count))


func can_afford_reroll() -> bool:
	return GameManager.tokens >= get_reroll_cost()


func can_afford_offering(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _offerings.size():
		return false
	if is_slot_sold(slot_index):
		return false
	var offering: ShopOffering = _offerings[slot_index]
	if offering == null:
		return false
	return GameManager.tokens >= offering.get_price()


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
	for i in _offerings.size():
		if _offerings[i] != null and not is_slot_sold(i):
			return true
	return false


func _build_pool(hero_id: String) -> void:
	_stall_pool = []
	_spell_pool = []
	_relic_pool = []
	_shopable_enhancements = []
	_enhancement_defs = []
	for type in ["stalls", "spells", "relics"]:
		for def in ContentRegistry.get_all_of_type(type):
			if not def.shopable:
				continue
			if def.hero_id == hero_id or def.hero_id == "":
				var card_def := def as CardDefinition
				match card_def.card_type:
					"stall": _stall_pool.append(card_def)
					"spell": _spell_pool.append(card_def)
					"relic": _relic_pool.append(card_def)

	for def in ContentRegistry.get_all_of_type("enhancements"):
		var enh_def := def as EnhancementDefinition
		if enh_def.hero_id != hero_id and enh_def.hero_id != "":
			continue
		_enhancement_defs.append(enh_def)
		if enh_def.shopable:
			_shopable_enhancements.append(enh_def)


func _generate_offerings() -> void:
	_sold_indices.clear()
	_pending_slot = -1
	_offerings = []

	# Pick stall offerings (guaranteed at least 1 food + 1 joy)
	var stall_defs: Array = WeightedRandom.select_multiple(_stall_pool, NUM_STALL_OFFERINGS, RARITY_WEIGHTS)
	stall_defs = _ensure_need_coverage(stall_defs)
	for def in stall_defs:
		var card := CardInstance.new(def)
		card.location = CardInstance.Location.SHOP
		card.price_offset = PRICE_OFFSETS.pick_random()
		_try_pre_enhance(card)
		_offerings.append(ShopOffering.from_card(card, card.price_offset))
	# Fill remaining stall slots with null if pool was too small
	while _offerings.size() < NUM_STALL_OFFERINGS:
		_offerings.append(null)

	# Pick extra offering: choose type first (equal weight), then item by rarity
	var extra_pools: Array = []
	if not _spell_pool.is_empty():
		extra_pools.append(_spell_pool)
	if not _relic_pool.is_empty():
		extra_pools.append(_relic_pool)
	if not _shopable_enhancements.is_empty():
		extra_pools.append(_shopable_enhancements)

	if not extra_pools.is_empty():
		var chosen_pool: Array = extra_pools[randi() % extra_pools.size()]
		var selected = WeightedRandom.select_by_rarity(chosen_pool, RARITY_WEIGHTS)
		if selected:
			if selected is EnhancementDefinition:
				_offerings.append(ShopOffering.from_enhancement(selected))
			else:
				var card := CardInstance.new(selected)
				card.location = CardInstance.Location.SHOP
				card.price_offset = PRICE_OFFSETS.pick_random()
				_offerings.append(ShopOffering.from_card(card, card.price_offset))


func _try_pre_enhance(card: CardInstance) -> void:
	if randf() > PRE_ENHANCED_CHANCE:
		return
	if _enhancement_defs.is_empty():
		return

	var stall_def := card.definition as StallDefinition
	if not stall_def:
		return

	var compatible: Array[EnhancementDefinition] = []
	for enh in _enhancement_defs:
		var allowed: Array = enh.applicable_to.get("operation_models", [])
		if allowed.is_empty() or stall_def.operation_model in allowed:
			compatible.append(enh)

	if not compatible.is_empty():
		card.apply_enhancement(compatible.pick_random())


func _ensure_need_coverage(selected: Array) -> Array:
	if _covers_need(selected, "food") and _covers_need(selected, "joy"):
		return selected

	var result := selected.duplicate()
	var used := {}
	for def in result:
		used[def] = true

	for needed_type in ["food", "joy"]:
		if _covers_need(result, needed_type):
			continue

		# Find a replacement that covers the missing need type
		var candidates := _stall_pool.filter(func(d: CardDefinition) -> bool:
			if used.has(d):
				return false
			var st := d as StallDefinition
			return st.need_type == needed_type or st.need_type == "any"
		)
		if candidates.is_empty():
			continue

		var replacement = WeightedRandom.select_by_rarity(candidates, RARITY_WEIGHTS)
		if not replacement:
			continue

		# Swap out a stall that doesn't serve the OTHER required type
		var other_type := "joy" if needed_type == "food" else "food"
		var swap_idx := -1
		for i in result.size():
			var st := result[i] as StallDefinition
			if st.need_type != other_type and st.need_type != "any":
				swap_idx = i
				break
		if swap_idx < 0:
			swap_idx = result.size() - 1

		used.erase(result[swap_idx])
		result[swap_idx] = replacement
		used[replacement] = true

	return result


func _covers_need(defs: Array, need: String) -> bool:
	for def in defs:
		var st := def as StallDefinition
		if st.need_type == need or st.need_type == "any":
			return true
	return false
