class_name StatModifier
extends RefCounted

## Represents a single modification to a stat.
## Modifiers are applied in priority order by ModifierStack.

enum Operation {
	ADD,        ## Add value to stat (applied first)
	MULTIPLY,   ## Multiply stat by value
	SET,        ## Set stat to value (overrides previous)
	ADD_FINAL,  ## Add value after all other operations
}

var stat: String           ## Name of the stat being modified
var operation: Operation   ## How to apply the modification
var value: Variant         ## The modification value
var source: Object         ## What created this modifier (for removal)
var priority: int = 0      ## Lower priority applied first within same operation
var condition: Callable    ## Optional: only active if this returns true

func _init(
	p_stat: String,
	p_operation: Operation,
	p_value: Variant,
	p_source: Object = null,
	p_priority: int = 0
) -> void:
	stat = p_stat
	operation = p_operation
	value = p_value
	source = p_source
	priority = p_priority


func is_active() -> bool:
	if condition.is_null():
		return true
	return condition.call()
