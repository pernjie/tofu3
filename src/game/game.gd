extends Node2D

## Main game scene - orchestrates gameplay.

const DiscoverOverlayScene = preload("res://src/ui/overlays/discover_overlay.tscn")

@onready var board_visual: BoardVisual = $BoardVisual
@onready var tokens_label: Label = $HUD/TopBar/TokensLabel
@onready var reputation_label: Label = $HUD/TopBar/ReputationLabel
@onready var turn_label: Label = $HUD/TopBar/TurnLabel
@onready var queue_label: Label = $HUD/TopBar/QueueLabel
@onready var phase_label: Label = $HUD/PhaseLabel
@onready var debug_panel: DebugInfoPanel = $HUD/DebugInfoPanel
@onready var hand_display: HandDisplay = $HandLayer/HandDisplay
@onready var end_turn_button: Button = $HandLayer/EndTurnButton
@onready var deck_system: DeckSystem = $DeckSystem
@onready var debug_console: DebugConsole = $HUD/DebugConsole

var selected_card: CardInstance = null
var _ui_blocking: bool = false  # True when a modal overlay is active


func _ready() -> void:
	_connect_signals()
	_start_game()


func _connect_signals() -> void:
	# EventBus connections
	EventBus.tokens_changed.connect(_on_tokens_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.card_drawn.connect(_on_card_drawn)
	EventBus.card_played.connect(_on_card_played)
	EventBus.guest_spawned.connect(_on_guest_spawned)
	EventBus.guest_moved.connect(_on_guest_moved)
	EventBus.guest_entered_stall.connect(_on_guest_entered_stall)
	EventBus.guest_exited_stall.connect(_on_guest_exited_stall)
	EventBus.guest_ascended.connect(_on_guest_ascended)
	EventBus.guest_descended.connect(_on_guest_descended)
	EventBus.guest_banished.connect(_on_guest_banished)
	EventBus.stall_restocked.connect(_on_stall_restocked)
	EventBus.guest_served.connect(_on_guest_served)
	EventBus.debug_show_guest.connect(_on_debug_show_guest)
	EventBus.debug_show_stall.connect(_on_debug_show_stall)
	EventBus.debug_show_relic.connect(_on_debug_show_relic)

	# UI connections
	board_visual.slot_clicked.connect(_on_slot_clicked)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	hand_display.card_clicked.connect(_on_card_clicked)


func _start_game() -> void:
	# Run should already be initialized by LevelFlowManager
	if not GameManager.current_run:
		push_warning("No current run — starting fallback run (game launched directly?)")
		GameManager.start_run("angry_bull", "standard_run")

	# Load level from current run state
	var level_id = GameManager.current_run.get_current_level_id()
	var level_def = ContentRegistry.get_definition("levels", level_id)
	if not level_def:
		push_error("Level not found: " + level_id)
		return

	# Generate guest queue from pool
	var guest_queue = _generate_guest_queue(level_def)

	# Setup board with generated queue (board comes from run definition)
	var board_data: Dictionary = {}
	if GameManager.current_run and GameManager.current_run.run_definition:
		board_data = GameManager.current_run.run_definition.board
	BoardSystem.setup_level(level_def, guest_queue, board_data)

	# Create StatusEffectSystem
	var status_effect_system = StatusEffectSystem.new()
	status_effect_system.name = "StatusEffectSystem"
	add_child(status_effect_system)

	# Create AuraSystem
	var aura_system = AuraSystem.new()
	aura_system.name = "AuraSystem"
	add_child(aura_system)

	# Wire up systems
	TurnSystem.set_board_system(BoardSystem)
	TurnSystem.set_board_visual(board_visual)
	TurnSystem.set_status_effect_system(status_effect_system)
	TurnSystem.set_trigger_system(TriggerSystem)
	BoardSystem.set_trigger_system(TriggerSystem)
	BoardSystem.set_status_effect_system(status_effect_system)
	BoardSystem.set_aura_system(aura_system)
	board_visual.set_aura_system(aura_system)
	aura_system.set_board_system(BoardSystem)
	aura_system.set_status_effect_system(status_effect_system)
	status_effect_system.set_trigger_system(TriggerSystem)
	status_effect_system.set_board_visual(board_visual)
	BoardSystem.set_deck_system(deck_system)

	# Setup board visual
	board_visual.setup(BoardSystem.board)
	BoardSystem.set_board_visual(board_visual)
	_center_board()

	# Setup deck
	deck_system.opening_hand_size = GameManager.current_hero.opening_hand_size
	deck_system.setup_from_instances(GameManager.current_run.deck)

	# Update UI
	_update_hud()

	# Start first turn
	TurnSystem.start_level()


func _center_board() -> void:
	## Center the board visual on screen.
	var viewport_size = get_viewport_rect().size

	# Calculate board bounds from all tiles and stall slots
	var min_pos := Vector2i(999999, 999999)
	var max_pos := Vector2i(-999999, -999999)

	# Include path tiles
	for tile in BoardSystem.board.tiles.values():
		min_pos.x = mini(min_pos.x, tile.position.x)
		min_pos.y = mini(min_pos.y, tile.position.y)
		max_pos.x = maxi(max_pos.x, tile.position.x)
		max_pos.y = maxi(max_pos.y, tile.position.y)

	# Include stall slots
	for slot_pos in BoardSystem.board.get_valid_stall_positions():
		min_pos.x = mini(min_pos.x, slot_pos.x)
		min_pos.y = mini(min_pos.y, slot_pos.y)
		max_pos.x = maxi(max_pos.x, slot_pos.x)
		max_pos.y = maxi(max_pos.y, slot_pos.y)

	# Calculate board dimensions in pixels
	var tile_size = board_visual.TILE_SIZE
	var board_width = (max_pos.x - min_pos.x + 1) * tile_size
	var board_height = (max_pos.y - min_pos.y + 1) * tile_size

	# Calculate offset to center the board
	var offset_x = (viewport_size.x - board_width) / 2 - min_pos.x * tile_size
	var offset_y = (viewport_size.y - board_height) / 2 - min_pos.y * tile_size

	board_visual.position = Vector2(offset_x, offset_y)


func _generate_guest_queue(level_def: LevelDefinition) -> Array:
	## Generate guest queue from the guest group selected at interlude.
	var queue: Array = []

	if level_def.guest_groups.is_empty():
		push_warning("No guest groups defined for level: " + level_def.id)
		return queue

	# Use the group selected by LevelFlowManager, or pick one if starting without interlude
	var group_index := LevelFlowManager._pending_guest_group_index
	if group_index < 0 or group_index >= level_def.guest_groups.size():
		var weights := {}
		for i in level_def.guest_groups.size():
			weights[str(i)] = level_def.guest_groups[i].get("weight", 1)
		group_index = int(WeightedRandom.select(weights))
	var group: Dictionary = level_def.guest_groups[group_index]

	# Resolve guest IDs to definitions
	for guest_id in group.get("guests", []):
		var guest_def = ContentRegistry.get_definition("guests", guest_id)
		if guest_def:
			queue.append(guest_def)
		else:
			push_warning("Guest not found in group '%s': %s" % [group.get("id", ""), guest_id])

	# Shuffle spawn order
	queue.shuffle()

	# Append boss as final guest (use pre-selected boss from interlude, or pick randomly)
	if not level_def.boss_guests.is_empty():
		var boss_id := LevelFlowManager._pending_boss_guest
		if boss_id == "":
			boss_id = level_def.boss_guests.pick_random()
		var boss_def = ContentRegistry.get_definition("guests", boss_id)
		if boss_def:
			queue.append(boss_def)
		else:
			push_warning("Boss guest not found: " + boss_id)

	return queue


func _update_hud() -> void:
	tokens_label.text = "Tokens: %d" % GameManager.tokens
	reputation_label.text = "Reputation: %d" % GameManager.reputation
	turn_label.text = "Turn: %d" % TurnSystem.current_turn
	queue_label.text = "Queue: %d" % BoardSystem.guest_queue.size()


func _refresh_hand_dimming() -> void:
	hand_display.refresh_all_dimming(deck_system.get_playable_types())


func _input(event: InputEvent) -> void:
	# Backtick toggles debug console
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:
			debug_console.toggle()
			get_viewport().set_input_as_handled()
			return

	# Press Space to end turn
	if event.is_action_pressed("ui_select"):  # Space by default
		var focus_owner = get_viewport().gui_get_focus_owner()
		if not (focus_owner is LineEdit or focus_owner is TextEdit):
			_on_end_turn_pressed()
			get_viewport().set_input_as_handled()
			return

	# Press Tab to toggle animation skip
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			AnimationCoordinator.skip_animations = not AnimationCoordinator.skip_animations
			print("Skip animations: %s" % AnimationCoordinator.skip_animations)
			get_viewport().set_input_as_handled()


func _is_input_blocked() -> bool:
	## Returns true when player input should be ignored (e.g., overlay is active).
	return _ui_blocking


func _on_card_clicked(card: CardInstance) -> void:
	if _is_input_blocked():
		return
	# Only allow card selection during player action phase
	if TurnSystem.current_phase != TurnSystem.Phase.PLAYER_ACTION:
		return

	# Check if card type can still be played this turn
	if not deck_system.can_play_card(card):
		return

	# Block targeted spells with no valid targets on the board
	var spell_check = card.definition as SpellDefinition
	if spell_check and spell_check.target_type != "none" and selected_card != card:
		if not _has_valid_spell_targets(spell_check):
			return

	# Deselect previous
	if selected_card:
		var prev_ui := hand_display.get_card_ui(selected_card)
		if prev_ui:
			prev_ui.set_selected(false)

	# Toggle selection
	if selected_card == card:
		selected_card = null
		board_visual.set_placement_mode(false)
	else:
		selected_card = card
		var card_ui := hand_display.get_card_ui(card)
		if card_ui:
			card_ui.set_selected(true)
		# Clear aura selection when entering card placement
		board_visual.clear_aura_selection()

		# Spells with target_type "none" cast immediately on selection
		var spell_def = card.definition as SpellDefinition
		if spell_def and spell_def.target_type == "none":
			await _cast_spell(spell_def, Vector2i.ZERO, null)
			return

		# Stalls, relics, and targeted spells use slot placement mode
		board_visual.set_placement_mode(true, card.definition)


func _on_slot_clicked(pos: Vector2i) -> void:
	if _is_input_blocked():
		return

	# If no card selected, handle aura selection toggle
	if not selected_card:
		_toggle_aura_selection(pos)
		return

	var spell_def = selected_card.definition as SpellDefinition
	if spell_def:
		var target_entity = _get_spell_target_entity(spell_def, pos)
		if _validate_spell_target(spell_def, pos, target_entity):
			await _cast_spell(spell_def, pos, target_entity)
		return

	var relic_def = selected_card.definition as RelicDefinition
	if relic_def:
		_place_relic(relic_def, pos)
		return

	var stall_def = selected_card.definition as StallDefinition
	if stall_def:
		_place_stall(stall_def, pos)


func _place_stall(stall_def: StallDefinition, pos: Vector2i) -> void:
	## Handle placing or upgrading a stall card on the board.
	var existing_stall = BoardSystem.get_stall_at(pos)

	if existing_stall:
		if existing_stall.definition.id != stall_def.id:
			return  # Different type - can't place
		if not existing_stall.can_upgrade():
			return  # Already at max tier
	else:
		if not BoardSystem.board.can_place_at(pos):
			return

	var stall = BoardSystem.deploy_stall(stall_def, pos)
	if stall:
		deck_system.play_card(selected_card, pos)

	_clear_card_selection()

	# Flush animations queued by aura status application/removal
	await AnimationCoordinator.play_batch()


func _place_relic(relic_def: RelicDefinition, pos: Vector2i) -> void:
	## Handle placing a relic card on the board.
	# Validate: no stall, no relic, valid position
	if BoardSystem.get_stall_at(pos):
		return
	if BoardSystem.get_relic_at(pos):
		return
	if not BoardSystem.board.can_place_at(pos):
		return

	var relic = BoardSystem.deploy_relic(relic_def, pos)
	if not relic:
		_clear_card_selection()
		return

	deck_system.play_card(selected_card, pos)

	# Remove from persistent deck (relic is permanent)
	if GameManager.current_run:
		for card in GameManager.current_run.deck:
			if card == selected_card:
				card.location = CardInstance.Location.REMOVED
				break

	_clear_card_selection()

	# Flush animations queued by aura status application/removal
	await AnimationCoordinator.play_batch()

	# Handle deferred requests (e.g., discover effects from on_place skills)
	if not TriggerSystem.pending_deferred_requests.is_empty():
		await _handle_deferred_requests(relic)

	# Persist relic to run state (after deferred requests resolve, so persistent_state is populated)
	_save_relic_to_run_state(relic, pos)

	# Mid-level catch-up: fire on_level_start for this relic since it missed the level's start
	_fire_level_start_for_relic(relic)


func _handle_deferred_requests(relic: RelicInstance) -> void:
	## Process pending deferred requests from skill effects.
	_ui_blocking = true
	for request in TriggerSystem.pending_deferred_requests:
		if request.get("type") == "discover":
			await _handle_discover_request(request, relic)
	TriggerSystem.pending_deferred_requests.clear()
	_ui_blocking = false


func _handle_discover_request(request: Dictionary, relic: RelicInstance) -> void:
	## Show discover overlay and store the player's choice.
	var overlay = DiscoverOverlayScene.instantiate()
	$HUD.add_child(overlay)

	var prompt = tr(request.get("prompt", "DISCOVER_DEFAULT_PROMPT"))
	var options: Array[Dictionary] = []
	for opt in request.get("options", []):
		options.append(opt)
	overlay.setup(prompt, options)

	# Wait for player selection
	var chosen_data = await overlay.option_selected

	# Store result in relic's persistent state
	var store_key = request.get("store_key", "discovered_choice")
	relic.persistent_state[store_key] = chosen_data

	# Clean up overlay
	overlay.queue_free()


func _save_relic_to_run_state(relic: RelicInstance, pos: Vector2i) -> void:
	## Persist relic definition and persistent state to RunState.
	if GameManager.current_run:
		GameManager.current_run.relics_on_board[pos] = {
			"definition": relic.definition,
			"persistent_state": relic.persistent_state.duplicate(true)
		}


func _fire_level_start_for_relic(relic: RelicInstance) -> void:
	## Fire on_level_start skills for a relic that was placed after the level already started.
	var context = TriggerContext.create("on_level_start")
	TriggerSystem.trigger_entity_skills("on_level_start", context, [relic])


func _cast_spell(spell_def: SpellDefinition, pos: Vector2i, target_entity: Variant) -> void:
	## Execute a spell: run effects, consume card, emit signal, flush animations.
	var card = selected_card
	_clear_card_selection()

	# Build context
	var context = TriggerContext.create("spell_cast")
	context.with_extra("spell_definition", spell_def)
	if pos != Vector2i.ZERO:
		var tile = BoardSystem.board.get_tile_at(pos)
		if tile:
			context.with_tile(tile)
	if target_entity is StallInstance:
		context.with_stall(target_entity)
	elif target_entity is GuestInstance:
		context.with_guest(target_entity)

	# Execute effects with null skill (spells have no SkillInstance)
	# Capture results to collect deferred requests (spell effects bypass TriggerSystem)
	var effects = SkillEffectFactory.create_all(spell_def.effects)
	var deferred_requests: Array[Dictionary] = []
	for effect in effects:
		var result = effect.execute(context, null)
		if not result.deferred_request.is_empty():
			deferred_requests.append(result.deferred_request)

	# Consume card (sets location to REMOVED, emits card_played → fires on_play trigger)
	deck_system.play_card(card, pos)

	# Emit spell_cast signal (fires on_cast trigger via TriggerSystem)
	EventBus.spell_cast.emit(spell_def, pos, target_entity)

	# Flush animations and sweep for ascensions (spells can fulfill needs)
	await TurnSystem.flush_and_sweep()

	# Handle deferred requests from spell effects
	if not deferred_requests.is_empty():
		await _handle_spell_deferred_requests(deferred_requests)


func _handle_spell_deferred_requests(requests: Array[Dictionary]) -> void:
	## Process deferred requests from spell effects.
	_ui_blocking = true
	for request in requests:
		match request.get("type"):
			"discover":
				push_warning("Discover effect on a spell has no entity to store result — skipping")
			"summon_beast_choice":
				await _handle_summon_beast_choice(request)
	_ui_blocking = false


func _handle_summon_beast_choice(request: Dictionary) -> void:
	## Show beast selection overlay and spawn the chosen beast at the target tile.
	var overlay = DiscoverOverlayScene.instantiate()
	$HUD.add_child(overlay)

	var prompt = tr(request.get("prompt", "DISCOVER_BEAST_PROMPT"))
	var options: Array[Dictionary] = []
	for opt in request.get("options", []):
		options.append(opt)
	overlay.setup(prompt, options)

	# Wait for player selection
	var chosen_data = await overlay.option_selected

	# Spawn the chosen beast at the target tile
	var beast_def = ContentRegistry.get_definition("guests", chosen_data)
	if beast_def:
		var target_pos: Vector2i = request.get("target_pos", Vector2i.ZERO)
		# Find the path and index for the target tile
		var spawn_index := -1
		var path_id := ""
		for path in BoardSystem.board.paths:
			var tile = BoardSystem.board.get_tile_at(target_pos)
			if tile:
				var idx = path.get_tile_index(tile)
				if idx >= 0:
					spawn_index = idx
					path_id = path.id
					break
		BoardSystem.summon_guest(beast_def, path_id, spawn_index)
		await TurnSystem.flush_and_sweep()

	# Clean up overlay
	overlay.queue_free()


func _get_spell_target_entity(spell_def: SpellDefinition, pos: Vector2i) -> Variant:
	## Resolve the target entity at a position based on the spell's target_type.
	match spell_def.target_type:
		"stall":
			return BoardSystem.get_stall_at(pos)
		"guest":
			var guests = BoardSystem.get_guests_at(pos)
			return guests[0] if not guests.is_empty() else null
		_:
			return null


func _validate_spell_target(spell_def: SpellDefinition, pos: Vector2i, target_entity: Variant) -> bool:
	## Check if the target is valid for this spell.
	match spell_def.target_type:
		"stall":
			if not target_entity is StallInstance:
				return false
			return _check_spell_filter(spell_def, target_entity)
		"guest":
			if not target_entity is GuestInstance:
				return false
			return _check_spell_filter(spell_def, target_entity)
		"tile":
			return _check_tile_filter(spell_def, pos)
		_:
			return true


func _check_spell_filter(spell_def: SpellDefinition, target_entity: Variant) -> bool:
	## Validate target_filter against a stall or guest entity.
	## Delegates to SpellDefinition methods for reuse by board_visual.
	if target_entity is StallInstance:
		return spell_def.is_valid_stall_target(target_entity)
	elif target_entity is GuestInstance:
		return spell_def.is_valid_guest_target(target_entity)
	return true


func _check_tile_filter(spell_def: SpellDefinition, pos: Vector2i) -> bool:
	## Validate target_filter for tile-targeted spells.
	return spell_def.is_valid_tile_target(pos)


func _has_valid_spell_targets(spell_def: SpellDefinition) -> bool:
	## Check if any valid target exists on the board for this spell.
	## Used to prevent selecting spells that have nothing to target.
	match spell_def.target_type:
		"none":
			return true
		"stall":
			for stall in BoardSystem.stalls.values():
				if spell_def.is_valid_stall_target(stall):
					return true
			return false
		"guest":
			for guest in BoardSystem.active_guests:
				if spell_def.is_valid_guest_target(guest):
					return true
			return false
		"tile":
			for pos in BoardSystem.board.tiles:
				if _check_tile_filter(spell_def, pos):
					return true
			return false
	return false


func _toggle_aura_selection(pos: Vector2i) -> void:
	## Toggle aura range highlight when clicking a stall slot.
	var stall = BoardSystem.get_stall_at(pos)
	if stall and board_visual.aura_system and board_visual.aura_system.has_aura(stall):
		if board_visual._selected_aura_source == stall:
			board_visual.clear_aura_selection()
		else:
			board_visual.select_aura_source(stall)
	else:
		board_visual.clear_aura_selection()


func _clear_card_selection() -> void:
	## Clear the currently selected card and exit placement mode.
	if selected_card:
		var card_ui := hand_display.get_card_ui(selected_card)
		if card_ui:
			card_ui.set_selected(false)
	selected_card = null
	board_visual.set_placement_mode(false)


func _on_end_turn_pressed() -> void:
	if TurnSystem.current_phase == TurnSystem.Phase.PLAYER_ACTION:
		_clear_card_selection()
		TurnSystem.player_action_complete()


# === Event handlers ===

func _on_tokens_changed(_old: int, _new: int) -> void:
	_update_hud()


func _on_reputation_changed(_old: int, _new: int) -> void:
	_update_hud()


func _on_turn_started(_turn: int) -> void:
	_update_hud()
	# deck_system.start_turn() is now called by TurnSystem before turn_started emits,
	# so on_turn_start skills can grant bonus plays without being overwritten.
	_refresh_hand_dimming()


func _on_phase_changed(phase: String) -> void:
	phase_label.text = phase.replace("_", " ").capitalize()


func _on_card_drawn(card: CardInstance) -> void:
	hand_display.add_card(card)
	_refresh_hand_dimming()


func _on_card_played(card: CardInstance) -> void:
	hand_display.remove_card(card)
	_refresh_hand_dimming()


func _on_guest_spawned(_guest: GuestInstance) -> void:
	_update_hud()


func _on_guest_moved(guest: GuestInstance, _from: Tile, _to: Tile) -> void:
	# Animation handled by AnimationCoordinator
	# Just refresh UI state
	var entity = board_visual.get_guest_entity(guest)
	if entity:
		entity.refresh()


func _on_guest_ascended(guest: GuestInstance) -> void:
	print("Guest ascended: %s" % guest.definition.id)
	# Animation already played - just remove entity
	board_visual.remove_guest_entity(guest, false)  # false = no animation


func _on_guest_descended(guest: GuestInstance) -> void:
	print("Guest descended: %s" % guest.definition.id)
	# Animation already played - just remove entity
	board_visual.remove_guest_entity(guest, false)


func _on_guest_banished(guest: GuestInstance) -> void:
	print("Guest banished: %s" % guest.definition.id)
	# Animation already played - just remove entity
	board_visual.remove_guest_entity(guest, false)


func _on_stall_restocked(_stall: StallInstance) -> void:
	pass  # Visuals handled by BoardSystem.restock_stall()


func _on_guest_entered_stall(guest: GuestInstance, stall: StallInstance) -> void:
	# Animation handled by AnimationCoordinator
	var guest_entity = board_visual.get_guest_entity(guest)
	if guest_entity:
		guest_entity.refresh()
	print("Guest %s entered %s" % [guest.definition.id, stall.definition.id])


func _on_guest_exited_stall(guest: GuestInstance, stall: StallInstance) -> void:
	# Animation handled by AnimationCoordinator
	var guest_entity = board_visual.get_guest_entity(guest)
	if guest_entity:
		guest_entity.refresh()
	print("Guest %s exited %s" % [guest.definition.id, stall.definition.id])


func _on_guest_served(guest: GuestInstance, stall: StallInstance) -> void:
	# Refresh guest visual after being served
	var guest_entity = board_visual.get_guest_entity(guest)
	if guest_entity:
		guest_entity.refresh()

	# Refresh stall visual (stock may have changed)
	if stall.tile:
		board_visual.refresh_stall(stall.tile.position)


func _on_debug_show_guest(guest: GuestInstance) -> void:
	debug_panel.show_guest_info(guest)


func _on_debug_show_stall(stall: StallInstance) -> void:
	debug_panel.show_stall_info(stall)


func _on_debug_show_relic(relic: RelicInstance) -> void:
	debug_panel.show_relic_info(relic)
