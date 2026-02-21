class_name WeightedRandom
extends RefCounted

## Utility class for weighted random selection.
## Used for guest pools, shop offerings, and enhancement rolls.


## Select a key from a dictionary of weights.
## Example: {"common": 70, "rare": 25, "epic": 5} -> returns "common" 70% of the time
static func select(weights: Dictionary) -> String:
	var total_weight := 0.0
	for weight in weights.values():
		total_weight += weight

	if total_weight <= 0:
		return weights.keys()[0] if weights.size() > 0 else ""

	var roll := randf() * total_weight
	var cumulative := 0.0

	for key in weights:
		cumulative += weights[key]
		if roll <= cumulative:
			return key

	return weights.keys()[-1]


## Select an item from an array using rarity weights.
## Items must have a "rarity" field.
static func select_by_rarity(items: Array, rarity_weights: Dictionary) -> Variant:
	if items.is_empty():
		return null

	var selected_rarity = select(rarity_weights)
	var candidates = items.filter(func(item): return item.rarity == selected_rarity)

	# Fallback to lower rarities if none found
	if candidates.is_empty():
		var rarity_order = ["legendary", "epic", "rare", "common"]
		var start_idx = rarity_order.find(selected_rarity)

		for i in range(start_idx + 1, rarity_order.size()):
			candidates = items.filter(func(item): return item.rarity == rarity_order[i])
			if not candidates.is_empty():
				break

	if candidates.is_empty():
		candidates = items

	return candidates[randi() % candidates.size()]


## Select multiple unique items using rarity weights.
static func select_multiple(items: Array, count: int, rarity_weights: Dictionary) -> Array:
	var results := []
	var available = items.duplicate()

	for i in count:
		if available.is_empty():
			break

		var selected = select_by_rarity(available, rarity_weights)
		if selected:
			results.append(selected)
			available.erase(selected)

	return results


## Roll a chance (0.0 to 1.0). Returns true if roll succeeds.
static func roll_chance(chance: float) -> bool:
	return randf() < chance
