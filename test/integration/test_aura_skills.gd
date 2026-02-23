# test/integration/test_aura_skills.gd
extends "res://test/helpers/test_base.gd"


class TestMoonShrineAura:
	extends "res://test/helpers/test_base.gd"

	var aura_system: AuraSystem

	func before_each():
		super.before_each()
		aura_system = AuraSystem.new()
		add_child(aura_system)
		aura_system.set_board_system(BoardSystem)
		aura_system.set_status_effect_system(status_effect_system)
		BoardSystem.set_aura_system(aura_system)

	func after_each():
		BoardSystem.set_aura_system(null)
		if aura_system:
			aura_system.clear_all()
			remove_child(aura_system)
			aura_system.free()
			aura_system = null
		super.after_each()

	func register_stall_with_aura(stall: StallInstance, position: Vector2i) -> void:
		register_stall(stall, position)
		EventBus.stall_placed.emit(stall, null)

	# --- Before midnight: dormant ---

	func test_no_buff_before_midnight():
		var shrine = create_stall("moon_shrine")
		var target = create_stall("noodle_stand")
		register_stall_with_aura(shrine, Vector2i(2, 1))
		register_stall_with_aura(target, Vector2i(3, 1))

		assert_false(target.has_status("moonlit_1"),
			"Adjacent stall should not have moonlit before midnight")
		var tier_data = target.get_current_tier_data()
		assert_eq(target.get_value(), tier_data.value,
			"Adjacent stall value should be unmodified before midnight")

	func test_no_aura_tiles_shown_before_midnight():
		var shrine = create_stall("moon_shrine")
		register_stall_with_aura(shrine, Vector2i(2, 1))

		var tiles = aura_system.get_all_aura_tiles()
		assert_true(tiles.is_empty(),
			"No aura tiles should be visible before midnight")

	# --- After midnight: active ---

	func test_buffs_adjacent_stall_after_midnight():
		var shrine = create_stall("moon_shrine")
		var target = create_stall("noodle_stand")
		register_stall_with_aura(shrine, Vector2i(2, 1))
		register_stall_with_aura(target, Vector2i(3, 1))

		EventBus.midnight_reached.emit()

		assert_true(target.has_status("moonlit_1"),
			"Adjacent stall should have moonlit_1 after midnight")
		var tier_data = target.get_current_tier_data()
		assert_eq(target.get_value(), tier_data.value + 1,
			"Adjacent stall value should be +1 after midnight")

	func test_does_not_buff_self():
		var shrine = create_stall("moon_shrine")
		register_stall_with_aura(shrine, Vector2i(2, 1))

		EventBus.midnight_reached.emit()

		assert_false(shrine.has_status("moonlit_1"),
			"Moon Shrine should not buff itself")

	func test_does_not_buff_distant_stall():
		var shrine = create_stall("moon_shrine")
		var distant = create_stall("noodle_stand")
		register_stall_with_aura(shrine, Vector2i(2, 1))
		register_stall_with_aura(distant, Vector2i(4, 1))

		EventBus.midnight_reached.emit()

		assert_false(distant.has_status("moonlit_1"),
			"Stall 2 tiles away should not receive moonlit buff")

	func test_buffs_multiple_adjacent_stalls():
		var shrine = create_stall("moon_shrine")
		var target_a = create_stall("noodle_stand")
		var target_b = create_stall("game_booth")
		register_stall_with_aura(shrine, Vector2i(2, 1))
		register_stall_with_aura(target_a, Vector2i(3, 1))
		register_stall_with_aura(target_b, Vector2i(1, 1))

		EventBus.midnight_reached.emit()

		assert_true(target_a.has_status("moonlit_1"),
			"First adjacent stall should have moonlit")
		assert_true(target_b.has_status("moonlit_1"),
			"Second adjacent stall should have moonlit")

	# --- Tier scaling ---

	func test_tier_2_gives_plus_2_value():
		var shrine = create_stall("moon_shrine")
		shrine.upgrade()
		var target = create_stall("noodle_stand")
		register_stall_with_aura(shrine, Vector2i(2, 1))
		register_stall_with_aura(target, Vector2i(3, 1))

		EventBus.midnight_reached.emit()

		assert_true(target.has_status("moonlit_2"),
			"Tier 2 shrine should apply moonlit_2")
		var tier_data = target.get_current_tier_data()
		assert_eq(target.get_value(), tier_data.value + 2,
			"Adjacent stall value should be +2 from tier 2 shrine")

	func test_tier_3_gives_plus_3_value():
		var shrine = create_stall("moon_shrine")
		shrine.upgrade()
		shrine.upgrade()
		var target = create_stall("noodle_stand")
		register_stall_with_aura(shrine, Vector2i(2, 1))
		register_stall_with_aura(target, Vector2i(3, 1))

		EventBus.midnight_reached.emit()

		assert_true(target.has_status("moonlit_3"),
			"Tier 3 shrine should apply moonlit_3")
		var tier_data = target.get_current_tier_data()
		assert_eq(target.get_value(), tier_data.value + 3,
			"Adjacent stall value should be +3 from tier 3 shrine")

	# --- Stall placed after midnight ---

	func test_stall_placed_after_midnight_gets_buff():
		var shrine = create_stall("moon_shrine")
		register_stall_with_aura(shrine, Vector2i(2, 1))

		EventBus.midnight_reached.emit()

		var target = create_stall("noodle_stand")
		register_stall_with_aura(target, Vector2i(3, 1))

		assert_true(target.has_status("moonlit_1"),
			"Stall placed after midnight should receive moonlit from active shrine")
