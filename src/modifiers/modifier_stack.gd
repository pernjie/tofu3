class_name ModifierStack
extends RefCounted

## Manages a collection of StatModifiers and calculates final stat values.
## Application order: ADD → MULTIPLY → SET → ADD_FINAL

var _modifiers: Array[StatModifier] = []


func add_modifier(modifier: StatModifier) -> void:
	_modifiers.append(modifier)
	_modifiers.sort_custom(_sort_by_priority)


func remove_modifier(modifier: StatModifier) -> void:
	_modifiers.erase(modifier)


func remove_modifiers_from_source(source: Object) -> void:
	_modifiers = _modifiers.filter(func(m): return m.source != source)


func get_modifiers_for_stat(stat_name: String) -> Array[StatModifier]:
	return _modifiers.filter(func(m): return m.stat == stat_name)


func calculate_stat(base_stat: String, base_value: Variant) -> Variant:
	var value = base_value

	# Pass 1: ADD, MULTIPLY, SET (in priority order)
	for modifier in _modifiers:
		if modifier.stat != base_stat:
			continue
		if not modifier.is_active():
			continue

		match modifier.operation:
			StatModifier.Operation.ADD:
				value += modifier.value
			StatModifier.Operation.MULTIPLY:
				value *= modifier.value
			StatModifier.Operation.SET:
				value = modifier.value
			StatModifier.Operation.ADD_FINAL:
				pass  # Applied in second pass

	# Pass 2: ADD_FINAL
	for modifier in _modifiers:
		if modifier.stat != base_stat:
			continue
		if not modifier.is_active():
			continue
		if modifier.operation == StatModifier.Operation.ADD_FINAL:
			value += modifier.value

	return value


func clear() -> void:
	_modifiers.clear()


func _sort_by_priority(a: StatModifier, b: StatModifier) -> bool:
	# Sort by operation type first, then by priority within type
	var op_order_a = _get_operation_order(a.operation)
	var op_order_b = _get_operation_order(b.operation)
	if op_order_a != op_order_b:
		return op_order_a < op_order_b
	return a.priority < b.priority


func _get_operation_order(op: StatModifier.Operation) -> int:
	match op:
		StatModifier.Operation.ADD: return 0
		StatModifier.Operation.MULTIPLY: return 1
		StatModifier.Operation.SET: return 2
		StatModifier.Operation.ADD_FINAL: return 3
	return 99
