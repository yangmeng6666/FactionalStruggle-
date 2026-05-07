extends Control

signal troop_selected(troop_type: String)

var _game_session: Node = null
var _troop_entries: Array[Dictionary] = []

@onready var _title_label: Label = $PanelContainer/VBox/Title
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
	_build_troop_rows()
	_update_ui()


func _build_troop_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _game_session == null or not _game_session.has_method("get_troop_selection_entries"):
		return entries
	var config = _game_session.get("config")
	for army_entry_variant in _game_session.get_troop_selection_entries():
		if not army_entry_variant is Dictionary:
			continue
		var army_entry: Dictionary = army_entry_variant
		var corps_config: Dictionary = config.get_corps(String(army_entry.get("corps_id", ""))) if config != null and config.has_method("get_corps") else {}
		var corps_name := String(corps_config.get("display_name", army_entry.get("display_name", army_entry.get("corps_id", "兵团"))))
		var members: Array = army_entry.get("members", [])
		var total_morale := 0
		var total_upkeep := 0
		var member_lines: Array[String] = []
		for member_variant in members:
			if not member_variant is Dictionary:
				continue
			var member: Dictionary = member_variant
			var unit_id := String(member.get("unit_id", ""))
			var count := int(member.get("count", 0))
			var unit_config: Dictionary = config.get_unit(unit_id) if config != null and config.has_method("get_unit") else {}
			var campaign: Dictionary = unit_config.get("campaign", {})
			member_lines.append("%s x%d" % [String(unit_config.get("display_name", unit_id)), count])
			total_morale += int(campaign.get("morale", 0)) * count
			total_upkeep += int(campaign.get("upkeep", 0)) * count
		entries.append({
			"display_name": corps_name,
			"members_text": " / ".join(member_lines),
			"morale": total_morale,
			"upkeep": total_upkeep,
		})
	return entries


func _build_troop_rows() -> void:
	for child in _troop_list.get_children():
		child.queue_free()
	for entry in _troop_entries:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var name_label := Label.new()
		name_label.text = String(entry.get("display_name", ""))
		row.add_child(name_label)

		var members_label := Label.new()
		members_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		members_label.modulate = Color(0.9, 0.9, 0.9, 1.0)
		members_label.text = String(entry.get("members_text", ""))
		row.add_child(members_label)

		var detail_label := Label.new()
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.modulate = Color(0.82, 0.82, 0.82, 1.0)
		detail_label.text = "士气 %d  维护 %d" % [
			int(entry.get("morale", 0)),
			int(entry.get("upkeep", 0)),
		]
		row.add_child(detail_label)

		var separator := HSeparator.new()
		row.add_child(separator)
		_troop_list.add_child(row)


func _on_confirm_pressed() -> void:
	if _troop_entries.is_empty():
		return
	_status_label.text = "正在部署全军..."
	troop_selected.emit("all_corps")


func _update_ui() -> void:
	_confirm_button.disabled = _troop_entries.is_empty()
	if _troop_entries.is_empty():
		_title_label.text = "暂无可部署部队"
		_status_label.text = "请先在经营阶段补充兵团"
		return
	_title_label.text = "确认本回合出战部队"
	_status_label.text = "当前将部署全部兵团进入战斗"
