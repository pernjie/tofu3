# Tengu Boss Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add the Tengu, a boss guest that starts with 9 joy needs and alternates need types (joy↔food) after every fulfillment until ascending.

**Architecture:** Pure JSON — no code changes. The `transform_need` effect, `need_type_check` condition, and `on_need_fulfilled` trigger all exist. One new reusable skill definition (transform on fulfillment), one new guest definition, and integration tests.

**Tech Stack:** GDScript, JSON data definitions, GUT test framework

---

### Task 1: Create the `transform_need_on_fulfill` Skill

**Files:**
- Create: `data/skills/transform_need_on_fulfill.json`

**Step 1: Create the skill JSON**

```json
{
  "$schema": "./_schema.json",
  "id": "transform_need_on_fulfill",
  "display_name_key": "SKILL_TRANSFORM_NEED_ON_FULFILL_NAME",
  "description_key": "SKILL_TRANSFORM_NEED_ON_FULFILL_DESC",
  "owner_types": ["guest"],
  "trigger_type": "on_need_fulfilled",
  "parameters": {
    "trigger_need_type": { "type": "string", "default": "" },
    "from_need_type": { "type": "string", "default": "" },
    "to_need_type": { "type": "string", "default": "" }
  },
  "conditions": [
    { "type": "need_type_check", "need_type": "{trigger_need_type}" }
  ],
  "effects": [
    { "type": "transform_need", "from_need_type": "{from_need_type}", "to_need_type": "{to_need_type}" }
  ],
  "tags": ["transformation"]
}
```

This is a reusable, parameterized version of `spider_transform.json` — same effect, different trigger. The `need_type_check` condition gates which fulfillment type triggers the swap.

**Step 2: Verify ContentRegistry loads it**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" --headless --import --path /Users/pern/night`

Expected: No errors related to `transform_need_on_fulfill`

---

### Task 2: Create the Tengu Guest

**Files:**
- Create: `data/guests/tengu.json`

**Step 1: Create the guest JSON**

```json
{
  "$schema": "./_schema.json",
  "id": "tengu",
  "display_name_key": "GUEST_TENGU_NAME",
  "description_key": "GUEST_TENGU_DESC",
  "rarity": "legendary",
  "is_core_guest": true,
  "is_boss": true,
  "base_stats": {
    "needs": { "joy": 9 },
    "money": 9,
    "movement_speed": 1
  },
  "skills": [
    { "skill_id": "transform_need_on_fulfill", "parameters": { "trigger_need_type": "joy", "from_need_type": "joy", "to_need_type": "food" } },
    { "skill_id": "transform_need_on_fulfill", "parameters": { "trigger_need_type": "food", "from_need_type": "food", "to_need_type": "joy" } }
  ],
  "tags": ["boss", "yokai"]
}
```

Two instances of the same skill with opposite parameters — joy→food fires when joy is fulfilled, food→joy fires when food is fulfilled.

**Step 2: Verify ContentRegistry loads it**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" --headless --import --path /Users/pern/night`

Expected: No errors related to `tengu` or `transform_need_on_fulfill`

---

### Task 3: Write Integration Tests

**Files:**
- Modify: `test/integration/test_on_need_fulfilled_skills.gd` (append new test class at end of file)

**Step 1: Write the tests**

Append this test class to the end of the file:

```gdscript


class TestTenguTransform:
	extends "res://test/helpers/test_base.gd"

	func test_joy_fulfillment_transforms_remaining_to_food():
		var tengu = create_guest("tengu")
		register_guest(tengu, Vector2i(1, 0))

		assert_eq(tengu.get_remaining_need("joy"), 9,
			"Should start with 9 joy needs")

		# Fulfill 3 joy, then fire on_need_fulfilled
		tengu.fulfill_need("joy", 3)

		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(3), [tengu])

		assert_eq(tengu.get_remaining_need("joy"), 0,
			"Joy needs should be 0 after transform")
		assert_eq(tengu.get_remaining_need("food"), 6,
			"Remaining 6 joy should have become food")

	func test_food_fulfillment_transforms_remaining_to_joy():
		var tengu = create_guest("tengu")
		register_guest(tengu, Vector2i(1, 0))

		# First: transform to food form
		tengu.fulfill_need("joy", 3)
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(3), [tengu])

		# Now fulfill 2 food, fire on_need_fulfilled
		tengu.fulfill_need("food", 2)

		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("food").with_amount(2), [tengu])

		assert_eq(tengu.get_remaining_need("food"), 0,
			"Food needs should be 0 after transform back")
		assert_eq(tengu.get_remaining_need("joy"), 4,
			"Remaining 4 food should have become joy")

	func test_full_alternation_cycle():
		var tengu = create_guest("tengu")
		register_guest(tengu, Vector2i(1, 0))

		# Cycle 1: fulfill 4 joy -> 5 food
		tengu.fulfill_need("joy", 4)
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(4), [tengu])
		assert_eq(tengu.get_remaining_need("food"), 5, "Cycle 1: 5 food remaining")

		# Cycle 2: fulfill 3 food -> 2 joy
		tengu.fulfill_need("food", 3)
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("food").with_amount(3), [tengu])
		assert_eq(tengu.get_remaining_need("joy"), 2, "Cycle 2: 2 joy remaining")

		# Cycle 3: fulfill all joy -> ascend-ready
		tengu.fulfill_need("joy", 2)
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(2), [tengu])

		assert_true(tengu.are_all_needs_fulfilled(),
			"Tengu should be fully fulfilled after complete cycle")

	func test_no_transform_when_all_needs_fulfilled():
		var tengu = create_guest("tengu")
		register_guest(tengu, Vector2i(1, 0))

		# Fulfill all 9 joy at once (overfulfill scenario)
		tengu.fulfill_need("joy", 9)

		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(9), [tengu])

		assert_eq(tengu.get_remaining_need("food"), 0,
			"No food needs should appear when joy was fully fulfilled")
		assert_true(tengu.are_all_needs_fulfilled(),
			"Tengu should be fully fulfilled")

	func test_initial_needs_updated_for_display():
		var tengu = create_guest("tengu")
		register_guest(tengu, Vector2i(1, 0))

		tengu.fulfill_need("joy", 3)
		fire_for("on_need_fulfilled", TriggerContext.create("on_need_fulfilled") \
			.with_guest(tengu).with_source(tengu) \
			.with_need_type("joy").with_amount(3), [tengu])

		assert_eq(tengu.initial_needs.get("food", 0), 6,
			"Initial food should reflect transformed amount for display")
		assert_eq(tengu.initial_needs.get("joy", 0), 3,
			"Initial joy should reflect only the already-fulfilled portion")
```

**Step 2: Run tests to verify they pass**

Run: `"/Users/pern/Downloads/Godot.app/Contents/MacOS/Godot" -d -s --path /Users/pern/night addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_on_need_fulfilled_skills.gd`

Expected: All `TestTenguTransform` tests PASS (5 tests). Existing tests also pass.
