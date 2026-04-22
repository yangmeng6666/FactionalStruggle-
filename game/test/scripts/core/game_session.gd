extends Node

signal selection_changed(selected_count: int)
signal phase_changed(phase: String)
signal campaign_state_changed(snapshot: Dictionary)
signal campaign_log_added(message: String)

const CONFIG_DATABASE_SCRIPT := preload("res://scripts/data/config_database.gd")

var current_phase: String = ""
var config = null
var campaign_state: Dictionary = {}
var _selected_squads: Array = []
var _config_loaded: bool = false
var _player_faction_id: String = ""


func _ready() -> void:
	add_to_group("game_session")


func start_new_campaign(faction_id: String = "") -> void:
	if not _ensure_config_loaded():
		campaign_state = {}
		campaign_state_changed.emit(get_campaign_snapshot())
		return

	var selectable_ids: Array = config.get_selectable_faction_ids()
	var selected_faction_id := String(faction_id)
	if selected_faction_id == "":
		selected_faction_id = config.get_player_faction_id()
	if selected_faction_id == "" and not selectable_ids.is_empty():
		selected_faction_id = String(selectable_ids[0])
	if not selectable_ids.has(selected_faction_id):
		push_warning("Cannot start campaign: unknown selectable faction %s" % selected_faction_id)
		campaign_state = {}
		campaign_state_changed.emit(get_campaign_snapshot())
		return
	_player_faction_id = selected_faction_id

	var factions: Dictionary = {}
	for current_faction_id in config.get_faction_ids():
		var runtime_faction_id := String(current_faction_id)
		var faction_resources: Dictionary = config.get_faction_initial_management_resources(runtime_faction_id)
		faction_resources["support_base"] = config.get_faction_initial_support_base(runtime_faction_id)
		faction_resources["owned_assets"] = config.get_faction_initial_owned_assets(runtime_faction_id)
		factions[runtime_faction_id] = {
			"faction_resources": faction_resources,
			"settlement_summary": [],
			"special_resources": config.get_faction_initial_special_resources(runtime_faction_id),
			"relations": config.get_faction(runtime_faction_id).get("relations", {}).duplicate(true),
			"army": _copy_army(config.get_faction(runtime_faction_id).get("initial_army", [])),
		}

	campaign_state = {
		"round": config.get_starting_round(),
		"phase": "management",
		"player_faction_id": _player_faction_id,
		"active_faction_id": "",
		"city": {
			"resources": config.get_management_shared_city_resources(),
		},
		"factions": factions,
		"log": [],
		"last_battle_outcome": "",
		"management": {},
	}
	_set_campaign_phase("management")
	_initialize_management_phase(true)
	_add_campaign_log("%s开始经营阶段。" % config.get_faction_display_name(_player_faction_id))
	campaign_state_changed.emit(get_campaign_snapshot())


func get_campaign_snapshot() -> Dictionary:
	if campaign_state.is_empty():
		return {}

	var round := int(campaign_state.get("round", 1))
	var player_faction_id := _get_player_faction_id()
	var player_state := _get_faction_state(player_faction_id)
	var round_battle: Dictionary = config.get_round_battle(round) if config != null else {}
	var management_resource_snapshot := get_management_resource_snapshot(player_faction_id)
	var current_actor_id := _get_current_management_actor_id()
	var snapshot := {
		"round": round,
		"phase": String(campaign_state.get("phase", "management")),
		"faction_id": player_faction_id,
		"resources": management_resource_snapshot.get("resources", {}).duplicate(true),
		"city_resources": management_resource_snapshot.get("city_resources", {}).duplicate(true),
		"faction_resources": management_resource_snapshot.get("faction_resources", {}).duplicate(true),
		"special_resources": management_resource_snapshot.get("special_resources", {}).duplicate(true),
		"derived_metrics": management_resource_snapshot.get("derived_metrics", {}).duplicate(true),
		"relations": management_resource_snapshot.get("relations", {}).duplicate(true),
		"army": _copy_army(player_state.get("army", [])),
		"log": campaign_state.get("log", []).duplicate(true),
		"current_round_enemy_name": String(round_battle.get("enemy_name", round_battle.get("display_name", ""))),
		"next_round_button_text": _build_next_round_button_text(),
		"current_actor_id": current_actor_id,
		"current_actor_name": _get_management_actor_display_name(current_actor_id),
		"is_player_turn": _is_player_turn(),
	}
	snapshot["total_morale"] = get_total_corps_morale()
	snapshot["total_maintenance"] = get_total_maintenance()
	snapshot["min_corps_morale"] = _get_upcoming_battle_min_corps_morale() if config != null else 0
	snapshot["can_start_battle"] = can_start_battle()
	return snapshot


func try_apply_action(action_id: String, payload: Dictionary = {}) -> bool:
	if campaign_state.is_empty() or not _ensure_config_loaded():
		return false
	if not _is_player_turn():
		_add_campaign_log("当前不是你的行动时机。")
		campaign_state_changed.emit(get_campaign_snapshot())
		return false
	if not _apply_action_for_faction(_get_player_faction_id(), action_id, payload, true):
		campaign_state_changed.emit(get_campaign_snapshot())
		return false

	_advance_management_round_robin()
	campaign_state_changed.emit(get_campaign_snapshot())
	return true


func can_apply_action(action_id: String, payload: Dictionary = {}) -> bool:
	if campaign_state.is_empty() or not _ensure_config_loaded():
		return false
	if not _is_player_turn():
		return false
	return _can_apply_action_for_faction(_get_player_faction_id(), action_id, payload)


func can_start_battle() -> bool:
	if campaign_state.is_empty() or config == null:
		return false
	if String(campaign_state.get("phase", "management")) != "management":
		return false
	if _has_any_manageable_faction() and not _is_player_turn():
		return false
	return get_total_corps_morale() >= _get_upcoming_battle_min_corps_morale() and not _get_player_army().is_empty()


func build_battle_setup() -> Dictionary:
	if not _ensure_config_loaded() or campaign_state.is_empty():
		return {}

	var round_battle: Dictionary = config.get_round_battle(int(campaign_state.get("round", 1)))
	var battle_scene_id := _resolve_battle_scene_id(round_battle)
	var setup_id: String = config.get_default_battle_setup_id(battle_scene_id)
	var battle_setup: Dictionary = config.get_battle_setup(setup_id)
	for key in round_battle.keys():
		battle_setup[key] = round_battle[key]
	battle_setup["id"] = String(round_battle.get("id", setup_id))
	battle_setup["round"] = int(campaign_state.get("round", 1))
	battle_setup["battle_scene_id"] = battle_scene_id
	battle_setup["player_faction_id"] = _get_player_faction_id()
	battle_setup["player_faction_name"] = config.get_faction_display_name(_get_player_faction_id())
	battle_setup["enemy_name"] = String(round_battle.get("enemy_name", battle_setup.get("enemy_name", "敌军")))
	battle_setup["player_army"] = _copy_army(_get_player_army())
	battle_setup["enemy_army"] = _copy_army(round_battle.get("enemy_army", battle_setup.get("default_enemy_army", [])))
	return battle_setup


func begin_battle_round() -> Dictionary:
	if not can_start_battle():
		return {}
	var battle_setup := build_battle_setup()
	if battle_setup.is_empty():
		return {}
	var remaining_ap := _get_management_action_points(_get_player_faction_id())
	if remaining_ap > 0:
		_consume_management_action_points(_get_player_faction_id(), remaining_ap)
		_add_campaign_log("%s结束经营，放弃了%d点行动力。" % [
			config.get_faction_display_name(_get_player_faction_id()),
			remaining_ap,
		])
	_set_campaign_phase("battle")
	campaign_state["active_faction_id"] = _get_player_faction_id()
	_add_campaign_log("%s迎战%s。" % [
		config.get_faction_display_name(_get_player_faction_id()),
		String(battle_setup.get("enemy_name", "敌军")),
	])
	campaign_state_changed.emit(get_campaign_snapshot())
	return battle_setup


func resolve_battle_round(result: Dictionary) -> void:
	if campaign_state.is_empty() or not _ensure_config_loaded():
		return
	if String(campaign_state.get("phase", "")) != "battle":
		return

	var resolved_round := int(campaign_state.get("round", 1))
	var player_faction_id := _get_player_faction_id()
	var enemy_name := String(config.get_round_battle(resolved_round).get("enemy_name", "敌军"))
	var outcome := _normalize_battle_outcome(result)
	var faction_state := _get_faction_state(player_faction_id)
	if result.get("player_army", null) is Array:
		faction_state["army"] = _copy_army(result.get("player_army", []))
	elif result.get("player_survivors", null) is Dictionary:
		faction_state["army"] = _build_army_from_survivors(result.get("player_survivors", {}), faction_state.get("army", []))
	campaign_state["last_battle_outcome"] = outcome
	_add_campaign_log("第%d回合战斗结束：%s对%s，结果%s。" % [
		resolved_round,
		config.get_faction_display_name(player_faction_id),
		enemy_name,
		_get_outcome_display_name(outcome),
	])
	for faction_id_variant in campaign_state.get("factions", {}).keys():
		var faction_id := String(faction_id_variant)
		_apply_round_settlement(faction_id, outcome, faction_id == player_faction_id)
	if outcome == "defeat":
		campaign_state_changed.emit(get_campaign_snapshot())
		return
	campaign_state["round"] = resolved_round + 1
	_set_campaign_phase("management")
	_initialize_management_phase(false)
	campaign_state_changed.emit(get_campaign_snapshot())


func get_total_corps_morale() -> int:
	if config == null:
		return 0

	var total := 0
	for army_entry in _get_player_army():
		var unit_id := String(army_entry.get("unit_id", ""))
		var unit_config: Dictionary = config.get_unit(unit_id)
		var campaign: Dictionary = unit_config.get("campaign", {})
		total += int(campaign.get("morale", 0)) * int(army_entry.get("count", 0))
	return total


func get_total_maintenance() -> int:
	return _get_total_maintenance_for_faction(_get_player_faction_id())


func get_troop_selection_entries() -> Array:
	if not _ensure_config_loaded():
		return []
	var army := _copy_army(_get_player_army())
	if army.is_empty():
		var battle_scene_id := _resolve_battle_scene_id(config.get_round_battle(int(campaign_state.get("round", 1))))
		var default_setup: Dictionary = config.get_battle_setup(config.get_default_battle_setup_id(battle_scene_id))
		army = _copy_army(default_setup.get("default_player_army", []))
	return army


func get_available_action_groups() -> Array:
	if campaign_state.is_empty() or not _ensure_config_loaded():
		return []
	if String(campaign_state.get("phase", "")) != "management":
		return []
	return config.get_action_groups_for_phase(
		String(campaign_state.get("phase", "")),
		_get_player_faction_id(),
		_get_runtime_controller(_get_player_faction_id())
	)


func get_available_action_options(group_id: String) -> Array:
	if campaign_state.is_empty() or not _ensure_config_loaded():
		return []
	if String(campaign_state.get("phase", "")) != "management":
		return []
	var actions: Array = config.get_action_options_for_group(
		group_id,
		_get_player_faction_id(),
		_get_runtime_controller(_get_player_faction_id())
	)
	var result: Array = []
	for action in actions:
		result.append(_with_runtime_action_cost(action))
	return result


func get_available_actions() -> Array:
	if campaign_state.is_empty() or not _ensure_config_loaded():
		return []
	if String(campaign_state.get("phase", "")) != "management":
		return []
	var actions: Array = config.get_actions_for_phase(
		String(campaign_state.get("phase", "")),
		_get_player_faction_id(),
		_get_runtime_controller(_get_player_faction_id())
	)
	var result: Array = []
	for action in actions:
		result.append(_with_runtime_action_cost(action))
	return result


func get_selectable_factions() -> Array[Dictionary]:
	var factions: Array[Dictionary] = []
	if not _ensure_config_loaded():
		return factions
	for faction_id in config.get_selectable_faction_ids():
		var current_id := String(faction_id)
		factions.append({
			"id": current_id,
			"display_name": config.get_faction_display_name(current_id),
		})
	return factions


func get_management_resource_factions() -> Array[Dictionary]:
	var factions: Array[Dictionary] = []
	if campaign_state.is_empty() or not _ensure_config_loaded():
		return factions
	for faction_id_variant in config.get_faction_ids():
		var faction_id := String(faction_id_variant)
		factions.append({
			"id": faction_id,
			"display_name": config.get_faction_display_name(faction_id),
			"is_player": faction_id == _get_player_faction_id(),
		})
	return factions


func get_management_resource_snapshot(faction_id: String) -> Dictionary:
	if campaign_state.is_empty() or not _ensure_config_loaded():
		return {}
	var target_faction_id := faction_id
	if target_faction_id == "" or not campaign_state.get("factions", {}).has(target_faction_id):
		target_faction_id = _get_player_faction_id()
	var city_resources: Dictionary = _get_city_resources().duplicate(true)
	var faction_state := _get_faction_state(target_faction_id)
	var faction_resources: Dictionary = faction_state.get("faction_resources", {}).duplicate(true)
	var special_resources: Dictionary = faction_state.get("special_resources", {}).duplicate(true)
	var derived_metrics: Dictionary = _build_derived_metrics_for_faction(target_faction_id)
	var resources: Dictionary = city_resources.duplicate(true)
	for resource_id in faction_resources.keys():
		resources[resource_id] = faction_resources[resource_id]
	for resource_id in special_resources.keys():
		resources[resource_id] = special_resources[resource_id]
	for resource_id in derived_metrics.keys():
		resources[resource_id] = derived_metrics[resource_id]
	return {
		"faction_id": target_faction_id,
		"resources": resources,
		"city_resources": city_resources,
		"faction_resources": faction_resources,
		"special_resources": special_resources,
		"derived_metrics": derived_metrics,
		"relations": faction_state.get("relations", {}).duplicate(true),
	}


func set_selected_squads(squads: Array) -> void:
	_cleanup_selected_squads()

	var next_selected: Array = []
	var seen: Dictionary = {}
	for squad in squads:
		if not is_instance_valid(squad):
			continue
		var instance_id: int = squad.get_instance_id()
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		next_selected.append(squad)

	for squad in _selected_squads:
		if is_instance_valid(squad) and squad.has_method("set_selected") and not next_selected.has(squad):
			squad.set_selected(false)

	for squad in next_selected:
		if squad.has_method("set_selected"):
			squad.set_selected(true)

	_selected_squads = next_selected
	selection_changed.emit(_selected_squads.size())


func clear_selection() -> void:
	set_selected_squads([])


func get_selected_squads() -> Array:
	_cleanup_selected_squads()
	return _selected_squads.duplicate()


func set_phase(phase: String) -> void:
	if current_phase == phase:
		return
	current_phase = phase
	phase_changed.emit(current_phase)


func get_phase() -> String:
	return current_phase


func _ensure_config_loaded() -> bool:
	if config == null:
		config = CONFIG_DATABASE_SCRIPT.new()
	if _config_loaded:
		return true

	_config_loaded = config.load_all()
	for error in config.get_errors():
		push_warning(error)
	return _config_loaded


func _get_player_faction_id() -> String:
	if _player_faction_id != "":
		return _player_faction_id
	if not campaign_state.is_empty():
		var state_player_id := String(campaign_state.get("player_faction_id", ""))
		if state_player_id != "":
			return state_player_id
	if config != null:
		var config_player_id: String = config.get_player_faction_id()
		if config_player_id != "":
			return config_player_id
	return ""


func _get_faction_state(faction_id: String) -> Dictionary:
	return campaign_state.get("factions", {}).get(faction_id, {})


func _get_player_army() -> Array:
	return _get_faction_state(_get_player_faction_id()).get("army", [])


func _get_city_state() -> Dictionary:
	return campaign_state.get("city", {})


func _get_city_resources() -> Dictionary:
	return _get_city_state().get("resources", {})


func _get_runtime_controller(faction_id: String) -> String:
	if faction_id == "":
		return ""
	if faction_id == _get_player_faction_id():
		return "player"
	return "ai"


func _can_faction_select_action(faction_id: String, action_id: String) -> bool:
	if config == null or faction_id == "" or action_id == "":
		return false
	var actions: Array = config.get_actions_for_phase(
		String(campaign_state.get("phase", "")),
		faction_id,
		_get_runtime_controller(faction_id)
	)
	for action in actions:
		if action is Dictionary and String(action.get("id", "")) == action_id:
			return true
	return false


func _can_apply_action_for_faction(faction_id: String, action_id: String, payload: Dictionary = {}) -> bool:
	var action: Dictionary = config.get_action(action_id)
	if action.is_empty():
		return false
	if String(action.get("phase", "")) != String(campaign_state.get("phase", "")):
		return false
	if faction_id != _get_current_management_actor_id():
		return false
	if not _can_faction_select_action(faction_id, action_id):
		return false
	if _get_management_action_points(faction_id) < _get_effective_action_cost(action_id):
		return false
	var full_cost := _build_action_cost(action, payload)
	for resource_id in full_cost.keys():
		if _get_resource_value_for_faction(faction_id, String(resource_id)) < int(full_cost[resource_id]):
			return false
	return true


func _apply_action_for_faction(faction_id: String, action_id: String, payload: Dictionary = {}, add_failure_log: bool = false) -> bool:
	var action: Dictionary = config.get_action(action_id)
	if action.is_empty():
		if add_failure_log:
			_add_campaign_log("未知行动：%s。" % action_id)
		return false

	if String(action.get("phase", "")) != String(campaign_state.get("phase", "")):
		if add_failure_log:
			_add_campaign_log("当前阶段不能执行%s。" % action.get("display_name", action_id))
		return false

	var faction_state := _get_faction_state(faction_id)
	if faction_state.is_empty():
		return false
	if faction_id != _get_current_management_actor_id():
		if add_failure_log:
			_add_campaign_log("当前轮到%s行动。" % _get_management_actor_display_name(_get_current_management_actor_id()))
		return false

	if not _can_faction_select_action(faction_id, action_id):
		if add_failure_log:
			_add_campaign_log("当前阵营不能执行%s。" % action.get("display_name", action_id))
		return false

	var ap_cost := _get_effective_action_cost(action_id)
	if _get_management_action_points(faction_id) < ap_cost:
		if add_failure_log:
			_add_campaign_log("行动力不足，无法执行%s。" % action.get("display_name", action_id))
		return false

	var full_cost := _build_action_cost(action, payload)
	for resource_id in full_cost.keys():
		if _get_resource_value_for_faction(faction_id, String(resource_id)) < int(full_cost[resource_id]):
			if add_failure_log:
				_add_campaign_log("%s不足，无法执行%s。" % [_get_resource_display_name(String(resource_id)), action.get("display_name", action_id)])
			return false

	_consume_management_action_points(faction_id, ap_cost)
	_increment_round_action_usage(action_id)
	for resource_id in full_cost.keys():
		_add_resource_value_for_faction(faction_id, String(resource_id), -int(full_cost[resource_id]))
		_apply_resource_caps_to_faction(faction_id, [String(resource_id)])

	_apply_effects(faction_id, action.get("effects", []), payload)
	_add_campaign_log(_build_action_log(faction_id, action, payload, ap_cost))
	return true


func _build_action_cost(action: Dictionary, payload: Dictionary) -> Dictionary:
	var cost: Dictionary = action.get("cost", {}).duplicate(true)
	var recruit_unit_id := _get_recruit_action_unit_id(action, payload)
	if recruit_unit_id == "":
		return cost
	var unit_campaign: Dictionary = config.get_unit(recruit_unit_id).get("campaign", {})
	if unit_campaign.has("manpower_cost"):
		cost["manpower_pool"] = int(unit_campaign.get("manpower_cost", 0))
	if unit_campaign.has("asset_cost"):
		cost["assets"] = int(unit_campaign.get("asset_cost", 0))
	return cost


func _get_recruit_action_unit_id(action: Dictionary, payload: Dictionary) -> String:
	if String(action.get("type", "")) != "recruit":
		return ""
	for effect_variant in action.get("effects", []):
		if not effect_variant is Dictionary:
			continue
		var effect: Dictionary = effect_variant
		var effect_op := String(effect.get("op", ""))
		if effect_op != "add_unit" and effect_op != "add_army_unit":
			continue
		return String(effect.get("unit_id", payload.get(String(effect.get("unit_id_from_payload", "unit_id")), "")))
	return ""


func _apply_effects(faction_id: String, effects: Array, payload: Dictionary) -> void:
	for effect in effects:
		if not effect is Dictionary:
			continue
		var scope := String(effect.get("scope", "resources"))
		var target := String(effect.get("target", effect.get("unit_id_from_payload", "")))
		if effect.has("target_from_payload"):
			target = String(payload.get(String(effect["target_from_payload"]), ""))

		match String(effect.get("op", "")):
			"add":
				if target == "":
					continue
				var value := int(effect.get("value", 0))
				if scope == "relations":
					var relations: Dictionary = _get_faction_state(faction_id).get("relations", {})
					relations[target] = int(relations.get(target, 0)) + value
					_get_faction_state(faction_id)["relations"] = relations
				else:
					_add_resource_value_for_faction(faction_id, target, value)
					_apply_resource_caps_to_faction(faction_id, [target])
			"set":
				if target == "":
					continue
				if scope == "relations":
					var relations: Dictionary = _get_faction_state(faction_id).get("relations", {})
					relations[target] = int(effect.get("value", 0))
					_get_faction_state(faction_id)["relations"] = relations
				else:
					_set_resource_value_for_faction(faction_id, target, int(effect.get("value", 0)))
					_apply_resource_caps_to_faction(faction_id, [target])
			"add_unit", "add_army_unit":
				var unit_id := String(effect.get("unit_id", payload.get(String(effect.get("unit_id_from_payload", "unit_id")), "")))
				var count := int(effect.get("count", payload.get(String(effect.get("count_from_payload", "count")), 1)))
				_add_army_unit(faction_id, unit_id, maxi(1, count))


func _add_army_unit(faction_id: String, unit_id: String, count: int) -> void:
	if unit_id == "" or config.get_unit(unit_id).is_empty():
		return
	var faction_state := _get_faction_state(faction_id)
	var army: Array = faction_state.get("army", [])
	for entry in army:
		if String(entry.get("unit_id", "")) == unit_id:
			entry["count"] = int(entry.get("count", 0)) + count
			return
	army.append({ "unit_id": unit_id, "count": count })
	faction_state["army"] = army


func _advance_management_round_robin() -> void:
	if String(campaign_state.get("phase", "")) != "management":
		return
	var order := _get_management_action_order()
	if order.is_empty():
		campaign_state["active_faction_id"] = ""
		return
	if not _has_any_manageable_faction():
		campaign_state["active_faction_id"] = ""
		return

	var scanned_unmanageable := 0
	while _has_any_manageable_faction() and scanned_unmanageable < order.size():
		_set_current_management_actor_index((_get_current_management_actor_index() + 1) % order.size())
		var actor_index := _get_current_management_actor_index()
		var current_actor_id := String(order[actor_index])
		if not _can_faction_continue_management(current_actor_id):
			scanned_unmanageable += 1
			continue
		campaign_state["active_faction_id"] = current_actor_id
		scanned_unmanageable = 0
		if current_actor_id == _get_player_faction_id():
			return
		_execute_ai_turn(current_actor_id)

	campaign_state["active_faction_id"] = ""


func _execute_ai_turn(faction_id: String) -> void:
	if faction_id == "" or _get_runtime_controller(faction_id) != "ai":
		return
	var tree_id: String = config.get_faction_behavior_tree_id(faction_id)
	var tree: Dictionary = _build_runtime_ai_behavior_tree(faction_id, tree_id)
	_execute_behavior_node(faction_id, tree)


func _build_runtime_ai_behavior_tree(faction_id: String, tree_id: String) -> Dictionary:
	var template: Dictionary = config.get_behavior_tree(tree_id)
	var children: Array = []
	var used_action_ids: Dictionary = {}
	var allowed_action_ids := _get_runtime_allowed_action_ids(faction_id)
	for rule in template.get("rules", []):
		if not rule is Dictionary:
			continue
		var action_ids: Array = []
		if bool(rule.get("use_remaining_allowed_actions", false)):
			for action_id in allowed_action_ids:
				if not used_action_ids.has(String(action_id)):
					action_ids.append(String(action_id))
		else:
			for action_id in rule.get("candidate_action_ids", []):
				var id := String(action_id)
				if allowed_action_ids.has(id):
					action_ids.append(id)
		for action_id in action_ids:
			used_action_ids[action_id] = true
		if action_ids.is_empty():
			continue
		children.append({
			"type": "sequence",
			"children": [
				_build_runtime_ai_condition(rule.get("condition", {})),
				_build_runtime_ai_action_selector(action_ids),
			]
		})
	return { "type": "selector", "children": children }


func _get_runtime_allowed_action_ids(faction_id: String) -> Array:
	var result: Array = []
	for action_id in config.get_faction_allowed_action_ids(faction_id):
		var id := String(action_id)
		if _can_faction_select_action(faction_id, id):
			result.append(id)
	return result


func _build_runtime_ai_condition(condition) -> Dictionary:
	var result := { "type": "condition", "condition": "always" }
	if not condition is Dictionary:
		return result
	result = condition.duplicate(true)
	var condition_type := String(result.get("type", "always"))
	result["type"] = "condition"
	result["condition"] = condition_type
	return result


func _build_runtime_ai_action_selector(action_ids: Array) -> Dictionary:
	var children: Array = []
	for action_id in action_ids:
		children.append({ "type": "action", "action_id": String(action_id) })
	return { "type": "selector", "children": children }


func _execute_behavior_node(faction_id: String, node) -> bool:
	if not node is Dictionary:
		return false
	match String(node.get("type", "")):
		"selector":
			for child in node.get("children", []):
				if _execute_behavior_node(faction_id, child):
					return true
			return false
		"sequence":
			for child in node.get("children", []):
				if not _execute_behavior_node(faction_id, child):
					return false
			return true
		"condition":
			return _evaluate_ai_condition(faction_id, node)
		"action":
			return _apply_action_for_faction(faction_id, String(node.get("action_id", "")), {}, false)
	return false


func _evaluate_ai_condition(faction_id: String, node: Dictionary) -> bool:
	var faction_state := _get_faction_state(faction_id)
	match String(node.get("condition", "")):
		"always":
			return true
		"resource_below":
			return _get_resource_value_for_faction(faction_id, String(node.get("resource_id", ""))) < int(node.get("value", 0))
		"resource_at_least":
			return _get_resource_value_for_faction(faction_id, String(node.get("resource_id", ""))) >= int(node.get("value", 0))
		"relation_below":
			var relations: Dictionary = faction_state.get("relations", {})
			return int(relations.get(String(node.get("faction_id", "")), 0)) < int(node.get("value", 0))
		"army_count_below":
			var unit_id := String(node.get("unit_id", ""))
			var total := 0
			for entry in faction_state.get("army", []):
				if unit_id == "" or String(entry.get("unit_id", "")) == unit_id:
					total += int(entry.get("count", 0))
			return total < int(node.get("value", 0))
	return false


func _build_action_log(faction_id: String, action: Dictionary, payload: Dictionary, ap_cost: int = -1) -> String:
	return "%s执行%s（消耗：%s；获得：%s）。" % [
		config.get_faction_display_name(faction_id),
		action.get("display_name", "行动"),
		_build_action_log_cost_text(action, payload, ap_cost),
		_build_action_log_effect_text(action.get("effects", []), payload),
	]


func _build_action_log_cost_text(action: Dictionary, payload: Dictionary, ap_cost: int = -1) -> String:
	var actual_ap_cost := ap_cost if ap_cost >= 0 else int(action.get("ap_cost", 0))
	var parts: Array[String] = ["行动力-%d" % actual_ap_cost]
	var full_cost := _build_action_cost(action, payload)
	for resource_id in full_cost.keys():
		parts.append("%s-%d" % [_get_resource_display_name(String(resource_id)), int(full_cost[resource_id])])
	return "、".join(parts) if not parts.is_empty() else "无"


func _build_action_log_effect_text(effects: Array, payload: Dictionary) -> String:
	var parts: Array[String] = []
	for effect in effects:
		if not effect is Dictionary:
			continue
		var scope := String(effect.get("scope", "resources"))
		var target := String(effect.get("target", effect.get("unit_id_from_payload", "")))
		if effect.has("target_from_payload"):
			target = String(payload.get(String(effect["target_from_payload"]), ""))
		match String(effect.get("op", "")):
			"add":
				if target == "":
					continue
				var target_name: String = config.get_faction_display_name(target) if scope == "relations" else _get_resource_display_name(target)
				parts.append("%s%+d" % [target_name, int(effect.get("value", 0))])
			"set":
				if target == "":
					continue
				var target_name: String = config.get_faction_display_name(target) if scope == "relations" else _get_resource_display_name(target)
				parts.append("%s设为%d" % [target_name, int(effect.get("value", 0))])
			"add_unit", "add_army_unit":
				var unit_id := String(effect.get("unit_id", payload.get(String(effect.get("unit_id_from_payload", "unit_id")), "")))
				if unit_id == "":
					continue
				var unit_config: Dictionary = config.get_unit(unit_id)
				var count := int(effect.get("count", payload.get(String(effect.get("count_from_payload", "count")), 1)))
				parts.append("%s+%d" % [unit_config.get("display_name", unit_id), maxi(1, count)])
	return "、".join(parts) if not parts.is_empty() else "无"


func _add_campaign_log(message: String) -> void:
	if campaign_state.is_empty():
		return
	var log: Array = campaign_state.get("log", [])
	log.append(message)
	while log.size() > 8:
		log.pop_front()
	campaign_state["log"] = log
	campaign_log_added.emit(message)


func _get_resource_display_name(resource_id: String) -> String:
	var resource: Dictionary = config.get_resource(resource_id) if config != null else {}
	return String(resource.get("display_name", resource_id))


func _copy_army(source: Array) -> Array:
	var copied: Array = []
	for entry in source:
		if entry is Dictionary:
			copied.append(entry.duplicate(true))
	return copied


func _build_army_from_survivors(survivors: Dictionary, previous_army: Array = []) -> Array:
	var army: Array = []
	var added_units: Dictionary = {}
	for entry in previous_army:
		if not entry is Dictionary:
			continue
		var unit_id := String(entry.get("unit_id", ""))
		var count := int(survivors.get(unit_id, 0))
		if count <= 0:
			continue
		army.append({
			"unit_id": unit_id,
			"count": count,
		})
		added_units[unit_id] = true
	for unit_id in survivors.keys():
		if added_units.has(unit_id):
			continue
		var count := int(survivors.get(unit_id, 0))
		if count <= 0:
			continue
		army.append({
			"unit_id": String(unit_id),
			"count": count,
		})
	return army


func _resolve_battle_scene_id(round_battle: Dictionary = {}) -> String:
	var battle_scene_id := String(round_battle.get("battle_scene_id", ""))
	if config == null:
		return battle_scene_id
	if battle_scene_id != "" and not config.get_battle_scene(battle_scene_id).is_empty():
		return battle_scene_id
	return config.get_default_battle_scene_id()


func _get_upcoming_battle_min_corps_morale() -> int:
	if config == null:
		return 0
	return config.get_min_corps_morale(_resolve_battle_scene_id(config.get_round_battle(int(campaign_state.get("round", 1)))))


func _cleanup_selected_squads() -> void:
	var alive: Array = []
	for squad in _selected_squads:
		if is_instance_valid(squad):
			alive.append(squad)
	_selected_squads = alive


func _set_campaign_phase(phase: String) -> void:
	campaign_state["phase"] = phase
	set_phase(phase)


func _build_next_round_button_text() -> String:
	var round := int(campaign_state.get("round", 1))
	if String(campaign_state.get("phase", "management")) == "battle":
		return "战斗进行中"
	if _has_any_manageable_faction():
		return "开始战斗"
	return "进入第%d回合战斗" % round


func _normalize_battle_outcome(result: Dictionary) -> String:
	var outcome := String(result.get("outcome", ""))
	if outcome != "":
		return outcome
	if bool(result.get("victory", false)) or bool(result.get("won", false)):
		return "victory"
	if bool(result.get("defeat", false)) or bool(result.get("lost", false)):
		return "defeat"
	if bool(result.get("retreat", false)):
		return "retreat"
	return "victory"


func _get_outcome_display_name(outcome: String) -> String:
	match outcome:
		"victory":
			return "胜利"
		"defeat":
			return "失败"
		"retreat":
			return "撤退"
	return outcome


func _apply_round_settlement(faction_id: String, outcome: String, apply_outcome_modifiers: bool = false) -> void:
	var settlement: Dictionary = config.get_round_settlement()
	if settlement.is_empty():
		return
	var summary: Array[String] = []
	var maintenance_cost := -_get_total_maintenance_for_faction(faction_id)
	_apply_settlement_resource_change(faction_id, "assets", maintenance_cost, summary)
	_apply_settlement_operations(faction_id, settlement.get("operations", []), summary)
	if apply_outcome_modifiers:
		var outcome_modifiers: Dictionary = settlement.get("outcome_modifiers", {})
		_apply_settlement_operations(faction_id, outcome_modifiers.get(outcome, []), summary)
	if summary.is_empty():
		return
	_add_campaign_log("%s回合结算：%s。" % [config.get_faction_display_name(faction_id), "，".join(summary)])


func _apply_resource_caps_to_faction(faction_id: String, resource_ids: Array = []) -> void:
	if config == null:
		return
	var rules: Dictionary = config.get_round_resource_rules()
	if rules.is_empty():
		return
	var target_ids: Array = resource_ids if not resource_ids.is_empty() else rules.keys()
	for resource_id_variant in target_ids:
		_apply_resource_cap(faction_id, String(resource_id_variant))


func _apply_resource_cap(faction_id: String, resource_id: String) -> void:
	var rule: Dictionary = config.get_round_resource_rule(resource_id)
	if rule.is_empty():
		return
	var scope := _get_resource_scope(resource_id)
	if scope == "derived":
		return
	var current_value = _get_resource_value_for_faction(faction_id, resource_id)
	_set_resource_value_for_faction(faction_id, resource_id, _clamp_resource_value(resource_id, current_value))


func _apply_round_resource_rules(faction_id: String, initialize_to_max: bool) -> void:
	if config == null:
		return
	for resource_id_variant in config.get_round_resource_rules().keys():
		var resource_id := String(resource_id_variant)
		var scope := _get_resource_scope(resource_id)
		if scope == "derived":
			continue
		if initialize_to_max:
			_set_resource_value_for_faction(faction_id, resource_id, _clamp_resource_value(resource_id, _get_resource_value_for_faction(faction_id, resource_id)))
		elif config.get_round_resource_reset_each_round(resource_id):
			_set_resource_value_for_faction(faction_id, resource_id, _get_initial_resource_value(faction_id, resource_id))
		else:
			_set_resource_value_for_faction(faction_id, resource_id, _clamp_resource_value(resource_id, _get_resource_value_for_faction(faction_id, resource_id)))


func _clamp_resource_value(resource_id: String, value):
	if config == null:
		return value
	var max_value = config.get_round_resource_max(resource_id)
	var resource: Dictionary = config.get_resource(resource_id)
	if String(resource.get("type", "integer")) == "float":
		return clampf(float(value), 0.0, float(max_value))
	return clampi(int(value), 0, int(max_value))


func _apply_settlement_operations(faction_id: String, operations: Array, summary: Array[String]) -> void:
	for operation in operations:
		if not operation is Dictionary:
			continue
		var target := String(operation.get("target", ""))
		if target == "":
			continue
		match String(operation.get("op", "")):
			"add":
				var add_value := int(operation.get("value", 0))
				_add_resource_value_for_faction(faction_id, target, add_value)
				_append_settlement_summary(summary, target, add_value)
			"add_from_resource":
				var source_id := String(operation.get("resource_id", ""))
				var resource_value := int(_get_resource_value_for_faction(faction_id, source_id)) * int(operation.get("multiplier", 1))
				_add_resource_value_for_faction(faction_id, target, resource_value)
				_append_settlement_summary(summary, target, resource_value)
			"add_percent_of":
				var base_value = _get_resource_value_for_faction(faction_id, String(operation.get("resource_id", "")))
				var percent_source_id := String(operation.get("percent_resource_id", ""))
				var percent_value := float(operation.get("percent", _get_resource_value_for_faction(faction_id, percent_source_id)))
				var percent_amount := int(round(float(base_value) * percent_value))
				_add_resource_value_for_faction(faction_id, target, percent_amount)
				_append_settlement_summary(summary, target, percent_amount)
			"reset_from_initial":
				var initial_value = _get_initial_resource_value(faction_id, target)
				_set_resource_value_for_faction(faction_id, target, initial_value)
				summary.append("%s重置为%d" % [_get_resource_display_name(target), initial_value])
		_apply_resource_cap(faction_id, target)


func _apply_settlement_resource_change(faction_id: String, target: String, value: int, summary: Array[String]) -> void:
	if target == "":
		return
	_add_resource_value_for_faction(faction_id, target, value)
	_apply_resource_cap(faction_id, target)
	_append_settlement_summary(summary, target, value)


func _append_settlement_summary(summary: Array[String], target: String, value: int) -> void:
	if value == 0:
		return
	summary.append("%s%+d" % [_get_resource_display_name(target), value])


func _get_initial_resource_value(faction_id: String, resource_id: String):
	match _get_resource_scope(resource_id):
		"city":
			return config.get_management_shared_city_resources().get(resource_id, 0)
		"faction":
			var management_resources: Dictionary = config.get_faction_initial_management_resources(faction_id)
			if management_resources.has(resource_id):
				return management_resources.get(resource_id, 0)
			if resource_id == "support_base":
				return config.get_faction_initial_support_base(faction_id)
			if resource_id == "owned_assets":
				return config.get_faction_initial_owned_assets(faction_id)
			return 0
		"special":
			return config.get_faction_initial_special_resources(faction_id).get(resource_id, 0)
	return 0


func _get_total_maintenance_for_faction(faction_id: String) -> int:
	if config == null:
		return 0
	var total := 0
	for army_entry in _get_faction_state(faction_id).get("army", []):
		var unit_id := String(army_entry.get("unit_id", ""))
		var unit_config: Dictionary = config.get_unit(unit_id)
		var campaign: Dictionary = unit_config.get("campaign", {})
		total += int(campaign.get("upkeep", 0)) * int(army_entry.get("count", 0))
	return total


func _initialize_management_phase(initialize_to_max: bool = false) -> void:
	var action_order: Array = config.get_management_action_order() if config != null else []
	var starting_index := maxi(action_order.size() - 1, 0)
	for faction_id_variant in campaign_state.get("factions", {}).keys():
		_apply_round_resource_rules(String(faction_id_variant), initialize_to_max)
	campaign_state["management"] = {
		"action_order": action_order.duplicate(),
		"current_actor_index": starting_index,
		"action_usage_counts": {},
	}
	campaign_state["active_faction_id"] = _get_current_management_actor_id()
	_advance_management_round_robin()


func _get_management_state() -> Dictionary:
	return campaign_state.get("management", {})


func _get_management_action_order() -> Array:
	return _get_management_state().get("action_order", [])


func _get_current_management_actor_index() -> int:
	return int(_get_management_state().get("current_actor_index", 0))


func _set_current_management_actor_index(index: int) -> void:
	var management := _get_management_state()
	management["current_actor_index"] = index
	campaign_state["management"] = management


func _get_current_management_actor_id() -> String:
	if String(campaign_state.get("phase", "")) != "management":
		return String(campaign_state.get("active_faction_id", ""))
	if not _has_any_manageable_faction():
		return ""
	var order := _get_management_action_order()
	if order.is_empty():
		return ""
	var index := clampi(_get_current_management_actor_index(), 0, order.size() - 1)
	var faction_id := String(order[index])
	if not _can_faction_continue_management(faction_id):
		return ""
	return faction_id


func _get_management_actor_display_name(faction_id: String) -> String:
	if faction_id == "":
		return "经营结束"
	return config.get_faction_display_name(faction_id) if config != null else faction_id


func _get_management_action_points(faction_id: String) -> int:
	if faction_id == "":
		return 0
	return int(_get_faction_state(faction_id).get("faction_resources", {}).get("action_points", 0))


func _can_faction_continue_management(faction_id: String) -> bool:
	if String(campaign_state.get("phase", "")) != "management":
		return false
	if faction_id == "" or _get_management_action_points(faction_id) <= 0:
		return false
	var actions: Array = config.get_actions_for_phase(
		String(campaign_state.get("phase", "")),
		faction_id,
		_get_runtime_controller(faction_id)
	)
	for action_variant in actions:
		if not action_variant is Dictionary:
			continue
		var action_id := String(action_variant.get("id", ""))
		if action_id == "" or not _can_faction_select_action(faction_id, action_id):
			continue
		if _get_management_action_points(faction_id) < _get_effective_action_cost(action_id):
			continue
		var full_cost := _build_action_cost(action_variant, {})
		var can_afford := true
		for resource_id in full_cost.keys():
			if _get_resource_value_for_faction(faction_id, String(resource_id)) < int(full_cost[resource_id]):
				can_afford = false
				break
		if can_afford:
			return true
	return false


func _has_any_manageable_faction() -> bool:
	for faction_id_variant in campaign_state.get("factions", {}).keys():
		if _can_faction_continue_management(String(faction_id_variant)):
			return true
	return false


func _consume_management_action_points(faction_id: String, amount: int) -> void:
	if faction_id == "":
		return
	var remaining := maxi(0, _get_management_action_points(faction_id) - amount)
	_set_resource_value_for_faction(faction_id, "action_points", remaining)


func _get_round_action_usage_count(action_id: String) -> int:
	var usage_counts: Dictionary = _get_management_state().get("action_usage_counts", {})
	return int(usage_counts.get(action_id, 0))


func _increment_round_action_usage(action_id: String) -> void:
	var management := _get_management_state()
	var usage_counts: Dictionary = management.get("action_usage_counts", {})
	usage_counts[action_id] = int(usage_counts.get(action_id, 0)) + 1
	management["action_usage_counts"] = usage_counts
	campaign_state["management"] = management


func _get_effective_action_cost(action_id: String) -> int:
	return config.get_effective_action_point_cost(action_id, _get_round_action_usage_count(action_id)) if config != null else 0


func _with_runtime_action_cost(action: Dictionary) -> Dictionary:
	var entry := action.duplicate(true)
	var action_id := String(entry.get("id", ""))
	entry["ap_cost"] = _get_effective_action_cost(action_id)
	entry["cost"] = _build_action_cost(entry, {})
	return entry


func _should_expose_player_management_actions() -> bool:
	if String(campaign_state.get("phase", "")) != "management":
		return false
	if _get_current_management_actor_id() == _get_player_faction_id():
		return true
	return not _has_any_manageable_faction() and String(campaign_state.get("player_faction_id", _get_player_faction_id())) == _get_player_faction_id()


func _is_player_turn() -> bool:
	return String(campaign_state.get("phase", "")) == "management" and _get_current_management_actor_id() == _get_player_faction_id()


func _get_resource_scope(resource_id: String) -> String:
	return config.get_resource_scope(resource_id) if config != null else "city"


func _get_resource_store_for_faction(faction_id: String, resource_id: String) -> Dictionary:
	var scope := _get_resource_scope(resource_id)
	if scope == "city":
		return _get_city_resources()
	var faction_state := _get_faction_state(faction_id)
	if scope == "faction":
		return faction_state.get("faction_resources", {})
	if scope == "special":
		return faction_state.get("special_resources", {})
	return {}


func _set_resource_store_for_faction(faction_id: String, resource_id: String, store: Dictionary) -> void:
	var scope := _get_resource_scope(resource_id)
	if scope == "city":
		var city_state := _get_city_state()
		city_state["resources"] = store
		campaign_state["city"] = city_state
		return
	var faction_state := _get_faction_state(faction_id)
	if scope == "faction":
		faction_state["faction_resources"] = store
	elif scope == "special":
		faction_state["special_resources"] = store


func _get_resource_value_for_faction(faction_id: String, resource_id: String):
	var scope := _get_resource_scope(resource_id)
	if scope == "derived":
		return _build_derived_metrics_for_faction(faction_id).get(resource_id, 0)
	var store := _get_resource_store_for_faction(faction_id, resource_id)
	return store.get(resource_id, 0)


func _set_resource_value_for_faction(faction_id: String, resource_id: String, value) -> void:
	if _get_resource_scope(resource_id) == "derived":
		return
	var store := _get_resource_store_for_faction(faction_id, resource_id).duplicate(true)
	store[resource_id] = value
	_set_resource_store_for_faction(faction_id, resource_id, store)


func _add_resource_value_for_faction(faction_id: String, resource_id: String, value) -> void:
	if _get_resource_scope(resource_id) == "derived":
		return
	var current_value = _get_resource_value_for_faction(faction_id, resource_id)
	_set_resource_value_for_faction(faction_id, resource_id, current_value + value)


func _build_derived_metrics_for_faction(faction_id: String) -> Dictionary:
	var support_base := int(_get_resource_value_for_faction(faction_id, "support_base"))
	var owned_assets := int(_get_resource_value_for_faction(faction_id, "owned_assets"))
	var total_support := 0
	var total_owned_assets := 0
	for other_faction_id in campaign_state.get("factions", {}).keys():
		var id := String(other_faction_id)
		total_support += int(_get_resource_value_for_faction(id, "support_base"))
		total_owned_assets += int(_get_resource_value_for_faction(id, "owned_assets"))
	return {
		"support_share": float(support_base) / float(total_support) if total_support > 0 else 0.0,
		"ownership_share": float(owned_assets) / float(total_owned_assets) if total_owned_assets > 0 else 0.0,
		"war_expectation": support_base + owned_assets,
		"maintenance": _get_total_maintenance_for_faction(faction_id),
	}
