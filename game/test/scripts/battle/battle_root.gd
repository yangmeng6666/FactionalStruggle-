extends Node2D

signal battle_finished(result: Dictionary)

@onready var player_units_root: Node = $Units/PlayerUnits
@onready var enemy_units_root: Node = $Units/EnemyUnits
@onready var effects_root: Node2D = $Effects
@onready var navigation_region: NavigationRegion2D = $Navigation
@onready var walkable_ground: Polygon2D = $MapRoot/WalkableGround

const SQUAD_SCENE: PackedScene = preload("res://scenes/units/squad.tscn")
const MOVE_TARGET_MARKER_SCRIPT := preload("res://scripts/battle/move_target_marker.gd")

const DEFAULT_PLAYER_FORMATION_ANCHOR := Vector2(10, -220)
const DEFAULT_ENEMY_FORMATION_ANCHOR := Vector2(220, -220)
const MIN_FORMATION_SPACING := 32.0
const FORMATION_SPACING_MULTIPLIER := 2.5
const FORMATION_SEARCH_STEPS := 7
const FORMATION_SEARCH_STEP_SCALE := 0.35
const DEFAULT_TARGET_REFRESH_INTERVAL := 0.25
const DEFAULT_AUTO_ENGAGE_RANGE := 180.0

var _target_refresh_timer: float = 0.0
var _target_refresh_interval: float = DEFAULT_TARGET_REFRESH_INTERVAL
var _battle_is_over: bool = false

func _ready() -> void:
	add_to_group("battle_root")
	for squad in get_player_squads():
		if squad.has_method("set_team"):
			squad.set_team("player")
	for squad in get_enemy_squads():
		if squad.has_method("set_team"):
			squad.set_team("enemy")

func _physics_process(delta: float) -> void:
	if _battle_is_over:
		return

	_target_refresh_timer -= delta
	if _target_refresh_timer > 0.0:
		return

	_target_refresh_timer = _target_refresh_interval
	var player_squads := get_player_squads()
	var enemy_squads := get_enemy_squads()
	if player_squads.is_empty() or enemy_squads.is_empty():
		_finish_battle(player_squads, enemy_squads)
		return
	_update_combat_targets(player_squads, enemy_squads)
	_update_combat_targets(enemy_squads, player_squads)

func spawn_player_units(troop_type: String) -> void:
	var game_session = get_tree().get_first_node_in_group("game_session")
	var active_config = game_session.get("config") if game_session != null else null
	if active_config == null:
		return
	var battle_setup: Dictionary = {}
	if game_session != null and game_session.has_method("build_battle_setup"):
		battle_setup = game_session.build_battle_setup()
	if battle_setup.is_empty():
		var battle_scene_id: String = active_config.get_default_battle_scene_id()
		var setup_id: String = active_config.get_default_battle_setup_id(battle_scene_id)
		battle_setup = active_config.get_battle_setup(setup_id)
		battle_setup["battle_scene_id"] = battle_scene_id
	if battle_setup.is_empty():
		return
	var selected_entry: Dictionary = {}
	for entry in battle_setup.get("player_army", battle_setup.get("default_player_army", [])):
		if String(entry.get("unit_id", "")) == troop_type:
			selected_entry = entry.duplicate(true)
			break
	if not selected_entry.is_empty():
		battle_setup["player_army"] = [selected_entry]
	spawn_from_battle_setup(battle_setup, active_config)


func spawn_from_battle_setup(battle_setup: Dictionary, config) -> void:
	_battle_is_over = false
	_target_refresh_timer = 0.0
	var battle_scene_id := String(battle_setup.get("battle_scene_id", ""))
	_target_refresh_interval = config.get_battle_target_refresh_interval(battle_scene_id) if config != null else DEFAULT_TARGET_REFRESH_INTERVAL
	_clear_unit_root(player_units_root)
	_clear_unit_root(enemy_units_root)
	if config == null:
		return
	_spawn_army(battle_setup.get("player_army", battle_setup.get("default_player_army", [])), player_units_root, "player", battle_setup, config)
	_spawn_army(battle_setup.get("enemy_army", battle_setup.get("default_enemy_army", [])), enemy_units_root, "enemy", battle_setup, config)


func _spawn_army(army: Array, parent: Node, team_name: String, battle_setup: Dictionary, config) -> void:
	var members: Array = []
	for entry in army:
		if not entry is Dictionary:
			continue
		var unit_id := String(entry.get("unit_id", ""))
		var unit_config: Dictionary = config.get_unit(unit_id)
		if unit_config.is_empty():
			continue
		for _i in range(maxi(0, int(entry.get("count", 0)))):
			members.append(_build_spawn_member(unit_id, unit_config, members.size()))

	for placement in _build_spawn_formation(battle_setup, team_name, members):
		var member: Dictionary = placement.get("member", {})
		_spawn_configured_squad(
			member.get("unit_config", {}),
			String(member.get("unit_id", "")),
			parent,
			team_name,
			placement.get("target", Vector2.ZERO)
		)


func _spawn_configured_squad(unit_config: Dictionary, unit_id: String, parent: Node, team_name: String, position: Vector2) -> void:
	var battle: Dictionary = unit_config.get("battle", {})
	var scene_path := String(battle.get("scene", ""))
	var packed_scene := SQUAD_SCENE
	if scene_path != "":
		var loaded_scene := load(scene_path)
		if loaded_scene is PackedScene:
			packed_scene = loaded_scene

	var squad: CharacterBody2D = packed_scene.instantiate()
	squad.set_meta("unit_id", unit_id)
	squad.global_position = position
	parent.add_child(squad)
	if squad.has_method("apply_unit_config"):
		squad.apply_unit_config(unit_config)
	if squad.has_method("set_team"):
		squad.set_team(team_name)
	if squad.has_method("set_combat_target"):
		squad.set_combat_target(null)
	if squad.has_method("stop_moving"):
		squad.stop_moving()


func _build_spawn_member(unit_id: String, unit_config: Dictionary, stable_order: int) -> Dictionary:
	var battle: Dictionary = unit_config.get("battle", {})
	return {
		"unit_id": unit_id,
		"unit_config": unit_config,
		"selection_radius": float(battle.get("selection_radius", MIN_FORMATION_SPACING * 0.5)),
		"size": float(battle.get("size", 1.0)),
		"tactic": String(battle.get("tactic", "frontline")),
		"stable_order": stable_order,
	}


func _build_move_member(squad, stable_order: int) -> Dictionary:
	return {
		"squad": squad,
		"selection_radius": _get_numeric_property(squad, "selection_radius", MIN_FORMATION_SPACING * 0.5),
		"size": _get_numeric_property(squad, "size", 1.0),
		"tactic": String(squad.get("tactic")),
		"stable_order": stable_order,
	}


func _build_spawn_formation(battle_setup: Dictionary, team_name: String, members: Array) -> Array:
	if members.is_empty():
		return []

	var forward := _get_spawn_forward_axis(team_name)
	var anchor := _get_spawn_anchor(battle_setup, team_name)
	var frontage := _get_spawn_frontage(members.size())
	return _build_formation_targets(anchor, forward, members, frontage, _get_spawn_navigation_map(), [], {}, true)


func _get_spawn_navigation_map() -> RID:
	if navigation_region != null:
		return navigation_region.get_navigation_map()
	return RID()


func _build_formation_targets(anchor: Vector2, forward: Vector2, members: Array, frontage: int, navigation_map: RID, preferred_offsets: Array = [], overflow: Dictionary = {}, prioritize_tactics: bool = false) -> Array:
	if members.is_empty():
		return []

	var ordered_members := _order_formation_members(members) if prioritize_tactics else members.duplicate()
	var forward_axis := forward.normalized()
	if forward_axis.length_squared() <= 0.0001:
		forward_axis = Vector2.RIGHT
	var lateral_axis := Vector2(-forward_axis.y, forward_axis.x)
	var placements: Array = []
	var assigned_targets: Array[Vector2] = []
	var preferred_count := mini(ordered_members.size(), preferred_offsets.size())
	var overflow_spacing := _get_overflow_spacing(overflow)
	var current_depth := _get_preferred_depth(preferred_offsets, forward_axis)
	if preferred_count > 0 and preferred_count < ordered_members.size():
		current_depth += _get_members_row_spacing(ordered_members.slice(preferred_count, ordered_members.size()), overflow_spacing.y)

	for index in range(preferred_count):
		var desired_position := anchor + _array_to_vector2(preferred_offsets[index])
		var member: Dictionary = ordered_members[index]
		var target := _get_preferred_spawn_target(desired_position, navigation_map)
		assigned_targets.append(target)
		placements.append({
			"member": member,
			"target": target,
		})

	var member_index := preferred_count
	while member_index < ordered_members.size():
		var row_count := mini(frontage, ordered_members.size() - member_index)
		var row_members := ordered_members.slice(member_index, member_index + row_count)
		var lateral_offsets := _build_row_lateral_offsets(row_members, overflow_spacing.x)
		for row_index in range(row_members.size()):
			var row_member: Dictionary = row_members[row_index]
			var desired_position: Vector2 = anchor - forward_axis * current_depth + lateral_axis * float(lateral_offsets[row_index])
			var target := _get_formation_target(
				desired_position,
				forward_axis,
				lateral_axis,
				_get_member_spacing(row_member),
				navigation_map,
				assigned_targets
			)
			assigned_targets.append(target)
			placements.append({
				"member": row_member,
				"target": target,
			})
		member_index += row_count
		current_depth += _get_members_row_spacing(row_members, overflow_spacing.y)

	return placements


func _order_formation_members(members: Array) -> Array:
	var frontline: Array = []
	var support: Array = []
	for member in members:
		if String(member.get("tactic", "frontline")) == "frontline":
			frontline.append(member)
		else:
			support.append(member)
	frontline.append_array(support)
	return frontline


func _build_row_lateral_offsets(row_members: Array, authored_spacing: float = 0.0) -> Array:
	var offsets: Array = []
	if row_members.is_empty():
		return offsets

	var running_offset := 0.0
	offsets.append(running_offset)
	for index in range(1, row_members.size()):
		var pair_spacing := _get_pair_spacing(row_members[index - 1], row_members[index])
		if authored_spacing > 0.0:
			pair_spacing = maxf(pair_spacing, authored_spacing)
		running_offset += pair_spacing
		offsets.append(running_offset)

	var row_center := running_offset * 0.5
	for index in range(offsets.size()):
		offsets[index] = float(offsets[index]) - row_center
	return offsets


func _get_spawn_anchor(battle_setup: Dictionary, team_name: String) -> Vector2:
	var key := "player_spawn_anchor" if team_name == "player" else "enemy_spawn_anchor"
	var fallback := DEFAULT_PLAYER_FORMATION_ANCHOR if team_name == "player" else DEFAULT_ENEMY_FORMATION_ANCHOR
	return _array_to_vector2(battle_setup.get(key, fallback))


func _get_spawn_forward_axis(team_name: String) -> Vector2:
	return Vector2.RIGHT if team_name == "player" else Vector2.LEFT


func _get_spawn_frontage(member_count: int) -> int:
	return maxi(1, int(ceil(sqrt(float(maxi(1, member_count))))))


func _get_preferred_depth(preferred_offsets: Array, forward_axis: Vector2) -> float:
	var max_depth := 0.0
	for offset in preferred_offsets:
		var depth := -_array_to_vector2(offset).dot(forward_axis)
		max_depth = maxf(max_depth, depth)
	return max_depth


func _get_members_row_spacing(members: Array, authored_spacing: float = 0.0) -> float:
	var row_spacing := maxf(MIN_FORMATION_SPACING, authored_spacing)
	for member in members:
		row_spacing = maxf(row_spacing, _get_member_spacing(member))
	return row_spacing


func _get_overflow_spacing(overflow: Dictionary) -> Vector2:
	var spacing: Variant = overflow.get("spacing", [])
	if spacing is Vector2:
		return spacing
	if spacing is Array and spacing.size() >= 2:
		return Vector2(float(spacing[0]), float(spacing[1]))
	return Vector2.ZERO


func _get_member_spacing(member: Dictionary) -> float:
	var radius := maxf(1.0, float(member.get("selection_radius", MIN_FORMATION_SPACING * 0.5)))
	var size_multiplier := maxf(1.0, float(member.get("size", 1.0)))
	return maxf(MIN_FORMATION_SPACING, radius * FORMATION_SPACING_MULTIPLIER * size_multiplier)


func _get_pair_spacing(left_member: Dictionary, right_member: Dictionary) -> float:
	return (_get_member_spacing(left_member) + _get_member_spacing(right_member)) * 0.5


func _get_numeric_property(target, property_name: String, fallback: float) -> float:
	var value = target.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback


func _array_to_vector2(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _clear_unit_root(root: Node) -> void:
	for child in root.get_children():
		child.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("command_move"):
		issue_move_command(get_global_mouse_position())

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

func issue_move_command(target: Vector2) -> void:
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

	formation_center /= float(move_squads.size())
	var move_direction := target - formation_center
	if move_direction.length_squared() <= 0.0001:
		move_direction = Vector2.RIGHT
	else:
		move_direction = move_direction.normalized()
	var lateral_axis := Vector2(-move_direction.y, move_direction.x)

	move_squads.sort_custom(func(a, b): return a.global_position.dot(lateral_axis) < b.global_position.dot(lateral_axis))

	var move_members: Array = []
	for index in range(move_squads.size()):
		move_members.append(_build_move_member(move_squads[index], index))

	var navigation_map := RID()
	var navigation_agent := move_squads[0].get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if navigation_agent != null:
		navigation_map = navigation_agent.get_navigation_map()

	var frontage := maxi(1, int(ceil(sqrt(float(move_members.size())))))
	for placement in _build_formation_targets(target, move_direction, move_members, frontage, navigation_map, [], {}, false):
		var squad = placement.get("member", {}).get("squad", null)
		if is_instance_valid(squad):
			squad.set_move_target(placement.get("target", target))

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

func _get_formation_target(desired_position: Vector2, forward_axis: Vector2, lateral_axis: Vector2, spacing: float, navigation_map: RID, assigned_targets: Array[Vector2]) -> Vector2:
	var best_target := _get_nav_safe_point(navigation_map, desired_position)
	if assigned_targets.is_empty():
		return best_target

	var best_score := _score_formation_target(best_target, desired_position, assigned_targets)
	for depth_step in range(FORMATION_SEARCH_STEPS):
		var depth_offset := float(depth_step) * spacing * FORMATION_SEARCH_STEP_SCALE
		for lateral_step in range(-FORMATION_SEARCH_STEPS, FORMATION_SEARCH_STEPS + 1):
			if depth_step == 0 and lateral_step == 0:
				continue
			var candidate_point := desired_position + lateral_axis * float(lateral_step) * spacing * FORMATION_SEARCH_STEP_SCALE - forward_axis * depth_offset
			var candidate := _get_nav_safe_point(navigation_map, candidate_point)
			var score := _score_formation_target(candidate, desired_position, assigned_targets)
			if score > best_score:
				best_score = score
				best_target = candidate

	return best_target


func _score_formation_target(candidate: Vector2, desired_position: Vector2, assigned_targets: Array[Vector2]) -> float:
	var nearest_assigned_distance := INF
	for assigned_target in assigned_targets:
		nearest_assigned_distance = minf(nearest_assigned_distance, candidate.distance_to(assigned_target))
	return nearest_assigned_distance - candidate.distance_to(desired_position)


func _get_preferred_spawn_target(desired_position: Vector2, navigation_map: RID) -> Vector2:
	return _get_nav_safe_point(navigation_map, desired_position)


func _get_nav_safe_point(navigation_map: RID, point: Vector2) -> Vector2:
	if navigation_map.is_valid() and NavigationServer2D.map_get_iteration_id(navigation_map) > 0:
		var closest_point := NavigationServer2D.map_get_closest_point(navigation_map, point)
		if _is_point_in_walkable_ground(point) and closest_point.is_equal_approx(Vector2.ZERO) and point.distance_to(Vector2.ZERO) > 96.0:
			return point
		return closest_point
	return point


func _is_point_in_walkable_ground(point: Vector2) -> bool:
	if walkable_ground == null or walkable_ground.polygon.is_empty():
		return false
	return Geometry2D.is_point_in_polygon(walkable_ground.to_local(point), walkable_ground.polygon)

func _spawn_move_target_marker(target: Vector2) -> void:
	if effects_root == null:
		return
	var marker: Node2D = MOVE_TARGET_MARKER_SCRIPT.new()
	marker.global_position = target
	effects_root.add_child(marker)


func _finish_battle(player_squads: Array, enemy_squads: Array) -> void:
	if _battle_is_over:
		return
	_battle_is_over = true
	var outcome := "draw"
	if enemy_squads.is_empty() and not player_squads.is_empty():
		outcome = "victory"
	elif player_squads.is_empty() and not enemy_squads.is_empty():
		outcome = "defeat"
	battle_finished.emit({
		"outcome": outcome,
		"player_survivors": _build_survivor_counts(player_squads),
		"enemy_survivors": _build_survivor_counts(enemy_squads),
	})


func _build_survivor_counts(squads: Array) -> Dictionary:
	var survivors: Dictionary = {}
	for squad in squads:
		if not is_instance_valid(squad):
			continue
		var unit_id := String(squad.get_meta("unit_id", ""))
		if unit_id == "":
			unit_id = String(squad.get("unit_id", ""))
		if unit_id == "":
			continue
		survivors[unit_id] = int(survivors.get(unit_id, 0)) + 1
	return survivors
