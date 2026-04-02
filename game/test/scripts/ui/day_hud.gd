extends Control

var _game_session = null
var _label: Label
var _selected_count: int = 0
var _phase: String = "day"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	_label = Label.new()
	_label.position = Vector2(12.0, 12.0)
	add_child(_label)

	call_deferred("_bind_game_session")

func _bind_game_session() -> void:
	_game_session = get_tree().get_first_node_in_group("game_session")
	if _game_session != null:
		_game_session.selection_changed.connect(_on_selection_changed)
		_game_session.phase_changed.connect(_on_phase_changed)
		_phase = _game_session.get_phase()
		_selected_count = _game_session.get_selected_squads().size()
	_update_text()

func _on_selection_changed(selected_count: int) -> void:
	_selected_count = selected_count
	_update_text()

func _on_phase_changed(phase: String) -> void:
	_phase = phase
	_update_text()

func _update_text() -> void:
	if _label == null:
		return
	_label.text = "Phase: %s\nSelected: %d" % [_phase.capitalize(), _selected_count]
