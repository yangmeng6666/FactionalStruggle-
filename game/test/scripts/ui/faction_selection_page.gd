extends Control

signal faction_selected(faction_id: String)

var game_session: Node = null
var config = null
var _selectable_factions: Array[Dictionary] = []
var _selected_faction_id: String = ""

@onready var _faction_list: VBoxContainer = $PanelContainer/MarginContainer/VBox/FactionScroll/FactionList
@onready var _confirm_button: Button = $PanelContainer/MarginContainer/VBox/ConfirmButton
@onready var _status_label: Label = $PanelContainer/MarginContainer/VBox/StatusLabel


func setup(session: Node) -> void:
	game_session = session
	if game_session != null and game_session.has_method("_ensure_config_loaded"):
		game_session._ensure_config_loaded()
	config = game_session.get("config") if game_session != null else null
	if is_inside_tree():
		_reload_factions()


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_reload_factions()


func _reload_factions() -> void:
	if _faction_list == null:
		return

	_clear_children(_faction_list)
	_selectable_factions = _get_selectable_factions()
	if _selectable_factions.is_empty():
		_selected_faction_id = ""
		_confirm_button.disabled = true
		_status_label.text = "暂无可选势力"
		return

	var available_ids: Array[String] = []
	for faction in _selectable_factions:
		available_ids.append(String(faction.get("id", "")))
	if _selected_faction_id == "" or not available_ids.has(_selected_faction_id):
		_selected_faction_id = available_ids[0]

	for faction in _selectable_factions:
		var faction_id := String(faction.get("id", ""))
		var button := Button.new()
		button.text = String(faction.get("display_name", faction_id))
		button.toggle_mode = true
		button.button_pressed = faction_id == _selected_faction_id
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(func() -> void:
			_selected_faction_id = faction_id
			_reload_factions()
		)
		_faction_list.add_child(button)

	var first_button := _faction_list.get_child(0) as Control
	if first_button != null:
		first_button.grab_focus()
	_confirm_button.disabled = false
	_status_label.text = "当前选择：%s" % _get_selected_faction_name()


func _get_selectable_factions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if game_session != null and game_session.has_method("get_selectable_factions"):
		var factions = game_session.get_selectable_factions()
		if factions is Array:
			for faction in factions:
				if faction is Dictionary:
					result.append(faction)
			if not result.is_empty():
				return result

	if config == null:
		return result
	if not config.has_method("get_faction_ids") or not config.has_method("get_faction"):
		return result

	for faction_id in config.get_faction_ids():
		var current_id := String(faction_id)
		if current_id == "neutral":
			continue
		var faction: Dictionary = config.get_faction(current_id)
		if faction.is_empty():
			continue
		result.append({
			"id": current_id,
			"display_name": config.get_faction_display_name(current_id),
		})
	return result


func _get_selected_faction_name() -> String:
	for faction in _selectable_factions:
		if String(faction.get("id", "")) == _selected_faction_id:
			return String(faction.get("display_name", _selected_faction_id))
	return _selected_faction_id


func _on_confirm_pressed() -> void:
	if _selected_faction_id == "":
		return
	_status_label.text = "正在进入%s的回合..." % _get_selected_faction_name()
	faction_selected.emit(_selected_faction_id)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
