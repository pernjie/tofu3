# src/skill_effects/skill_effect_factory.gd
class_name SkillEffectFactory
extends RefCounted

## Factory for creating SkillEffect instances from effect data dictionaries.
## Maps effect type strings to their implementing classes.


static func create(effect_data: Dictionary) -> SkillEffect:
	## Create a SkillEffect from effect data dictionary.
	var effect_type = effect_data.get("type", "")

	match effect_type:
		"grant_tokens":
			return GrantTokensEffect.new(effect_data)
		"modify_stat":
			return ModifyStatEffect.new(effect_data)
		"fulfill_need":
			return FulfillNeedEffect.new(effect_data)
		"apply_status":
			return ApplyStatusEffect.new(effect_data)
		"increment_state":
			return IncrementStateEffect.new(effect_data)
		"chance_block_service":
			return ChanceBlockServiceEffect.new(effect_data)
		"chance_block_fulfillment":
			return ChanceBlockFulfillmentEffect.new(effect_data)
		"chance_reverse_movement":
			return ChanceReverseMovementEffect.new(effect_data)
		"restock_stall":
			return RestockStallEffect.new(effect_data)
		"reset_service_durations":
			return ResetServiceDurationsEffect.new(effect_data)
		"summon_guest":
			return SummonGuestEffect.new(effect_data)
		"modify_fulfillment":
			return ModifyFulfillmentEffect.new(effect_data)
		"bonus_restock":
			return BonusRestockEffect.new(effect_data)
		"steal_money":
			return StealMoneyEffect.new(effect_data)
		"remove_status":
			return RemoveStatusEffect.new(effect_data)
		"banish":
			return BanishEffect.new(effect_data)
		"banish_from_group":
			return BanishFromGroupEffect.new(effect_data)
		"force_ascend":
			return ForceAscendEffect.new(effect_data)
		"summon_from_queue":
			return SummonFromQueueEffect.new(effect_data)
		"add_to_beast_queue":
			return AddToBeastQueueEffect.new(effect_data)
		"discover":
			return DiscoverEffect.new(effect_data)
		"block_status":
			return BlockStatusEffect.new(effect_data)
		"block_banish":
			return BlockBanishEffect.new(effect_data)
		"spawn_next_from_queue":
			return SpawnNextFromQueueEffect.new(effect_data)
		"block_entry":
			return BlockEntryEffect.new(effect_data)
		"transform_need":
			return TransformNeedEffect.new(effect_data)
		"change_stall_need_type":
			return ChangeStallNeedTypeEffect.new(effect_data)
		"scale_stat_by_beast_count":
			return ScaleStatByBeastCountEffect.new(effect_data)
		"average_adjacent_stall_values":
			return AverageAdjacentStallValuesEffect.new(effect_data)
		"state_bonus_stock":
			return StateBonusStockEffect.new(effect_data)
		"grant_bonus_play":
			return GrantBonusPlayEffect.new(effect_data)
		"set_state":
			return SetStateEffect.new(effect_data)
		"clone_self":
			return CloneSelfEffect.new(effect_data)
		_:
			push_warning("Unknown effect type: %s" % effect_type)
			return SkillEffect.new(effect_data)


static func create_all(effects_array: Array) -> Array[SkillEffect]:
	## Create SkillEffect instances for all effects in an array.
	var result: Array[SkillEffect] = []
	for effect_data in effects_array:
		result.append(create(effect_data))
	return result
