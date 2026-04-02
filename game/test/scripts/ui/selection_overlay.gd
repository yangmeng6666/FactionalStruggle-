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

	var squad = battle_root.get_player_squad_at_world_position(world_position)
	if squad == null:
		game_session.clear_selection()
		return

	game_session.set_selected_squads([squad])

func _select_box(screen_rect: Rect2) -> void:
	var battle_root = _get_battle_root()
	var game_session = _get_game_session()
	if battle_root == null or game_session == null:
		return

	var selected_squads: Array = []
	for squad in battle_root.get_player_squads():
		if not is_instance_valid(squad):
			continue
		var screen_position := _world_to_screen(squad.global_position)
		if screen_rect.has_point(screen_position):
			selected_squads.append(squad)

	game_session.set_selected_squads(selected_squads)

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
