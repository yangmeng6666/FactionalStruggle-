extends Control

const CLICK_THRESHOLD: float = 6.0

var _is_selecting: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.pressed:
			_is_selecting = true
			_drag_start = mouse_button.position
			_drag_current = mouse_button.position
			queue_redraw()
			return

		if not _is_selecting:
			return

		_drag_current = mouse_button.position
		var drag_rect: Rect2 = _get_drag_rect()
		_is_selecting = false
		queue_redraw()

		if maxf(drag_rect.size.x, drag_rect.size.y) <= CLICK_THRESHOLD:
			_select_single(_screen_to_world(mouse_button.position))
		else:
			_select_box(drag_rect)
		return

	if event is InputEventMouseMotion and _is_selecting:
		var mouse_motion: InputEventMouseMotion = event
		_drag_current = mouse_motion.position
		queue_redraw()

func _draw() -> void:
	if not _is_selecting:
		return

	var drag_rect := _get_drag_rect()
	draw_rect(drag_rect, Color(0.3, 0.7, 1.0, 0.15), true)
	draw_rect(drag_rect, Color(0.3, 0.7, 1.0, 0.95), false, 2.0)

func _select_single(world_position: Vector2) -> void:
	var battle_root = _get_battle_root()
	var game_session = _get_game_session()
	if battle_root == null or game_session == null:
		return

	var formation = null
	if battle_root.has_method("get_player_formation_at_world_position"):
		formation = battle_root.get_player_formation_at_world_position(world_position)
	else:
		formation = battle_root.get_player_squad_at_world_position(world_position)
	if formation == null:
		game_session.clear_selection()
		return

	if game_session.has_method("set_selected_formations"):
		game_session.set_selected_formations([formation])
	else:
		game_session.set_selected_squads([formation])

func _select_box(screen_rect: Rect2) -> void:
	var battle_root = _get_battle_root()
	var game_session = _get_game_session()
	if battle_root == null or game_session == null:
		return

	var selected_formations: Array = []
	var player_formations: Array = battle_root.get_player_formations() if battle_root.has_method("get_player_formations") else battle_root.get_player_squads()
	for formation in player_formations:
		if not is_instance_valid(formation):
			continue
		var screen_position := _world_to_screen(formation.global_position)
		if screen_rect.has_point(screen_position):
			selected_formations.append(formation)

	if game_session.has_method("set_selected_formations"):
		game_session.set_selected_formations(selected_formations)
	else:
		game_session.set_selected_squads(selected_formations)

func _get_drag_rect() -> Rect2:
	return Rect2(_drag_start, _drag_current - _drag_start).abs()

func _get_game_session():
	return get_tree().get_first_node_in_group("game_session")

func _get_battle_root():
	return get_tree().get_first_node_in_group("battle_root")

func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

func _world_to_screen(world_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_position
