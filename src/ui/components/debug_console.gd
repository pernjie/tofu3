class_name DebugConsole
extends PanelContainer

## In-game debug console for testing game systems at runtime.
## Toggle with backtick (`) key. Only active in debug builds.

var _commands: Dictionary = {}  # name -> {callable, usage, description}
var _last_command: String = ""

var _output: RichTextLabel
var _input_line: LineEdit


func _ready() -> void:
	_build_ui()
	_register_commands()
	hide()


func _build_ui() -> void:
	# Anchor to bottom of screen, full width, 200px tall
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -220.0
	offset_bottom = 0.0

	# Semi-transparent dark background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	style.border_color = Color(0.3, 0.3, 0.5)
	style.border_width_top = 1
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	add_child(vbox)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = false
	_output.scroll_following = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(_output)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "Type 'help' for commands..."
	_input_line.add_theme_font_size_override("font_size", 14)
	_input_line.text_submitted.connect(_on_command_submitted)
	vbox.add_child(_input_line)


func toggle() -> void:
	if visible:
		hide()
		_input_line.release_focus()
	else:
		show()
		_input_line.grab_focus()
		_input_line.clear()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP and _last_command != "":
			_input_line.text = _last_command
			_input_line.caret_column = _last_command.length()
			get_viewport().set_input_as_handled()


func _on_command_submitted(text: String) -> void:
	_input_line.clear()
	var trimmed = text.strip_edges()
	if trimmed.is_empty():
		return

	_last_command = trimmed
	_print("> " + trimmed)

	var parts = trimmed.split(" ", false)
	var cmd_name = parts[0].to_lower()
	var args = parts.slice(1)

	if not _commands.has(cmd_name):
		_print("Unknown command '%s'. Type 'help' for available commands." % cmd_name)
		return

	var cmd = _commands[cmd_name]
	cmd.callable.call(args)


func _print(text: String) -> void:
	_output.append_text(text + "\n")
	print("[Console] " + text)


# =============================================================================
# Command Registration
# =============================================================================

func _register(cmd_name: String, callable: Callable, usage: String, description: String) -> void:
	_commands[cmd_name] = {
		"callable": callable,
		"usage": usage,
		"description": description,
	}


func _register_commands() -> void:
	_register("help", _cmd_help, "help [command]", "List commands or show details for one")
	_register("list_guests", _cmd_list_guests, "list_guests", "List all active guests with index and position")
	_register("inspect_guest", _cmd_inspect_guest, "inspect_guest <index>", "Show guest needs, money, status effects")
	_register("apply_status", _cmd_apply_status, "apply_status <status_id> <guest_index> [stacks]", "Apply status effect to a guest")
	_register("remove_status", _cmd_remove_status, "remove_status <status_id> <guest_index>", "Remove status effect from a guest")
	_register("spawn_guest", _cmd_spawn_guest, "spawn_guest <guest_id>", "Spawn a guest by definition id")
	_register("restock", _cmd_restock, "restock <x> <y>", "Restock the stall at position")
	_register("banish", _cmd_banish, "banish <guest_index>", "Banish a guest by index")


# =============================================================================
# Commands
# =============================================================================

func _cmd_help(args: Array) -> void:
	if args.size() > 0:
		var cmd_name = args[0].to_lower()
		if _commands.has(cmd_name):
			var cmd = _commands[cmd_name]
			_print("  %s" % cmd.usage)
			_print("  %s" % cmd.description)
		else:
			_print("Unknown command: %s" % cmd_name)
		return

	_print("Available commands:")
	var names = _commands.keys()
	names.sort()
	for cmd_name in names:
		_print("  %-16s %s" % [cmd_name, _commands[cmd_name].description])


func _cmd_list_guests(args: Array) -> void:
	var guests = BoardSystem.active_guests
	if guests.is_empty():
		_print("No active guests.")
		return

	_print("Active guests:")
	for i in guests.size():
		var guest = guests[i]
		var pos_str = str(guest.current_tile.position) if guest.current_tile else "none"
		var status_str = ""
		if not guest.status_effects.is_empty():
			var names: Array[String] = []
			for effect in guest.status_effects:
				names.append("%s(%d)" % [effect.definition.id, effect.stacks])
			status_str = " [%s]" % ", ".join(names)
		_print("  [%d] %s @ %s%s" % [i, guest.definition.id, pos_str, status_str])


func _cmd_inspect_guest(args: Array) -> void:
	if args.size() < 1:
		_print("Usage: inspect_guest <index>")
		return

	var guest = _get_guest_by_index(args[0])
	if not guest:
		return

	var guest_def = guest.definition as GuestDefinition
	_print("Guest: %s (instance: %s)" % [guest_def.id, guest.instance_id])
	var pos_str = str(guest.current_tile.position) if guest.current_tile else "none"
	_print("  Position: %s  Path index: %d" % [pos_str, guest.path_index])
	_print("  In stall: %s  Exiting: %s" % [guest.is_in_stall, guest.is_exiting])

	if guest.current_stall:
		_print("  Current stall: %s (%d turns left)" % [guest.current_stall.definition.id, guest.service_turns_remaining])

	_print("  Needs:")
	for need_type in guest.current_needs:
		var remaining = guest.current_needs[need_type]
		var base = guest.initial_needs.get(need_type, 0)
		var fulfilled = base - remaining
		_print("    %s: %d / %d" % [need_type, fulfilled, base])

	_print("  Money: %d / %d" % [guest.current_money, guest_def.base_money])

	if not guest.status_effects.is_empty():
		_print("  Status effects:")
		for effect in guest.status_effects:
			_print("    %s: %d stacks (max %d, type: %s)" % [
				effect.definition.id, effect.stacks,
				effect.definition.max_stacks, effect.definition.stack_type])

	if not guest.skill_instances.is_empty():
		_print("  Skills:")
		for skill in guest.skill_instances:
			_print("    %s (trigger: %s)" % [skill.definition.id, skill.definition.trigger_type])


func _cmd_apply_status(args: Array) -> void:
	if args.size() < 2:
		_print("Usage: apply_status <status_id> <guest_index> [stacks]")
		return

	var status_id = args[0]
	var guest = _get_guest_by_index(args[1])
	if not guest:
		return

	var stacks = 1
	if args.size() >= 3 and args[2].is_valid_int():
		stacks = args[2].to_int()

	# Validate status exists
	var status_def = ContentRegistry.get_definition("status_effects", status_id)
	if not status_def:
		_print("Status '%s' not found in ContentRegistry." % status_id)
		return

	var result = BoardSystem.inflict_status(guest, status_id, stacks)
	await AnimationCoordinator.play_batch()
	if result:
		_print("Applied '%s' to %s (%d stacks)" % [status_id, guest.definition.id, result.stacks])
	else:
		_print("Failed to apply '%s' to %s" % [status_id, guest.definition.id])


func _cmd_remove_status(args: Array) -> void:
	if args.size() < 2:
		_print("Usage: remove_status <status_id> <guest_index>")
		return

	var status_id = args[0]
	var guest = _get_guest_by_index(args[1])
	if not guest:
		return

	var existing = guest.get_status(status_id)
	if not existing:
		_print("Guest %s does not have status '%s'." % [guest.definition.id, status_id])
		return

	BoardSystem.revoke_status(guest, status_id)
	await AnimationCoordinator.play_batch()
	_print("Removed '%s' from %s." % [status_id, guest.definition.id])


func _cmd_spawn_guest(args: Array) -> void:
	if args.size() < 1:
		_print("Usage: spawn_guest <guest_id>")
		return

	var guest_id = args[0]
	var guest_def = ContentRegistry.get_definition("guests", guest_id)
	if not guest_def:
		_print("Guest '%s' not found in ContentRegistry." % guest_id)
		return

	var guest = BoardSystem.summon_guest(guest_def)
	if guest:
		var pos_str = str(guest.current_tile.position) if guest.current_tile else "none"
		await AnimationCoordinator.play_batch()
		_print("Spawned %s at %s." % [guest_id, pos_str])
	else:
		_print("Failed to spawn %s." % guest_id)


func _cmd_restock(args: Array) -> void:
	if args.size() < 2:
		_print("Usage: restock <x> <y>")
		return

	var pos = Vector2i(int(args[0]), int(args[1]))
	var stall = BoardSystem.get_stall_at(pos)
	if not stall:
		_print("No stall at %s." % str(pos))
		return

	if BoardSystem.restock_and_notify(stall):
		await AnimationCoordinator.play_batch()
		_print("Restocked %s at %s." % [stall.definition.id, str(pos)])
	else:
		_print("Cannot restock %s (not a product stall)." % stall.definition.id)


func _cmd_banish(args: Array) -> void:
	if args.size() < 1:
		_print("Usage: banish <guest_index>")
		return

	var guest = _get_guest_by_index(args[0])
	if not guest:
		return

	var result = BoardSystem.banish_guest(guest)
	await AnimationCoordinator.play_batch()
	if result:
		_print("Banished %s." % guest.definition.id)
	else:
		_print("Failed to banish %s (blocked or already exiting)." % guest.definition.id)


# =============================================================================
# Helpers
# =============================================================================

func _get_guest_by_index(index_str: String) -> GuestInstance:
	if not index_str.is_valid_int():
		_print("Invalid guest index: %s" % index_str)
		return null

	var index = index_str.to_int()
	var guests = BoardSystem.active_guests
	if index < 0 or index >= guests.size():
		_print("Guest index %d out of range (0-%d). Use 'list_guests' to see active guests." % [index, guests.size() - 1])
		return null

	return guests[index]


