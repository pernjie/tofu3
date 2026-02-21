class_name DebugInfoPanel
extends PanelContainer

## Simple panel to display debug info when clicking entities.

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var content_label: Label = $MarginContainer/VBoxContainer/ContentLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	close_button.pressed.connect(hide)
	hide()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Hide if clicking outside the panel
			if not get_global_rect().has_point(event.position):
				hide()


func show_guest_info(guest: GuestInstance) -> void:
	var guest_def := guest.definition as GuestDefinition
	title_label.text = "Guest: %s" % guest_def.id

	var lines: Array[String] = []
	lines.append("Instance ID: %s" % guest.instance_id)
	lines.append("")
	lines.append("Path Index: %d" % guest.path_index)
	lines.append("In Stall: %s" % guest.is_in_stall)
	lines.append("Exiting: %s" % guest.is_exiting)

	if guest.current_stall:
		lines.append("Current Stall: %s" % guest.current_stall.definition.id)
		lines.append("Service Turns Left: %d" % guest.service_turns_remaining)

	lines.append("")
	lines.append("== Needs ==")
	for need_type in guest.current_needs:
		var remaining = guest.current_needs[need_type]
		var base = guest.initial_needs.get(need_type, 0)
		var fulfilled = base - remaining
		lines.append("  %s: %d / %d" % [need_type.capitalize(), fulfilled, base])

	lines.append("")
	lines.append("Money: %d / %d" % [guest.current_money, guest_def.base_money])
	lines.append("Fulfilled: %s" % guest.are_all_needs_fulfilled())

	_append_status_effects(lines, guest)

	content_label.text = "\n".join(lines)
	show()


func show_stall_info(stall: StallInstance) -> void:
	var stall_def := stall.definition as StallDefinition
	title_label.text = "Stall: %s" % stall_def.id

	var tier_data = stall.get_current_tier_data()
	var base_value = tier_data.value if tier_data else 0

	var lines: Array[String] = []
	lines.append("Instance ID: %s" % stall.instance_id)
	lines.append("Position: %s" % stall.board_position)
	lines.append("Tier: %d / %d" % [stall.current_tier, stall_def.tiers.size()])

	lines.append("")
	lines.append("== Service ==")
	lines.append("Need Type: %s" % stall.get_need_type())
	lines.append("Value: %d (base: %d)" % [stall.get_value(), base_value])
	lines.append("Model: %s" % stall.get_operation_model())

	if stall.get_operation_model() == "product":
		var restock_amount = tier_data.restock_amount if tier_data else 0
		lines.append("Stock: %d / %d" % [stall.current_stock, restock_amount])
	else:
		lines.append("Duration: %d turns" % stall.get_service_duration())

	lines.append("")
	lines.append("== Occupants ==")
	lines.append("Capacity: %d" % stall.get_capacity())
	lines.append("Current: %d" % stall.current_occupants.size())
	for occupant in stall.current_occupants:
		lines.append("  - %s" % occupant.definition.id)

	_append_status_effects(lines, stall)

	content_label.text = "\n".join(lines)
	show()


func show_relic_info(relic: RelicInstance) -> void:
	var relic_def := relic.definition as RelicDefinition
	title_label.text = "Relic: %s" % relic_def.id.replace("_", " ").capitalize()

	var lines: Array[String] = []
	lines.append("ID: %s" % relic_def.id)
	lines.append("Position: %s" % relic.board_position)

	lines.append("")
	lines.append("== Skills ==")
	for skill in relic.skill_instances:
		lines.append("  %s (%s)" % [skill.definition.id, skill.definition.trigger_type])

	if not relic.persistent_state.is_empty():
		lines.append("")
		lines.append("== Persistent State ==")
		for key in relic.persistent_state:
			lines.append("  %s: %s" % [key, relic.persistent_state[key]])

	_append_status_effects(lines, relic)

	content_label.text = "\n".join(lines)
	show()


func _append_status_effects(lines: Array[String], instance: BaseInstance) -> void:
	if instance.status_effects.is_empty():
		return

	lines.append("")
	lines.append("== Status Effects ==")
	for effect in instance.status_effects:
		var se: StatusEffectInstance = effect
		var def: StatusEffectDefinition = se.definition
		var type_tag := "[%s]" % def.effect_type.to_upper()
		var stack_info := str(se.stacks) if def.max_stacks > 1 else ""
		var parts: Array[String] = [type_tag, def.id]
		if not stack_info.is_empty():
			parts.append("x%s" % stack_info)
		parts.append("(%s)" % def.stack_type)
		lines.append("  %s" % " ".join(parts))
