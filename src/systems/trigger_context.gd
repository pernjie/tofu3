# src/systems/trigger_context.gd
class_name TriggerContext
extends RefCounted

## Context object passed during skill execution.
## Contains all relevant information about the triggering event.

var trigger_type: String = ""
var source: BaseInstance = null  # Entity whose skill triggered
var target: BaseInstance = null  # Primary target of the event
var stall: StallInstance = null  # Stall involved (if any)
var guest: GuestInstance = null  # Guest involved (if any)
var tile: Tile = null            # Tile involved (if any)
var from_tile: Tile = null       # Origin tile for movement
var to_tile: Tile = null         # Destination tile for movement
var amount: int = 0              # Numeric value (damage, tokens, etc.)
var need_type: String = ""       # Need type for service events
var extra: Dictionary = {}       # Additional context data
var service_result: Dictionary = {}  # Mutable service outcome for on_pre_serve effects
var movement_result: Dictionary = {}  # Mutable movement outcome for on_pre_move effects
var status_result: Dictionary = {}  # Mutable status outcome for on_pre_status effects
var banish_result: Dictionary = {}  # Mutable banish outcome for on_pre_banish effects
var fulfillment_result: Dictionary = {}  # Mutable fulfillment outcome for on_pre_fulfill effects
var entry_result: Dictionary = {}  # Mutable entry outcome for on_pre_enter_stall effects
var encounter_result: Dictionary = {}  # Mutable encounter outcome for on_pre_encounter effects
var guests: Array = []  # Array of GuestInstance, populated for on_bulk_serve


static func create(p_trigger_type: String) -> TriggerContext:
	var ctx = TriggerContext.new()
	ctx.trigger_type = p_trigger_type
	return ctx


func with_source(p_source: BaseInstance) -> TriggerContext:
	source = p_source
	return self


func with_target(p_target: BaseInstance) -> TriggerContext:
	target = p_target
	return self


func with_stall(p_stall: StallInstance) -> TriggerContext:
	stall = p_stall
	return self


func with_guest(p_guest: GuestInstance) -> TriggerContext:
	guest = p_guest
	return self


func with_tile(p_tile: Tile) -> TriggerContext:
	tile = p_tile
	return self


func with_movement(p_from: Tile, p_to: Tile) -> TriggerContext:
	from_tile = p_from
	to_tile = p_to
	return self


func with_amount(p_amount: int) -> TriggerContext:
	amount = p_amount
	return self


func with_need_type(p_need_type: String) -> TriggerContext:
	need_type = p_need_type
	return self


func with_extra(key: String, value: Variant) -> TriggerContext:
	extra[key] = value
	return self


func with_service_result() -> TriggerContext:
	## Initialize default service result for on_serve triggers.
	service_result = {
		"blocked": false,
		"fulfillment_multiplier": 1.0,
		"fulfillment_bonus": 0,
	}
	return self


func with_movement_result() -> TriggerContext:
	## Initialize default movement result for on_pre_move triggers.
	movement_result = {
		"direction": 1,  # 1 = forward, -1 = reverse
	}
	return self


func with_status_result() -> TriggerContext:
	## Initialize default status result for on_pre_status triggers.
	status_result = {
		"blocked": false,
	}
	return self


func with_banish_result() -> TriggerContext:
	## Initialize default banish result for on_pre_banish triggers.
	banish_result = {
		"blocked": false,
	}
	return self


func with_fulfillment_result() -> TriggerContext:
	## Initialize default fulfillment result for on_pre_fulfill triggers.
	fulfillment_result = {
		"blocked": false,
		"fulfillment_bonus": 0,
		"fulfillment_multiplier": 1.0,
	}
	return self


func with_guests(p_guests: Array) -> TriggerContext:
	guests = p_guests
	return self


func with_entry_result() -> TriggerContext:
	## Initialize default entry result for on_pre_enter_stall triggers.
	entry_result = {
		"blocked": false,
	}
	return self


func with_encounter_result() -> TriggerContext:
	## Initialize default encounter result for on_pre_encounter triggers.
	encounter_result = {
		"blocked": false,
		"benefit_multiplier": 1.0,
	}
	return self


func get_extra(key: String, default: Variant = null) -> Variant:
	return extra.get(key, default)


func resolve_target_entity(target_string: String, skill: SkillInstance) -> BaseInstance:
	## Resolve a target string to an actual entity.
	match target_string:
		"self":
			return skill.owner if skill else null
		"source":
			return source
		"target":
			return target
		"guest":
			return guest
		"stall":
			return stall
		"random_guest_on_tile":
			if tile:
				var guests_on_tile = BoardSystem.get_guests_at(tile.position)
				if not guests_on_tile.is_empty():
					return guests_on_tile.pick_random()
			return null
		_:
			return null
