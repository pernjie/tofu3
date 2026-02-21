extends Node

## Global game state manager.
## Tracks current run state including hero, tokens, reputation.

var current_hero: HeroDefinition
var tokens: int = 0
var reputation: int = 0
var current_level_number: int = 0

# Run state
var current_run: RunState = null

# Run statistics (for end screens)
var run_stats: Dictionary = {
	"guests_ascended": 0,
	"guests_descended": 0,
	"levels_completed": 0
}


class RunState:
	var run_definition: RunDefinition
	var hero: HeroDefinition
	var current_act: int = 1
	var current_level_index: int = 0
	var is_boss_level: bool = false
	var deck: Array[CardInstance] = []
	var relics_on_board: Dictionary = {}  # Vector2i -> { "definition": RelicDefinition, "persistent_state": Dictionary }

	func _init(run_def: RunDefinition, hero_def: HeroDefinition) -> void:
		run_definition = run_def
		hero = hero_def
		current_act = 1
		current_level_index = 0
		is_boss_level = false

	func get_current_level_id() -> String:
		return run_definition.get_level_id(current_act, current_level_index, is_boss_level)

	func advance_to_next_level() -> void:
		## Move to the next level in the run.
		if is_boss_level:
			# Move to next act
			current_act += 1
			current_level_index = 0
			is_boss_level = false
		else:
			current_level_index += 1
			var levels_in_act = run_definition.get_levels_in_act(current_act)
			if current_level_index >= levels_in_act:
				# Completed all regular levels, boss is next
				is_boss_level = true

	func is_final_boss() -> bool:
		return is_boss_level and current_act >= run_definition.get_total_acts()


func start_run(hero_id: String, run_id: String = "standard_run") -> void:
	## Initialize a new run with the given hero.
	current_hero = ContentRegistry.get_definition("heroes", hero_id)
	if not current_hero:
		push_error("Hero not found: " + hero_id)
		return

	var run_def = ContentRegistry.get_definition("runs", run_id)
	if not run_def:
		push_error("Run not found: " + run_id)
		return

	current_run = RunState.new(run_def, current_hero)

	tokens = current_hero.starting_stats.get("tokens", 100)
	reputation = current_hero.starting_stats.get("reputation", 10)
	current_level_number = 1

	# Reset stats
	run_stats = {
		"guests_ascended": 0,
		"guests_descended": 0,
		"levels_completed": 0
	}

	print("GameManager: Started run with hero '%s' (Tokens: %d, Reputation: %d)" % [hero_id, tokens, reputation])

	# Initialize persistent deck from hero's starting deck
	current_run.deck = []
	for entry in current_hero.starting_deck:
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
				current_run.deck.append(instance)
		else:
			push_warning("GameManager: Card not found for deck: " + card_id)

	print("GameManager: Initialized persistent deck with %d cards" % current_run.deck.size())


func add_tokens(amount: int) -> void:
	## Add tokens to the player.
	var old_val = tokens
	tokens += amount
	EventBus.tokens_changed.emit(old_val, tokens)


func spend_tokens(amount: int) -> bool:
	## Spend tokens. Returns true if player had enough.
	if tokens < amount:
		return false
	var old_val = tokens
	tokens -= amount
	EventBus.tokens_changed.emit(old_val, tokens)
	return true


func change_reputation(amount: int) -> void:
	## Change reputation by amount (can be negative).
	var old_val = reputation
	reputation += amount
	reputation = max(0, reputation)
	EventBus.reputation_changed.emit(old_val, reputation)

	if reputation <= 0:
		EventBus.level_lost.emit()


func is_game_over() -> bool:
	## Check if the game is over (reputation reached 0).
	return reputation <= 0


func record_guest_ascended() -> void:
	run_stats.guests_ascended += 1


func record_guest_descended() -> void:
	run_stats.guests_descended += 1


func record_level_completed() -> void:
	run_stats.levels_completed += 1
