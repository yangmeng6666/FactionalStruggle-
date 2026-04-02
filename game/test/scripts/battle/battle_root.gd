extends Node2D

@onready var player_units_root: Node = $Units/PlayerUnits
@onready var enemy_units_root: Node = $Units/EnemyUnits

func _ready() -> void:
	add_to_group("battle_root")
	for squad in get_player_squads():
		if squad.has_method("set_team"):
			squad.set_team("player")
	for squad in get_enemy_squads():
		if squad.has_method("set_team"):
			squad.set_team("enemy")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("command_move"):
		_issue_move_command(get_global_mouse_position())

func get_player_squads() -> Array:
	var squads: Array = []
	for child in player_units_root.get_children():
		if is_instance_valid(child):
			squads.append(child)
	return squads

func get_enemy_squads() -> Array:
	var squads: Array = []
	for child in enemy_units_root.get_children():
		if is_instance_valid(child):
			squads.append(child)
	return squads

func get_player_squad_at_world_position(world_position: Vector2):
	var best_squad = null
	var best_distance: float = INF

	for squad in get_player_squads():
		if not squad.has_method("contains_world_point"):
			continue
		if not squad.contains_world_point(world_position):
			continue

		var distance: float = squad.global_position.distance_to(world_position)
		if distance < best_distance:
			best_distance = distance
			best_squad = squad

	return best_squad

func _issue_move_command(target: Vector2) -> void:
	var game_session = get_tree().get_first_node_in_group("game_session")
	if game_session == null or not game_session.has_method("get_selected_squads"):
		return

	var selected_squads: Array = game_session.get_selected_squads()
	if selected_squads.is_empty():
		return

	for squad in selected_squads:
		if not is_instance_valid(squad):
			continue
		if squad.get("team") != "player":
			continue
		if squad.has_method("set_move_target"):
			squad.set_move_target(target)
