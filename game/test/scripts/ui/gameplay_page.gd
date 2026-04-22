extends Control

signal action_requested(action_id: String, payload: Dictionary)
signal battle_requested

var game_session: Node = null
var config = null
var _snapshot: Dictionary = {}
var _selected_action_group_id: String = ""
var _selected_view_faction_id: String = ""
var _hovered_faction_id: String = ""
var _is_hovering_faction_marker := false
var _is_hovering_hover_panel := false
var _hover_visibility_request_id: int = 0
var _action_cue_tween: Tween = null
var _queued_ai_action_cues: Array = []
var _active_action_cue_faction_id: String = ""
var _last_seen_log_count: int = -1
var _is_playing_action_cue := false
var _resource_faction_markers: Dictionary = {}
var _resource_faction_labels: Dictionary = {}
var _resource_faction_indicator_lights: Dictionary = {}

@onready var _top_bar: Label = $MainPanel/MarginContainer/VBox/TopBar
@onready var _action_cue: PanelContainer = $ActionCue
@onready var _action_cue_label: Label = $ActionCue/ActionCueMargin/ActionCueLabel
@onready var _resource_title: Label = $MainPanel/MarginContainer/VBox/Content/Left/ResourceTitle
@onready var _resource_faction_selector: HBoxContainer = $MainPanel/MarginContainer/VBox/Content/Left/ResourceFactionSelector
@onready var _resource_list: GridContainer = $MainPanel/MarginContainer/VBox/Content/Left/LeftScroll/LeftContent/ResourceList
@onready var _relation_title: Label = $MainPanel/MarginContainer/VBox/Content/Left/LeftScroll/LeftContent/RelationTitle
@onready var _relation_list: GridContainer = $MainPanel/MarginContainer/VBox/Content/Left/LeftScroll/LeftContent/RelationList
@onready var _resource_hover_panel: PanelContainer = $ResourceHoverPanel
@onready var _resource_hover_title: Label = $ResourceHoverPanel/MarginContainer/HoverContent/HoverTitle
@onready var _resource_hover_scroll: ScrollContainer = $ResourceHoverPanel/MarginContainer/HoverContent/HoverScroll
@onready var _resource_hover_list: GridContainer = $ResourceHoverPanel/MarginContainer/HoverContent/HoverScroll/HoverInner/HoverResourceList
@onready var _resource_hover_relation_list: GridContainer = $ResourceHoverPanel/MarginContainer/HoverContent/HoverScroll/HoverInner/HoverRelationList
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
	_action_cue.hide()
	_action_cue.modulate = Color(1, 1, 1, 0)
	_resource_hover_panel.hide()
	_resource_hover_panel.mouse_entered.connect(_on_hover_panel_mouse_entered)
	_resource_hover_panel.mouse_exited.connect(_on_hover_panel_mouse_exited)
	if game_session != null and game_session.has_method("get_campaign_snapshot"):
		_on_campaign_state_changed(game_session.get_campaign_snapshot())


func _on_campaign_state_changed(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if config == null and game_session != null:
		config = game_session.get("config")
	_sync_selected_view_faction()
	_render()
	_update_ai_action_cue()


func _render() -> void:
	_clear_children(_resource_faction_selector)
	_clear_children(_resource_list)
	_clear_children(_relation_list)
	_clear_children(_action_list)
	_clear_children(_recruit_list)
	_clear_children(_army_list)
	_clear_children(_log_list)

	_start_battle_button.text = String(_snapshot.get("next_round_button_text", "进入战斗"))
	_start_battle_button.tooltip_text = ""

	if _snapshot.is_empty() or config == null:
		_top_bar.text = "玩法配置加载失败"
		_resource_title.text = "城市概览"
		_relation_title.hide()
		_start_battle_button.disabled = true
		_hide_action_cue_immediately()
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

	_render_resource_faction_selector()
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
	if _get_available_action_points() > 0 and bool(_snapshot.get("is_player_turn", false)):
		_start_battle_button.tooltip_text = "点击后会立即结束经营，并放弃剩余行动力。"


func _render_resource_faction_selector() -> void:
	var factions := _get_management_resource_factions()
	_resource_faction_markers.clear()
	_resource_faction_labels.clear()
	_resource_faction_indicator_lights.clear()
	_resource_title.text = "城市概览"
	if factions.is_empty():
		_hide_hover_panel()
		return
	for faction in factions:
		var faction_id := String(faction.get("id", ""))
		var marker := PanelContainer.new()
		marker.mouse_filter = Control.MOUSE_FILTER_STOP
		marker.custom_minimum_size = Vector2(72, 30)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)
		marker.add_child(row)

		var indicator := ColorRect.new()
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		indicator.custom_minimum_size = Vector2(8, 0)
		indicator.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(indicator)

		var label := Label.new()
		label.text = String(faction.get("display_name", faction_id))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)

		_resource_faction_markers[faction_id] = marker
		_resource_faction_labels[faction_id] = label
		_resource_faction_indicator_lights[faction_id] = indicator
		marker.mouse_entered.connect(func() -> void:
			_on_faction_marker_mouse_entered(faction_id, marker)
		)
		marker.mouse_exited.connect(func() -> void:
			_on_faction_marker_mouse_exited(faction_id)
		)
		marker.gui_input.connect(func(event: InputEvent) -> void:
			_on_faction_marker_gui_input(event)
		)
		_resource_faction_selector.add_child(marker)
	_refresh_resource_faction_selector_state()


func _refresh_resource_faction_selector_state() -> void:
	var current_actor_id := String(_snapshot.get("current_actor_id", ""))
	var player_faction_id := String(_snapshot.get("faction_id", ""))
	for faction_id_variant in _resource_faction_markers.keys():
		var faction_id := String(faction_id_variant)
		var is_selected := faction_id == _selected_view_faction_id
		var is_current_actor := faction_id == current_actor_id
		var is_player_faction := faction_id == player_faction_id
		var is_active_cue := faction_id == _active_action_cue_faction_id
		var marker_variant = _resource_faction_markers.get(faction_id)
		if marker_variant is Control:
			var marker := marker_variant as Control
			marker.modulate = _get_faction_marker_modulate(is_selected, is_current_actor, is_player_faction, is_active_cue)
			marker.scale = Vector2(1.08, 1.08) if (is_current_actor or is_active_cue) else Vector2.ONE
		var label_variant = _resource_faction_labels.get(faction_id)
		if label_variant is Label:
			_apply_faction_marker_label_style(label_variant as Label, is_selected, is_current_actor, is_player_faction, is_active_cue)
		var indicator_variant = _resource_faction_indicator_lights.get(faction_id)
		if indicator_variant is ColorRect:
			(indicator_variant as ColorRect).color = _get_faction_indicator_color(is_current_actor, is_player_faction, is_active_cue)


func _apply_faction_marker_label_style(label: Label, is_selected: bool, is_current_actor: bool, is_player_faction: bool, is_active_cue: bool) -> void:
	label.add_theme_font_size_override("font_size", 15 if (is_current_actor or is_active_cue) else 14)
	if is_active_cue:
		label.modulate = Color(1.0, 0.98, 0.9, 1.0)
	elif is_current_actor:
		label.modulate = Color(1.0, 0.97, 0.84, 1.0)
	elif is_selected:
		label.modulate = Color(0.92, 0.88, 0.62, 1.0)
	elif is_player_faction:
		label.modulate = Color(0.84, 0.92, 1.0, 1.0)
	else:
		label.modulate = Color(0.9, 0.93, 0.96, 0.95)


func _get_faction_indicator_color(is_current_actor: bool, is_player_faction: bool, is_active_cue: bool) -> Color:
	if is_active_cue:
		return Color(1.0, 0.9, 0.32, 1.0)
	if is_current_actor:
		return Color(1.0, 0.72, 0.32, 0.95)
	if is_player_faction:
		return Color(0.58, 0.8, 1.0, 0.55)
	return Color(0.28, 0.35, 0.41, 0.35)


func _render_resources() -> void:
	_render_resource_snapshot(_resource_list, _relation_list, _get_selected_management_resource_snapshot(), true, false)


func _render_relations() -> void:
	_relation_title.hide()


func _render_resource_snapshot(resource_list: GridContainer, relation_list: GridContainer, resource_snapshot: Dictionary, include_city_resources: bool = true, include_faction_details: bool = true) -> void:
	var city_resources: Dictionary = resource_snapshot.get("city_resources", {})
	var faction_resources: Dictionary = resource_snapshot.get("faction_resources", {})
	var special_resources: Dictionary = resource_snapshot.get("special_resources", {})
	var derived_metrics: Dictionary = resource_snapshot.get("derived_metrics", {})
	var resources: Dictionary = resource_snapshot.get("resources", {}).duplicate(true)
	if include_city_resources and not city_resources.is_empty():
		_render_resource_group(resource_list, "城市资源", city_resources, config.get_city_resource_order())
	if include_faction_details:
		_render_resource_group(resource_list, "阵营资源", faction_resources, config.get_faction_resource_order())
		_render_resource_group(resource_list, "特殊资源", special_resources, config.get_special_resource_order())
		_render_resource_group(resource_list, "衍生指标", derived_metrics, config.get_derived_resource_order())
	elif city_resources.is_empty():
		var order: Array = config.get_resource_order()
		if order.is_empty():
			order = resources.keys()
		_render_resource_section(resource_list, resources, order)
	if include_faction_details:
		var relations: Dictionary = resource_snapshot.get("relations", {})
		for faction_id in relations.keys():
			_add_pair(relation_list, config.get_faction_display_name(String(faction_id)), str(relations[faction_id]))


func _render_resource_group(resource_list: GridContainer, title: String, values: Dictionary, order: Array) -> void:
	if values.is_empty():
		return
	_add_section_header(resource_list, title)
	_render_resource_section(resource_list, values, order)


func _render_resource_section(resource_list: GridContainer, values: Dictionary, order: Array) -> void:
	if values.is_empty():
		return
	var resolved_order: Array = order.duplicate() if not order.is_empty() else values.keys()
	for resource_id in resolved_order:
		if not values.has(resource_id):
			continue
		var resource_config: Dictionary = config.get_resource(String(resource_id))
		_add_pair(resource_list, resource_config.get("display_name", resource_id), _format_value(values[resource_id]))


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


func _update_ai_action_cue() -> void:
	if _snapshot.is_empty() or config == null:
		_hide_action_cue_immediately()
		_last_seen_log_count = -1
		return
	var log_entries: Array = _snapshot.get("log", [])
	var current_log_count := log_entries.size()
	if _last_seen_log_count < 0:
		_last_seen_log_count = current_log_count
		return
	if current_log_count < _last_seen_log_count:
		_last_seen_log_count = current_log_count
		return
	var player_faction_name: String = config.get_faction_display_name(String(_snapshot.get("faction_id", "")))
	for i in range(_last_seen_log_count, current_log_count):
		var message := String(log_entries[i])
		if not _is_ai_action_log(message, player_faction_name):
			continue
		_queued_ai_action_cues.append({
			"message": message,
			"faction_id": _extract_faction_id_from_ai_action_log(message),
		})
	_last_seen_log_count = current_log_count
	_play_next_action_cue()


func _is_ai_action_log(message: String, player_faction_name: String) -> bool:
	if message == "" or not message.ends_with("）。"):
		return false
	if message.find("执行") == -1 or message.find("（消耗：") == -1 or message.find("；获得：") == -1:
		return false
	if player_faction_name != "" and message.begins_with(player_faction_name):
		return false
	return true


func _extract_faction_id_from_ai_action_log(message: String) -> String:
	var action_index := message.find("执行")
	if action_index <= 0:
		return ""
	var faction_name := message.substr(0, action_index)
	for faction in _get_management_resource_factions():
		var faction_id := String(faction.get("id", ""))
		var display_name := String(faction.get("display_name", faction_id))
		if faction_name == display_name:
			return faction_id
	return ""


func _play_next_action_cue() -> void:
	if _is_playing_action_cue or _queued_ai_action_cues.is_empty():
		return
	var cue: Dictionary = _queued_ai_action_cues.pop_front()
	var message := String(cue.get("message", ""))
	if message == "":
		_play_next_action_cue()
		return
	_is_playing_action_cue = true
	_active_action_cue_faction_id = String(cue.get("faction_id", ""))
	_refresh_resource_faction_selector_state()
	_show_action_cue(message)


func _show_action_cue(message: String) -> void:
	if _action_cue_tween != null:
		_action_cue_tween.kill()
		_action_cue_tween = null
	_action_cue_label.text = message
	_action_cue.show()
	_action_cue.modulate = Color(1, 1, 1, 1)
	_action_cue_tween = create_tween()
	_action_cue_tween.tween_interval(1.1)
	_action_cue_tween.tween_property(_action_cue, "modulate:a", 0.0, 0.25)
	_action_cue_tween.finished.connect(_finish_action_cue)


func _finish_action_cue() -> void:
	_action_cue.hide()
	_action_cue.modulate = Color(1, 1, 1, 0)
	_action_cue_tween = null
	_is_playing_action_cue = false
	_active_action_cue_faction_id = ""
	_refresh_resource_faction_selector_state()
	_play_next_action_cue()


func _hide_action_cue_immediately() -> void:
	if _action_cue_tween != null:
		_action_cue_tween.kill()
		_action_cue_tween = null
	_action_cue.hide()
	_action_cue.modulate = Color(1, 1, 1, 0)
	_action_cue_label.text = ""
	_queued_ai_action_cues.clear()
	_is_playing_action_cue = false
	_active_action_cue_faction_id = ""
	_refresh_resource_faction_selector_state()


func _get_faction_marker_modulate(is_selected: bool, is_current_actor: bool, is_player_faction: bool, is_active_cue: bool) -> Color:
	if is_active_cue:
		return Color(0.96, 0.72, 0.22, 1.0)
	if is_current_actor:
		return Color(0.78, 0.54, 0.2, 1.0)
	if is_selected:
		return Color(0.41, 0.34, 0.18, 1.0)
	if is_player_faction:
		return Color(0.2, 0.33, 0.44, 1.0)
	return Color(0.16, 0.2, 0.24, 1.0)


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


func _add_section_header(parent: GridContainer, title: String) -> void:
	var title_label := Label.new()
	title_label.text = title
	title_label.modulate = Color(0.86, 0.82, 0.58, 1.0)
	parent.add_child(title_label)

	var spacer := Label.new()
	spacer.text = ""
	parent.add_child(spacer)


func _get_available_action_points() -> int:
	var faction_resources: Dictionary = _snapshot.get("faction_resources", {})
	if faction_resources.has("action_points"):
		return int(faction_resources.get("action_points", 0))
	var resources: Dictionary = _snapshot.get("resources", {})
	return int(resources.get("action_points", 0))


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _format_value(value) -> String:
	if value is float:
		return "%.2f" % value
	return str(value)


func _sync_selected_view_faction() -> void:
	var available_ids: Array[String] = []
	for faction in _get_management_resource_factions():
		available_ids.append(String(faction.get("id", "")))
	var player_faction_id := String(_snapshot.get("faction_id", ""))
	if _selected_view_faction_id == "" and player_faction_id != "":
		_selected_view_faction_id = player_faction_id
	if not available_ids.has(_selected_view_faction_id):
		_selected_view_faction_id = player_faction_id if available_ids.has(player_faction_id) else (available_ids[0] if not available_ids.is_empty() else "")
	if _hovered_faction_id != "" and not available_ids.has(_hovered_faction_id):
		_hide_hover_panel()


func _get_management_resource_factions() -> Array:
	if game_session != null and game_session.has_method("get_management_resource_factions"):
		return game_session.get_management_resource_factions()
	return []


func _get_selected_management_resource_snapshot() -> Dictionary:
	return _get_management_resource_snapshot(_selected_view_faction_id)


func _get_management_resource_snapshot(faction_id: String) -> Dictionary:
	if game_session != null and game_session.has_method("get_management_resource_snapshot"):
		return game_session.get_management_resource_snapshot(faction_id)
	return {
		"resources": _snapshot.get("resources", {}).duplicate(true),
		"city_resources": _snapshot.get("city_resources", {}).duplicate(true),
		"faction_resources": _snapshot.get("faction_resources", {}).duplicate(true),
		"special_resources": _snapshot.get("special_resources", {}).duplicate(true),
		"derived_metrics": _snapshot.get("derived_metrics", {}).duplicate(true),
		"relations": _snapshot.get("relations", {}).duplicate(true),
	}


func _show_hover_panel(faction_id: String, marker: Control) -> void:
	_hovered_faction_id = faction_id
	_hover_visibility_request_id += 1
	_clear_children(_resource_hover_list)
	_clear_children(_resource_hover_relation_list)
	var resource_snapshot := _get_management_resource_snapshot(faction_id)
	_resource_hover_title.text = "%s资源概览" % config.get_faction_display_name(String(resource_snapshot.get("faction_id", faction_id)))
	_render_resource_snapshot(_resource_hover_list, _resource_hover_relation_list, resource_snapshot, false, true)
	_resource_hover_panel.show()
	_resource_hover_scroll.scroll_vertical = 0
	_resource_hover_panel.reset_size()
	await get_tree().process_frame
	var viewport_rect := get_viewport_rect()
	var max_panel_width := maxf(240.0, viewport_rect.size.x - 24.0)
	var max_panel_height := maxf(220.0, viewport_rect.size.y - 24.0)
	_resource_hover_panel.custom_minimum_size = Vector2(minf(320.0, max_panel_width), 0)
	_resource_hover_panel.size = Vector2(minf(_resource_hover_panel.size.x, max_panel_width), minf(_resource_hover_panel.size.y, max_panel_height))
	await get_tree().process_frame
	var panel_size := _resource_hover_panel.size
	var marker_position := marker.get_global_position()
	var below_position := marker_position + Vector2(0, marker.size.y + 6)
	var above_position := marker_position + Vector2(0, -panel_size.y - 6)
	var position := below_position
	if below_position.y + panel_size.y > viewport_rect.size.y - 12.0 and above_position.y >= 12.0:
		position = above_position
	position.x = clampf(position.x, 12.0, viewport_rect.size.x - panel_size.x - 12.0)
	position.y = clampf(position.y, 12.0, viewport_rect.size.y - panel_size.y - 12.0)
	_resource_hover_panel.global_position = position


func _hide_hover_panel() -> void:
	_hovered_faction_id = ""
	_is_hovering_faction_marker = false
	_is_hovering_hover_panel = false
	_hover_visibility_request_id += 1
	_resource_hover_panel.hide()


func _update_hover_panel_visibility(request_id: int) -> void:
	if request_id != _hover_visibility_request_id:
		return
	if _is_hovering_faction_marker or _is_hovering_hover_panel:
		return
	_hide_hover_panel()


func _on_faction_marker_mouse_entered(faction_id: String, marker: Control) -> void:
	_is_hovering_faction_marker = true
	_show_hover_panel(faction_id, marker)


func _on_faction_marker_mouse_exited(faction_id: String) -> void:
	if _hovered_faction_id == faction_id:
		_is_hovering_faction_marker = false
		var request_id := _hover_visibility_request_id
		get_tree().create_timer(0.12).timeout.connect(func() -> void:
			_update_hover_panel_visibility(request_id)
		)


func _on_faction_marker_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_resource_hover_scroll.scroll_vertical = maxi(_resource_hover_scroll.scroll_vertical - 48, 0)
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var max_scroll := maxi(_resource_hover_scroll.get_v_scroll_bar().max_value - _resource_hover_scroll.get_v_scroll_bar().page, 0)
		_resource_hover_scroll.scroll_vertical = mini(_resource_hover_scroll.scroll_vertical + 48, int(max_scroll))
		accept_event()


func _on_hover_panel_mouse_entered() -> void:
	_is_hovering_hover_panel = true


func _on_hover_panel_mouse_exited() -> void:
	_is_hovering_hover_panel = false
	var request_id := _hover_visibility_request_id
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		_update_hover_panel_visibility(request_id)
	)
