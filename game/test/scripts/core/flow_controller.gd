extends Node

signal battle_started(troop_type: String)

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const FACTION_SELECTION_SCENE: PackedScene = preload("res://scenes/ui/faction_selection_page.tscn")
const TROOP_SELECTION_SCENE: PackedScene = preload("res://scenes/troop_selection.tscn")
const GAMEPLAY_PAGE_SCENE: PackedScene = preload("res://scenes/ui/gameplay_page.tscn")
const FALLBACK_BATTLE_ROOT_SCENE: PackedScene = preload("res://scenes/battle_root.tscn")

@onready var _game_session: Node = get_node_or_null("../GameSession")
@onready var _ui_root: CanvasLayer = get_node_or_null("../UIRoot") as CanvasLayer
@onready var _selection_overlay: Control = get_node_or_null("../UIRoot/SelectionOverlay") as Control
@onready var _day_hud: Control = get_node_or_null("../UIRoot/DayHUD") as Control
@onready var _battle_unit_bar: Control = get_node_or_null("../UIRoot/BattleUnitBar") as Control

var _main_menu: Control = null
var _faction_selection_page: Control = null
var _troop_selection: Control = null
var _gameplay_page: Control = null
var _battle_root: Node2D = null
var _current_troop: String = "infantry"
var _current_battle_setup: Dictionary = {}


func _ready() -> void:
	add_to_group("flow_controller")
	_show_main_menu()


func _show_main_menu() -> void:
	_set_game_ui_visible(false)
	_reset_battle_ui_state()
	_free_runtime_nodes()

	_main_menu = MAIN_MENU_SCENE.instantiate()
	_get_ui_parent().add_child(_main_menu)
	_main_menu.start_requested.connect(_on_main_menu_start_requested)
	_main_menu.quit_requested.connect(_on_main_menu_quit_requested)


func _show_faction_selection_page() -> void:
	_set_game_ui_visible(false)
	_reset_battle_ui_state()
	_free_runtime_nodes()

	_faction_selection_page = FACTION_SELECTION_SCENE.instantiate()
	_get_ui_parent().add_child(_faction_selection_page)
	_faction_selection_page.faction_selected.connect(_on_faction_selected)
	if _faction_selection_page.has_method("setup"):
		_faction_selection_page.setup(_game_session)


func _show_troop_selection() -> void:
	_set_game_ui_visible(false)
	_reset_battle_ui_state()

	if _battle_root != null:
		_battle_root.queue_free()
		_battle_root = null

	_troop_selection = TROOP_SELECTION_SCENE.instantiate()
	_get_ui_parent().add_child(_troop_selection)
	_troop_selection.troop_selected.connect(_on_troop_selected)
	if _troop_selection.has_method("setup"):
		_troop_selection.setup(_game_session)


func _show_gameplay_page() -> void:
	_set_game_ui_visible(false)
	_reset_battle_ui_state()

	if _battle_root != null:
		_battle_root.queue_free()
		_battle_root = null
	if _troop_selection != null:
		_troop_selection.queue_free()
		_troop_selection = null
	if _faction_selection_page != null:
		_faction_selection_page.queue_free()
		_faction_selection_page = null
	if _gameplay_page != null:
		_gameplay_page.queue_free()
		_gameplay_page = null

	_gameplay_page = GAMEPLAY_PAGE_SCENE.instantiate()
	_get_ui_parent().add_child(_gameplay_page)
	_gameplay_page.action_requested.connect(_on_gameplay_action_requested)
	_gameplay_page.battle_requested.connect(_on_gameplay_battle_requested)
	if _gameplay_page.has_method("setup"):
		_gameplay_page.setup(_game_session)


func _on_main_menu_start_requested() -> void:
	if _main_menu != null:
		_main_menu.queue_free()
		_main_menu = null

	_show_faction_selection_page()


func _on_main_menu_quit_requested() -> void:
	get_tree().quit()


func _on_faction_selected(faction_id: String) -> void:
	if _game_session != null and _game_session.has_method("start_new_campaign"):
		_game_session.start_new_campaign(faction_id)
	_show_gameplay_page()


func _on_troop_selected(troop_type: String) -> void:
	_current_troop = troop_type
	_start_battle()


func _on_gameplay_action_requested(action_id: String, payload: Dictionary) -> void:
	if _game_session != null and _game_session.has_method("try_apply_action"):
		_game_session.try_apply_action(action_id, payload)


func _on_gameplay_battle_requested() -> void:
	if _game_session == null or not _game_session.has_method("can_start_battle"):
		return
	if not _game_session.can_start_battle():
		return
	if _game_session.has_method("begin_battle_round"):
		_current_battle_setup = _game_session.begin_battle_round()
	elif _game_session.has_method("build_battle_setup"):
		_current_battle_setup = _game_session.build_battle_setup()
	if _current_battle_setup.is_empty():
		return
	_show_troop_selection()


func _start_battle() -> void:
	if _troop_selection != null:
		_troop_selection.queue_free()
		_troop_selection = null
	if _gameplay_page != null:
		_gameplay_page.queue_free()
		_gameplay_page = null

	var battle_scene: PackedScene = _resolve_battle_scene()
	_battle_root = battle_scene.instantiate()
	add_child(_battle_root)
	if _battle_root.has_signal("battle_finished"):
		_battle_root.battle_finished.connect(_on_battle_finished)

	if _battle_root.has_method("spawn_from_battle_setup") and not _current_battle_setup.is_empty() and _game_session != null:
		_battle_root.spawn_from_battle_setup(_current_battle_setup, _game_session.get("config"))
	elif _battle_root.has_method("spawn_player_units"):
		_battle_root.spawn_player_units(_current_troop)

	if _battle_unit_bar != null and _battle_unit_bar.has_method("bind_battle"):
		_battle_unit_bar.bind_battle(_battle_root, _game_session)
	_set_game_ui_visible(true)
	battle_started.emit(_current_troop)


func _on_battle_finished(result: Dictionary) -> void:
	if _game_session != null and _game_session.has_method("resolve_battle_round"):
		_game_session.resolve_battle_round(result)
	_current_battle_setup = {}
	_reset_battle_ui_state()
	if String(result.get("outcome", "")) == "defeat" or bool(result.get("defeat", false)) or bool(result.get("lost", false)):
		_show_main_menu()
		return
	_show_gameplay_page()


func _get_ui_parent() -> Node:
	if _ui_root != null:
		return _ui_root

	return self


func _resolve_battle_scene() -> PackedScene:
	var battle_scene_path := ""
	if _game_session != null:
		var active_config = _game_session.get("config")
		var battle_scene_id := String(_current_battle_setup.get("battle_scene_id", ""))
		if active_config != null and active_config.has_method("get_battle_scene_path"):
			battle_scene_path = active_config.get_battle_scene_path(battle_scene_id)
	if battle_scene_path != "":
		var loaded_scene = load(battle_scene_path)
		if loaded_scene is PackedScene:
			return loaded_scene
	return FALLBACK_BATTLE_ROOT_SCENE


func _set_game_ui_visible(is_visible: bool) -> void:
	if _selection_overlay != null:
		_selection_overlay.visible = is_visible
		_selection_overlay.set_process_unhandled_input(is_visible)

	if _day_hud != null:
		_day_hud.visible = is_visible

	if _battle_unit_bar != null:
		_battle_unit_bar.visible = is_visible


func _reset_battle_ui_state() -> void:
	if _game_session != null and _game_session.has_method("clear_selection"):
		_game_session.clear_selection()
	if _battle_unit_bar != null and _battle_unit_bar.has_method("clear_battle"):
		_battle_unit_bar.clear_battle()


func _free_runtime_nodes() -> void:
	if _battle_root != null:
		_battle_root.queue_free()
		_battle_root = null
	if _troop_selection != null:
		_troop_selection.queue_free()
		_troop_selection = null
	if _faction_selection_page != null:
		_faction_selection_page.queue_free()
		_faction_selection_page = null
	if _gameplay_page != null:
		_gameplay_page.queue_free()
		_gameplay_page = null


func get_current_troop() -> String:
	return _current_troop
