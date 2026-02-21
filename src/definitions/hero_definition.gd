class_name HeroDefinition extends BaseDefinition

var portrait_path: String
var starting_stats: Dictionary  # reputation, tokens
var opening_hand_size: int = 4
var starting_deck: Array[Dictionary]  # [{ card_id, count }]
var exclusive_cards: Array[String]
var passive_skills: Array[Dictionary]  # [{ skill_id, parameters }]
var unlock_condition: Dictionary
var progression: Dictionary  # levels array with xp_required and unlocks


static func from_dict(data: Dictionary) -> HeroDefinition:
	var def = HeroDefinition.new()
	def._populate_from_dict(data)

	def.portrait_path = data.get("portrait_path", "")
	def.starting_stats = data.get("starting_stats", {})
	def.opening_hand_size = data.get("opening_hand_size", 4)

	var deck_arr: Array[Dictionary] = []
	for entry in data.get("starting_deck", []):
		deck_arr.append(entry)
	def.starting_deck = deck_arr

	def.exclusive_cards = Array(data.get("exclusive_cards", []), TYPE_STRING, "", null)

	var passive_arr: Array[Dictionary] = []
	for entry in data.get("passive_skills", []):
		passive_arr.append(entry)
	def.passive_skills = passive_arr

	def.unlock_condition = data.get("unlock_condition", {})
	def.progression = data.get("progression", {})

	return def
