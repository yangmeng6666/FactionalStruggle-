extends Control

var _battle_root: Node = null
var _game_session: Node = null
var _cards_by_id: Dictionary = {}
var _card_units_by_id: Dictionary = {}

@onready var _card_list: HBoxContainer = $PanelContainer/MarginContainer/CardScroll/CardList

func _ready() -> void:
	visible = false


func bind_battle(battle_root: Node, game_session: Node) -> void:
	_clear_battle()
	_battle_root = battle_root
	_game_session = game_session
	if _battle_root != null and _battle_root.has_signal("player_formations_spawned") and not _battle_root.player_formations_spawned.is_connected(_on_player_formations_spawned):
		_battle_root.player_formations_spawned.connect(_on_player_formations_spawned)
	elif _battle_root != null and _battle_root.has_signal("player_squads_spawned") and not _battle_root.player_squads_spawned.is_connected(_on_player_formations_spawned):
		_battle_root.player_squads_spawned.connect(_on_player_formations_spawned)
	if _game_session != null and _game_session.has_signal("selection_changed") and not _game_session.selection_changed.is_connected(_on_selection_changed):
		_game_session.selection_changed.connect(_on_selection_changed)
	visible = true
	_rebuild_cards(_get_player_formations())


func clear_battle() -> void:
	_clear_battle()
	visible = false


func _clear_battle() -> void:
	if _battle_root != null and _battle_root.has_signal("player_formations_spawned") and _battle_root.player_formations_spawned.is_connected(_on_player_formations_spawned):
		_battle_root.player_formations_spawned.disconnect(_on_player_formations_spawned)
	if _battle_root != null and _battle_root.has_signal("player_squads_spawned") and _battle_root.player_squads_spawned.is_connected(_on_player_formations_spawned):
		_battle_root.player_squads_spawned.disconnect(_on_player_formations_spawned)
	if _game_session != null and _game_session.has_signal("selection_changed") and _game_session.selection_changed.is_connected(_on_selection_changed):
		_game_session.selection_changed.disconnect(_on_selection_changed)
	for formation_id in _card_units_by_id.keys():
		var formation = _card_units_by_id[formation_id]
		if is_instance_valid(formation) and formation.has_signal("state_changed") and formation.state_changed.is_connected(_on_formation_state_changed):
			formation.state_changed.disconnect(_on_formation_state_changed)
	_cards_by_id.clear()
	_card_units_by_id.clear()
	if _card_list != null:
		for child in _card_list.get_children():
			child.queue_free()
	_battle_root = null
	_game_session = null


func _get_player_formations() -> Array:
	if _battle_root == null:
		return []
	if _battle_root.has_method("get_player_formations"):
		return _battle_root.get_player_formations()
	if _battle_root.has_method("get_player_squads"):
		return _battle_root.get_player_squads()
	return []


func _get_player_squads() -> Array:
	return _get_player_formations()


func _on_player_formations_spawned(_formations: Array) -> void:
	_rebuild_cards(_get_player_formations())


func _on_player_squads_spawned(_squads: Array) -> void:
	_on_player_formations_spawned(_squads)


func _rebuild_cards(formations: Array) -> void:
	_cards_by_id.clear()
	_card_units_by_id.clear()
	for child in _card_list.get_children():
		child.queue_free()
	for formation in formations:
		if not is_instance_valid(formation):
			continue
		var card := Button.new()
		card.custom_minimum_size = Vector2(190, 92)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.pressed.connect(_on_card_pressed.bind(formation))
		_card_list.add_child(card)
		var formation_id: int = int(formation.get_instance_id())
		_cards_by_id[formation_id] = card
		_card_units_by_id[formation_id] = formation
		if formation.has_signal("state_changed") and not formation.state_changed.is_connected(_on_formation_state_changed):
			formation.state_changed.connect(_on_formation_state_changed)
		if not formation.tree_exited.is_connected(_on_formation_tree_exited.bind(formation_id)):
			formation.tree_exited.connect(_on_formation_tree_exited.bind(formation_id))
		_refresh_card(formation)
	_on_selection_changed(0)


func _on_card_pressed(formation) -> void:
	if _game_session == null or not is_instance_valid(formation):
		return
	if _game_session.has_method("set_selected_formations"):
		_game_session.set_selected_formations([formation])
	elif _game_session.has_method("set_selected_squads"):
		_game_session.set_selected_squads([formation])


func _on_selection_changed(_selected_count: int) -> void:
	for formation_id in _card_units_by_id.keys():
		var formation = _card_units_by_id[formation_id]
		if is_instance_valid(formation):
			_refresh_card(formation)


func _on_formation_state_changed() -> void:
	for formation_id in _card_units_by_id.keys():
		var formation = _card_units_by_id[formation_id]
		if is_instance_valid(formation):
			_refresh_card(formation)
		else:
			_remove_card(formation_id)


func _on_squad_state_changed() -> void:
	_on_formation_state_changed()


func _on_formation_tree_exited(formation_id: int) -> void:
	_remove_card(formation_id)


func _on_squad_tree_exited(squad_id: int) -> void:
	_on_formation_tree_exited(squad_id)


func _remove_card(formation_id: int) -> void:
	var card = _cards_by_id.get(formation_id, null)
	if card != null:
		card.queue_free()
	_cards_by_id.erase(formation_id)
	_card_units_by_id.erase(formation_id)


func _refresh_card(formation) -> void:
	if not is_instance_valid(formation):
		return
	var formation_id: int = formation.get_instance_id()
	var card := _cards_by_id.get(formation_id, null) as Button
	if card == null:
		return
	var selected: bool = bool(formation.get("is_selected"))
	var engaged: bool = formation.has_method("is_engaged") and bool(formation.is_engaged())
	var state_text: String = "交战中" if engaged else "待命"
	var formation_label: String = formation.get_formation_label() if formation.has_method("get_formation_label") else "%s方阵" % String(formation.get("display_name"))
	var member_count: int = formation.get_current_formation_members() if formation.has_method("get_current_formation_members") else 1
	var member_total: int = formation.get_formation_size() if formation.has_method("get_formation_size") else 1
	var formation_alive: int = 1
	if formation.has_method("is_dead") and formation.is_dead():
		formation_alive = 0
	card.text = "%s\n编制 %d/%d  士兵 %d/%d\n士气 %d/%d  %s" % [
		formation_label,
		formation_alive,
		1,
		member_count,
		maxi(1, member_total),
		int(round(float(formation.get("current_morale")))),
		maxi(1, int(round(float(formation.get("max_morale"))))),
		state_text,
	]
	card.modulate = _get_card_modulate(selected, engaged)


func _get_card_modulate(selected: bool, engaged: bool) -> Color:
	if selected and engaged:
		return Color(1.0, 0.88, 0.72, 1.0)
	if selected:
		return Color(0.78, 0.9, 1.0, 1.0)
	if engaged:
		return Color(1.0, 0.8, 0.8, 1.0)
	return Color(0.92, 0.92, 0.92, 1.0)
