extends Node

## Manages level transitions and run flow.

var _interlude_screen_scene: PackedScene = preload("res://src/ui/screens/interlude/interlude_screen.tscn")
var _game_over_screen_scene: PackedScene = preload("res://src/ui/screens/game_over/game_over_screen.tscn")
var _victory_screen_scene: PackedScene = preload("res://src/ui/screens/victory/victory_screen.tscn")
var _game_scene_path: String = "res://scenes/game.tscn"

var _pending_level_id: String = ""
var _pending_guest_preview: Array = []
var _pending_guest_group_index: int = -1


func _ready() -> void:
	EventBus.level_won.connect(_on_level_won)
	EventBus.level_lost.connect(_on_level_lost)


func start_new_run(hero_id: String = "angry_bull", run_id: String = "standard_run") -> void:
	## Initialize a new run and show the interlude for the first level.
	GameManager.start_run(hero_id, run_id)

	_pending_level_id = GameManager.current_run.get_current_level_id()
	var level_def = ContentRegistry.get_definition("levels", _pending_level_id)
	if level_def:
		_pending_guest_preview = _generate_guest_preview(level_def)
	else:
		_pending_guest_preview = []

	print("LevelFlowManager: Starting run, first level: %s" % _pending_level_id)
	_show_interlude()


func _on_level_won() -> void:
	print("LevelFlowManager: Level won!")

	if not GameManager.current_run:
		push_error("No current run!")
		return

	var run = GameManager.current_run

	# Reset temporary state on persistent deck cards for next level
	for card in run.deck:
		if card.location != CardInstance.Location.REMOVED:
			card.location = CardInstance.Location.DECK
		card.clear_temporary_state()

	# Check for victory (final boss defeated)
	if run.is_final_boss():
		print("LevelFlowManager: Final boss defeated - VICTORY!")
		EventBus.run_won.emit()
		_show_victory_screen()
		return

	# Advance to next level
	run.advance_to_next_level()
	_pending_level_id = run.get_current_level_id()

	# Get preview of next level's guests
	var next_level = ContentRegistry.get_definition("levels", _pending_level_id)
	if next_level:
		_pending_guest_preview = _generate_guest_preview(next_level)
	else:
		_pending_guest_preview = []

	print("LevelFlowManager: Showing interlude, next level: %s" % _pending_level_id)
	_show_interlude()


func _on_level_lost() -> void:
	print("LevelFlowManager: Level lost - GAME OVER")
	EventBus.run_lost.emit()
	_show_game_over_screen()


func _show_interlude() -> void:
	var interlude = _interlude_screen_scene.instantiate()
	var hero_id: String = GameManager.current_run.hero.id if GameManager.current_run else ""
	interlude.setup(_pending_level_id, _pending_guest_preview, GameManager.current_run.deck, hero_id)
	interlude.continue_pressed.connect(_on_interlude_continue)
	get_tree().root.add_child(interlude)

	# Remove game scene
	var game_scene = get_tree().current_scene
	if game_scene:
		game_scene.queue_free()
	get_tree().current_scene = interlude


func _show_game_over_screen() -> void:
	get_tree().change_scene_to_packed(_game_over_screen_scene)


func _show_victory_screen() -> void:
	get_tree().change_scene_to_packed(_victory_screen_scene)


func _on_interlude_continue() -> void:
	print("LevelFlowManager: Loading next level")
	get_tree().change_scene_to_file(_game_scene_path)


func _generate_guest_preview(level_def: LevelDefinition) -> Array:
	## Generate preview by selecting a guest group and resolving its guests.
	var preview: Array = []

	if level_def.guest_groups.is_empty():
		return preview

	# Select a group using weights
	var weights := {}
	for i in level_def.guest_groups.size():
		weights[str(i)] = level_def.guest_groups[i].get("weight", 1)

	var selected_key := WeightedRandom.select(weights)
	_pending_guest_group_index = int(selected_key)
	var group: Dictionary = level_def.guest_groups[_pending_guest_group_index]

	for guest_id in group.get("guests", []):
		var guest_def = ContentRegistry.get_definition("guests", guest_id)
		if guest_def:
			preview.append({
				"id": guest_def.id,
				"name": guest_def.display_name_key,
				"needs": guest_def.base_needs.duplicate(),
			})

	# Add boss if present
	if level_def.boss_guest != "":
		var boss_def = ContentRegistry.get_definition("guests", level_def.boss_guest)
		if boss_def:
			preview.append({
				"id": boss_def.id,
				"name": boss_def.display_name_key,
				"needs": boss_def.base_needs.duplicate(),
				"is_boss": true,
			})

	return preview
