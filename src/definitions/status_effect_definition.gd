class_name StatusEffectDefinition extends BaseDefinition

var effect_type: String  # buff, debuff
var stack_type: String  # time, trigger, passive
var max_stacks: int
var initial_stacks: int = 1
var applicable_to: Array[String]  # ["guest", "stall"]
var stat_modifiers: Array[Dictionary]
var on_apply_effects: Array[Dictionary]
var on_turn_end_effects: Array[Dictionary]
var on_remove_effects: Array[Dictionary]
var is_aura: bool = false
var aura_range: int = 0
var aura_target_filter: Dictionary
var granted_skills: Array[Dictionary] = []  # Skills granted to target while active
var visual: Dictionary  # particle_effect, tint_color


static func from_dict(data: Dictionary) -> StatusEffectDefinition:
	var def = StatusEffectDefinition.new()
	def._populate_from_dict(data)

	def.effect_type = data.get("effect_type", "buff")
	def.stack_type = data.get("stack_type", "time")
	def.max_stacks = data.get("max_stacks", 1)
	def.initial_stacks = data.get("initial_stacks", 1)
	def.applicable_to = Array(data.get("applicable_to", []), TYPE_STRING, "", null)
	def.is_aura = data.get("is_aura", false)
	def.aura_range = data.get("aura_range", 0)
	def.aura_target_filter = data.get("aura_target_filter", {})
	def.visual = data.get("visual", {})

	var stat_mods: Array[Dictionary] = []
	for mod in data.get("stat_modifiers", []):
		stat_mods.append(mod)
	def.stat_modifiers = stat_mods

	var apply_effects: Array[Dictionary] = []
	for effect in data.get("on_apply_effects", []):
		apply_effects.append(effect)
	def.on_apply_effects = apply_effects

	var turn_effects: Array[Dictionary] = []
	for effect in data.get("on_turn_end_effects", []):
		turn_effects.append(effect)
	def.on_turn_end_effects = turn_effects

	var remove_effects: Array[Dictionary] = []
	for effect in data.get("on_remove_effects", []):
		remove_effects.append(effect)
	def.on_remove_effects = remove_effects

	var g_skills: Array[Dictionary] = []
	for skill_data in data.get("granted_skills", []):
		g_skills.append(skill_data)
	def.granted_skills = g_skills

	return def
