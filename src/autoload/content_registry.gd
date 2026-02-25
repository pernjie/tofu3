extends Node

var heroes: Dictionary = {}          # id -> HeroDefinition
var guests: Dictionary = {}          # id -> GuestDefinition
var stalls: Dictionary = {}          # id -> StallDefinition
var spells: Dictionary = {}          # id -> SpellDefinition
var relics: Dictionary = {}          # id -> RelicDefinition
var skills: Dictionary = {}          # id -> SkillDefinition
var status_effects: Dictionary = {}  # id -> StatusEffectDefinition
var enhancements: Dictionary = {}    # id -> EnhancementDefinition
var levels: Dictionary = {}          # id -> LevelDefinition
var runs: Dictionary = {}              # id -> RunDefinition

var _type_to_dict: Dictionary = {}
var _type_to_class: Dictionary = {}


func _ready() -> void:
	_setup_type_mappings()
	_load_all_content("res://data/")
	_load_mod_content("user://mods/")
	_print_load_summary()


func _setup_type_mappings() -> void:
	_type_to_dict = {
		"heroes": heroes,
		"guests": guests,
		"stalls": stalls,
		"spells": spells,
		"relics": relics,
		"skills": skills,
		"status_effects": status_effects,
		"enhancements": enhancements,
		"levels": levels,
		"runs": runs,
	}

	_type_to_class = {
		"heroes": HeroDefinition,
		"guests": GuestDefinition,
		"stalls": StallDefinition,
		"spells": SpellDefinition,
		"relics": RelicDefinition,
		"skills": SkillDefinition,
		"status_effects": StatusEffectDefinition,
		"enhancements": EnhancementDefinition,
		"levels": LevelDefinition,
		"runs": RunDefinition,
	}


func _load_all_content(base_path: String) -> void:
	for type_name in _type_to_dict.keys():
		var dir_path = base_path + type_name + "/"
		_load_directory(type_name, dir_path)


func _load_mod_content(mods_path: String) -> void:
	if not DirAccess.dir_exists_absolute(mods_path):
		return

	var mods_dir = DirAccess.open(mods_path)
	if mods_dir == null:
		return

	mods_dir.list_dir_begin()
	var mod_name = mods_dir.get_next()
	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var mod_data_path = mods_path + mod_name + "/data/"
			if DirAccess.dir_exists_absolute(mod_data_path):
				print("[ContentRegistry] Loading mod: ", mod_name)
				for type_name in _type_to_dict.keys():
					var dir_path = mod_data_path + type_name + "/"
					_load_directory(type_name, dir_path)
		mod_name = mods_dir.get_next()
	mods_dir.list_dir_end()


func _load_directory(type_name: String, dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return

	var dir = DirAccess.open(dir_path)
	if dir == null:
		push_warning("[ContentRegistry] Could not open directory: " + dir_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json") and not file_name.begins_with("_"):
			var file_path = dir_path + file_name
			_load_definition_file(type_name, file_path)
		elif dir.current_is_dir() and not file_name.begins_with("."):
			# Recurse into subdirectories
			_load_directory(type_name, dir_path + file_name + "/")
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_definition_file(type_name: String, file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("[ContentRegistry] Could not open file: " + file_path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("[ContentRegistry] JSON parse error in " + file_path + ": " + json.get_error_message())
		return

	var data = json.data
	if not data is Dictionary:
		push_error("[ContentRegistry] Invalid JSON structure in " + file_path)
		return

	var definition = _create_definition(type_name, data)
	if definition == null:
		push_error("[ContentRegistry] Failed to create definition from " + file_path)
		return

	var target_dict = _type_to_dict.get(type_name)
	if target_dict != null:
		if target_dict.has(definition.id):
			print("[ContentRegistry] Overriding definition: ", type_name, "/", definition.id)
		target_dict[definition.id] = definition


func _create_definition(type_name: String, data: Dictionary) -> BaseDefinition:
	var def_class = _type_to_class.get(type_name)
	if def_class == null:
		push_error("[ContentRegistry] Unknown type: " + type_name)
		return null

	return def_class.from_dict(data)


func _print_load_summary() -> void:
	print("[ContentRegistry] === Load Summary ===")
	for type_name in _type_to_dict.keys():
		var count = _type_to_dict[type_name].size()
		if count > 0:
			print("[ContentRegistry]   ", type_name, ": ", count)
	print("[ContentRegistry] ===================")


func get_definition(type: String, id: String) -> BaseDefinition:
	var target_dict = _type_to_dict.get(type)
	if target_dict == null:
		push_warning("[ContentRegistry] Unknown type: " + type)
		return null

	if not target_dict.has(id):
		push_warning("[ContentRegistry] Definition not found: " + type + "/" + id)
		return null

	return target_dict[id]


func get_all_of_type(type: String) -> Array[BaseDefinition]:
	var target_dict = _type_to_dict.get(type)
	if target_dict == null:
		push_warning("[ContentRegistry] Unknown type: " + type)
		return []

	var result: Array[BaseDefinition] = []
	for def in target_dict.values():
		result.append(def)
	return result


func get_card_definition(card_id: String) -> CardDefinition:
	for dict in [stalls, spells, relics]:
		if dict.has(card_id):
			return dict[card_id] as CardDefinition
	return null


func get_by_tag(type: String, tag: String) -> Array[BaseDefinition]:
	var all_defs = get_all_of_type(type)
	var result: Array[BaseDefinition] = []
	for def in all_defs:
		if def.tags.has(tag):
			result.append(def)
	return result
