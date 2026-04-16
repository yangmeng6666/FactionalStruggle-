class_name ConfigDatabase
extends RefCounted

const CONFIG_FILES := {
	"gameplay_rules": "gameplay_rules.json",
	"resources": "resources.json",
	"factions": "factions.json",
	"units": "units.json",
	"actions": "actions.json",
	"ai_behavior_trees": "ai_behavior_trees.json",
	"battle_setups": "battle_setups.json",
	"battle_rounds": "battle_rounds.json",
	"round_settlement": "round_settlement.json",
}

var _data: Dictionary = {}
var _errors: Array[String] = []


func load_all() -> bool:
	_data.clear()
	_errors.clear()

	for key in CONFIG_FILES.keys():
		var path := _resolve_config_path(CONFIG_FILES[key])
		var loaded := _load_json(path)
		if loaded.is_empty():
			continue
		_data[key] = loaded

	_validate()
	return _errors.is_empty()


func get_resource(resource_id: String) -> Dictionary:
	return _get_nested("resources", "resources", resource_id)


func get_resource_order() -> Array:
	return _data.get("resources", {}).get("display_order", [])


func get_faction(faction_id: String) -> Dictionary:
	return _get_nested("factions", "factions", faction_id)


func get_faction_ids() -> Array:
	return _data.get("factions", {}).get("factions", {}).keys()


func get_selectable_faction_ids() -> Array:
	var result: Array = []
	for faction_id in get_faction_ids():
		var id := String(faction_id)
		if id == "neutral":
			continue
		result.append(id)
	return result


func get_faction_behavior_tree_id(faction_id: String) -> String:
	return String(get_faction(faction_id).get("behavior_tree_id", ""))


func get_faction_allowed_action_ids(faction_id: String) -> Array:
	var faction: Dictionary = get_faction(faction_id)
	if faction.is_empty():
		return []
	return faction.get("allowed_action_ids", []).duplicate()


func get_faction_display_name(faction_id: String) -> String:
	return String(get_faction(faction_id).get("display_name", faction_id))


func get_unit(unit_id: String) -> Dictionary:
	return _get_nested("units", "units", unit_id)


func get_unit_ids() -> Array:
	return _data.get("units", {}).get("units", {}).keys()


func get_action(action_id: String) -> Dictionary:
	return _get_nested("actions", "actions", action_id)


func get_action_group(group_id: String) -> Dictionary:
	return _get_nested("actions", "action_groups", group_id)


func get_action_groups_for_phase(phase_id: String, faction_id: String = "", controller_override: String = "") -> Array:
	var result: Array = []
	var groups: Dictionary = _data.get("actions", {}).get("action_groups", {})
	var ordered_ids: Array = _data.get("actions", {}).get("group_order", groups.keys())
	for group_id in ordered_ids:
		var group: Dictionary = groups.get(group_id, {})
		if group.get("phase", "") != phase_id:
			continue
		var has_options := false
		for action in get_action_options_for_group(String(group_id), faction_id, controller_override):
			if action is Dictionary:
				has_options = true
				break
		if not has_options:
			continue
		var entry := group.duplicate(true)
		entry["id"] = group_id
		result.append(entry)
	return result


func get_action_options_for_group(group_id: String, faction_id: String = "", controller_override: String = "") -> Array:
	var result: Array = []
	var group: Dictionary = get_action_group(group_id)
	if group.is_empty():
		return result
	for action_id in group.get("actions", []):
		var action: Dictionary = get_action(String(action_id))
		if action.is_empty():
			continue
		if not _action_matches_faction(String(action_id), action, faction_id, controller_override):
			continue
		var entry := action.duplicate(true)
		entry["id"] = String(action_id)
		result.append(entry)
	return result


func get_actions_for_phase(phase_id: String, faction_id: String = "", controller_override: String = "") -> Array:
	var result: Array = []
	var actions: Dictionary = _data.get("actions", {}).get("actions", {})
	var ordered_ids: Array = _data.get("actions", {}).get("display_order", actions.keys())
	for action_id in ordered_ids:
		var action: Dictionary = actions.get(action_id, {})
		if action.get("phase", "") != phase_id:
			continue
		if not _action_matches_faction(String(action_id), action, faction_id, controller_override):
			continue
		var entry := action.duplicate(true)
		entry["id"] = action_id
		result.append(entry)
	return result


func get_behavior_tree(tree_id: String) -> Dictionary:
	return _get_nested("ai_behavior_trees", "behavior_trees", tree_id)


func get_battle_setup(setup_id: String) -> Dictionary:
	return _get_nested("battle_setups", "setups", setup_id)


func get_round_battle(round: int) -> Dictionary:
	var rounds: Dictionary = _data.get("battle_rounds", {}).get("rounds", {})
	if rounds.is_empty():
		return {}
	var best_key := ""
	for round_key in rounds.keys():
		var current_key := String(round_key)
		if int(current_key) <= round and (best_key == "" or int(current_key) > int(best_key)):
			best_key = current_key
	if best_key == "":
		var ordered_keys: Array = rounds.keys()
		ordered_keys.sort_custom(func(a, b): return int(a) < int(b))
		best_key = String(ordered_keys[-1])
	var battle: Dictionary = rounds.get(best_key, {}).duplicate(true)
	battle["round"] = int(best_key)
	return battle


func get_round_settlement() -> Dictionary:
	return _data.get("round_settlement", {}).duplicate(true)


func get_round_resource_rules() -> Dictionary:
	return _data.get("round_settlement", {}).get("round_parameters", {}).get("resources", {}).duplicate(true)


func get_round_resource_rule(resource_id: String) -> Dictionary:
	return get_round_resource_rules().get(resource_id, {}).duplicate(true)


func get_round_resource_max(resource_id: String):
	return get_round_resource_rule(resource_id).get("max", 0)


func get_round_resource_reset_each_round(resource_id: String) -> bool:
	return bool(get_round_resource_rule(resource_id).get("reset_each_round", false))


func get_default_battle_scene_id() -> String:
	var battle: Dictionary = _data.get("gameplay_rules", {}).get("battle", {})
	var default_scene_id := String(battle.get("default_scene_id", ""))
	if default_scene_id != "":
		return default_scene_id
	var scenes: Dictionary = battle.get("scenes", {})
	for scene_id in scenes.keys():
		return String(scene_id)
	return ""


func get_battle_scene(scene_id: String) -> Dictionary:
	var battle: Dictionary = _data.get("gameplay_rules", {}).get("battle", {})
	var scenes: Dictionary = battle.get("scenes", {})
	var resolved_scene_id := scene_id
	if resolved_scene_id == "" or not scenes.has(resolved_scene_id):
		resolved_scene_id = get_default_battle_scene_id()
	return scenes.get(resolved_scene_id, {}).duplicate(true)


func get_battle_scene_path(scene_id: String = "") -> String:
	return String(get_battle_scene(scene_id).get("scene_path", ""))


func get_min_corps_morale(scene_id: String = "") -> int:
	return int(get_battle_scene(scene_id).get("min_corps_morale", 0))


func get_phase_display_name(phase_id: String) -> String:
	if phase_id == "":
		return ""
	for phase in _data.get("gameplay_rules", {}).get("phases", []):
		if String(phase.get("id", "")) == phase_id:
			return String(phase.get("display_name", ""))
	return ""


func get_player_faction_id() -> String:
	return String(_data.get("gameplay_rules", {}).get("player_faction_id", ""))


func get_starting_round() -> int:
	return int(_data.get("gameplay_rules", {}).get("starting_round", 1))


func get_default_battle_setup_id(scene_id: String = "") -> String:
	return String(get_battle_scene(scene_id).get("default_battle_setup_id", ""))


func get_battle_target_refresh_interval(scene_id: String = "") -> float:
	return float(get_battle_scene(scene_id).get("target_refresh_interval", 0.25))


func get_management_action_order() -> Array:
	return _data.get("gameplay_rules", {}).get("management", {}).get("action_order", [])


func get_effective_action_point_cost(action_id: String, usage_count: int) -> int:
	var action := get_action(action_id)
	if action.is_empty():
		return 0
	var base_cost := int(action.get("ap_cost", 0))
	var increment := int(action.get("ap_increment", 0))
	return base_cost + increment * maxi(0, usage_count)


func get_errors() -> Array[String]:
	return _errors.duplicate()


func _get_external_config_dir() -> String:
	var executable_path := OS.get_executable_path()
	if executable_path == "":
		return ""
	var executable_dir := executable_path.get_base_dir()
	var sibling_config_dir := executable_dir.get_base_dir().path_join("configs")
	if DirAccess.dir_exists_absolute(sibling_config_dir):
		return sibling_config_dir
	return executable_dir.path_join("configs")


func _resolve_config_path(file_name: String) -> String:
	var external_dir := _get_external_config_dir()
	if external_dir != "":
		var external_path := external_dir.path_join(file_name)
		if FileAccess.file_exists(external_path):
			return external_path
	return "res://configs/%s" % file_name


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_errors.append("Missing config file: %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Cannot open config file: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_errors.append("Invalid JSON object: %s" % path)
		return {}

	return parsed


func _get_nested(config_key: String, section_key: String, item_id: String) -> Dictionary:
	return _data.get(config_key, {}).get(section_key, {}).get(item_id, {}).duplicate(true)


func _action_matches_faction(action_id: String, action: Dictionary, faction_id: String, controller_override: String = "") -> bool:
	var controller := controller_override
	if action.get("visible", true) == false and controller == "player":
		return false
	var required_controller := String(action.get("controller", ""))
	if required_controller != "" and controller != "" and required_controller != controller:
		return false
	if faction_id == "":
		return true
	return get_faction_allowed_action_ids(faction_id).has(action_id)


func _validate() -> void:
	_require_section("gameplay_rules", "battle")
	_require_section("resources", "resources")
	_require_section("factions", "factions")
	_require_section("units", "units")
	_require_section("actions", "actions")
	_require_section("ai_behavior_trees", "behavior_trees")
	_require_section("battle_setups", "setups")
	_require_section("battle_rounds", "rounds")

	var player_faction_id := get_player_faction_id()
	if player_faction_id != "" and get_faction(player_faction_id).is_empty():
		_errors.append("Unknown player faction: %s" % player_faction_id)

	var battle_rules: Dictionary = _data.get("gameplay_rules", {}).get("battle", {})
	var default_scene_id := get_default_battle_scene_id()
	var battle_scenes: Dictionary = battle_rules.get("scenes", {})
	if default_scene_id == "" or not battle_scenes.has(default_scene_id):
		_errors.append("Unknown default battle scene: %s" % default_scene_id)
	for scene_id in battle_scenes.keys():
		var battle_scene: Dictionary = get_battle_scene(String(scene_id))
		var scene_path := String(battle_scene.get("scene_path", ""))
		if scene_path == "" or not ResourceLoader.exists(scene_path, "PackedScene"):
			_errors.append("Battle scene %s references invalid scene path %s" % [scene_id, scene_path])
		var default_battle_setup_id := String(battle_scene.get("default_battle_setup_id", ""))
		if default_battle_setup_id == "" or get_battle_setup(default_battle_setup_id).is_empty():
			_errors.append("Battle scene %s references unknown default battle setup %s" % [scene_id, default_battle_setup_id])

	for faction_id in _data.get("factions", {}).get("factions", {}).keys():
		var faction: Dictionary = get_faction(String(faction_id))
		for action_id in faction.get("allowed_action_ids", []):
			if get_action(String(action_id)).is_empty():
				_errors.append("Faction %s allows unknown action %s" % [faction_id, action_id])
		for army_entry in faction.get("initial_army", []):
			var unit_id := String(army_entry.get("unit_id", ""))
			if unit_id != "" and get_unit(unit_id).is_empty():
				_errors.append("Faction %s references unknown unit %s" % [faction_id, unit_id])
		var tree_id := String(faction.get("behavior_tree_id", ""))
		if tree_id == "" or get_behavior_tree(tree_id).is_empty():
			_errors.append("Faction %s references unknown behavior tree %s" % [faction_id, tree_id])

	for group_id in _data.get("actions", {}).get("action_groups", {}).keys():
		var group: Dictionary = get_action_group(String(group_id))
		for action_id in group.get("actions", []):
			if get_action(String(action_id)).is_empty():
				_errors.append("Action group %s references unknown action %s" % [group_id, action_id])

	for group_id in _data.get("actions", {}).get("group_order", []):
		if get_action_group(String(group_id)).is_empty():
			_errors.append("Group order references unknown action group %s" % group_id)

	for action_id in _data.get("actions", {}).get("display_order", []):
		if get_action(String(action_id)).is_empty():
			_errors.append("Display order references unknown action %s" % action_id)

	for action_id in _data.get("actions", {}).get("actions", {}).keys():
		var action: Dictionary = get_action(String(action_id))
		for unit_id in action.get("unit_options", []):
			if get_unit(String(unit_id)).is_empty():
				_errors.append("Action %s references unknown unit %s" % [action_id, unit_id])
		for effect in action.get("effects", []):
			_validate_effect_unit_reference(String(action_id), effect)

	for tree_id in _data.get("ai_behavior_trees", {}).get("behavior_trees", {}).keys():
		var tree: Dictionary = get_behavior_tree(String(tree_id))
		_validate_behavior_tree_template(String(tree_id), tree)

	for setup_id in _data.get("battle_setups", {}).get("setups", {}).keys():
		var setup: Dictionary = get_battle_setup(String(setup_id))
		var battle_scene_id := String(setup.get("battle_scene_id", ""))
		if battle_scene_id == "" or get_battle_scene(battle_scene_id).is_empty():
			_errors.append("Battle setup %s references unknown battle scene %s" % [setup_id, battle_scene_id])

	for round_key in _data.get("battle_rounds", {}).get("rounds", {}).keys():
		var battle := get_round_battle(int(round_key))
		var battle_scene_id := String(battle.get("battle_scene_id", ""))
		if battle_scene_id != "" and get_battle_scene(battle_scene_id).is_empty():
			_errors.append("Round battle %s references unknown battle scene %s" % [round_key, battle_scene_id])
		for army_entry in battle.get("enemy_army", []):
			var unit_id := String(army_entry.get("unit_id", ""))
			if unit_id != "" and get_unit(unit_id).is_empty():
				_errors.append("Round battle %s references unknown unit %s" % [round_key, unit_id])

	var round_resource_rules: Dictionary = get_round_resource_rules()
	if get_round_resource_rule("action_points").is_empty():
		_errors.append("Round parameters are missing action_points resource rule")
	for resource_id_variant in round_resource_rules.keys():
		var resource_id := String(resource_id_variant)
		if get_resource(resource_id).is_empty():
			_errors.append("Round parameters reference unknown resource %s" % resource_id)


func _validate_effect_unit_reference(action_id: String, effect) -> void:
	if not effect is Dictionary:
		return
	var op := String(effect.get("op", ""))
	if op != "add_unit" and op != "add_army_unit":
		return
	var unit_id := String(effect.get("unit_id", ""))
	if unit_id != "" and get_unit(unit_id).is_empty():
		_errors.append("Action %s effect references unknown unit %s" % [action_id, unit_id])


func _validate_behavior_tree_template(tree_id: String, tree: Dictionary) -> void:
	if tree.has("rules"):
		var rules = tree.get("rules", [])
		if not rules is Array:
			_errors.append("Behavior tree %s has invalid rules" % tree_id)
			return
		for rule in rules:
			if not rule is Dictionary:
				_errors.append("Behavior tree %s contains invalid rule" % tree_id)
				continue
			var condition = rule.get("condition", {})
			if not condition is Dictionary or String(condition.get("type", "")) == "":
				_errors.append("Behavior tree %s contains invalid rule condition" % tree_id)
			for action_id in rule.get("candidate_action_ids", []):
				if get_action(String(action_id)).is_empty():
					_errors.append("Behavior tree %s references unknown candidate action %s" % [tree_id, action_id])
		return
	_validate_behavior_tree_node(tree_id, tree.get("root", {}))


func _validate_behavior_tree_node(tree_id: String, node) -> void:
	if not node is Dictionary:
		_errors.append("Behavior tree %s contains invalid node" % tree_id)
		return
	if String(node.get("type", "")) == "action":
		var action_id := String(node.get("action_id", ""))
		if get_action(action_id).is_empty():
			_errors.append("Behavior tree %s references unknown action %s" % [tree_id, action_id])
	for child in node.get("children", []):
		_validate_behavior_tree_node(tree_id, child)


func _require_section(config_key: String, section_key: String) -> void:
	if not _data.has(config_key):
		return
	if not _data[config_key].has(section_key):
		_errors.append("Config %s is missing section %s" % [config_key, section_key])
