# Candy Nuts Stand Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a candy nuts stand — an overpriced food product stall whose skill fully fulfills a guest's remaining food needs when at least half are already met.

**Architecture:** Product stall with an `on_serve` skill. Requires one new condition (`need_fulfillment_ratio`) and one extension to the existing `fulfill_need` effect (`amount: "remaining"`). Both are general-purpose additions.

**Tech Stack:** GDScript, JSON data definitions, GUT testing framework

---

### Task 1: Add `resolve_float_parameter` to SkillCondition base class

The new `need_fulfillment_ratio` condition needs to resolve a float parameter (the ratio threshold). `SkillCondition` only has `resolve_int_parameter` and `resolve_string_parameter`. `SkillEffect` already has `resolve_float_parameter` — mirror the same method.

**Files:**
- Modify: `src/skill_conditions/skill_condition.gd:38` (after `resolve_int_parameter`)

**Step 1: Add the method**

Add after the existing `resolve_int_parameter` method (after line 48):

```gdscript
func resolve_float_parameter(key: String, skill: SkillInstance, default: float = 0.0) -> float:
	## Convenience method to resolve a float parameter.
	var raw_value = condition_data.get(key, default)
	var resolved = resolve_parameter(raw_value, skill)
	if resolved is float:
		return resolved
	if resolved is int:
		return float(resolved)
	if resolved is String:
		return float(resolved) if resolved.is_valid_float() else default
	return default
```

This is an exact copy of the same method on `SkillEffect` (see `src/skill_effects/skill_effect.gd:61-70`), adapted for `condition_data`.

---

### Task 2: Create `need_fulfillment_ratio` condition

Checks what fraction of a guest's need has been fulfilled. Compares `(initial - remaining) / initial` against a threshold.

**Files:**
- Create: `src/skill_conditions/need_fulfillment_ratio_condition.gd`
- Modify: `src/skill_conditions/skill_condition_factory.gd:41` (add match case before `_:`)

**Step 1: Write the failing test**

Add to the **end** of `test/integration/test_on_serve_skills.gd`:

```gdscript
class TestNeedFulfillmentRatioCondition:
	extends "res://test/helpers/test_base.gd"

	func _create_skill_with_ratio_condition(threshold: float) -> SkillInstance:
		# Minimal skill definition with need_fulfillment_ratio condition
		var skill_data = {
			"id": "test_ratio_skill",
			"trigger_type": "on_serve",
			"owner_types": ["stall"],
			"parameters": {
				"threshold": { "type": "float", "default": threshold }
			},
			"conditions": [
				{
					"type": "need_fulfillment_ratio",
					"target": "guest",
					"need_type": "food",
					"comparison": "greater_or_equal",
					"ratio": "{threshold}"
				}
			],
			"effects": []
		}
		var def = SkillDefinition.from_dict(skill_data)
		return SkillInstance.new(def, null)

	func test_passes_when_ratio_met():
		var guest = create_guest("hungry_ghost")
		# Set up: 4 initial food, 2 remaining = 50% fulfilled
		guest.initial_needs = { "food": 4 }
		guest.current_needs = { "food": 2 }
		register_guest(guest, Vector2i(2, 0))

		var skill = _create_skill_with_ratio_condition(0.5)
		var context = TriggerContext.create("on_serve").with_guest(guest)
		var result = SkillConditionFactory.evaluate_all(skill.conditions, context, skill)

		assert_true(result, "Should pass when exactly 50% fulfilled (2/4)")

	func test_fails_when_ratio_not_met():
		var guest = create_guest("hungry_ghost")
		# Set up: 4 initial food, 3 remaining = 25% fulfilled
		guest.initial_needs = { "food": 4 }
		guest.current_needs = { "food": 3 }
		register_guest(guest, Vector2i(2, 0))

		var skill = _create_skill_with_ratio_condition(0.5)
		var context = TriggerContext.create("on_serve").with_guest(guest)
		var result = SkillConditionFactory.evaluate_all(skill.conditions, context, skill)

		assert_false(result, "Should fail when only 25% fulfilled (1/4)")

	func test_passes_when_fully_fulfilled():
		var guest = create_guest("hungry_ghost")
		# Set up: 4 initial food, 0 remaining = 100% fulfilled
		guest.initial_needs = { "food": 4 }
		guest.current_needs = { "food": 0 }
		register_guest(guest, Vector2i(2, 0))

		var skill = _create_skill_with_ratio_condition(0.5)
		var context = TriggerContext.create("on_serve").with_guest(guest)
		var result = SkillConditionFactory.evaluate_all(skill.conditions, context, skill)

		assert_true(result, "Should pass when 100% fulfilled")

	func test_fails_when_no_initial_need():
		var guest = create_guest("hungry_ghost")
		# Guest has no food need at all
		guest.initial_needs = { "joy": 2 }
		guest.current_needs = { "joy": 2 }
		register_guest(guest, Vector2i(2, 0))

		var skill = _create_skill_with_ratio_condition(0.5)
		var context = TriggerContext.create("on_serve").with_guest(guest)
		var result = SkillConditionFactory.evaluate_all(skill.conditions, context, skill)

		assert_false(result, "Should fail when guest has no food need")
```

**Step 2: Run test to verify it fails**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" -d -s --path /Users/pern/night addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_serve_skills.gd -ginner_class=TestNeedFulfillmentRatioCondition`

Expected: FAIL — `NeedFulfillmentRatioCondition` class doesn't exist.

**Step 3: Create the condition class**

Create `src/skill_conditions/need_fulfillment_ratio_condition.gd`:

```gdscript
# src/skill_conditions/need_fulfillment_ratio_condition.gd
class_name NeedFulfillmentRatioCondition
extends SkillCondition

## Checks what fraction of a guest's need has been fulfilled.
## Compares (initial - remaining) / initial against a ratio threshold.
##
## Condition data:
##   type: "need_fulfillment_ratio"
##   target: "self", "target", "guest" (must be a guest)
##   need_type: string (food, joy)
##   comparison: "greater_than", "less_than", "equal", "greater_or_equal", "less_or_equal"
##   ratio: float or "{parameter_name}" (0.0 to 1.0)


func evaluate(context: TriggerContext, skill: SkillInstance) -> bool:
	var target_str = condition_data.get("target", "self")
	var target_entity = context.resolve_target_entity(target_str, skill)

	if not target_entity:
		return false

	if not target_entity is GuestInstance:
		push_warning("NeedFulfillmentRatioCondition: target is not a guest")
		return false

	var guest = target_entity as GuestInstance
	var need_type = resolve_string_parameter("need_type", skill, "")
	if need_type.is_empty():
		push_warning("NeedFulfillmentRatioCondition: missing need_type")
		return false

	var initial = guest.initial_needs.get(need_type, 0)
	if initial <= 0:
		return false  # No such need — can't compute ratio

	var remaining = guest.get_remaining_need(need_type)
	var fulfilled_ratio = float(initial - remaining) / float(initial)

	var threshold = resolve_float_parameter("ratio", skill, 0.0)
	var comparison = condition_data.get("comparison", "greater_or_equal")

	match comparison:
		"greater_than":
			return fulfilled_ratio > threshold
		"less_than":
			return fulfilled_ratio < threshold
		"equal":
			return is_equal_approx(fulfilled_ratio, threshold)
		"greater_or_equal":
			return fulfilled_ratio >= threshold or is_equal_approx(fulfilled_ratio, threshold)
		"less_or_equal":
			return fulfilled_ratio <= threshold or is_equal_approx(fulfilled_ratio, threshold)
		_:
			push_warning("NeedFulfillmentRatioCondition: unknown comparison '%s'" % comparison)
			return false
```

**Step 4: Register in factory**

In `src/skill_conditions/skill_condition_factory.gd`, add a new match case before the `_:` wildcard (line 41):

```gdscript
		"need_fulfillment_ratio":
			return NeedFulfillmentRatioCondition.new(condition_data)
```

**Step 5: Run tests to verify they pass**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" -d -s --path /Users/pern/night addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_serve_skills.gd -ginner_class=TestNeedFulfillmentRatioCondition`

Expected: All 4 tests PASS.

---

### Task 3: Extend `fulfill_need` effect to support `amount: "remaining"`

When `amount` is the string `"remaining"`, fulfill all of the guest's remaining need of the specified type. This avoids using an arbitrary large number (which would show wrong amounts in animations).

**Files:**
- Modify: `src/skill_effects/fulfill_need_effect.gd`

**Step 1: Write the failing test**

Add to the **end** of `test/integration/test_on_serve_skills.gd`:

```gdscript
class TestFulfillNeedRemainingAmount:
	extends "res://test/helpers/test_base.gd"

	func test_remaining_fulfills_all_food():
		var guest = create_guest("hungry_ghost")
		guest.initial_needs = { "food": 6 }
		guest.current_needs = { "food": 4 }
		register_guest(guest, Vector2i(2, 0))

		var effect_data = {
			"type": "fulfill_need",
			"target": "guest",
			"need_type": "food",
			"amount": "remaining"
		}
		var effect = SkillEffectFactory.create(effect_data)
		var skill_data = {
			"id": "test_remaining",
			"trigger_type": "on_serve",
			"owner_types": ["stall"],
			"parameters": {},
			"conditions": [],
			"effects": [effect_data]
		}
		var def = SkillDefinition.from_dict(skill_data)
		var skill = SkillInstance.new(def, null)
		var context = TriggerContext.create("on_serve").with_guest(guest)

		effect.execute(context, skill)

		assert_eq(guest.get_remaining_need("food"), 0,
			"Should fulfill all 4 remaining food")

	func test_remaining_with_zero_remaining_is_noop():
		var guest = create_guest("hungry_ghost")
		guest.initial_needs = { "food": 2 }
		guest.current_needs = { "food": 0 }
		register_guest(guest, Vector2i(2, 0))

		var effect_data = {
			"type": "fulfill_need",
			"target": "guest",
			"need_type": "food",
			"amount": "remaining"
		}
		var effect = SkillEffectFactory.create(effect_data)
		var skill_data = {
			"id": "test_remaining_noop",
			"trigger_type": "on_serve",
			"owner_types": ["stall"],
			"parameters": {},
			"conditions": [],
			"effects": [effect_data]
		}
		var def = SkillDefinition.from_dict(skill_data)
		var skill = SkillInstance.new(def, null)
		var context = TriggerContext.create("on_serve").with_guest(guest)

		effect.execute(context, skill)

		assert_eq(guest.get_remaining_need("food"), 0,
			"Should be a no-op when already fulfilled")
```

**Step 2: Run test to verify it fails**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" -d -s --path /Users/pern/night addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_serve_skills.gd -ginner_class=TestFulfillNeedRemainingAmount`

Expected: FAIL — `amount` resolves to default `1`, so only 1 food is fulfilled instead of 4.

**Step 3: Modify `fulfill_need_effect.gd`**

Replace the `execute` method to handle `"remaining"` before resolving amount as int. The key change: check if the raw amount value resolves to the string `"remaining"`, and if so, pass a sentinel to the single/area methods where the guest is known.

Replace `src/skill_effects/fulfill_need_effect.gd` entirely:

```gdscript
# src/skill_effects/fulfill_need_effect.gd
class_name FulfillNeedEffect
extends SkillEffect

## Directly fulfills a need on a target guest or area.
##
## Effect data:
##   type: "fulfill_need"
##   target: "self", "target", "guest", "adjacent_guests"
##   need_type: string (food, joy, or "random" to pick a random unfulfilled need)
##   amount: int, "{parameter_name}", or "remaining" (fulfills all remaining of that need)
##   range: int (Manhattan distance, only for "adjacent_guests", default 1)


func execute(context: TriggerContext, skill: SkillInstance) -> SkillEffectResult:
	var need_type = resolve_string_parameter("need_type", skill, "")
	if need_type.is_empty():
		return SkillEffectResult.failed("No need_type specified")

	var use_remaining = _is_remaining_amount(skill)
	var amount = 0 if use_remaining else resolve_int_parameter("amount", skill, 1)
	var target_mode = get_target_string()

	if target_mode == "adjacent_guests":
		return _execute_area(context, skill, need_type, amount, use_remaining)
	return _execute_single(context, skill, need_type, amount, use_remaining)


func _is_remaining_amount(skill: SkillInstance) -> bool:
	var raw = effect_data.get("amount", 1)
	var resolved = resolve_parameter(raw, skill)
	return resolved is String and resolved == "remaining"


func _execute_single(context: TriggerContext, skill: SkillInstance, need_type: String, amount: int, use_remaining: bool) -> SkillEffectResult:
	var target_entity = resolve_target(context, skill)

	if not target_entity:
		return SkillEffectResult.failed("No valid target")

	if not target_entity is GuestInstance:
		return SkillEffectResult.failed("Target is not a guest")

	var guest = target_entity as GuestInstance

	# Resolve "random" to a random unfulfilled need
	var resolved_need_type = need_type
	if need_type == "random":
		var unfulfilled: Array[String] = []
		for key in guest.current_needs:
			if guest.current_needs[key] > 0:
				unfulfilled.append(key)
		if unfulfilled.is_empty():
			return SkillEffectResult.succeeded()  # No-op, not a failure
		resolved_need_type = unfulfilled.pick_random()

	var final_amount = guest.get_remaining_need(resolved_need_type) if use_remaining else amount
	if final_amount <= 0:
		return SkillEffectResult.succeeded()  # Nothing to fulfill

	if not context.encounter_result.is_empty():
		final_amount = int(final_amount * context.encounter_result.get("benefit_multiplier", 1.0))

	var old_value = guest.get_remaining_need(resolved_need_type)
	var fulfilled = BoardSystem.fulfill_and_notify(guest, resolved_need_type, final_amount, skill.owner)

	var result = SkillEffectResult.succeeded()
	result.add_modified_target(guest)
	result.set_value_changed(resolved_need_type, old_value, guest.get_remaining_need(resolved_need_type))
	return result


func _execute_area(context: TriggerContext, skill: SkillInstance, need_type: String, amount: int, use_remaining: bool) -> SkillEffectResult:
	var range_val = resolve_int_parameter("range", skill, 1)

	var owner_guest = context.guest
	if not owner_guest or not owner_guest.current_tile:
		return SkillEffectResult.failed("No guest with position in context")

	var center_pos = owner_guest.current_tile.position

	if not BoardSystem.board:
		return SkillEffectResult.failed("No board available")

	var adjacent_tiles = BoardSystem.board.get_adjacent_tiles(center_pos)
	var result = SkillEffectResult.succeeded()

	for tile in adjacent_tiles:
		var distance = abs(tile.position.x - center_pos.x) + abs(tile.position.y - center_pos.y)
		if distance > range_val:
			continue

		var guests_on_tile = BoardSystem.get_guests_at(tile.position)
		for guest in guests_on_tile:
			var final_amount = guest.get_remaining_need(need_type) if use_remaining else amount
			if final_amount <= 0:
				continue
			var fulfilled = BoardSystem.fulfill_and_notify(guest, need_type, final_amount, skill.owner)
			if fulfilled > 0:
				result.add_modified_target(guest)

	return result
```

**Step 4: Run tests to verify they pass**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" -d -s --path /Users/pern/night addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_serve_skills.gd -ginner_class=TestFulfillNeedRemainingAmount`

Expected: Both tests PASS.

**Step 5: Run ALL existing fulfill_need tests to check for regressions**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" -d -s --path /Users/pern/night addons/gut/gut_cmdln.gd`

Expected: All existing tests still PASS. The change is backward-compatible — existing integer amounts resolve exactly as before.

---

### Task 4: Create skill JSON

**Files:**
- Create: `data/skills/candy_nuts_food_finisher.json`

**Step 1: Create the skill**

Create `data/skills/candy_nuts_food_finisher.json`:

```json
{
  "$schema": "./_schema.json",
  "id": "candy_nuts_food_finisher",
  "display_name_key": "SKILL_CANDY_NUTS_FOOD_FINISHER_NAME",
  "description_key": "SKILL_CANDY_NUTS_FOOD_FINISHER_DESC",
  "owner_types": ["stall"],
  "trigger_type": "on_serve",
  "parameters": {
    "threshold": { "type": "float", "default": 0.5, "min": 0.0, "max": 1.0 }
  },
  "conditions": [
    {
      "type": "need_fulfillment_ratio",
      "target": "guest",
      "need_type": "food",
      "comparison": "greater_or_equal",
      "ratio": "{threshold}"
    }
  ],
  "effects": [
    {
      "type": "fulfill_need",
      "target": "guest",
      "need_type": "food",
      "amount": "remaining"
    }
  ],
  "tags": ["food", "finisher"]
}
```

---

### Task 5: Create stall JSON

**Files:**
- Create: `data/stalls/candy_nuts_stand.json`

**Step 1: Create the stall**

Create `data/stalls/candy_nuts_stand.json`:

```json
{
  "$schema": "./_schema.json",
  "id": "candy_nuts_stand",
  "display_name_key": "STALL_CANDY_NUTS_STAND_NAME",
  "description_key": "STALL_CANDY_NUTS_STAND_DESC",
  "rarity": "rare",

  "card_type": "stall",
  "hero_id": "",

  "operation_model": "product",
  "need_type": "food",

  "tiers": [
    {
      "tier": 1,
      "cost_to_guest": 3,
      "value": 1,
      "restock_amount": 2,
      "restock_duration": 3,
      "skills": [
        { "skill_id": "candy_nuts_food_finisher" }
      ]
    },
    {
      "tier": 2,
      "cost_to_guest": 3,
      "value": 1,
      "restock_amount": 2,
      "restock_duration": 2,
      "skills": [
        { "skill_id": "candy_nuts_food_finisher" }
      ]
    },
    {
      "tier": 3,
      "cost_to_guest": 3,
      "value": 1,
      "restock_amount": 2,
      "restock_duration": 1,
      "skills": [
        { "skill_id": "candy_nuts_food_finisher" }
      ]
    }
  ],

  "placement_restriction": null,
  "tags": []
}
```

---

### Task 6: Integration tests for the candy nuts stand

**Files:**
- Modify: `test/integration/test_on_serve_skills.gd` (add test class at end)

**Step 1: Write the integration tests**

Add to the **end** of `test/integration/test_on_serve_skills.gd`:

```gdscript
class TestCandyNutsFoodFinisher:
	extends "res://test/helpers/test_base.gd"

	func test_finishes_food_when_half_fulfilled():
		var guest = create_guest("hungry_ghost")
		# Guest has 6 food, 3 already fulfilled (50%), 3 remaining
		guest.initial_needs = { "food": 6 }
		guest.current_needs = { "food": 3 }
		var stall = create_stall("candy_nuts_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_eq(guest.get_remaining_need("food"), 0,
			"Should fulfill all remaining food when 50% already met")

	func test_does_not_trigger_below_half():
		var guest = create_guest("hungry_ghost")
		# Guest has 6 food, 2 fulfilled (33%), 4 remaining
		guest.initial_needs = { "food": 6 }
		guest.current_needs = { "food": 4 }
		var stall = create_stall("candy_nuts_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_eq(guest.get_remaining_need("food"), 4,
			"Should not trigger when less than 50% fulfilled")

	func test_finishes_food_when_more_than_half():
		var guest = create_guest("hungry_ghost")
		# Guest has 4 food, 3 fulfilled (75%), 1 remaining
		guest.initial_needs = { "food": 4 }
		guest.current_needs = { "food": 1 }
		var stall = create_stall("candy_nuts_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_eq(guest.get_remaining_need("food"), 0,
			"Should fulfill remaining food when more than 50% met")

	func test_no_effect_on_guest_without_food_need():
		var guest = create_guest("hungry_ghost")
		# Guest only has joy needs
		guest.initial_needs = { "joy": 4 }
		guest.current_needs = { "joy": 2 }
		var stall = create_stall("candy_nuts_stand")
		register_guest(guest, Vector2i(2, 0))
		register_stall(stall, Vector2i(2, 1))

		fire_for("on_serve", TriggerContext.create("on_serve") \
			.with_guest(guest).with_stall(stall).with_source(stall) \
			.with_target(guest), [guest, stall])

		assert_eq(guest.get_remaining_need("joy"), 2,
			"Should not affect joy needs — skill only checks food")
```

**Step 2: Run integration tests**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" -d -s --path /Users/pern/night addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_serve_skills.gd -ginner_class=TestCandyNutsFoodFinisher`

Expected: All 4 tests PASS.

**Step 3: Run full test suite**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" -d -s --path /Users/pern/night addons/gut/gut_cmdln.gd`

Expected: All tests PASS, no regressions.

---

### Checklist

- [ ] Created `data/stalls/candy_nuts_stand.json` with valid schema
- [ ] `card_type` is `"stall"`, `operation_model` is `"product"`, `need_type` is `"food"`
- [ ] Tiers well-structured: 1→2→3, restock_duration scales 3→2→1, all other stats flat
- [ ] `rarity` is `"rare"`
- [ ] Skill ID `candy_nuts_food_finisher` exists in `data/skills/`
- [ ] New skill JSON: `owner_types` includes `"stall"`, trigger `on_serve`, condition and effect valid
- [ ] New condition `need_fulfillment_ratio` registered in `skill_condition_factory.gd`
- [ ] `fulfill_need` effect extended to support `amount: "remaining"` (backward-compatible)
- [ ] `resolve_float_parameter` added to `SkillCondition` base class
- [ ] Run project — ContentRegistry confirms stall and skill loaded
- [ ] Integration tests: positive cases (50%, 75%) and negative cases (33%, no food need) all pass
- [ ] Full test suite passes with no regressions
