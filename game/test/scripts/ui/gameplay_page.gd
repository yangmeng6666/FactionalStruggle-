extends Control

signal action_requested(action_id: String, payload: Dictionary)
signal battle_requested

var game_session: Node = null
var config = null
var _snapshot: Dictionary = {}
var _selected_action_group_id: String = ""

@onready var _top_bar: Label = $MainPanel/MarginContainer/VBox/TopBar
@onready var _resource_list: GridContainer = $MainPanel/MarginContainer/VBox/Content/Left/ResourceList
@onready var _relation_list: GridContainer = $MainPanel/MarginContainer/VBox/Content/Left/RelationList
@onready var _action_list: VBoxContainer = $MainPanel/MarginContainer/VBox/Content/Center/ActionScroll/ActionList
@onready var _recruit_list: VBoxContainer = $MainPanel/MarginContainer/VBox/Content/Center/RecruitScroll/RecruitList
@onready var _army_list: VBoxContainer = $MainPanel/MarginContainer/VBox/Content/Right/ArmyList
@onready var _morale_label: Label = $MainPanel/MarginContainer/VBox/Content/Right/MoraleLabel
@onready var _maintenance_label: Label = $MainPanel/MarginContainer/VBox/Content/Right/MaintenanceLabel
@onready var _log_list: VBoxContainer = $MainPanel/MarginContainer/VBox/Content/Right/LogScroll/LogList
@onready var _start_battle_button: Button = $MainPanel/MarginContainer/VBox/Footer/StartBattleButton


func setup(session: Node) -> void:
	if game_session != null and game_session.has_signal("campaign_state_changed") and game_session.campaign_state_changed.is_connected(_on_campaign_state_changed):
		game_session.campaign_state_changed.disconnect(_on_campaign_state_changed)
	game_session = session
	config = game_session.get("config") if game_session != null else null
	if game_session != null and game_session.has_signal("campaign_state_changed") and not game_session.campaign_state_changed.is_connected(_on_campaign_state_changed):
		game_session.campaign_state_changed.connect(_on_campaign_state_changed)
	if game_session != null and game_session.has_method("get_campaign_snapshot"):
		_on_campaign_state_changed(game_session.get_campaign_snapshot())


func _ready() -> void:
	_start_battle_button.pressed.connect(_on_start_battle_pressed)
	if game_session != null and game_session.has_method("get_campaign_snapshot"):
		_on_campaign_state_changed(game_session.get_campaign_snapshot())


func _on_campaign_state_changed(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if config == null and game_session != null:
		config = game_session.get("config")
	_render()


func _render() -> void:
	_clear_children(_resource_list)
	_clear_children(_relation_list)
	_clear_children(_action_list)
	_clear_children(_recruit_list)
	_clear_children(_army_list)
	_clear_children(_log_list)

	_start_battle_button.text = String(_snapshot.get("next_round_button_text", "进入战斗"))

	if _snapshot.is_empty() or config == null:
		_top_bar.text = "玩法配置加载失败"
		_start_battle_button.disabled = true
		return

	var faction_id := String(_snapshot.get("faction_id", ""))
	var current_actor_name := String(_snapshot.get("current_actor_name", ""))
	var phase_id := String(_snapshot.get("phase", "management"))
	var phase_name: String = config.get_phase_display_name(phase_id)
	var top_bar_parts: Array = [
		"第%d回合" % int(_snapshot.get("round", 1)),
		config.get_faction_display_name(faction_id),
		phase_name,
	]
	if current_actor_name != "":
		top_bar_parts.append("当前行动:%s" % current_actor_name)
	var enemy_name := String(_snapshot.get("current_round_enemy_name", ""))
	if enemy_name != "":
		top_bar_parts.append("敌军:%s" % enemy_name)
	_top_bar.text = " · ".join(top_bar_parts)

	_render_resources()
	_render_relations()
	_render_action_groups()
	_render_action_options()
	_render_army()
	_render_log()

	var morale := int(_snapshot.get("total_morale", 0))
	var min_morale := int(_snapshot.get("min_corps_morale", 0))
	_morale_label.text = "兵团士气：%d / %d" % [morale, min_morale]
	_maintenance_label.text = "维护费：%d" % int(_snapshot.get("total_maintenance", 0))
	_start_battle_button.disabled = not bool(_snapshot.get("can_start_battle", false))


func _render_resources() -> void:
	var resources: Dictionary = _snapshot.get("resources", {})
	var order: Array = config.get_resource_order()
	var shared_ap := int(_snapshot.get("shared_action_points", resources.get("action_points", 0)))
	if resources.has("action_points"):
		resources["action_points"] = shared_ap
	if order.is_empty():
		order = resources.keys()
	for resource_id in order:
		if not resources.has(resource_id):
			continue
		var resource_config: Dictionary = config.get_resource(String(resource_id))
		_add_pair(_resource_list, resource_config.get("display_name", resource_id), _format_value(resources[resource_id]))


func _render_relations() -> void:
	var relations: Dictionary = _snapshot.get("relations", {})
	for faction_id in relations.keys():
		_add_pair(_relation_list, config.get_faction_display_name(String(faction_id)), str(relations[faction_id]))


func _render_action_groups() -> void:
	if game_session == null or not game_session.has_method("get_available_action_groups"):
		return
	var groups: Array = game_session.get_available_action_groups()
	if groups.is_empty():
		_selected_action_group_id = ""
		return
	var group_ids: Array = []
	for group in groups:
		group_ids.append(String(group.get("id", "")))
	if _selected_action_group_id == "" or not group_ids.has(_selected_action_group_id):
		_selected_action_group_id = String(group_ids[0])
	for group in groups:
		var group_id := String(group.get("id", ""))
		var button := Button.new()
		button.text = String(group.get("display_name", group_id))
		button.toggle_mode = true
		button.button_pressed = group_id == _selected_action_group_id
		button.pressed.connect(func() -> void:
			_selected_action_group_id = group_id
			_render()
		)
		_action_list.add_child(button)


func _render_action_options() -> void:
	if _selected_action_group_id == "" or game_session == null or not game_session.has_method("get_available_action_options"):
		return
	var is_player_turn := bool(_snapshot.get("is_player_turn", false))
	for action in game_session.get_available_action_options(_selected_action_group_id):
		var action_id := String(action.get("id", ""))
		var button := Button.new()
		button.text = _build_action_button_text(action)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = (not is_player_turn) or (not _can_apply_action(action_id))
		button.pressed.connect(func() -> void:
			action_requested.emit(action_id, {})
		)
		_recruit_list.add_child(button)


func _render_army() -> void:
	for entry in _snapshot.get("army", []):
		var unit_id := String(entry.get("unit_id", ""))
		var unit_config: Dictionary = config.get_unit(unit_id)
		var campaign: Dictionary = unit_config.get("campaign", {})
		var label := Label.new()
		label.text = "%s x%d  士气:%d  维护:%d" % [
			unit_config.get("display_name", unit_id),
			int(entry.get("count", 0)),
			int(campaign.get("morale", 0)) * int(entry.get("count", 0)),
			int(campaign.get("upkeep", 0)) * int(entry.get("count", 0)),
		]
		_army_list.add_child(label)


func _render_log() -> void:
	for message in _snapshot.get("log", []):
		var label := Label.new()
		label.text = String(message)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_log_list.add_child(label)


func _build_action_button_text(action: Dictionary) -> String:
	var parts: Array[String] = [String(action.get("display_name", action.get("id", "action")))]
	parts.append("行动力:%d" % int(action.get("ap_cost", 0)))
	var cost: Dictionary = action.get("cost", {})
	for resource_id in cost.keys():
		var resource_config: Dictionary = config.get_resource(String(resource_id))
		parts.append("%s:%d" % [resource_config.get("display_name", resource_id), int(cost[resource_id])])
	var effect_text := _build_effect_text(action.get("effects", []))
	if effect_text != "":
		parts.append(effect_text)
	return "  ".join(parts)


func _build_effect_text(effects: Array) -> String:
	var parts: Array[String] = []
	for effect in effects:
		if not effect is Dictionary:
			continue
		match String(effect.get("op", "")):
			"add":
				var target := String(effect.get("target", ""))
				var value := int(effect.get("value", 0))
				var target_name := _get_effect_target_name(effect, target)
				parts.append("%s:%+d" % [target_name, value])
			"set":
				var target := String(effect.get("target", ""))
				var target_name := _get_effect_target_name(effect, target)
				parts.append("%s=%d" % [target_name, int(effect.get("value", 0))])
			"add_unit", "add_army_unit":
				var unit_id := String(effect.get("unit_id", ""))
				var unit_config: Dictionary = config.get_unit(unit_id)
				parts.append("%s:+%d" % [unit_config.get("display_name", unit_id), int(effect.get("count", 1))])
	return "  ".join(parts)


func _get_effect_target_name(effect: Dictionary, target: String) -> String:
	if String(effect.get("scope", "resources")) == "relations":
		return config.get_faction_display_name(target)
	var resource_config: Dictionary = config.get_resource(target)
	return String(resource_config.get("display_name", target))


func _can_apply_action(action_id: String) -> bool:
	if game_session != null and game_session.has_method("can_apply_action"):
		return game_session.can_apply_action(action_id, {})
	return true


func _on_start_battle_pressed() -> void:
	battle_requested.emit()


func _add_pair(parent: GridContainer, key, value) -> void:
	var key_label := Label.new()
	key_label.text = String(key)
	parent.add_child(key_label)

	var value_label := Label.new()
	value_label.text = String(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(value_label)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _format_value(value) -> String:
	if value is float:
		return "%.2f" % value
	return str(value)
