extends Control

signal action_requested(action_id: String, payload: Dictionary)
signal battle_requested

var game_session: Node = null
var config = null
var _snapshot: Dictionary = {}
var _selected_action_group_id: String = ""
var _selected_action_id: String = ""
var _selected_target_faction_id: String = ""
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
var _hovered_action_id: String = ""
var _is_hovering_action_button := false
var _is_hovering_action_panel := false
var _action_hover_request_id: int = 0
var _forecast_breakdown_expanded := false

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
@onready var _action_hover_panel: PanelContainer = $ActionHoverPanel
@onready var _action_hover_title: Label = $ActionHoverPanel/MarginContainer/HoverContent/ActionHoverTitle
@onready var _action_hover_summary: Label = $ActionHoverPanel/MarginContainer/HoverContent/ActionHoverSummary
@onready var _action_hover_scroll: ScrollContainer = $ActionHoverPanel/MarginContainer/HoverContent/HoverScroll
@onready var _action_hover_effect_title: Label = $ActionHoverPanel/MarginContainer/HoverContent/HoverScroll/HoverInner/ActionHoverEffectTitle
@onready var _action_hover_effect_list: VBoxContainer = $ActionHoverPanel/MarginContainer/HoverContent/HoverScroll/HoverInner/ActionHoverEffectList
@onready var _action_hover_delta_title: Label = $ActionHoverPanel/MarginContainer/HoverContent/HoverScroll/HoverInner/ActionHoverDeltaTitle
@onready var _action_hover_delta_list: GridContainer = $ActionHoverPanel/MarginContainer/HoverContent/HoverScroll/HoverInner/ActionHoverDeltaList
@onready var _action_list: VBoxContainer = $MainPanel/MarginContainer/VBox/Content/Center/ActionScroll/ActionList
@onready var _recruit_list: VBoxContainer = $MainPanel/MarginContainer/VBox/Content/Center/RecruitScroll/RecruitList
@onready var _target_title: Label = $MainPanel/MarginContainer/VBox/Content/Center/TargetTitle
@onready var _target_scroll: ScrollContainer = $MainPanel/MarginContainer/VBox/Content/Center/TargetScroll
@onready var _target_list: VBoxContainer = $MainPanel/MarginContainer/VBox/Content/Center/TargetScroll/TargetList
@onready var _detail_summary_label: Label = $MainPanel/MarginContainer/VBox/Content/Center/ActionDetailPanel/ActionDetailMargin/ActionDetailScroll/ActionDetailContent/ActionDetailSummary
@onready var _detail_cost_title: Label = $MainPanel/MarginContainer/VBox/Content/Center/ActionDetailPanel/ActionDetailMargin/ActionDetailScroll/ActionDetailContent/DetailCostTitle
@onready var _detail_cost_list: GridContainer = $MainPanel/MarginContainer/VBox/Content/Center/ActionDetailPanel/ActionDetailMargin/ActionDetailScroll/ActionDetailContent/DetailCostList
@onready var _detail_effect_title: Label = $MainPanel/MarginContainer/VBox/Content/Center/ActionDetailPanel/ActionDetailMargin/ActionDetailScroll/ActionDetailContent/DetailEffectTitle
@onready var _detail_effect_list: VBoxContainer = $MainPanel/MarginContainer/VBox/Content/Center/ActionDetailPanel/ActionDetailMargin/ActionDetailScroll/ActionDetailContent/DetailEffectList
@onready var _detail_delta_title: Label = $MainPanel/MarginContainer/VBox/Content/Center/ActionDetailPanel/ActionDetailMargin/ActionDetailScroll/ActionDetailContent/DetailDeltaTitle
@onready var _detail_delta_list: GridContainer = $MainPanel/MarginContainer/VBox/Content/Center/ActionDetailPanel/ActionDetailMargin/ActionDetailScroll/ActionDetailContent/DetailDeltaList
@onready var _execute_action_button: Button = $MainPanel/MarginContainer/VBox/Content/Center/ExecuteActionButton
@onready var _army_list: VBoxContainer = $MainPanel/MarginContainer/VBox/Content/Right/ArmyScroll/ArmyList
@onready var _morale_label: Label = $MainPanel/MarginContainer/VBox/Content/Right/MoraleLabel
@onready var _maintenance_label: Label = $MainPanel/MarginContainer/VBox/Content/Right/MaintenanceLabel
@onready var _forecast_summary_list: VBoxContainer = $MainPanel/MarginContainer/VBox/Content/Right/ForecastPanel/ForecastMargin/ForecastScroll/ForecastContent/ForecastSummaryList
@onready var _forecast_breakdown_button: Button = $MainPanel/MarginContainer/VBox/Content/Right/ForecastPanel/ForecastMargin/ForecastScroll/ForecastContent/ForecastBreakdownButton
@onready var _forecast_breakdown_list: VBoxContainer = $MainPanel/MarginContainer/VBox/Content/Right/ForecastPanel/ForecastMargin/ForecastScroll/ForecastContent/ForecastBreakdownList
@onready var _forecast_delta_title: Label = $MainPanel/MarginContainer/VBox/Content/Right/ForecastPanel/ForecastMargin/ForecastScroll/ForecastContent/ForecastDeltaTitle
@onready var _forecast_delta_list: GridContainer = $MainPanel/MarginContainer/VBox/Content/Right/ForecastPanel/ForecastMargin/ForecastScroll/ForecastContent/ForecastDeltaList
@onready var _forecast_projected_title: Label = $MainPanel/MarginContainer/VBox/Content/Right/ForecastPanel/ForecastMargin/ForecastScroll/ForecastContent/ForecastProjectedTitle
@onready var _forecast_projected_list: GridContainer = $MainPanel/MarginContainer/VBox/Content/Right/ForecastPanel/ForecastMargin/ForecastScroll/ForecastContent/ForecastProjectedList
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
	_execute_action_button.pressed.connect(_on_execute_action_pressed)
	_forecast_breakdown_button.pressed.connect(_on_forecast_breakdown_pressed)
	_action_cue.hide()
	_action_cue.modulate = Color(1, 1, 1, 0)
	_resource_hover_panel.hide()
	_resource_hover_panel.mouse_entered.connect(_on_hover_panel_mouse_entered)
	_resource_hover_panel.mouse_exited.connect(_on_hover_panel_mouse_exited)
	_resource_hover_panel.gui_input.connect(_on_resource_hover_panel_gui_input)
	_action_hover_panel.hide()
	_action_hover_panel.mouse_entered.connect(_on_action_hover_panel_mouse_entered)
	_action_hover_panel.mouse_exited.connect(_on_action_hover_panel_mouse_exited)
	_action_hover_panel.gui_input.connect(_on_action_hover_panel_gui_input)
	if game_session != null and game_session.has_method("get_campaign_snapshot"):
		_on_campaign_state_changed(game_session.get_campaign_snapshot())


func _on_campaign_state_changed(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if config == null and game_session != null:
		config = game_session.get("config")
	_sync_selected_view_faction()
	_update_ai_action_cue()
	_render()


func _render() -> void:
	_clear_children(_resource_faction_selector)
	_clear_children(_resource_list)
	_clear_children(_relation_list)
	_clear_children(_action_list)
	_clear_children(_recruit_list)
	_clear_children(_target_list)
	_clear_children(_detail_cost_list)
	_clear_children(_detail_effect_list)
	_clear_children(_detail_delta_list)
	_clear_children(_army_list)
	_clear_children(_forecast_summary_list)
	_clear_children(_forecast_breakdown_list)
	_clear_children(_forecast_delta_list)
	_clear_children(_forecast_projected_list)
	_clear_children(_log_list)
	_clear_children(_action_hover_effect_list)
	_clear_children(_action_hover_delta_list)
	_hide_action_hover_panel()

	_start_battle_button.text = String(_snapshot.get("next_round_button_text", "进入战斗"))
	_start_battle_button.tooltip_text = ""

	if _snapshot.is_empty() or config == null:
		_top_bar.text = "玩法配置加载失败"
		_resource_title.text = "城市概览"
		_relation_title.hide()
		_target_title.hide()
		_target_scroll.hide()
		_detail_summary_label.text = "未能加载经营行动。"
		_detail_cost_title.hide()
		_detail_effect_title.hide()
		_detail_delta_title.hide()
		_forecast_breakdown_button.hide()
		_forecast_breakdown_list.hide()
		_execute_action_button.disabled = true
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
	_render_selected_action_details()
	_render_forecast_panel()
	_render_army()
	_render_log()

	var morale := int(_snapshot.get("total_morale", 0))
	var min_morale := int(_snapshot.get("min_corps_morale", 0))
	_morale_label.text = "兵团士气：%d / %d" % [morale, min_morale]
	_maintenance_label.text = "维护费：%d" % int(_snapshot.get("total_maintenance", 0))
	_start_battle_button.disabled = _are_management_interactions_locked() or not bool(_snapshot.get("can_start_battle", false))
	if _are_management_interactions_locked():
		_start_battle_button.tooltip_text = "其他阵营行动演出中。"
	elif _get_available_action_points() > 0 and bool(_snapshot.get("is_player_turn", false)):
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
	_relation_title.visible = _relation_list.get_child_count() > 0


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
		_selected_action_id = ""
		_selected_target_faction_id = ""
		return
	var interactions_locked := _are_management_interactions_locked()
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
		button.disabled = interactions_locked
		button.pressed.connect(func() -> void:
			if _selected_action_group_id == group_id:
				return
			_selected_action_group_id = group_id
			_selected_action_id = ""
			_selected_target_faction_id = ""
			_render()
		)
		_action_list.add_child(button)


func _render_action_options() -> void:
	if _selected_action_group_id == "" or game_session == null or not game_session.has_method("get_available_action_options"):
		_selected_action_id = ""
		_selected_target_faction_id = ""
		_target_title.hide()
		_target_scroll.hide()
		_execute_action_button.disabled = true
		return
	var is_player_turn := bool(_snapshot.get("is_player_turn", false))
	var interactions_locked := _are_management_interactions_locked()
	var actions: Array = game_session.get_available_action_options(_selected_action_group_id)
	var action_ids: Array[String] = []
	for action_variant in actions:
		if action_variant is Dictionary:
			action_ids.append(String((action_variant as Dictionary).get("id", "")))
	if actions.is_empty():
		_selected_action_id = ""
		_selected_target_faction_id = ""
	else:
		if _selected_action_id == "" or not action_ids.has(_selected_action_id):
			_selected_action_id = action_ids[0]
	var selected_action := _get_selected_action_definition(actions)
	_sync_selected_target_for_action(selected_action)
	for action_variant in actions:
		if not action_variant is Dictionary:
			continue
		var action := action_variant as Dictionary
		var action_id := String(action.get("id", ""))
		var button := Button.new()
		var hovered_action := action.duplicate(true)
		button.text = _build_action_button_text(action)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = action_id == _selected_action_id
		button.disabled = interactions_locked or not is_player_turn or not _can_select_action(action)
		button.tooltip_text = ""
		button.mouse_entered.connect(func() -> void:
			_on_action_button_mouse_entered(hovered_action, button)
		)
		button.mouse_exited.connect(func() -> void:
			_on_action_button_mouse_exited(action_id)
		)
		button.gui_input.connect(func(event: InputEvent) -> void:
			_on_action_button_gui_input(event, hovered_action, button)
		)
		button.pressed.connect(func() -> void:
			_selected_action_id = action_id
			_selected_target_faction_id = ""
			_render()
		)
		_recruit_list.add_child(button)
	if String(selected_action.get("id", "")) == "recruit_corps":
		_render_pending_recruit_options(_snapshot.get("pending_recruit_options", []), interactions_locked or not is_player_turn)
	_render_target_options(selected_action)
	_update_execute_action_button(selected_action)

func _render_pending_recruit_options(options: Array, disabled: bool) -> void:
	for option_variant in options:
		if not option_variant is Dictionary:
			continue
		var option: Dictionary = option_variant
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = disabled
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var member_parts: Array[String] = []
		for member_variant in option.get("members", []):
			if not member_variant is Dictionary:
				continue
			var member: Dictionary = member_variant
			var unit_id := String(member.get("unit_id", ""))
			var unit_config: Dictionary = config.get_unit(unit_id)
			member_parts.append("%s x%d" % [String(unit_config.get("display_name", unit_id)), int(member.get("count", 0))])
		button.text = "%s\n%s\n士气 %d  维护 %d" % [
			String(option.get("display_name", option.get("corps_id", "兵团"))),
			" / ".join(member_parts),
			int(option.get("morale", 0)),
			int(option.get("maintenance", 0)),
		]
		button.pressed.connect(func() -> void:
			action_requested.emit("recruit_corps", {"selected_corps_id": String(option.get("corps_id", ""))})
		)
		_recruit_list.add_child(button)


func _render_target_options(action: Dictionary) -> void:
	var requires_target := bool(action.get("requires_target", false))
	_target_title.visible = requires_target
	_target_scroll.visible = requires_target
	if not requires_target:
		return
	var options := _get_selected_action_target_options()
	if options.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前没有可选目标。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_target_list.add_child(empty_label)
		return
	var is_player_turn := bool(_snapshot.get("is_player_turn", false))
	var interactions_locked := _are_management_interactions_locked()
	for option_variant in options:
		if not option_variant is Dictionary:
			continue
		var option := option_variant as Dictionary
		var target_id := String(option.get("id", ""))
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = target_id == _selected_target_faction_id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = interactions_locked or not is_player_turn
		button.text = _build_target_button_text(option)
		button.pressed.connect(func() -> void:
			_selected_target_faction_id = target_id
			_render()
		)
		_target_list.add_child(button)


func _render_selected_action_details() -> void:
	_detail_summary_label.text = ""
	_detail_cost_title.hide()
	_detail_effect_title.hide()
	_detail_delta_title.hide()


func _on_action_button_mouse_entered(action: Dictionary, button: Control) -> void:
	_is_hovering_action_button = true
	_show_action_hover_panel(action, button)


func _on_action_button_mouse_exited(action_id: String) -> void:
	if _hovered_action_id != action_id:
		return
	_is_hovering_action_button = false
	var request_id := _action_hover_request_id
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		_update_action_hover_visibility(request_id)
	)


func _on_action_button_gui_input(event: InputEvent, action: Dictionary, button: Control) -> void:
	if _handle_action_hover_scroll(event):
		if not _action_hover_panel.visible:
			_show_action_hover_panel(action, button)


func _show_action_hover_panel(action: Dictionary, button: Control) -> void:
	var action_id := String(action.get("id", ""))
	_hovered_action_id = action_id
	_action_hover_request_id += 1
	var request_id := _action_hover_request_id
	_clear_children(_action_hover_effect_list)
	_clear_children(_action_hover_delta_list)
	_action_hover_title.text = String(action.get("display_name", action_id))
	_action_hover_summary.hide()
	_action_hover_effect_title.hide()
	_action_hover_delta_title.hide()
	var payload := _build_action_hover_payload(action)
	var projection := _get_projection_for_action(action_id, payload)
	var resolved_action: Dictionary = projection.get("resolved_action", {})
	if resolved_action.is_empty():
		if bool(action.get("requires_target", false)):
			_action_hover_summary.text = "选择目标后可查看该行动的具体变化。"
		else:
			_action_hover_summary.text = "当前无法解析该行动。"
		_action_hover_summary.show()
	else:
		if payload.has("target_faction_id"):
			_action_hover_summary.text = "当前目标：%s" % config.get_faction_display_name(String(payload.get("target_faction_id", "")))
			_action_hover_summary.show()
		_render_action_hover_effects(resolved_action)
		_render_action_hover_delta(projection.get("action_delta", {}))
		if _action_hover_effect_list.get_child_count() == 0 and _action_hover_delta_list.get_child_count() == 0 and not _action_hover_summary.visible:
			_action_hover_summary.text = "当前没有额外变化。"
			_action_hover_summary.show()
	await _present_hover_panel("action", _action_hover_panel, _action_hover_scroll, button, "horizontal", 360.0, 260.0, request_id)


func _render_action_hover_effects(resolved_action: Dictionary) -> void:
	for effect_variant in resolved_action.get("effects", []):
		if not effect_variant is Dictionary:
			continue
		var effect := effect_variant as Dictionary
		var op := String(effect.get("op", ""))
		if op != "add_unit" and op != "add_army_unit":
			continue
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = _describe_resolved_effect(effect)
		_action_hover_effect_list.add_child(label)
	_action_hover_effect_title.visible = _action_hover_effect_list.get_child_count() > 0


func _render_action_hover_delta(action_delta: Dictionary) -> void:
	_action_hover_delta_title.visible = not action_delta.is_empty()
	if action_delta.is_empty():
		return
	_render_delta_sections(_action_hover_delta_list, action_delta)


func _build_action_hover_payload(action: Dictionary) -> Dictionary:
	var action_id := String(action.get("id", ""))
	if bool(action.get("requires_target", false)) and action_id == _selected_action_id and _selected_target_faction_id != "":
		return {"target_faction_id": _selected_target_faction_id}
	return {}


func _hide_action_hover_panel() -> void:
	_hovered_action_id = ""
	_is_hovering_action_button = false
	_is_hovering_action_panel = false
	_action_hover_request_id += 1
	_action_hover_summary.hide()
	_action_hover_effect_title.hide()
	_action_hover_delta_title.hide()
	_action_hover_panel.hide()


func _update_action_hover_visibility(request_id: int) -> void:
	if request_id != _action_hover_request_id:
		return
	if _is_hovering_action_button or _is_hovering_action_panel:
		return
	_hide_action_hover_panel()


func _on_action_hover_panel_mouse_entered() -> void:
	_is_hovering_action_panel = true


func _on_action_hover_panel_mouse_exited() -> void:
	_is_hovering_action_panel = false
	var request_id := _action_hover_request_id
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		_update_action_hover_visibility(request_id)
	)


func _on_action_hover_panel_gui_input(event: InputEvent) -> void:
	_handle_action_hover_scroll(event)


func _handle_action_hover_scroll(event: InputEvent) -> bool:
	return _scroll_hover_panel(_action_hover_panel, _action_hover_scroll, event)


func _scroll_hover_panel(panel: PanelContainer, scroll: ScrollContainer, event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or not panel.visible:
		return false
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll.scroll_vertical = maxi(scroll.scroll_vertical - 48, 0)
		accept_event()
		return true
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var max_scroll := maxi(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page, 0)
		scroll.scroll_vertical = mini(scroll.scroll_vertical + 48, int(max_scroll))
		accept_event()
		return true
	return false


func _is_hover_request_current(kind: String, request_id: int) -> bool:
	if kind == "action":
		return request_id == _action_hover_request_id
	if kind == "resource":
		return request_id == _hover_visibility_request_id
	return false


func _present_hover_panel(kind: String, panel: PanelContainer, scroll: ScrollContainer, anchor: Control, placement: String, preferred_width: float, minimum_width: float, request_id: int) -> void:
	panel.show()
	scroll.scroll_vertical = 0
	panel.reset_size()
	await get_tree().process_frame
	if not _is_hover_request_current(kind, request_id):
		return
	var viewport_rect := get_viewport_rect()
	var max_panel_width := maxf(minimum_width, viewport_rect.size.x - 24.0)
	var max_panel_height := maxf(220.0, viewport_rect.size.y - 24.0)
	panel.custom_minimum_size = Vector2(minf(preferred_width, max_panel_width), 0)
	panel.size = Vector2(minf(panel.size.x, max_panel_width), minf(panel.size.y, max_panel_height))
	await get_tree().process_frame
	if not _is_hover_request_current(kind, request_id):
		return
	var panel_size := panel.size
	var anchor_position := anchor.get_global_position()
	var position := anchor_position
	if placement == "horizontal":
		var right_position := anchor_position + Vector2(anchor.size.x + 8.0, 0)
		var left_position := anchor_position + Vector2(-panel_size.x - 8.0, 0)
		position = right_position
		if right_position.x + panel_size.x > viewport_rect.size.x - 12.0 and left_position.x >= 12.0:
			position = left_position
		position.y = clampf(anchor_position.y, 12.0, viewport_rect.size.y - panel_size.y - 12.0)
	else:
		var below_position := anchor_position + Vector2(0, anchor.size.y + 6.0)
		var above_position := anchor_position + Vector2(0, -panel_size.y - 6.0)
		position = below_position
		if below_position.y + panel_size.y > viewport_rect.size.y - 12.0 and above_position.y >= 12.0:
			position = above_position
		position.y = clampf(position.y, 12.0, viewport_rect.size.y - panel_size.y - 12.0)
	position.x = clampf(position.x, 12.0, viewport_rect.size.x - panel_size.x - 12.0)
	panel.global_position = position


func _render_action_costs(resolved_action: Dictionary) -> void:
	var cost: Dictionary = resolved_action.get("cost", {})
	_detail_cost_title.visible = not cost.is_empty()
	if cost.is_empty():
		return
	for resource_id in cost.keys():
		var resource_config: Dictionary = config.get_resource(String(resource_id))
		_add_pair(_detail_cost_list, resource_config.get("display_name", resource_id), "-%s" % _format_value(cost[resource_id]))


func _render_action_effects(resolved_action: Dictionary) -> void:
	var effects: Array = resolved_action.get("effects", [])
	_detail_effect_title.visible = not effects.is_empty()
	if effects.is_empty():
		return
	for effect_variant in effects:
		if not effect_variant is Dictionary:
			continue
		var effect := effect_variant as Dictionary
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = _describe_resolved_effect(effect)
		_detail_effect_list.add_child(label)


func _render_action_delta(action_delta: Dictionary) -> void:
	_detail_delta_title.visible = not action_delta.is_empty()
	if action_delta.is_empty():
		return
	_render_delta_sections(_detail_delta_list, action_delta)


func _render_forecast_panel() -> void:
	_clear_children(_forecast_summary_list)
	_clear_children(_forecast_breakdown_list)
	_clear_children(_forecast_delta_list)
	_clear_children(_forecast_projected_list)
	var projection := _get_selected_action_projection()
	var settlement_delta: Dictionary = projection.get("settlement_delta", {})
	var settlement_summary: Array[String] = _build_forecast_summary_lines(settlement_delta)
	var settlement_breakdown: Array[String] = _get_forecast_breakdown_lines(projection.get("settlement_breakdown", []))
	if settlement_summary.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前没有可显示的结算预测。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_forecast_summary_list.add_child(empty_label)
	else:
		for summary_variant in settlement_summary:
			var summary_label := Label.new()
			summary_label.text = String(summary_variant)
			summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_forecast_summary_list.add_child(summary_label)
	_render_forecast_breakdown(settlement_breakdown)
	_forecast_delta_title.visible = not settlement_delta.is_empty()
	if not settlement_delta.is_empty():
		_render_delta_sections(_forecast_delta_list, settlement_delta)
	var projected: Dictionary = projection.get("projected", {})
	_forecast_projected_title.visible = not projected.is_empty()
	if not projected.is_empty():
		_render_projected_snapshot(_forecast_projected_list, projected)


func _render_delta_sections(parent: GridContainer, delta_sections: Dictionary) -> void:
	var section_names := {
		"city_resources": "城市资源",
		"faction_resources": "阵营资源",
		"special_resources": "特殊资源",
		"derived_metrics": "衍生指标",
		"relations": "关系",
		"resources": "资源",
	}
	for section_id in ["city_resources", "faction_resources", "special_resources", "derived_metrics", "relations"]:
		var values: Dictionary = delta_sections.get(section_id, {})
		if values.is_empty():
			continue
		_add_section_header(parent, String(section_names.get(section_id, section_id)))
		for key in values.keys():
			_add_pair(parent, _get_delta_entry_name(section_id, String(key)), _format_signed_value(values[key]))
	var merged_values: Dictionary = delta_sections.get("resources", {})
	if merged_values.is_empty():
		return
	var merged_keys: Array[String] = []
	for key_variant in merged_values.keys():
		var key := String(key_variant)
		if _is_duplicate_merged_delta_key(delta_sections, key):
			continue
		merged_keys.append(key)
	if merged_keys.is_empty():
		return
	_add_section_header(parent, String(section_names.get("resources", "resources")))
	for key in merged_keys:
		_add_pair(parent, _get_delta_entry_name("resources", key), _format_signed_value(merged_values.get(key, 0)))


func _build_forecast_summary_lines(settlement_delta: Dictionary) -> Array[String]:
	var summary: Array[String] = []
	for section_id in ["city_resources", "faction_resources", "special_resources", "derived_metrics", "relations"]:
		var values: Dictionary = settlement_delta.get(section_id, {})
		for key_variant in values.keys():
			var key := String(key_variant)
			summary.append("%s%s" % [_get_delta_entry_name(section_id, key), _format_signed_value(values.get(key, 0))])
	var merged_values: Dictionary = settlement_delta.get("resources", {})
	for key_variant in merged_values.keys():
		var key := String(key_variant)
		if _is_duplicate_merged_delta_key(settlement_delta, key):
			continue
		summary.append("%s%s" % [_get_delta_entry_name("resources", key), _format_signed_value(merged_values.get(key, 0))])
	return summary


func _get_forecast_breakdown_lines(raw_breakdown: Array) -> Array[String]:
	var lines: Array[String] = []
	for entry_variant in raw_breakdown:
		var entry := String(entry_variant).strip_edges()
		if entry != "":
			lines.append(entry)
	return lines


func _render_forecast_breakdown(settlement_breakdown: Array[String]) -> void:
	if settlement_breakdown.is_empty():
		_forecast_breakdown_expanded = false
		_forecast_breakdown_button.hide()
		_forecast_breakdown_list.hide()
		return
	_forecast_breakdown_button.text = "收起明细" if _forecast_breakdown_expanded else "展开明细"
	_forecast_breakdown_button.show()
	_forecast_breakdown_list.visible = _forecast_breakdown_expanded
	if not _forecast_breakdown_expanded:
		return
	for entry in settlement_breakdown:
		var breakdown_label := Label.new()
		breakdown_label.text = entry
		breakdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_forecast_breakdown_list.add_child(breakdown_label)


func _is_duplicate_merged_delta_key(delta_sections: Dictionary, key: String) -> bool:
	for section_id in ["city_resources", "faction_resources", "special_resources", "derived_metrics"]:
		var section_values: Dictionary = delta_sections.get(section_id, {})
		if section_values.has(key):
			return true
	return false


func _render_projected_snapshot(parent: GridContainer, projected: Dictionary) -> void:
	_render_resource_group(parent, "城市资源", projected.get("city_resources", {}), config.get_city_resource_order())
	_render_resource_group(parent, "阵营资源", projected.get("faction_resources", {}), config.get_faction_resource_order())
	_render_resource_group(parent, "特殊资源", projected.get("special_resources", {}), config.get_special_resource_order())
	_render_resource_group(parent, "衍生指标", projected.get("derived_metrics", {}), config.get_derived_resource_order())
	var relations: Dictionary = projected.get("relations", {})
	if not relations.is_empty():
		_add_section_header(parent, "关系")
		for faction_id in relations.keys():
			_add_pair(parent, config.get_faction_display_name(String(faction_id)), _format_value(relations[faction_id]))


func _render_army() -> void:
	for entry_variant in _snapshot.get("army", []):
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		var corps_id := String(entry.get("corps_id", ""))
		var corps_config: Dictionary = config.get_corps(corps_id) if config != null and config.has_method("get_corps") else {}
		var corps_name := String(corps_config.get("display_name", entry.get("display_name", corps_id if corps_id != "" else "兵团")))
		var members: Array = entry.get("members", [])
		var member_parts: Array[String] = []
		var total_morale := 0
		var total_upkeep := 0
		for member_variant in members:
			if not member_variant is Dictionary:
				continue
			var member: Dictionary = member_variant
			var unit_id := String(member.get("unit_id", ""))
			var count := int(member.get("count", 0))
			var unit_config: Dictionary = config.get_unit(unit_id)
			var campaign: Dictionary = unit_config.get("campaign", {})
			member_parts.append("%s x%d" % [String(unit_config.get("display_name", unit_id)), count])
			total_morale += int(campaign.get("morale", 0)) * count
			total_upkeep += int(campaign.get("upkeep", 0)) * count
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s\n%s\n士气:%d  维护:%d" % [
			corps_name,
			" / ".join(member_parts),
			total_morale,
			total_upkeep,
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
	_render()
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
	_render()
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
	if not _snapshot.is_empty() and config != null:
		_render()


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
	parts.append("AP%d" % int(action.get("ap_cost", 0)))
	var cost_parts: Array[String] = []
	var cost: Dictionary = action.get("cost", {})
	for resource_id in cost.keys():
		var resource_config: Dictionary = config.get_resource(String(resource_id))
		cost_parts.append("%s%s" % [resource_config.get("display_name", resource_id), _format_value(cost[resource_id])])
	if not cost_parts.is_empty():
		parts.append(" / ".join(cost_parts))
	if bool(action.get("requires_target", false)):
		parts.append("需目标")
	return "  ".join(parts)


func _describe_resolved_effect(effect: Dictionary) -> String:
	var recipient_id := String(effect.get("resolved_recipient_faction_id", ""))
	var recipient_name := "本方"
	if recipient_id != "" and recipient_id != String(_snapshot.get("faction_id", "")):
		recipient_name = config.get_faction_display_name(recipient_id)
	var target_name := _get_resolved_effect_target_name(effect)
	var resolved_value = effect.get("resolved_value", effect.get("value", 0))
	match String(effect.get("op", "")):
		"add":
			return "%s：%s %s" % [recipient_name, target_name, _format_signed_value(resolved_value)]
		"set":
			return "%s：%s -> %s" % [recipient_name, target_name, _format_value(resolved_value)]
		"add_unit", "add_army_unit":
			var unit_id := String(effect.get("unit_id", ""))
			var unit_config: Dictionary = config.get_unit(unit_id)
			return "%s：%s +%d" % [recipient_name, unit_config.get("display_name", unit_id), int(effect.get("count", 1))]
		"add_corps":
			var corps_id := String(effect.get("corps_id", ""))
			var corps_config: Dictionary = config.get_corps(corps_id) if config != null and config.has_method("get_corps") else {}
			var corps_name := String(corps_config.get("display_name", corps_id))
			return "%s：%s +1" % [recipient_name, corps_name]
	return "%s：%s" % [recipient_name, target_name]


func _get_resolved_effect_target_name(effect: Dictionary) -> String:
	if String(effect.get("scope", "resources")) == "relations":
		var relation_target := String(effect.get("resolved_target", effect.get("target", "")))
		if relation_target == "":
			return "目标阵营关系"
		return "%s关系" % config.get_faction_display_name(relation_target)
	var resource_id := String(effect.get("resolved_target", effect.get("target", "")))
	if resource_id == "":
		return "效果"
	var resource_config: Dictionary = config.get_resource(resource_id)
	return String(resource_config.get("display_name", resource_id))


func _can_select_action(action: Dictionary) -> bool:
	if not bool(_snapshot.get("is_player_turn", false)):
		return false
	var action_id := String(action.get("id", ""))
	var payload := _build_action_payload(false)
	if action_id == "recruit_corps" and not payload.has("selected_corps_id"):
		return _can_apply_action(action_id, payload)
	var projection := _get_projection_for_action(action_id, payload)
	var resolved_action: Dictionary = projection.get("resolved_action", {})
	if resolved_action.is_empty():
		return false
	if _get_available_action_points() < int(resolved_action.get("ap_cost", action.get("ap_cost", 0))):
		return false
	for resource_id in resolved_action.get("cost", {}).keys():
		if _get_snapshot_resource_amount(projection.get("current", {}), String(resource_id)) < int(resolved_action.get("cost", {}).get(resource_id, 0)):
			return false
	return true


func _on_execute_action_pressed() -> void:
	if _selected_action_id == "":
		return
	var payload := _build_action_payload(true)
	action_requested.emit(_selected_action_id, payload)


func _on_forecast_breakdown_pressed() -> void:
	_forecast_breakdown_expanded = not _forecast_breakdown_expanded
	_render_forecast_panel()


func _update_execute_action_button(action: Dictionary) -> void:
	if action.is_empty():
		_execute_action_button.text = "执行行动"
		_execute_action_button.tooltip_text = ""
		_execute_action_button.disabled = true
		return
	_execute_action_button.text = "执行：%s" % String(action.get("display_name", action.get("id", "行动")))
	if _are_management_interactions_locked():
		_execute_action_button.disabled = true
		_execute_action_button.tooltip_text = "其他阵营行动演出中。"
		return
	var requires_target := bool(action.get("requires_target", false))
	if requires_target and _selected_target_faction_id == "":
		_execute_action_button.disabled = true
		_execute_action_button.tooltip_text = "请先选择目标阵营。"
		return
	var payload := _build_action_payload(true)
	_execute_action_button.disabled = not _can_apply_action(_selected_action_id, payload)
	_execute_action_button.tooltip_text = "" if not _execute_action_button.disabled else "当前条件不足，无法执行该行动。"


func _build_action_payload(include_target: bool) -> Dictionary:
	var payload := {}
	if include_target and _selected_target_faction_id != "":
		payload["target_faction_id"] = _selected_target_faction_id
	return payload


func _get_selected_action_definition(actions: Array = []) -> Dictionary:
	var source_actions := actions
	if source_actions.is_empty() and game_session != null and _selected_action_group_id != "" and game_session.has_method("get_available_action_options"):
		source_actions = game_session.get_available_action_options(_selected_action_group_id)
	for action_variant in source_actions:
		if not action_variant is Dictionary:
			continue
		var action := action_variant as Dictionary
		if String(action.get("id", "")) == _selected_action_id:
			return action
	return {}


func _sync_selected_target_for_action(action: Dictionary) -> void:
	if action.is_empty() or not bool(action.get("requires_target", false)):
		_selected_target_faction_id = ""
		return
	var option_ids: Array[String] = []
	for option_variant in _get_selected_action_target_options():
		if option_variant is Dictionary:
			option_ids.append(String((option_variant as Dictionary).get("id", "")))
	if not option_ids.has(_selected_target_faction_id):
		_selected_target_faction_id = ""


func _get_selected_action_target_options() -> Array:
	if _selected_action_id == "" or game_session == null or not game_session.has_method("get_action_target_options"):
		return []
	return game_session.get_action_target_options(_selected_action_id, String(_snapshot.get("faction_id", "")))


func _get_selected_action_projection() -> Dictionary:
	return _get_projection_for_action(_selected_action_id, _build_action_payload(true))


func _get_projection_for_action(action_id: String, payload: Dictionary) -> Dictionary:
	if game_session == null or not game_session.has_method("get_management_projection"):
		return {}
	return game_session.get_management_projection(String(_snapshot.get("faction_id", "")), action_id, payload)


func _build_target_button_text(option: Dictionary) -> String:
	return "%s  关系%s" % [
		String(option.get("display_name", option.get("id", "目标"))),
		_format_signed_value(option.get("relation", 0)),
	]


func _get_delta_entry_name(section_id: String, key: String) -> String:
	if section_id == "relations":
		return config.get_faction_display_name(key)
	var resource_config: Dictionary = config.get_resource(key)
	return String(resource_config.get("display_name", key))


func _get_snapshot_resource_amount(resource_snapshot: Dictionary, resource_id: String) -> int:
	for section_id in ["resources", "city_resources", "faction_resources", "special_resources", "derived_metrics"]:
		var values: Dictionary = resource_snapshot.get(section_id, {})
		if values.has(resource_id):
			return int(values.get(resource_id, 0))
	return 0


func _can_apply_action(action_id: String, payload: Dictionary = {}) -> bool:
	if game_session != null and game_session.has_method("can_apply_action"):
		return game_session.can_apply_action(action_id, payload)
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


func _are_management_interactions_locked() -> bool:
	return _is_playing_action_cue or not _queued_ai_action_cues.is_empty()


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _format_value(value) -> String:
	if value is float:
		return "%.2f" % value
	return str(value)


func _format_signed_value(value) -> String:
	if value is float:
		var float_value := snappedf(float(value), 0.01)
		if absf(float_value) < 0.005:
			float_value = 0.0
		return "%+.2f" % float_value
	return "%+d" % int(value)


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
	var request_id := _hover_visibility_request_id
	_clear_children(_resource_hover_list)
	_clear_children(_resource_hover_relation_list)
	var resource_snapshot := _get_management_resource_snapshot(faction_id)
	_resource_hover_title.text = "%s资源概览" % config.get_faction_display_name(String(resource_snapshot.get("faction_id", faction_id)))
	_render_resource_snapshot(_resource_hover_list, _resource_hover_relation_list, resource_snapshot, false, true)
	await _present_hover_panel("resource", _resource_hover_panel, _resource_hover_scroll, marker, "vertical", 320.0, 240.0, request_id)


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
	if _are_management_interactions_locked():
		accept_event()
		return
	_scroll_hover_panel(_resource_hover_panel, _resource_hover_scroll, event)


func _on_resource_hover_panel_gui_input(event: InputEvent) -> void:
	_scroll_hover_panel(_resource_hover_panel, _resource_hover_scroll, event)


func _on_hover_panel_mouse_entered() -> void:
	_is_hovering_hover_panel = true


func _on_hover_panel_mouse_exited() -> void:
	_is_hovering_hover_panel = false
	var request_id := _hover_visibility_request_id
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		_update_hover_panel_visibility(request_id)
	)
