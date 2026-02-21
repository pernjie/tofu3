class_name DeckSystem
extends Node

## Manages the player's deck and hand.
## Hearthstone-style: draw opening hand, draw 1/turn, no reshuffle,
## cards persist in hand, 1 card play per turn.

const DEFAULT_OPENING_HAND_SIZE: int = 4
const DRAW_PER_TURN: int = 1

var opening_hand_size: int = DEFAULT_OPENING_HAND_SIZE
const MAX_HAND_SIZE: int = 10

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []

## Tracks how many cards have been played this turn.
var cards_played_this_turn: int = 0

## Maximum cards allowed per turn (can be modified by skills).
var max_plays_per_turn: int = 1


func setup_deck(starting_deck: Array) -> void:
	## Initialize deck from hero's starting deck definition.
	## starting_deck: Array of {card_id: String, count: int}
	draw_pile.clear()
	hand.clear()
	for entry in starting_deck:
		var card_id: String = entry.get("card_id", "")
		var count: int = entry.get("count", 1)

		var card_def = ContentRegistry.get_definition("stalls", card_id)
		if not card_def:
			card_def = ContentRegistry.get_definition("spells", card_id)
		if not card_def:
			card_def = ContentRegistry.get_definition("relics", card_id)

		if card_def:
			for i in count:
				var instance = CardInstance.new(card_def)
				instance.location = CardInstance.Location.DECK
				draw_pile.append(instance)
		else:
			push_warning("DeckSystem: Card not found: " + card_id)

	_shuffle_draw_pile()
	draw_cards(opening_hand_size)
	print("DeckSystem: Deck initialized with %d cards (%d in hand)" % [draw_pile.size() + hand.size(), hand.size()])


func setup_from_instances(cards: Array[CardInstance]) -> void:
	## Initialize deck from existing CardInstance objects (for persistent deck).
	## Skips removed cards (e.g. played relics, spent spells).
	draw_pile.clear()
	hand.clear()

	for card in cards:
		if card.location == CardInstance.Location.REMOVED:
			continue
		card.location = CardInstance.Location.DECK
		draw_pile.append(card)

	_shuffle_draw_pile()
	draw_cards(opening_hand_size)
	print("DeckSystem: Deck initialized from %d persistent cards (%d in hand)" % [draw_pile.size() + hand.size(), hand.size()])


func draw_cards(count: int = DRAW_PER_TURN) -> void:
	## Draw cards from draw pile to hand.
	for i in count:
		if hand.size() >= MAX_HAND_SIZE:
			break
		if draw_pile.is_empty():
			break

		var card = draw_pile.pop_back()
		card.location = CardInstance.Location.HAND
		hand.append(card)
		EventBus.card_drawn.emit(card)


func can_play_card(card: CardInstance) -> bool:
	## Check if a card can be played this turn (play limit not reached).
	if card not in hand:
		return false
	return cards_played_this_turn < max_plays_per_turn


func play_card(card: CardInstance, target_pos: Vector2i) -> bool:
	## Play a card from hand to the given target position.
	## Returns true if successful.
	if not can_play_card(card):
		return false

	hand.erase(card)

	var card_type: String = card.get_card_type()
	if card_type == "spell" or card_type == "relic":
		card.location = CardInstance.Location.REMOVED
	else:
		card.location = CardInstance.Location.PLAYED

	cards_played_this_turn += 1

	EventBus.card_played.emit(card)
	return true


func start_turn() -> void:
	## Called at the start of each turn: draw a card and reset play limit.
	cards_played_this_turn = 0
	max_plays_per_turn = 1
	draw_cards(DRAW_PER_TURN)


func get_playable_types() -> Array[String]:
	## Returns card types that can still be played this turn.
	if cards_played_this_turn >= max_plays_per_turn:
		return []
	return ["stall", "spell", "relic"]


func _shuffle_draw_pile() -> void:
	draw_pile.shuffle()


func get_hand_size() -> int:
	return hand.size()


func get_draw_pile_size() -> int:
	return draw_pile.size()


func get_all_cards() -> Array[CardInstance]:
	## Returns all cards across draw_pile and hand.
	var all_cards: Array[CardInstance] = []
	all_cards.append_array(draw_pile)
	all_cards.append_array(hand)
	return all_cards
