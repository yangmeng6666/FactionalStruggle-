extends Node

signal selection_changed(selected_count: int)
signal phase_changed(phase: String)
signal campaign_state_changed(snapshot: Dictionary)
signal campaign_log_added(message: String)

const CONFIG_DATABASE_SCRIPT := preload("res://scripts/data/config_database.gd")
const RECRUIT_ACTION_ID := "recruit_corps"
const RECRUIT_OPTION_COUNT := 3

var current_phase: String = ""
var config = null
var campaign_state: Dictionary = {}
var _selected_squads: Array = []
var _config_loaded: bool = false
var _player_faction_id: String = ""
var _next_corps_instance_serial: int = 1


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
	_next_corps_instance_serial = 1
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
			"army": _normalize_army_runtime(config.get_faction(runtime_faction_id).get("initial_army", [])),
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
	snapshot["pending_recruit_options"] = _get_pending_recruit_options_for_faction(player_faction_id)
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
	var player_faction_id := _get_player_faction_id()
	if action_id == RECRUIT_ACTION_ID and not payload.has("selected_corps_id"):
		var recruit_started := _begin_recruit_roll_for_faction(player_faction_id, true)
		campaign_state_changed.emit(get_campaign_snapshot())
		return recruit_started
	if not _apply_action_for_faction(player_faction_id, action_id, payload, true):
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
	if action_id == RECRUIT_ACTION_ID and not payload.has("selected_corps_id"):
		return _can_begin_recruit_roll_for_faction(_get_player_faction_id())
	return _can_apply_action_for_faction(_get_player_faction_id(), action_id, payload)


func can_start_battle() -> bool:
	if campaign_state.is_empty() or config == null:
		return false
	if String(campaign_state.get("phase", "management")) != "management":
		return false
	if _has_any_manageable_faction() and not _is_player_turn():
		return false
	return get_total_corps_morale() >= _get_upcoming_battle_min_corps_morale() and not _normalize_army_runtime(_get_player_army()).is_empty()


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
	battle_setup["player_army"] = _flatten_corps_army_for_battle(_get_player_army())
	battle_setup["enemy_army"] = _flatten_corps_army_for_battle(round_battle.get("enemy_army", battle_setup.get("default_enemy_army", [])))
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
		faction_state["army"] = _normalize_army_runtime(result.get("player_army", []))
	elif result.get("player_survivors_by_corps", null) is Dictionary:
		faction_state["army"] = _rebuild_corps_army_from_survivors(result.get("player_survivors_by_corps", {}), faction_state.get("army", []))
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
	return _get_total_army_metric(_get_player_army(), "morale")


func get_total_maintenance() -> int:
	return _get_total_maintenance_for_faction(_get_player_faction_id())


func get_troop_selection_entries() -> Array:
	if not _ensure_config_loaded():
		return []
	var army := _normalize_army_runtime(_get_player_army())
	if army.is_empty():
		var battle_scene_id := _resolve_battle_scene_id(config.get_round_battle(int(campaign_state.get("round", 1))))
		var default_setup: Dictionary = config.get_battle_setup(config.get_default_battle_setup_id(battle_scene_id))
		army = _normalize_army_runtime(default_setup.get("default_player_army", []))
	return _copy_army(army)


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


func get_management_projection(faction_id: String, pending_action_id: String = "", payload: Dictionary = {}) -> Dictionary:
	if campaign_state.is_empty() or not _ensure_config_loaded():
		return {}
	var target_faction_id := faction_id
	if target_faction_id == "" or not campaign_state.get("factions", {}).has(target_faction_id):
		target_faction_id = _get_player_faction_id()
	var current_snapshot := get_management_resource_snapshot(target_faction_id)
	var resolved_action: Dictionary = {}
	var immediate_snapshot := current_snapshot.duplicate(true)
	var action_delta := {}
	var original_state := campaign_state.duplicate(true)
	if pending_action_id != "":
		var simulation_state := original_state.duplicate(true)
		campaign_state = simulation_state
		resolved_action = _resolve_action_for_faction(target_faction_id, pending_action_id, payload)
		if not resolved_action.is_empty() and _can_apply_resolved_action_for_faction(target_faction_id, resolved_action):
			_apply_resolved_action_for_faction(target_faction_id, resolved_action, false, true)
			immediate_snapshot = get_management_resource_snapshot(target_faction_id)
			action_delta = _diff_resource_snapshots(current_snapshot, immediate_snapshot)
		campaign_state = original_state
	var settlement_state := original_state.duplicate(true)
	campaign_state = settlement_state
	if not action_delta.is_empty():
		_apply_resolved_action_for_faction(target_faction_id, resolved_action, false, true)
	var before_settlement := get_management_resource_snapshot(target_faction_id)
	var settlement_breakdown: Array[String] = []
	_apply_settlement_resource_change(target_faction_id, "assets", -_get_total_maintenance_for_faction(target_faction_id), settlement_breakdown, _get_resource_display_name("maintenance"))
	_apply_settlement_operations(target_faction_id, config.get_round_settlement().get("operations", []), settlement_breakdown)
	var after_settlement := get_management_resource_snapshot(target_faction_id)
	var settlement_delta := _diff_resource_snapshots(before_settlement, after_settlement)
	campaign_state = original_state
	return {
		"faction_id": target_faction_id,
		"current": current_snapshot,
		"resolved_action": resolved_action,
		"action_delta": action_delta,
		"settlement_delta": settlement_delta,
		"projected": after_settlement,
		"settlement_summary": _build_settlement_summary_from_delta(settlement_delta),
		"settlement_breakdown": settlement_breakdown,
	}


func get_action_target_options(action_id: String, faction_id: String = "") -> Array:
	if campaign_state.is_empty() or not _ensure_config_loaded():
		return []
	var actor_id := faction_id if faction_id != "" else _get_player_faction_id()
	return _get_action_target_options(config.get_action(action_id), actor_id)


func _diff_resource_snapshots(before: Dictionary, after: Dictionary) -> Dictionary:
	var sections := ["city_resources", "faction_resources", "special_resources", "derived_metrics", "relations", "resources"]
	var result := {}
	for section_variant in sections:
		var section := String(section_variant)
		var before_values: Dictionary = before.get(section, {})
		var after_values: Dictionary = after.get(section, {})
		var delta := {}
		for key_variant in after_values.keys():
			var key := String(key_variant)
			var after_value = after_values.get(key, 0)
			var before_value = before_values.get(key, 0)
			if after_value is float or before_value is float:
				var float_delta := float(after_value) - float(before_value)
				if absf(float_delta) > 0.0001:
					delta[key] = float_delta
			else:
				var int_delta := int(after_value) - int(before_value)
				if int_delta != 0:
					delta[key] = int_delta
		if not delta.is_empty():
			result[section] = delta
	return result


func _get_action_target_options(action: Dictionary, actor_faction_id: String) -> Array:
	if action.is_empty() or not bool(action.get("requires_target", false)):
		return []
	var result: Array = []
	var target_filter := String(action.get("target_filter", "other_factions"))
	var excluded_target_ids: Array = action.get("exclude_target_faction_ids", [])
	for faction_id_variant in campaign_state.get("factions", {}).keys():
		var faction_id := String(faction_id_variant)
		if excluded_target_ids.has(faction_id):
			continue
		match target_filter:
			"other_factions":
				if faction_id == actor_faction_id:
					continue
			"player_faction":
				if faction_id != _get_player_faction_id():
					continue
			"all_factions", "":
				pass
			_:
				continue
		result.append({
			"id": faction_id,
			"display_name": config.get_faction_display_name(faction_id),
			"relation": int(_get_faction_state(actor_faction_id).get("relations", {}).get(faction_id, 0)),
		})
	return result


func set_selected_formations(formations: Array) -> void:
	_cleanup_selected_formations()

	var next_selected: Array = []
	var seen: Dictionary = {}
	for formation in formations:
		if not is_instance_valid(formation):
			continue
		var instance_id: int = formation.get_instance_id()
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		next_selected.append(formation)

	for formation in _selected_squads:
		if is_instance_valid(formation) and formation.has_method("set_selected") and not next_selected.has(formation):
			formation.set_selected(false)

	for formation in next_selected:
		if formation.has_method("set_selected"):
			formation.set_selected(true)

	_selected_squads = next_selected
	selection_changed.emit(_selected_squads.size())


func set_selected_squads(squads: Array) -> void:
	set_selected_formations(squads)


func clear_selection() -> void:
	set_selected_formations([])


func get_selected_formations() -> Array:
	_cleanup_selected_formations()
	return _selected_squads.duplicate()


func get_selected_squads() -> Array:
	return get_selected_formations()


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
	var resolved_action := _resolve_action_for_faction(faction_id, action_id, payload)
	return _can_apply_resolved_action_for_faction(faction_id, resolved_action)


func _can_apply_resolved_action_for_faction(faction_id: String, resolved_action: Dictionary) -> bool:
	if resolved_action.is_empty():
		return false
	if String(resolved_action.get("phase", "")) != String(campaign_state.get("phase", "")):
		return false
	if faction_id != _get_current_management_actor_id():
		return false
	if not _can_faction_select_action(faction_id, String(resolved_action.get("id", ""))):
		return false
	if bool(resolved_action.get("requires_target", false)):
		var target_faction_id := String(resolved_action.get("payload", {}).get("target_faction_id", ""))
		if target_faction_id == "":
			return false
		var target_is_valid := false
		for option in _get_action_target_options(resolved_action, faction_id):
			if option is Dictionary and String(option.get("id", "")) == target_faction_id:
				target_is_valid = true
				break
		if not target_is_valid:
			return false
	if _get_management_action_points(faction_id) < int(resolved_action.get("ap_cost", 0)):
		return false
	var full_cost: Dictionary = resolved_action.get("cost", {})
	for resource_id in full_cost.keys():
		if _get_resource_value_for_faction(faction_id, String(resource_id)) < int(full_cost[resource_id]):
			return false
	return true


func _apply_action_for_faction(faction_id: String, action_id: String, payload: Dictionary = {}, add_failure_log: bool = false) -> bool:
	var resolved_action := _resolve_action_for_faction(faction_id, action_id, payload)
	if resolved_action.is_empty():
		if add_failure_log:
			_add_campaign_log("未知行动：%s。" % action_id)
		return false
	if not _can_apply_resolved_action_for_faction(faction_id, resolved_action):
		if add_failure_log:
			if bool(resolved_action.get("requires_target", false)) and String(resolved_action.get("payload", {}).get("target_faction_id", "")) == "":
				_add_campaign_log("执行%s需要选择目标。" % resolved_action.get("display_name", action_id))
			elif _get_management_action_points(faction_id) < int(resolved_action.get("ap_cost", 0)):
				_add_campaign_log("行动力不足，无法执行%s。" % resolved_action.get("display_name", action_id))
			else:
				for resource_id in resolved_action.get("cost", {}).keys():
					if _get_resource_value_for_faction(faction_id, String(resource_id)) < int(resolved_action.get("cost", {}).get(resource_id, 0)):
						_add_campaign_log("%s不足，无法执行%s。" % [_get_resource_display_name(String(resource_id)), resolved_action.get("display_name", action_id)])
						break
		return false
	return _apply_resolved_action_for_faction(faction_id, resolved_action, add_failure_log, false)


func _apply_resolved_action_for_faction(faction_id: String, resolved_action: Dictionary, add_failure_log: bool = false, is_projection: bool = false) -> bool:
	if resolved_action.is_empty():
		return false
	var ap_cost := int(resolved_action.get("ap_cost", 0))
	_consume_management_action_points(faction_id, ap_cost)
	if not is_projection:
		_increment_round_action_usage(String(resolved_action.get("id", "")))
	for resource_id in resolved_action.get("cost", {}).keys():
		_add_resource_value_for_faction(faction_id, String(resource_id), -int(resolved_action.get("cost", {}).get(resource_id, 0)))
		_apply_resource_caps_to_faction(faction_id, [String(resource_id)])
	_apply_effects(faction_id, resolved_action.get("effects", []), resolved_action.get("payload", {}))
	if String(resolved_action.get("id", "")) == RECRUIT_ACTION_ID:
		_set_pending_recruit_options_for_faction(faction_id, [])
	if not is_projection:
		_add_campaign_log(_build_action_log(faction_id, resolved_action, resolved_action.get("payload", {}), ap_cost))
	return true


func _resolve_action_for_faction(faction_id: String, action_id: String, payload: Dictionary = {}) -> Dictionary:
	var action: Dictionary = config.get_action(action_id)
	if action.is_empty():
		return {}
	if action_id == RECRUIT_ACTION_ID:
		return _resolve_recruit_action_for_faction(faction_id, action, payload)
	var resolved_payload := payload.duplicate(true)
	resolved_payload["action_id"] = action_id
	var resolved := action.duplicate(true)
	resolved["id"] = action_id
	resolved["payload"] = resolved_payload
	resolved["ap_cost"] = _get_effective_action_cost(action_id)
	var value_cache: Dictionary = {}
	resolved["cost"] = _build_action_cost(resolved, resolved_payload, faction_id, value_cache)
	resolved["effects"] = _resolve_effects_for_action(faction_id, resolved, resolved_payload, value_cache)
	return resolved


func _build_action_cost(action: Dictionary, payload: Dictionary, faction_id: String = "", value_cache: Dictionary = {}) -> Dictionary:
	var actor_id := faction_id if faction_id != "" else _get_player_faction_id()
	var cost: Dictionary = {}
	for resource_id_variant in action.get("cost", {}).keys():
		cost[String(resource_id_variant)] = _resolve_value_spec(actor_id, action, action.get("cost", {}).get(resource_id_variant), payload, value_cache)
	var recruit_corps_id := _get_recruit_action_corps_id(action, payload)
	if recruit_corps_id == "":
		return cost
	for member in _get_corps_members_from_id(recruit_corps_id):
		var unit_id := String(member.get("unit_id", ""))
		var count := int(member.get("count", 0))
		var unit_campaign: Dictionary = config.get_unit(unit_id).get("campaign", {})
		if unit_campaign.has("manpower_cost"):
			cost["manpower_pool"] = int(cost.get("manpower_pool", 0)) + int(unit_campaign.get("manpower_cost", 0)) * count
		if unit_campaign.has("asset_cost"):
			cost["assets"] = int(cost.get("assets", 0)) + int(unit_campaign.get("asset_cost", 0)) * count
	return cost


func _resolve_effects_for_action(faction_id: String, action: Dictionary, payload: Dictionary, value_cache: Dictionary = {}) -> Array:
	var result: Array = []
	for effect_variant in action.get("effects", []):
		if not effect_variant is Dictionary:
			continue
		var effect: Dictionary = effect_variant.duplicate(true)
		effect["resolved_value"] = _resolve_value_spec(faction_id, action, effect.get("value", 0), payload, value_cache)
		var recipient := String(effect.get("recipient", "actor"))
		effect["resolved_recipient_faction_id"] = _resolve_effect_recipient_faction_id(faction_id, recipient, payload)
		var resolved_target := String(effect.get("target", effect.get("unit_id_from_payload", "")))
		if effect.has("target_from_payload"):
			resolved_target = String(payload.get(String(effect["target_from_payload"]), ""))
		elif recipient == "target_faction" and String(effect.get("scope", "resources")) == "relations" and String(effect.get("target_faction_id", "")) != "":
			resolved_target = String(effect.get("target_faction_id", ""))
		effect["resolved_target"] = resolved_target
		result.append(effect)
	return result


func _resolve_effect_recipient_faction_id(actor_faction_id: String, recipient: String, payload: Dictionary) -> String:
	match recipient:
		"actor", "":
			return actor_faction_id
		"target_faction":
			return String(payload.get("target_faction_id", ""))
	return actor_faction_id


func _resolve_value_spec(faction_id: String, action: Dictionary, spec, payload: Dictionary = {}, value_cache: Dictionary = {}):
	if spec is int or spec is float:
		return spec
	if not spec is Dictionary:
		return int(spec)
	var spec_type := "value_ref" if spec.has("value_ref") else String(spec.get("type", "literal"))
	match spec_type:
		"resource_percent":
			var resource_faction_id := _resolve_value_source_faction_id(faction_id, spec, payload)
			var base_resource = _get_resource_value_for_faction(resource_faction_id, String(spec.get("resource_id", "")))
			var value = float(spec.get("base", 0)) + float(base_resource) * float(spec.get("percent", 0.0))
			return _finalize_resolved_value(value, bool(spec.get("round", true)))
		"derived_percent":
			var derived_faction_id := _resolve_value_source_faction_id(faction_id, spec, payload)
			var resource_value = _get_resource_value_for_faction(derived_faction_id, String(spec.get("resource_id", "")))
			var derived_value = _build_derived_metrics_for_faction(derived_faction_id).get(String(spec.get("derived_id", "")), 0.0)
			var combined = float(spec.get("base", 0)) + float(resource_value) * float(derived_value) * float(spec.get("multiplier", 1.0))
			return _finalize_resolved_value(combined, bool(spec.get("round", true)))
		"per_use":
			var uses := _get_round_action_usage_count(String(spec.get("action_id", payload.get("action_id", ""))))
			if uses <= 0:
				uses = _get_round_action_usage_count(String(payload.get("action_id", "")))
			return int(spec.get("base", 0)) + int(spec.get("increment", 0)) * uses
		"relation_scale":
			var target_faction_id := String(spec.get("target_faction_id", payload.get("target_faction_id", "")))
			if spec.has("target_faction_id_from_payload"):
				target_faction_id = String(payload.get(String(spec.get("target_faction_id_from_payload", "target_faction_id")), ""))
			var relation_value := int(_get_faction_state(faction_id).get("relations", {}).get(target_faction_id, 0))
			var relation_factor := float(spec.get("positive_multiplier", 1.0)) if relation_value >= 0 else float(spec.get("negative_multiplier", 1.0))
			var relation_scaled := float(spec.get("base", 0)) + absf(float(relation_value)) * relation_factor
			return _finalize_resolved_value(relation_scaled, bool(spec.get("round", true)))
		"value_ref":
			var value_id := String(spec.get("value_ref", spec.get("value_id", "")))
			if value_id == "":
				return 0
			if value_cache.has(value_id):
				return _finalize_resolved_value(float(value_cache[value_id]) * float(spec.get("multiplier", 1.0)), bool(spec.get("round", true)))
			var value_defs: Dictionary = action.get("value_defs", {})
			var value_spec = value_defs.get(value_id, null)
			if value_spec == null:
				return 0
			var resolved_value = _resolve_value_spec(faction_id, action, value_spec, payload, value_cache)
			value_cache[value_id] = resolved_value
			return _finalize_resolved_value(float(resolved_value) * float(spec.get("multiplier", 1.0)), bool(spec.get("round", true)))
	return int(spec.get("value", spec.get("base", 0)))


func _resolve_value_source_faction_id(actor_faction_id: String, spec: Dictionary, payload: Dictionary) -> String:
	var source_faction := String(spec.get("source_faction", "actor"))
	match source_faction:
		"", "actor":
			return actor_faction_id
		"target_faction":
			return String(payload.get("target_faction_id", actor_faction_id))
		_:
			return source_faction


func _finalize_resolved_value(value: float, should_round: bool) -> int:
	return int(round(value)) if should_round else int(value)


func _get_recruit_action_corps_id(action: Dictionary, payload: Dictionary) -> String:
	if String(action.get("type", "")) != "recruit":
		return ""
	return String(payload.get("selected_corps_id", ""))


func _apply_effects(faction_id: String, effects: Array, payload: Dictionary) -> void:
	for effect_variant in effects:
		if not effect_variant is Dictionary:
			continue
		var effect: Dictionary = effect_variant
		var recipient_faction_id := String(effect.get("resolved_recipient_faction_id", faction_id))
		if recipient_faction_id == "":
			continue
		var scope := String(effect.get("scope", "resources"))
		var target := String(effect.get("resolved_target", effect.get("target", "")))
		match String(effect.get("op", "")):
			"add":
				if target == "":
					continue
				var value := int(effect.get("resolved_value", effect.get("value", 0)))
				if scope == "relations":
					var relations: Dictionary = _get_faction_state(recipient_faction_id).get("relations", {}).duplicate(true)
					relations[target] = int(relations.get(target, 0)) + value
					_get_faction_state(recipient_faction_id)["relations"] = relations
				else:
					_add_resource_value_for_faction(recipient_faction_id, target, value)
					_apply_resource_caps_to_faction(recipient_faction_id, [target])
			"set":
				if target == "":
					continue
				var set_value := int(effect.get("resolved_value", effect.get("value", 0)))
				if scope == "relations":
					var relation_store: Dictionary = _get_faction_state(recipient_faction_id).get("relations", {}).duplicate(true)
					relation_store[target] = set_value
					_get_faction_state(recipient_faction_id)["relations"] = relation_store
				else:
					_set_resource_value_for_faction(recipient_faction_id, target, set_value)
					_apply_resource_caps_to_faction(recipient_faction_id, [target])
			"add_unit", "add_army_unit":
				var unit_id := String(effect.get("unit_id", payload.get(String(effect.get("unit_id_from_payload", "unit_id")), "")))
				var count := int(effect.get("count", payload.get(String(effect.get("count_from_payload", "count")), 1)))
				_add_army_unit(recipient_faction_id, unit_id, maxi(1, count))
			"add_corps":
				var corps_id := String(effect.get("corps_id", payload.get("selected_corps_id", "")))
				_add_corps_to_army(recipient_faction_id, corps_id)


func _add_army_unit(faction_id: String, unit_id: String, count: int) -> void:
	if unit_id == "" or config.get_unit(unit_id).is_empty():
		return
	var faction_state := _get_faction_state(faction_id)
	var army := _normalize_army_runtime(faction_state.get("army", []))
	army.append({
		"corps_instance_id": _allocate_corps_instance_id(),
		"corps_id": unit_id,
		"members": [{"unit_id": unit_id, "count": count}],
	})
	faction_state["army"] = army


func _add_corps_to_army(faction_id: String, corps_id: String) -> void:
	if corps_id == "":
		return
	var faction_state := _get_faction_state(faction_id)
	var army := _normalize_army_runtime(faction_state.get("army", []))
	army.append(_instantiate_corps_runtime(corps_id))
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


func _build_action_payload_for_faction(faction_id: String, action: Dictionary) -> Dictionary:
	var payload := {}
	var action_id := String(action.get("id", ""))
	if action_id == RECRUIT_ACTION_ID:
		if _get_pending_recruit_options_for_faction(faction_id).is_empty():
			_begin_recruit_roll_for_faction(faction_id, false)
		var corps_id := _pick_ai_recruit_corps_id(faction_id)
		if corps_id != "":
			payload["selected_corps_id"] = corps_id
		return payload
	if not bool(action.get("requires_target", false)):
		return payload
	var target_options := _get_action_target_options(action, faction_id)
	if target_options.is_empty():
		return payload
	var target_faction_id := String(target_options[0].get("id", ""))
	if target_faction_id != "":
		payload["target_faction_id"] = target_faction_id
	return payload


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
			var action_id := String(node.get("action_id", ""))
			var action: Dictionary = config.get_action(action_id)
			var payload := _build_action_payload_for_faction(faction_id, action)
			return _apply_action_for_faction(faction_id, action_id, payload, false)
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
			for corps_entry in _normalize_army_runtime(faction_state.get("army", [])):
				if unit_id == "":
					total += 1
					continue
				for member_variant in corps_entry.get("members", []):
					if not member_variant is Dictionary:
						continue
					var member: Dictionary = member_variant
					if String(member.get("unit_id", "")) == unit_id:
						total += int(member.get("count", 0))
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
	var full_cost: Dictionary = action.get("cost", {})
	for resource_id in full_cost.keys():
		parts.append("%s-%d" % [_get_resource_display_name(String(resource_id)), int(full_cost[resource_id])])
	return "、".join(parts) if not parts.is_empty() else "无"


func _build_action_log_effect_text(effects: Array, payload: Dictionary) -> String:
	var parts: Array[String] = []
	for effect in effects:
		if not effect is Dictionary:
			continue
		var scope := String(effect.get("scope", "resources"))
		var target := String(effect.get("resolved_target", effect.get("target", "")))
		match String(effect.get("op", "")):
			"add":
				if target == "":
					continue
				var target_name: String = config.get_faction_display_name(target) if scope == "relations" else _get_resource_display_name(target)
				var value := int(effect.get("resolved_value", effect.get("value", 0)))
				parts.append("%s%+d" % [target_name, value])
			"set":
				if target == "":
					continue
				var target_name: String = config.get_faction_display_name(target) if scope == "relations" else _get_resource_display_name(target)
				var set_value := int(effect.get("resolved_value", effect.get("value", 0)))
				parts.append("%s设为%d" % [target_name, set_value])
			"add_unit", "add_army_unit":
				var unit_id := String(effect.get("resolved_target", effect.get("unit_id", payload.get(String(effect.get("unit_id_from_payload", "unit_id")), ""))))
				if unit_id == "":
					continue
				var unit_config: Dictionary = config.get_unit(unit_id)
				var count := int(effect.get("count", payload.get(String(effect.get("count_from_payload", "count")), 1)))
				parts.append("%s+%d" % [unit_config.get("display_name", unit_id), maxi(1, count)])
			"add_corps":
				var corps_id := String(effect.get("corps_id", payload.get("selected_corps_id", "")))
				if corps_id == "":
					continue
				parts.append("%s+1" % _get_corps_display_name_from_id(corps_id))
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
	for entry in _flatten_corps_army_for_battle(previous_army):
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
	return _normalize_army_runtime(army)



func _get_pending_recruit_options_for_faction(faction_id: String) -> Array:
	var pending_recruits: Dictionary = _get_management_state().get("pending_recruits", {})
	return pending_recruits.get(faction_id, []).duplicate(true)


func _set_pending_recruit_options_for_faction(faction_id: String, options: Array) -> void:
	var management := _get_management_state()
	var pending_recruits: Dictionary = management.get("pending_recruits", {}).duplicate(true)
	if options.is_empty():
		pending_recruits.erase(faction_id)
	else:
		pending_recruits[faction_id] = options.duplicate(true)
	management["pending_recruits"] = pending_recruits
	campaign_state["management"] = management


func _begin_recruit_roll_for_faction(faction_id: String, add_log: bool = false) -> bool:
	if not _can_begin_recruit_roll_for_faction(faction_id):
		if add_log:
			_add_campaign_log("当前无法发起征募。")
		return false
	var options := _get_pending_recruit_options_for_faction(faction_id)
	if options.is_empty():
		options = _roll_recruit_options_for_faction(faction_id)
		_set_pending_recruit_options_for_faction(faction_id, options)
	if add_log and not options.is_empty():
		var option_names: Array[String] = []
		for option_variant in options:
			if option_variant is Dictionary:
				option_names.append(String((option_variant as Dictionary).get("display_name", "兵团")))
		_add_campaign_log("%s开始征募：%s。" % [config.get_faction_display_name(faction_id), "、".join(option_names)])
	return not options.is_empty()


func _can_begin_recruit_roll_for_faction(faction_id: String) -> bool:
	if faction_id == "":
		return false
	if _get_management_action_points(faction_id) < _get_effective_action_cost(RECRUIT_ACTION_ID):
		return false
	if not _can_faction_select_action(faction_id, RECRUIT_ACTION_ID):
		return false
	if not _get_pending_recruit_options_for_faction(faction_id).is_empty():
		return _has_affordable_pending_recruit_option(faction_id)
	return _has_affordable_recruit_option_for_faction(faction_id)


func _has_affordable_pending_recruit_option(faction_id: String) -> bool:
	for option_variant in _get_pending_recruit_options_for_faction(faction_id):
		if option_variant is Dictionary and _can_afford_recruit_corps(faction_id, String((option_variant as Dictionary).get("corps_id", ""))):
			return true
	return false


func _has_affordable_recruit_option_for_faction(faction_id: String) -> bool:
	for corps_id_variant in _get_recruit_pool_corps_ids(faction_id):
		if _can_afford_recruit_corps(faction_id, String(corps_id_variant)):
			return true
	return false


func _can_afford_recruit_corps(faction_id: String, corps_id: String) -> bool:
	if corps_id == "":
		return false
	var recruit_action: Dictionary = config.get_action(RECRUIT_ACTION_ID)
	var cost := _build_action_cost(recruit_action, {"selected_corps_id": corps_id}, faction_id)
	for resource_id in cost.keys():
		if _get_resource_value_for_faction(faction_id, String(resource_id)) < int(cost.get(resource_id, 0)):
			return false
	return true


func _roll_recruit_options_for_faction(faction_id: String) -> Array:
	var options: Array = []
	for _i in range(RECRUIT_OPTION_COUNT):
		var corps_id := _roll_recruit_corps_id(faction_id)
		if corps_id != "":
			options.append(_build_pending_recruit_option(corps_id))
	return options


func _roll_recruit_corps_id(faction_id: String) -> String:
	var pool: Dictionary = config.get_recruit_pool(config.get_faction_recruit_pool_id(faction_id))
	var total_weight := 0
	for option_variant in pool.get("options", []):
		if option_variant is Dictionary:
			total_weight += maxi(0, int((option_variant as Dictionary).get("weight", 0)))
	if total_weight <= 0:
		return ""
	var roll := randi_range(1, total_weight)
	var running_weight := 0
	for option_variant in pool.get("options", []):
		if not option_variant is Dictionary:
			continue
		var option := option_variant as Dictionary
		running_weight += maxi(0, int(option.get("weight", 0)))
		if roll <= running_weight:
			return String(option.get("corps_id", ""))
	return ""


func _build_pending_recruit_option(corps_id: String) -> Dictionary:
	return {
		"corps_id": corps_id,
		"display_name": _get_corps_display_name_from_id(corps_id),
		"members": _get_corps_members_from_id(corps_id),
		"morale": _get_total_members_metric(_get_corps_members_from_id(corps_id), "morale"),
		"maintenance": _get_total_members_metric(_get_corps_members_from_id(corps_id), "upkeep"),
		"cost": _build_action_cost(config.get_action(RECRUIT_ACTION_ID), {"selected_corps_id": corps_id}),
	}


func _pick_ai_recruit_corps_id(faction_id: String) -> String:
	for option_variant in _get_pending_recruit_options_for_faction(faction_id):
		if option_variant is Dictionary:
			var corps_id := String((option_variant as Dictionary).get("corps_id", ""))
			if _can_afford_recruit_corps(faction_id, corps_id):
				return corps_id
	for corps_id_variant in _get_recruit_pool_corps_ids(faction_id):
		var corps_id := String(corps_id_variant)
		if _can_afford_recruit_corps(faction_id, corps_id):
			return corps_id
	return ""


func _get_recruit_pool_corps_ids(faction_id: String) -> Array:
	var result: Array = []
	var pool: Dictionary = config.get_recruit_pool(config.get_faction_recruit_pool_id(faction_id))
	for option_variant in pool.get("options", []):
		if option_variant is Dictionary:
			var corps_id := String((option_variant as Dictionary).get("corps_id", ""))
			if corps_id != "":
				result.append(corps_id)
	return result


func _resolve_recruit_action_for_faction(faction_id: String, action: Dictionary, payload: Dictionary) -> Dictionary:
	var corps_id := String(payload.get("selected_corps_id", ""))
	if corps_id == "":
		return {}
	if _get_runtime_controller(faction_id) == "player":
		var pending_match := false
		for option_variant in _get_pending_recruit_options_for_faction(faction_id):
			if option_variant is Dictionary and String((option_variant as Dictionary).get("corps_id", "")) == corps_id:
				pending_match = true
				break
		if not pending_match:
			return {}
	elif not _get_recruit_pool_corps_ids(faction_id).has(corps_id):
		return {}
	var resolved_payload := payload.duplicate(true)
	resolved_payload["action_id"] = RECRUIT_ACTION_ID
	var resolved := action.duplicate(true)
	resolved["id"] = RECRUIT_ACTION_ID
	resolved["payload"] = resolved_payload
	resolved["ap_cost"] = _get_effective_action_cost(RECRUIT_ACTION_ID)
	resolved["cost"] = _build_action_cost(resolved, resolved_payload, faction_id)
	resolved["effects"] = [{
		"op": "add_corps",
		"corps_id": corps_id,
		"resolved_target": corps_id,
		"resolved_recipient_faction_id": faction_id,
	}]
	return resolved


func _get_corps_members_from_id(corps_id: String) -> Array:
	var corps: Dictionary = config.get_corps(corps_id) if config != null else {}
	var members: Array = corps.get("members", [])
	return _normalize_corps_members(members)


func _get_corps_display_name_from_id(corps_id: String) -> String:
	var corps: Dictionary = config.get_corps(corps_id) if config != null else {}
	if not corps.is_empty():
		return String(corps.get("display_name", corps_id))
	var unit: Dictionary = config.get_unit(corps_id) if config != null else {}
	if unit.is_empty():
		return corps_id
	return "%s队" % String(unit.get("display_name", corps_id))


func _allocate_corps_instance_id() -> String:
	var corps_instance_id := "corps_%d" % _next_corps_instance_serial
	_next_corps_instance_serial += 1
	if not campaign_state.is_empty():
		campaign_state["next_corps_instance_serial"] = _next_corps_instance_serial
	return corps_instance_id


func _instantiate_corps_runtime(corps_id: String) -> Dictionary:
	var members := _get_corps_members_from_id(corps_id)
	if members.is_empty() and config != null and not config.get_unit(corps_id).is_empty():
		members = [{"unit_id": corps_id, "count": 1}]
	return {
		"corps_instance_id": _allocate_corps_instance_id(),
		"corps_id": corps_id,
		"members": members,
	}


func _normalize_army_runtime(source: Array) -> Array:
	var normalized: Array = []
	for entry_variant in source:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		var members := _normalize_corps_members(entry.get("members", []))
		var corps_id := String(entry.get("corps_id", ""))
		var corps_instance_id := String(entry.get("corps_instance_id", ""))
		if members.is_empty() and corps_id != "":
			members = _get_corps_members_from_id(corps_id)
		if members.is_empty():
			var unit_id := String(entry.get("unit_id", ""))
			var count := int(entry.get("count", 0))
			if unit_id == "" or count <= 0:
				continue
			corps_id = unit_id if corps_id == "" else corps_id
			members = [{"unit_id": unit_id, "count": count}]
		if members.is_empty():
			continue
		if corps_id == "":
			corps_id = String((members[0] as Dictionary).get("unit_id", "corps"))
		if corps_instance_id == "":
			corps_instance_id = _allocate_corps_instance_id()
		normalized.append({
			"corps_instance_id": corps_instance_id,
			"corps_id": corps_id,
			"members": members,
		})
	return normalized


func _normalize_corps_members(source: Array) -> Array:
	var members: Array = []
	for member_variant in source:
		if member_variant is Dictionary:
			var member: Dictionary = member_variant
			var unit_id := String(member.get("unit_id", ""))
			var count := int(member.get("count", 0))
			if unit_id != "" and count > 0:
				members.append({"unit_id": unit_id, "count": count})
	return members


func _flatten_corps_army_for_battle(army_source) -> Array:
	var flattened: Array = []
	var army: Array = army_source if army_source is Array else []
	for corps_entry in _normalize_army_runtime(army):
		var corps_instance_id := String(corps_entry.get("corps_instance_id", ""))
		for member_variant in corps_entry.get("members", []):
			if member_variant is Dictionary:
				var member: Dictionary = member_variant
				flattened.append({
					"unit_id": String(member.get("unit_id", "")),
					"count": 1,
					"formation_size_override": int(member.get("count", 0)),
					"source_corps_instance_id": corps_instance_id,
				})
	return flattened


func _rebuild_corps_army_from_survivors(player_survivors_by_corps: Dictionary, previous_army: Array) -> Array:
	var rebuilt: Array = []
	var remaining_survivors: Dictionary = player_survivors_by_corps.duplicate(true)
	for corps_entry in _normalize_army_runtime(previous_army):
		var corps_instance_id := String(corps_entry.get("corps_instance_id", ""))
		var corps_survivors: Dictionary = remaining_survivors.get(corps_instance_id, {})
		remaining_survivors.erase(corps_instance_id)
		var members: Array = []
		for member_variant in corps_entry.get("members", []):
			if member_variant is Dictionary:
				var member: Dictionary = member_variant
				var unit_id := String(member.get("unit_id", ""))
				var count := int(corps_survivors.get(unit_id, 0))
				if count > 0:
					members.append({"unit_id": unit_id, "count": count})
		if not members.is_empty():
			rebuilt.append({
				"corps_instance_id": corps_instance_id,
				"corps_id": String(corps_entry.get("corps_id", "")),
				"members": members,
			})
	for corps_instance_id_variant in remaining_survivors.keys():
		var corps_instance_id := String(corps_instance_id_variant)
		var corps_survivors: Dictionary = remaining_survivors.get(corps_instance_id_variant, {})
		var members: Array = []
		for unit_id_variant in corps_survivors.keys():
			var unit_id := String(unit_id_variant)
			var count := int(corps_survivors.get(unit_id_variant, 0))
			if count > 0:
				members.append({"unit_id": unit_id, "count": count})
		if not members.is_empty():
			rebuilt.append({
				"corps_instance_id": corps_instance_id,
				"corps_id": String((members[0] as Dictionary).get("unit_id", "")),
				"members": members,
			})
	return rebuilt


func _get_total_army_metric(army: Array, metric_key: String) -> int:
	var total := 0
	for corps_entry in _normalize_army_runtime(army):
		total += _get_total_members_metric(corps_entry.get("members", []), metric_key)
	return total


func _get_total_members_metric(members: Array, metric_key: String) -> int:
	if config == null:
		return 0
	var total := 0
	for member_variant in members:
		if member_variant is Dictionary:
			var member: Dictionary = member_variant
			var unit_config: Dictionary = config.get_unit(String(member.get("unit_id", "")))
			var campaign: Dictionary = unit_config.get("campaign", {})
			total += int(campaign.get(metric_key, 0)) * int(member.get("count", 0))
	return total


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


func _cleanup_selected_formations() -> void:
	var alive: Array = []
	for formation in _selected_squads:
		if is_instance_valid(formation):
			alive.append(formation)
	_selected_squads = alive


func _cleanup_selected_squads() -> void:
	_cleanup_selected_formations()


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
	_apply_settlement_resource_change(faction_id, "assets", maintenance_cost, summary, _get_resource_display_name("maintenance"))
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
		var derived_metrics := _build_derived_metrics_for_faction(faction_id)
		match String(operation.get("op", "")):
			"add":
				var add_value := int(operation.get("value", 0))
				_add_resource_value_for_faction(faction_id, target, add_value)
				_append_settlement_summary(summary, target, add_value, _describe_settlement_operation(operation))
			"add_from_resource":
				var source_id := String(operation.get("resource_id", ""))
				var resource_value := _finalize_resolved_value(float(_get_resource_value_for_faction(faction_id, source_id)) * float(operation.get("multiplier", 1.0)), bool(operation.get("round", true)))
				_add_resource_value_for_faction(faction_id, target, resource_value)
				_append_settlement_summary(summary, target, resource_value, _describe_settlement_operation(operation))
			"add_percent_of":
				var base_value = _get_resource_value_for_faction(faction_id, String(operation.get("resource_id", "")))
				var percent_source_id := String(operation.get("percent_resource_id", ""))
				var percent_value := float(operation.get("percent", _get_resource_value_for_faction(faction_id, percent_source_id)))
				var percent_amount := _finalize_resolved_value(float(base_value) * percent_value, bool(operation.get("round", true)))
				_add_resource_value_for_faction(faction_id, target, percent_amount)
				_append_settlement_summary(summary, target, percent_amount, _describe_settlement_operation(operation))
			"add_scaled_resource":
				var source_resource_id := String(operation.get("resource_id", ""))
				var scaled_value := float(_get_resource_value_for_faction(faction_id, source_resource_id)) * float(operation.get("multiplier", 1.0))
				var scale_resource_id := String(operation.get("scale_resource_id", ""))
				if scale_resource_id != "":
					scaled_value *= float(_get_resource_value_for_faction(faction_id, scale_resource_id))
				var scale_derived_id := String(operation.get("scale_derived_id", ""))
				if scale_derived_id != "":
					scaled_value *= float(derived_metrics.get(scale_derived_id, 0.0))
				var scaled_amount := _finalize_resolved_value(scaled_value, bool(operation.get("round", true)))
				_add_resource_value_for_faction(faction_id, target, scaled_amount)
				_append_settlement_summary(summary, target, scaled_amount, _describe_settlement_operation(operation))
			"add_share_of_city_resource":
				var city_resource_id := String(operation.get("resource_id", ""))
				var share_id := String(operation.get("share_id", ""))
				var share_amount := _finalize_resolved_value(float(_get_resource_value_for_faction(faction_id, city_resource_id)) * float(derived_metrics.get(share_id, 0.0)) * float(operation.get("multiplier", 1.0)), bool(operation.get("round", true)))
				_add_resource_value_for_faction(faction_id, target, share_amount)
				_append_settlement_summary(summary, target, share_amount, _describe_settlement_operation(operation))
			"add_from_derived":
				var derived_id := String(operation.get("derived_id", ""))
				var derived_amount := _finalize_resolved_value(float(derived_metrics.get(derived_id, 0.0)) * float(operation.get("multiplier", 1.0)), bool(operation.get("round", true)))
				_add_resource_value_for_faction(faction_id, target, derived_amount)
				_append_settlement_summary(summary, target, derived_amount, _describe_settlement_operation(operation))
			"add_from_relation":
				var relation_faction_id := String(operation.get("relation_faction_id", ""))
				var relation_value := int(_get_faction_state(faction_id).get("relations", {}).get(relation_faction_id, 0))
				var relation_amount := _finalize_resolved_value(float(relation_value) * float(operation.get("multiplier", 1.0)), bool(operation.get("round", true)))
				_add_resource_value_for_faction(faction_id, target, relation_amount)
				_append_settlement_summary(summary, target, relation_amount, _describe_settlement_operation(operation))
			"reset_from_initial":
				var initial_value = _get_initial_resource_value(faction_id, target)
				_set_resource_value_for_faction(faction_id, target, initial_value)
				summary.append("%s：%s重置为%d" % [_describe_settlement_operation(operation), _get_resource_display_name(target), initial_value])
		_apply_resource_cap(faction_id, target)


func _apply_settlement_resource_change(faction_id: String, target: String, value: int, summary: Array[String], source_label: String = "") -> void:
	if target == "":
		return
	_add_resource_value_for_faction(faction_id, target, value)
	_apply_resource_cap(faction_id, target)
	_append_settlement_summary(summary, target, value, source_label)


func _append_settlement_summary(summary: Array[String], target: String, value: int, source_label: String = "") -> void:
	if value == 0:
		return
	var resource_change := "%s%+d" % [_get_resource_display_name(target), value]
	if source_label == "":
		summary.append(resource_change)
		return
	summary.append("%s：%s" % [source_label, resource_change])


func _describe_settlement_operation(operation: Dictionary) -> String:
	match String(operation.get("op", "")):
		"add":
			return _get_resource_display_name(String(operation.get("target", "")))
		"add_from_resource":
			return _get_resource_display_name(String(operation.get("resource_id", "")))
		"add_percent_of":
			var resource_name := _get_resource_display_name(String(operation.get("resource_id", "")))
			var percent_source_id := String(operation.get("percent_resource_id", ""))
			if percent_source_id != "":
				return "%s x %s" % [resource_name, _get_resource_display_name(percent_source_id)]
			return "%s x %.0f%%" % [resource_name, float(operation.get("percent", 0.0)) * 100.0]
		"add_scaled_resource":
			var scaled_parts: Array[String] = [_get_resource_display_name(String(operation.get("resource_id", "")))]
			var scale_resource_id := String(operation.get("scale_resource_id", ""))
			if scale_resource_id != "":
				scaled_parts.append(_get_resource_display_name(scale_resource_id))
			var scale_derived_id := String(operation.get("scale_derived_id", ""))
			if scale_derived_id != "":
				scaled_parts.append(_get_resource_display_name(scale_derived_id))
			return " x ".join(scaled_parts)
		"add_share_of_city_resource":
			return "%s x %s" % [
				_get_resource_display_name(String(operation.get("resource_id", ""))),
				_get_resource_display_name(String(operation.get("share_id", "")))
			]
		"add_from_derived":
			return _get_resource_display_name(String(operation.get("derived_id", "")))
		"add_from_relation":
			return "与%s关系" % _get_relation_target_display_name(String(operation.get("relation_faction_id", "")))
		"reset_from_initial":
			return "初始化"
	return _get_resource_display_name(String(operation.get("target", "")))


func _get_relation_target_display_name(faction_id: String) -> String:
	if faction_id == "":
		return "目标势力"
	return config.get_faction_display_name(faction_id) if config != null else faction_id


func _build_settlement_summary_from_delta(settlement_delta: Dictionary) -> Array[String]:
	var summary: Array[String] = []
	for section_id in ["city_resources", "faction_resources", "special_resources", "derived_metrics", "relations"]:
		var values: Dictionary = settlement_delta.get(section_id, {})
		for key_variant in values.keys():
			var key := String(key_variant)
			var value = values.get(key, 0)
			if value is float:
				if absf(float(value)) <= 0.0001:
					continue
				summary.append("%s%+.2f" % [_get_settlement_summary_name(section_id, key), snappedf(float(value), 0.01)])
			else:
				if int(value) == 0:
					continue
				summary.append("%s%+d" % [_get_settlement_summary_name(section_id, key), int(value)])
	return summary


func _get_settlement_summary_name(section_id: String, key: String) -> String:
	if section_id == "relations":
		return config.get_faction_display_name(key)
	return _get_resource_display_name(key)


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
	return _get_total_army_metric(_get_faction_state(faction_id).get("army", []), "upkeep")


func _initialize_management_phase(initialize_to_max: bool = false) -> void:
	var action_order: Array = config.get_management_action_order() if config != null else []
	var starting_index := maxi(action_order.size() - 1, 0)
	for faction_id_variant in campaign_state.get("factions", {}).keys():
		_apply_round_resource_rules(String(faction_id_variant), initialize_to_max)
	campaign_state["management"] = {
		"action_order": action_order.duplicate(),
		"current_actor_index": starting_index,
		"action_usage_counts": {},
		"pending_recruits": {},
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
		var payload := _build_action_payload_for_faction(faction_id, action_variant)
		if bool(action_variant.get("requires_target", false)) and String(payload.get("target_faction_id", "")) == "":
			continue
		if _get_management_action_points(faction_id) < _get_effective_action_cost(action_id):
			continue
		var full_cost := _build_action_cost(action_variant, payload, faction_id)
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
	var preview_payload := {}
	if action_id == RECRUIT_ACTION_ID:
		var pending_options := _get_pending_recruit_options_for_faction(_get_player_faction_id())
		if not pending_options.is_empty():
			preview_payload["selected_corps_id"] = String((pending_options[0] as Dictionary).get("corps_id", ""))
	entry["cost"] = _build_action_cost(entry, preview_payload)
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
	var population := int(_get_resource_value_for_faction(faction_id, "population"))
	var development := int(_get_resource_value_for_faction(faction_id, "development"))
	var recruit_rate := float(_get_resource_value_for_faction(faction_id, "recruit_rate"))
	var total_support := 0
	var total_owned_assets := 0
	for other_faction_id in campaign_state.get("factions", {}).keys():
		var id := String(other_faction_id)
		total_support += int(_get_resource_value_for_faction(id, "support_base"))
		total_owned_assets += int(_get_resource_value_for_faction(id, "owned_assets"))
	var support_share := float(support_base) / float(total_support) if total_support > 0 else 0.0
	var ownership_share := float(owned_assets) / float(total_owned_assets) if total_owned_assets > 0 else 0.0
	var recruit_share := support_share
	var total_manpower_pool := float(population) * recruit_rate
	var development_pool := float(population) * float(development) / 10000.0
	var support_development_gain := _finalize_resolved_value(development_pool * 0.5 * support_share, true)
	var ownership_development_gain := _finalize_resolved_value(development_pool * 0.5 * ownership_share, true)
	var maintenance := _get_total_maintenance_for_faction(faction_id)
	var relations: Dictionary = _get_faction_state(faction_id).get("relations", {})
	var relation_pressure := 0
	for relation_value in relations.values():
		var relation_amount := int(relation_value)
		if relation_amount < 0:
			relation_pressure += abs(relation_amount)
	var city_influence := _finalize_resolved_value(float(support_base) * 0.4 + float(owned_assets) * 0.35 + float(development) * 0.25, true)
	var projected_asset_gain := owned_assets + support_development_gain + ownership_development_gain
	var projected_manpower_gain := _finalize_resolved_value(total_manpower_pool * support_share, true)
	var readiness_margin := projected_asset_gain - maintenance
	return {
		"support_share": support_share,
		"ownership_share": ownership_share,
		"recruit_share": recruit_share,
		"city_influence": city_influence,
		"relation_pressure": relation_pressure,
		"projected_asset_gain": projected_asset_gain,
		"projected_manpower_gain": projected_manpower_gain,
		"readiness_margin": readiness_margin,
		"war_expectation": support_base + owned_assets,
		"maintenance": maintenance,
	}
