class_name ShopPoolDefinition extends BaseDefinition

var rarity_weights: Dictionary  # { common: 60, rare: 30, epic: 8, legendary: 2 }
var enhancement_chance: float
var cards: Array[Dictionary]  # [{ card_id, rarity, hero_id }]


static func from_dict(data: Dictionary) -> ShopPoolDefinition:
	var def = ShopPoolDefinition.new()
	def._populate_from_dict(data)

	def.rarity_weights = data.get("rarity_weights", {})
	def.enhancement_chance = data.get("enhancement_chance", 0.0)

	var cards_arr: Array[Dictionary] = []
	for card in data.get("cards", []):
		cards_arr.append(card)
	def.cards = cards_arr

	return def
