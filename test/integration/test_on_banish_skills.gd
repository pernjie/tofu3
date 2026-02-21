# test/integration/test_on_banish_skills.gd
extends "res://test/helpers/test_base.gd"


class TestWhisperingAltarBanishRestock:
	extends "res://test/helpers/test_base.gd"

	func test_restocks_altar_on_banish():
		var altar = create_stall("whispering_altar")
		register_stall(altar, Vector2i(2, 1))
		altar.current_stock = 0  # depleted

		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(1, 0))

		fire_for("on_banish", TriggerContext.create("on_banish") \
			.with_guest(guest).with_source(guest), [guest])

		assert_eq(altar.current_stock, 1,
			"T1 altar should restock to 1 after banish")

	func test_t2_restocks_to_restock_amount():
		var altar = create_stall("whispering_altar")
		register_stall(altar, Vector2i(2, 1))
		BoardSystem.upgrade_stall(altar)
		altar.current_stock = 0

		var guest = create_guest("hungry_ghost")
		register_guest(guest, Vector2i(1, 0))

		fire_for("on_banish", TriggerContext.create("on_banish") \
			.with_guest(guest).with_source(guest), [guest])

		assert_eq(altar.current_stock, 2,
			"T2 altar should restock to 2 after banish")

	func test_no_auto_restock_after_depletion():
		var altar = create_stall("whispering_altar")
		register_stall(altar, Vector2i(2, 1))

		# Deplete stock — should NOT set restock cooldown
		altar.use_stock(1)
		assert_eq(altar.current_stock, 0,
			"Stock should be depleted")
		assert_eq(altar.restock_cooldown, 0,
			"Restock cooldown should remain 0 with auto_restock false")

	func test_no_restock_without_banish():
		var altar = create_stall("whispering_altar")
		register_stall(altar, Vector2i(2, 1))
		altar.current_stock = 0

		# Don't fire any banish event — stock should stay at 0
		assert_eq(altar.current_stock, 0,
			"Altar stock should stay 0 without banish trigger")
