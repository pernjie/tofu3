class_name StallTierData extends Resource

var tier: int
var cost_to_guest: int
var value: int  # How much need it fulfills
# Product-specific
var restock_amount: int
var restock_duration: int
# Service-specific
var service_duration: int
var capacity: int
var auto_restock: bool
# Skills active at this tier
var skill_data: Array[Dictionary]


static func from_dict(data: Dictionary) -> StallTierData:
	var tier_data = StallTierData.new()
	tier_data.tier = data.get("tier", 1)
	tier_data.cost_to_guest = data.get("cost_to_guest", 0)
	tier_data.value = data.get("value", 0)
	tier_data.restock_amount = data.get("restock_amount", 0)
	tier_data.restock_duration = data.get("restock_duration", 0)
	tier_data.service_duration = data.get("service_duration", 0)
	tier_data.capacity = data.get("capacity", 0)
	tier_data.auto_restock = data.get("auto_restock", true)

	var skills_arr: Array[Dictionary] = []
	for skill in data.get("skills", []):
		if skill is Dictionary:
			skills_arr.append(skill)
		elif skill is String:
			skills_arr.append({ "skill_id": skill })
	tier_data.skill_data = skills_arr

	return tier_data
