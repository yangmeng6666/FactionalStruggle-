extends Control

signal troop_selected(troop_type: String)

var _game_session: Node = null
var _troop_entries: Array[Dictionary] = []
var _selected_troop_id: String = ""

@onready var _troop_list: VBoxContainer = $PanelContainer/VBox/TroopList
@onready var _confirm_button: Button = $PanelContainer/VBox/ConfirmButton
@onready var _status_label: Label = $StatusLabel

func setup(game_session: Node) -> void:
	_game_session = game_session
	if is_node_ready():
		_refresh_options()


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_refresh_options()


func _refresh_options() -> void:
	_troop_entries = _build_troop_entries()
	if _troop_entries.is_empty():
		_selected_troop_id = ""
	else:
		var available_ids: Array[String] = []
		for entry in _troop_entries:
			available_ids.append(String(entry.get("unit_id", "")))
		if _selected_troop_id == "" or not available_ids.has(_selected_troop_id):
			_selected_troop_id = available_ids[0]
	_build_troop_buttons()
	_update_selection_ui()


func _build_troop_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _game_session == null or not _game_session.has_method("get_troop_selection_entries"):
		return entries
	var config = _game_session.get("config")
	for army_entry in _game_session.get_troop_selection_entries():
		if not army_entry is Dictionary:
			continue
		var unit_id := String(army_entry.get("unit_id", ""))
		if unit_id == "":
			continue
		var display_name := unit_id
		if config != null and config.has_method("get_unit"):
			var unit_config: Dictionary = config.get_unit(unit_id)
			display_name = String(unit_config.get("display_name", unit_id))
		entries.append({
			"unit_id": unit_id,
			"display_name": display_name,
			"count": int(army_entry.get("count", 0)),
		})
	return entries


func _build_troop_buttons() -> void:
	for child in _troop_list.get_children():
		child.queue_free()
	for entry in _troop_entries:
		var unit_id := String(entry.get("unit_id", ""))
		var button := Button.new()
		button.toggle_mode = true
		button.text = "%s x%d" % [String(entry.get("display_name", unit_id)), int(entry.get("count", 0))]
		button.pressed.connect(_on_troop_button_pressed.bind(unit_id))
		_troop_list.add_child(button)


func _on_troop_button_pressed(troop_id: String) -> void:
	_selected_troop_id = troop_id
	_update_selection_ui()


func _on_confirm_pressed() -> void:
	if _selected_troop_id == "":
		return
	_status_label.text = "正在部署%s..." % _get_selected_troop_name()
	troop_selected.emit(_selected_troop_id)


func _update_selection_ui() -> void:
	var index := 0
	for child in _troop_list.get_children():
		var button := child as Button
		if button == null:
			continue
		var troop_id := String(_troop_entries[index].get("unit_id", "")) if index < _troop_entries.size() else ""
		button.button_pressed = troop_id == _selected_troop_id
		index += 1
	_confirm_button.disabled = _selected_troop_id == ""
	if _selected_troop_id == "":
		_status_label.text = "暂无可部署部队"
		return
	_status_label.text = "已选择：%s，确认后进入战斗" % _get_selected_troop_name()


func _get_selected_troop_name() -> String:
	for entry in _troop_entries:
		if String(entry.get("unit_id", "")) == _selected_troop_id:
			return String(entry.get("display_name", _selected_troop_id))
	return _selected_troop_id
