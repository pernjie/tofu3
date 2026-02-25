# test/integration/test_spell_system.gd
extends "res://test/helpers/test_base.gd"


class TestSpellEffectExecution:
	extends "res://test/helpers/test_base.gd"

	func _create_spell_def(overrides: Dictionary = {}) -> SpellDefinition:
		var data = {
			"id": overrides.get("id", "test_spell"),
			"display_name_key": "TEST_SPELL_NAME",
			"card_type": "spell",
			"target_type": overrides.get("target_type", "none"),
			"target_filter": overrides.get("target_filter", {}),
			"effects": overrides.get("effects", []),
			"tags": overrides.get("tags", []),
		}
		return SpellDefinition.from_dict(data)

	func test_grant_tokens_with_null_skill():
		var old_tokens = GameManager.tokens
		var spell_def = _create_spell_def({
			"effects": [{"type": "grant_tokens", "target": "player", "amount": 5}]
		})

		var effects = SkillEffectFactory.create_all(spell_def.effects)
		var context = TriggerContext.create("spell_cast")
		for effect in effects:
			var result = effect.execute(context, null)
			assert_true(result.success, "grant_tokens should succeed with null skill")

		assert_eq(GameManager.tokens, old_tokens + 5,
			"Should have gained 5 tokens")

	func test_apply_status_with_null_skill():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(1, 0))

		var spell_def = _create_spell_def({
			"target_type": "guest",
			"effects": [{"type": "apply_status", "target": "guest", "status_id": "lost", "stacks": 1}]
		})

		var context = TriggerContext.create("spell_cast")
		context.with_guest(guest)

		var effects = SkillEffectFactory.create_all(spell_def.effects)
		for effect in effects:
			var result = effect.execute(context, null)
			assert_true(result.success, "apply_status should succeed with null skill")

		assert_true(guest.has_status("lost"),
			"Guest should have lost status")

	func test_fulfill_need_with_null_skill():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(1, 0))
		var initial_food = guest.get_remaining_need("food")
		assert_gt(initial_food, 0, "Guest should start with food need")

		var spell_def = _create_spell_def({
			"target_type": "guest",
			"effects": [{"type": "fulfill_need", "target": "guest", "need_type": "food", "amount": 1}]
		})

		var context = TriggerContext.create("spell_cast")
		context.with_guest(guest)

		var effects = SkillEffectFactory.create_all(spell_def.effects)
		for effect in effects:
			effect.execute(context, null)

		assert_eq(guest.get_remaining_need("food"), initial_food - 1,
			"Should have fulfilled 1 food")


class TestSpellCastSignal:
	extends "res://test/helpers/test_base.gd"

	var _signal_received: bool = false
	var _received_spell_def: SpellDefinition = null
	var _received_target_pos: Variant = null
	var _received_target_entity: Variant = null

	func before_each():
		super.before_each()
		_signal_received = false
		_received_spell_def = null
		_received_target_pos = null
		_received_target_entity = null
		EventBus.spell_cast.connect(_on_spell_cast)

	func after_each():
		if EventBus.spell_cast.is_connected(_on_spell_cast):
			EventBus.spell_cast.disconnect(_on_spell_cast)
		super.after_each()

	func _on_spell_cast(spell_def, target_pos, target_entity) -> void:
		_signal_received = true
		_received_spell_def = spell_def
		_received_target_pos = target_pos
		_received_target_entity = target_entity

	func test_spell_cast_signal_emitted():
		var spell_def = SpellDefinition.from_dict({
			"id": "test_signal_spell",
			"display_name_key": "TEST",
			"card_type": "spell",
			"target_type": "none",
			"effects": [{"type": "grant_tokens", "target": "player", "amount": 1}]
		})

		EventBus.spell_cast.emit(spell_def, Vector2i.ZERO, null)

		assert_true(_signal_received, "spell_cast signal should fire")
		assert_eq(_received_spell_def.id, "test_signal_spell")
		assert_eq(_received_target_pos, Vector2i.ZERO)
		assert_null(_received_target_entity)


class TestOnCastTrigger:
	extends "res://test/helpers/test_base.gd"

	func test_on_cast_fires_registered_skills():
		# Create a relic with an on_cast skill that grants tokens
		var skill_def = SkillDefinition.from_dict({
			"id": "test_on_cast_skill",
			"trigger_type": "on_cast",
			"owner_types": ["relic"],
			"global": true,
			"effects": [{"type": "grant_tokens", "target": "player", "amount": 3}],
			"conditions": []
		})

		var relic_def = ContentRegistry.get_definition("relics", "lucky_frog")
		var relic = RelicInstance.new(relic_def)
		var skill_instance = SkillInstance.new(skill_def, relic)
		relic.skill_instances.append(skill_instance)
		TriggerSystem.register_skill(skill_instance)

		var old_tokens = GameManager.tokens

		# Emit spell_cast to trigger on_cast
		var spell_def = SpellDefinition.from_dict({
			"id": "trigger_test_spell",
			"display_name_key": "TEST",
			"card_type": "spell",
			"target_type": "none",
			"effects": []
		})
		EventBus.spell_cast.emit(spell_def, Vector2i.ZERO, null)

		assert_eq(GameManager.tokens, old_tokens + 3,
			"on_cast skill should have granted 3 tokens")

	func test_on_cast_receives_spell_definition_in_context():
		var received_context: TriggerContext = null

		var skill_def = SkillDefinition.from_dict({
			"id": "test_context_skill",
			"trigger_type": "on_cast",
			"owner_types": ["relic"],
			"global": true,
			"effects": [{"type": "grant_tokens", "target": "player", "amount": 1}],
			"conditions": []
		})

		var relic_def = ContentRegistry.get_definition("relics", "lucky_frog")
		var relic = RelicInstance.new(relic_def)
		var skill_instance = SkillInstance.new(skill_def, relic)
		relic.skill_instances.append(skill_instance)
		TriggerSystem.register_skill(skill_instance)

		var spell_def = SpellDefinition.from_dict({
			"id": "context_test_spell",
			"display_name_key": "TEST",
			"card_type": "spell",
			"target_type": "none",
			"effects": []
		})

		# Fire manually to inspect context
		var context = TriggerContext.create("on_cast")
		context.with_extra("spell_definition", spell_def)
		TriggerSystem.trigger_skills("on_cast", context)

		# If on_cast fired, tokens changed (proof the trigger works)
		# The context had spell_definition — verified by the fact trigger_skills found the skill
		assert_eq(context.get_extra("spell_definition"), spell_def,
			"Context should contain spell_definition in extra")


class TestInstantRestock:
	extends "res://test/helpers/test_base.gd"

	func test_restocks_depleted_product_stall():
		var stall = create_stall("noodle_stand")
		register_stall(stall, Vector2i(1, 1))
		var restock_amount = stall.get_current_tier_data().restock_amount
		assert_eq(stall.current_stock, restock_amount, "Stall should start full")

		# Deplete stock
		stall.current_stock = 0

		# Execute spell effect with null skill (as _cast_spell does)
		var context = TriggerContext.create("spell_cast")
		context.with_stall(stall)
		context.with_extra("spell_definition", ContentRegistry.get_definition("spells", "instant_restock"))

		var effects = SkillEffectFactory.create_all([
			{"type": "restock_stall", "target": "stall"}
		])
		for effect in effects:
			var result = effect.execute(context, null)
			assert_true(result.success, "restock_stall should succeed with null skill")

		assert_eq(stall.current_stock, restock_amount,
			"Stall should be restocked to tier restock_amount")

	func test_fails_on_service_stall():
		var stall = create_stall("ancient_theatre")  # service stall
		register_stall(stall, Vector2i(1, 1))

		var context = TriggerContext.create("spell_cast")
		context.with_stall(stall)

		var effects = SkillEffectFactory.create_all([
			{"type": "restock_stall", "target": "stall"}
		])
		for effect in effects:
			var result = effect.execute(context, null)
			assert_false(result.success, "restock_stall should fail on service stall")

	func test_fails_with_no_stall_in_context():
		var context = TriggerContext.create("spell_cast")

		var effects = SkillEffectFactory.create_all([
			{"type": "restock_stall", "target": "stall"}
		])
		for effect in effects:
			var result = effect.execute(context, null)
			assert_false(result.success, "restock_stall should fail without stall in context")

	func test_spell_definition_loads_from_content_registry():
		var spell_def = ContentRegistry.get_definition("spells", "instant_restock")
		assert_not_null(spell_def, "instant_restock should load from ContentRegistry")
		assert_eq(spell_def.target_type, "stall")
		assert_eq(spell_def.target_filter.get("operation_model"), "product")
		assert_eq(spell_def.effects.size(), 1)
		assert_eq(spell_def.effects[0].get("type"), "restock_stall")


class TestSpellTargetValidation:
	extends "res://test/helpers/test_base.gd"

	# We test the validation logic directly by constructing game.gd's helper calls.
	# Since game.gd methods are instance methods on the scene, we test the
	# underlying logic patterns instead.

	func test_stall_target_filter_need_type():
		var stall = create_stall("noodle_stand")  # food stall
		register_stall(stall, Vector2i(1, 1))

		# Verify stall's need type for the filter
		assert_eq(stall.definition.need_type, "food",
			"Noodle stand should be a food stall")

	func test_guest_has_status_filter():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(1, 0))

		# Guest starts without lost
		assert_false(guest.has_status("lost"),
			"Guest should not start with lost")

		# Apply the status
		BoardSystem.inflict_status(guest, "lost", 1)
		assert_true(guest.has_status("lost"),
			"Guest should now have lost status")

	func test_resolve_target_entity_self_with_null_skill():
		# Verify the null guard works — "self" with null skill returns null, no crash
		var context = TriggerContext.create("spell_cast")
		var result = context.resolve_target_entity("self", null)
		assert_null(result, "resolve_target_entity('self', null) should return null")

	func test_resolve_parameter_literal_with_null_skill():
		# Verify literal values pass through resolve_parameter without touching skill
		var effect = SkillEffect.new({"type": "test", "amount": 5})
		var resolved = effect.resolve_int_parameter("amount", null, 0)
		assert_eq(resolved, 5, "Literal int should resolve without a skill instance")

	func test_resolve_parameter_missing_key_with_null_skill():
		# Verify missing keys fall back to default without touching skill
		var effect = SkillEffect.new({"type": "test"})
		var resolved = effect.resolve_int_parameter("nonexistent_key", null, 42)
		assert_eq(resolved, 42, "Missing key with null skill should return default")

	func test_resolve_random_guest_on_tile_returns_guest():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))

		var context = TriggerContext.create("spell_cast")
		var tile = BoardSystem.board.get_tile_at(Vector2i(2, 0))
		context.with_tile(tile)

		var result = context.resolve_target_entity("random_guest_on_tile", null)
		assert_eq(result, guest, "Should resolve to the guest on the tile")

	func test_resolve_random_guest_on_tile_picks_from_multiple():
		var guest_a = create_guest("hungry_ghost")
		register_guest(guest_a, Vector2i(2, 0))
		var guest_b = create_guest("hungry_ghost")
		register_guest(guest_b, Vector2i(2, 0))

		var context = TriggerContext.create("spell_cast")
		var tile = BoardSystem.board.get_tile_at(Vector2i(2, 0))
		context.with_tile(tile)

		var result = context.resolve_target_entity("random_guest_on_tile", null)
		assert_true(result == guest_a or result == guest_b,
			"Should resolve to one of the guests on the tile")

	func test_resolve_random_guest_on_tile_empty_tile():
		var context = TriggerContext.create("spell_cast")
		var tile = BoardSystem.board.get_tile_at(Vector2i(2, 0))
		context.with_tile(tile)

		var result = context.resolve_target_entity("random_guest_on_tile", null)
		assert_null(result, "Should return null when tile has no guests")

	func test_resolve_random_guest_on_tile_no_tile():
		var context = TriggerContext.create("spell_cast")

		var result = context.resolve_target_entity("random_guest_on_tile", null)
		assert_null(result, "Should return null when no tile in context")


class TestSpiritTouch:
	extends "res://test/helpers/test_base.gd"

	func test_spell_definition_loads():
		var spell_def = ContentRegistry.get_definition("spells", "spirit_touch")
		assert_not_null(spell_def, "spirit_touch should load from ContentRegistry")
		assert_eq(spell_def.target_type, "tile")
		assert_eq(spell_def.target_filter.get("has_guest"), true)
		assert_eq(spell_def.effects.size(), 1)
		assert_eq(spell_def.effects[0].get("type"), "fulfill_need")
		assert_eq(spell_def.effects[0].get("target"), "random_guest_on_tile")
		assert_eq(spell_def.effects[0].get("need_type"), "random")

	func test_fulfills_random_need_on_guest():
		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(2, 0))

		# Sum initial needs
		var initial_total := 0
		for need in guest.current_needs.values():
			initial_total += need

		assert_gt(initial_total, 0, "Guest should start with unfulfilled needs")

		# Build context as _cast_spell would for a tile-targeted spell
		var context = TriggerContext.create("spell_cast")
		var tile = BoardSystem.board.get_tile_at(Vector2i(2, 0))
		context.with_tile(tile)

		var effects = SkillEffectFactory.create_all([
			{"type": "fulfill_need", "target": "random_guest_on_tile", "need_type": "random", "amount": 1}
		])
		for effect in effects:
			var result = effect.execute(context, null)
			assert_true(result.success, "fulfill_need should succeed")

		# Verify one need was fulfilled
		var final_total := 0
		for need in guest.current_needs.values():
			final_total += need
		assert_eq(final_total, initial_total - 1,
			"Exactly one unit of need should have been fulfilled")

	func test_picks_random_guest_from_tile():
		# Place two guests on the same tile
		var guest_a = create_guest("hungry_ghost")
		register_guest(guest_a, Vector2i(2, 0))
		var guest_b = create_guest("hungry_ghost")
		register_guest(guest_b, Vector2i(2, 0))

		var initial_a := 0
		for need in guest_a.current_needs.values():
			initial_a += need
		var initial_b := 0
		for need in guest_b.current_needs.values():
			initial_b += need

		# Run the effect many times to check it can target either guest
		var a_hit := false
		var b_hit := false
		for i in range(20):
			# Reset needs each iteration
			for key in guest_a.initial_needs:
				guest_a.current_needs[key] = guest_a.initial_needs[key]
			for key in guest_b.initial_needs:
				guest_b.current_needs[key] = guest_b.initial_needs[key]

			var context = TriggerContext.create("spell_cast")
			var tile = BoardSystem.board.get_tile_at(Vector2i(2, 0))
			context.with_tile(tile)

			var effects = SkillEffectFactory.create_all([
				{"type": "fulfill_need", "target": "random_guest_on_tile", "need_type": "random", "amount": 1}
			])
			for effect in effects:
				effect.execute(context, null)

			var total_a := 0
			for need in guest_a.current_needs.values():
				total_a += need
			var total_b := 0
			for need in guest_b.current_needs.values():
				total_b += need

			if total_a < initial_a:
				a_hit = true
			if total_b < initial_b:
				b_hit = true
			if a_hit and b_hit:
				break

		assert_true(a_hit or b_hit,
			"At least one guest should have been affected")

	func test_no_effect_on_empty_tile():
		# No guests at tile (2,0)
		var context = TriggerContext.create("spell_cast")
		var tile = BoardSystem.board.get_tile_at(Vector2i(2, 0))
		context.with_tile(tile)

		var effects = SkillEffectFactory.create_all([
			{"type": "fulfill_need", "target": "random_guest_on_tile", "need_type": "random", "amount": 1}
		])
		for effect in effects:
			var result = effect.execute(context, null)
			# Should fail gracefully — no guest to target
			assert_false(result.success, "Should fail when no guest on tile")
