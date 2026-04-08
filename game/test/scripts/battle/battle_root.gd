extends Node2D

@onready var player_units_root: Node = $Units/PlayerUnits
@onready var enemy_units_root: Node = $Units/EnemyUnits
@onready var effects_root: Node2D = $Effects

const SQUAD_SCENE: PackedScene = preload("res://scenes/units/squad.tscn")
const MOVE_TARGET_MARKER_SCRIPT := preload("res://scripts/battle/move_target_marker.gd")

# Infantry: 3 units in formation, normal stats
const INFANTRY_POSITIONS: Array[Vector2] = [
	Vector2(-430, 220),
	Vector2(-480, 280),
	Vector2(-380, 280),
]

# Cavalry: 1 elite unit, faster but less hp
const CAVALRY_POSITION: Vector2 = Vector2(-430, 220)
const MIN_FORMATION_SPACING := 32.0
const FORMATION_SPACING_MULTIPLIER := 2.5
const FORMATION_SEARCH_STEPS := 7
const FORMATION_SEARCH_STEP_SCALE := 0.35
const TARGET_REFRESH_INTERVAL := 0.25
const DEFAULT_AUTO_ENGAGE_RANGE := 180.0

var _target_refresh_timer: float = 0.0

func _ready() -> void:
	add_to_group("battle_root")
	for squad in get_player_squads():
		if squad.has_method("set_team"):
			squad.set_team("player")
	for squad in get_enemy_squads():
		if squad.has_method("set_team"):
			squad.set_team("enemy")

func _physics_process(delta: float) -> void:
	_target_refresh_timer -= delta
	if _target_refresh_timer > 0.0:
		return

	_target_refresh_timer = TARGET_REFRESH_INTERVAL
	var player_squads := get_player_squads()
	var enemy_squads := get_enemy_squads()
	_update_combat_targets(player_squads, enemy_squads)
	_update_combat_targets(enemy_squads, player_squads)

func spawn_player_units(troop_type: String) -> void:
	# Clear existing player units
	for child in player_units_root.get_children():
		child.queue_free()

	match troop_type:
		"infantry":
			_spawn_infantry_team()
		"cavalry":
			_spawn_cavalry_team()
		_:
			_spawn_infantry_team()


func _spawn_infantry_team() -> void:
	for pos in INFANTRY_POSITIONS:
		var squad: CharacterBody2D = SQUAD_SCENE.instantiate()
		squad.global_position = pos
		player_units_root.add_child(squad)
		if squad.has_method("set_team"):
			squad.set_team("player")


func _spawn_cavalry_team() -> void:
	var squad: CharacterBody2D = SQUAD_SCENE.instantiate()
	squad.global_position = CAVALRY_POSITION
	# Cavalry: faster movement, less hp, larger presence
	squad.set("move_speed", 200.0)
	squad.set("max_hp", 80)
	squad.set("selection_radius", 24.0)
	player_units_root.add_child(squad)
	if squad.has_method("set_team"):
		squad.set_team("player")

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

	var move_squads: Array = []
	var formation_center := Vector2.ZERO
	for squad in selected_squads:
		if not is_instance_valid(squad):
			continue
		if squad.get("team") != "player":
			continue
		move_squads.append(squad)
		formation_center += squad.global_position

	if move_squads.is_empty():
		return

	formation_center /= move_squads.size()
	var move_direction := target - formation_center
	if move_direction.length_squared() <= 0.0001:
		move_direction = Vector2.RIGHT
	else:
		move_direction = move_direction.normalized()
	var lateral_axis := Vector2(-move_direction.y, move_direction.x)

	move_squads.sort_custom(func(a, b): return a.global_position.dot(lateral_axis) < b.global_position.dot(lateral_axis))

	var spacing := MIN_FORMATION_SPACING
	for squad in move_squads:
		spacing = maxf(spacing, squad.get("selection_radius") * FORMATION_SPACING_MULTIPLIER)

	var navigation_map := RID()
	var navigation_agent := move_squads[0].get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if navigation_agent != null:
		navigation_map = navigation_agent.get_navigation_map()

	var assigned_targets: Array[Vector2] = []
	for index in move_squads.size():
		var slot_offset := (float(index) - (move_squads.size() - 1) * 0.5) * spacing
		var slot_target := _get_formation_target(target, lateral_axis, slot_offset, spacing, navigation_map, assigned_targets)
		assigned_targets.append(slot_target)
		move_squads[index].set_move_target(slot_target)

	_spawn_move_target_marker(target)


func _update_combat_targets(allies: Array, enemies: Array) -> void:
	var claimed_enemy_ids: Dictionary = {}

	for squad in allies:
		if not is_instance_valid(squad):
			continue
		if not squad.has_method("can_auto_engage") or not squad.can_auto_engage():
			continue
		if not squad.has_method("get_combat_target"):
			continue

		var current_target = squad.get_combat_target()
		if current_target == null:
			continue
		if not enemies.has(current_target):
			squad.set_combat_target(null)
			continue
		var current_target_id: int = current_target.get_instance_id()
		if claimed_enemy_ids.has(current_target_id):
			squad.set_combat_target(null)
			continue
		claimed_enemy_ids[current_target_id] = true

	for squad in allies:
		if not is_instance_valid(squad):
			continue
		if not squad.has_method("can_auto_engage") or not squad.can_auto_engage():
			continue
		if squad.has_method("get_combat_target") and squad.get_combat_target() != null:
			continue

		var combat_target = _get_nearest_enemy(squad, enemies, claimed_enemy_ids)
		if combat_target != null:
			claimed_enemy_ids[combat_target.get_instance_id()] = true
		squad.set_combat_target(combat_target)

func _get_nearest_enemy(squad, enemies: Array, claimed_enemy_ids: Dictionary):
	var nearest_enemy = null
	var nearest_distance := INF
	var max_acquire_distance := DEFAULT_AUTO_ENGAGE_RANGE
	var auto_engage_range = squad.get("auto_engage_range")
	if auto_engage_range is float or auto_engage_range is int:
		max_acquire_distance = float(auto_engage_range)
	var max_acquire_distance_squared := max_acquire_distance * max_acquire_distance
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy == squad:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var enemy_id: int = enemy.get_instance_id()
		if claimed_enemy_ids.has(enemy_id):
			continue
		var distance: float = squad.global_position.distance_squared_to(enemy.global_position)
		if distance > max_acquire_distance_squared:
			continue
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	return nearest_enemy

func _get_formation_target(target: Vector2, lateral_axis: Vector2, slot_offset: float, spacing: float, navigation_map: RID, assigned_targets: Array[Vector2]) -> Vector2:
	var best_target := _get_nav_safe_point(navigation_map, target + lateral_axis * slot_offset)
	if assigned_targets.is_empty():
		return best_target

	var best_score := -INF
	for search_step in range(FORMATION_SEARCH_STEPS):
		var search_offset := slot_offset
		if search_step > 0:
			var step_sign := -1.0 if search_step % 2 == 0 else 1.0
			search_offset += ceil(search_step * 0.5) * spacing * FORMATION_SEARCH_STEP_SCALE * step_sign
		var candidate := _get_nav_safe_point(navigation_map, target + lateral_axis * search_offset)
		var nearest_assigned_distance := INF
		for assigned_target in assigned_targets:
			nearest_assigned_distance = minf(nearest_assigned_distance, candidate.distance_to(assigned_target))
		var score := nearest_assigned_distance - absf(search_offset - slot_offset)
		if score > best_score:
			best_score = score
			best_target = candidate

	return best_target


func _get_nav_safe_point(navigation_map: RID, point: Vector2) -> Vector2:
	if navigation_map.is_valid() and NavigationServer2D.map_get_iteration_id(navigation_map) > 0:
		return NavigationServer2D.map_get_closest_point(navigation_map, point)
	return point

func _spawn_move_target_marker(target: Vector2) -> void:
	if effects_root == null:
		return
	var marker: Node2D = MOVE_TARGET_MARKER_SCRIPT.new()
	marker.global_position = target
	effects_root.add_child(marker)
