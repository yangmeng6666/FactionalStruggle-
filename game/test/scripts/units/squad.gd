extends CharacterBody2D

signal state_changed

@export_enum("neutral", "player", "enemy") var team: String = "neutral"
@export var move_speed: float = 120.0
@export var max_hp: int = 100
@export var selection_radius: float = 16.0
@export var auto_engage_range: float = 180.0
@export var attack_interval: float = 0.75
@export var attack_damage: int = 25
@export var attack_damage_frame: int = 4
@export var armor: int = 0
@export var defense: int = 0
@export var injured_ratio: float = 1.0
@export var tactic: String = "frontline"
@export var max_morale: float = 100.0
@export var morale_damage_factor: float = 0.6
@export var size: float = 1.0
@export var formation_size: int = 1
@export var formation_files: int = 1
@export var formation_ranks: int = 1
@export var member_spacing: Vector2 = Vector2(16.0, 18.0)

const HURT_FLASH_DURATION := 0.12
const MIN_VISIBLE_FORMATION_MEMBERS := 1
const FORMATION_MEMBER_SCALE := 0.72
const FORMATION_MEMBER_TINT := Color(1.0, 1.0, 1.0, 0.9)

const FORMATION_RING_COLOR := Color(0.92, 0.92, 0.92, 0.55)
const FORMATION_FILL_COLOR := Color(0.14, 0.16, 0.18, 0.42)
const ENGAGED_COLOR := Color(1.0, 0.45, 0.45, 0.22)
const STRENGTH_COLOR := Color(0.58, 0.9, 0.64, 0.95)
const MORALE_COLOR := Color(0.95, 0.85, 0.4, 0.95)

enum AnimationState {
	IDLE,
	WALK,
	ATTACK,
	HURT,
	DEAD,
}

var is_selected: bool = false
var current_hp: int = 0
var current_morale: float = 0.0
var display_name: String = ""
var unit_id: String = ""
var _animation_state: int = AnimationState.IDLE
var _is_dead: bool = false
var _attack_cooldown: float = 0.0
var _combat_target = null
var _pending_attack_target = null
var _attack_damage_applied: bool = false
var _melee_range: float = 0.0
var _manual_move_override: bool = false
var _hurt_tween: Tween
var _formation_members_root: Node2D
var _formation_member_sprites: Array[Sprite2D] = []
var _formation_member_positions: Array[Vector2] = []

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_range_shape: CollisionShape2D = $AttackRange/CollisionShape2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var selection_shape: CollisionShape2D = $SelectionArea/CollisionShape2D

func _ready() -> void:
	current_hp = max_hp
	current_morale = max_morale
	_ensure_formation_members_root()
	_refresh_formation_layout()
	_update_collision_shapes()
	_melee_range = _read_melee_range()
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	navigation_agent.avoidance_enabled = false
	navigation_agent.target_position = global_position
	if not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)
	if not sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		sprite.frame_changed.connect(_on_sprite_frame_changed)
	sprite.visible = false
	_update_visuals()
	_update_formation_member_visuals()
	_update_animation()
	_emit_state_changed()
	queue_redraw()

func _draw() -> void:
	var formation_radius := selection_radius
	draw_circle(Vector2.ZERO, formation_radius, FORMATION_FILL_COLOR)
	if is_engaged():
		draw_circle(Vector2.ZERO, formation_radius, ENGAGED_COLOR)
	var ring_color: Color = Color.WHITE if is_selected else FORMATION_RING_COLOR
	var ring_width: float = 3.0 if is_selected else 2.0
	draw_arc(Vector2.ZERO, formation_radius, 0.0, TAU, 48, ring_color, ring_width)
	_draw_status_bar(Vector2(-formation_radius, -formation_radius - 14.0), formation_radius * 2.0, 5.0, _get_strength_ratio(), STRENGTH_COLOR)
	_draw_status_bar(Vector2(-formation_radius, -formation_radius - 7.0), formation_radius * 2.0, 4.0, _get_morale_ratio(), MORALE_COLOR)

func _physics_process(delta: float) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation()
		return

	if _manual_move_override and navigation_agent.is_navigation_finished():
		_manual_move_override = false
		_emit_state_changed()

	var has_combat_target := false
	if not _manual_move_override:
		has_combat_target = _has_valid_combat_target()
		if has_combat_target:
			var target_position: Vector2 = _combat_target.global_position
			if global_position.distance_to(target_position) <= get_engage_distance_to(_combat_target):
				_manual_move_override = false
				stop_moving()
				if _attack_cooldown <= 0.0:
					_begin_attack(_combat_target)
				return
			navigation_agent.target_position = target_position
		else:
			stop_moving()
			return

	if navigation_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation()
		return

	var next_position: Vector2 = navigation_agent.get_next_path_position()
	var direction: Vector2 = global_position.direction_to(next_position)
	if direction.length_squared() <= 0.0001:
		velocity = Vector2.ZERO
	else:
		velocity = direction * move_speed

	move_and_slide()
	_update_animation()

func set_team(value: String) -> void:
	team = value
	_update_visuals()
	_emit_state_changed()
	queue_redraw()

func apply_unit_config(unit_config: Dictionary) -> void:
	unit_id = String(unit_config.get("id", get_meta("unit_id", unit_id)))
	display_name = String(unit_config.get("display_name", display_name if display_name != "" else unit_id))
	var battle: Dictionary = unit_config.get("battle", {})
	max_hp = int(battle.get("max_hp", max_hp))
	move_speed = float(battle.get("move_speed", move_speed))
	selection_radius = float(battle.get("selection_radius", selection_radius))
	auto_engage_range = float(battle.get("auto_engage_range", auto_engage_range))
	attack_damage = int(battle.get("attack", attack_damage))
	attack_interval = float(battle.get("attack_interval", attack_interval))
	attack_damage_frame = int(battle.get("attack_damage_frame", attack_damage_frame))
	armor = int(battle.get("armor", armor))
	defense = int(battle.get("defense", defense))
	injured_ratio = float(battle.get("injured_ratio", injured_ratio))
	tactic = String(battle.get("tactic", tactic))
	size = float(battle.get("size", size))
	max_morale = float(battle.get("max_morale", battle.get("morale", max_morale)))
	morale_damage_factor = float(battle.get("morale_damage_factor", morale_damage_factor))
	formation_size = maxi(1, int(battle.get("formation_size", formation_size)))
	formation_files = maxi(1, int(battle.get("files", battle.get("formation_files", formation_files))))
	formation_ranks = maxi(1, int(battle.get("ranks", battle.get("formation_ranks", formation_ranks))))
	member_spacing = _read_member_spacing(battle.get("member_spacing", member_spacing))
	current_hp = max_hp
	current_morale = max_morale
	_refresh_formation_layout()
	_update_collision_shapes()
	_melee_range = _read_melee_range()
	_update_formation_member_visuals()
	_emit_state_changed()
	queue_redraw()

func set_move_target(target: Vector2) -> void:
	if _is_dead:
		return
	_manual_move_override = true
	_combat_target = null
	navigation_agent.target_position = target
	_emit_state_changed()

func stop_moving() -> void:
	navigation_agent.target_position = global_position
	velocity = Vector2.ZERO
	_update_animation()

func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	_update_visuals()
	_emit_state_changed()
	queue_redraw()

func contains_world_point(world_point: Vector2) -> bool:
	return global_position.distance_to(world_point) <= selection_radius

func play_attack_animation() -> void:
	if _is_dead:
		return
	_set_animation_state(AnimationState.ATTACK)

func get_formation_size() -> int:
	return formation_size

func get_formation_member_count() -> int:
	return get_current_formation_members()

func get_current_formation_members() -> int:
	if _is_dead:
		return 0
	return _get_visible_member_count()

func get_formation_label() -> String:
	return "%s方阵" % get_display_name()

func _begin_attack(target) -> void:
	if _is_dead:
		return
	_pending_attack_target = target
	_attack_damage_applied = false
	_attack_cooldown = attack_interval
	if _has_animation(&"attack"):
		play_attack_animation()
		return
	_apply_pending_attack_damage()

func take_damage(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
	current_hp = maxi(0, current_hp - amount)
	current_morale = maxf(0.0, current_morale - float(amount) * morale_damage_factor)
	_update_formation_member_visuals()
	_emit_state_changed()
	queue_redraw()
	if current_hp <= 0 or current_morale <= 0.0:
		set_dead(true)
		queue_free()
		return
	_play_hurt_feedback()

func set_combat_target(target) -> void:
	if _is_dead:
		return
	if target == self:
		target = null
	if target != null and target.get("team") == team:
		target = null
	if _combat_target == target:
		return
	_combat_target = target
	if _combat_target != null and can_force_engage_target(_combat_target):
		_manual_move_override = false
	_emit_state_changed()
	queue_redraw()

func get_combat_target():
	if _has_valid_combat_target():
		return _combat_target
	return null

func can_auto_engage() -> bool:
	return not _is_dead and not _manual_move_override

func get_contact_radius() -> float:
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return (collision_shape.shape as CircleShape2D).radius
	return maxf(10.0, selection_radius * 0.55)

func get_engage_distance_to(target) -> float:
	var engage_distance := _melee_range
	if is_instance_valid(target):
		var target_contact_radius := 0.0
		if target.has_method("get_contact_radius"):
			target_contact_radius = float(target.get_contact_radius())
		else:
			var target_selection_radius = target.get("selection_radius")
			if target_selection_radius is float or target_selection_radius is int:
				target_contact_radius = float(target_selection_radius) * 0.55
		engage_distance = maxf(engage_distance, get_contact_radius() + target_contact_radius + 4.0)
	return engage_distance

func can_force_engage_target(target) -> bool:
	if _is_dead or not is_instance_valid(target):
		return false
	if target == self:
		return false
	if target.has_method("is_dead") and target.is_dead():
		return false
	if target.get("team") == team:
		return false
	return global_position.distance_to(target.global_position) <= get_engage_distance_to(target)

func is_dead() -> bool:
	return _is_dead

func is_engaged() -> bool:
	return get_combat_target() != null

func get_display_name() -> String:
	return display_name

func set_dead(value: bool) -> void:
	if _is_dead == value:
		return
	_is_dead = value
	if _is_dead:
		_pending_attack_target = null
		_attack_damage_applied = true
		if _hurt_tween != null:
			_hurt_tween.kill()
			_hurt_tween = null
		modulate = _get_team_color().lerp(Color.WHITE, 0.25 if is_selected else 0.0)
		_combat_target = null
		_manual_move_override = false
		stop_moving()
		_update_formation_member_visuals()
		_emit_state_changed()
		_set_animation_state(AnimationState.DEAD)
		return
	_update_formation_member_visuals()
	_emit_state_changed()
	_set_animation_state(AnimationState.IDLE)

func _update_visuals() -> void:
	scale = Vector2.ONE * (1.08 if is_selected else 1.0)
	modulate = _get_team_color().lerp(Color.WHITE, 0.25 if is_selected else 0.0)
	_update_formation_member_visuals()

func _update_animation() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if _is_dead:
		_set_animation_state(AnimationState.DEAD)
	elif _animation_state == AnimationState.ATTACK or _animation_state == AnimationState.HURT:
		pass
	elif velocity.length_squared() > 1.0:
		_set_animation_state(AnimationState.WALK)
	else:
		_set_animation_state(AnimationState.IDLE)

	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0
		_update_formation_member_visuals()

func _set_animation_state(next_state: int) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if _animation_state == next_state and sprite.is_playing():
		return

	_animation_state = next_state

	match _animation_state:
		AnimationState.IDLE:
			_play_animation(&"idle")
		AnimationState.WALK:
			_play_animation(&"walk", &"idle")
		AnimationState.ATTACK:
			if _has_animation(&"attack"):
				sprite.play(&"attack")
			else:
				_animation_state = AnimationState.IDLE
				_play_animation(&"idle")
		AnimationState.HURT:
			_play_animation(&"hurt", &"idle")
		AnimationState.DEAD:
			if _has_animation(&"dead"):
				sprite.play(&"dead")
			else:
				sprite.stop()
	_update_formation_member_visuals()

func _play_animation(name: StringName, fallback: StringName = &"") -> void:
	if _has_animation(name):
		sprite.play(name)
		return
	if fallback != &"" and _has_animation(fallback):
		sprite.play(fallback)
		return
	sprite.stop()

func _has_animation(name: StringName) -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(name)

func _apply_pending_attack_damage() -> void:
	if _attack_damage_applied:
		return
	_attack_damage_applied = true
	if not is_instance_valid(_pending_attack_target):
		_pending_attack_target = null
		return
	if _pending_attack_target.has_method("is_dead") and _pending_attack_target.is_dead():
		_pending_attack_target = null
		return
	if _pending_attack_target.get("team") == team:
		_pending_attack_target = null
		return
	_pending_attack_target.take_damage(attack_damage)
	_pending_attack_target = null

func _play_hurt_feedback() -> void:
	var base_modulate := _get_team_color().lerp(Color.WHITE, 0.25 if is_selected else 0.0)
	if _hurt_tween != null:
		_hurt_tween.kill()
	modulate = Color.WHITE
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(self, "modulate", base_modulate, HURT_FLASH_DURATION)
	_hurt_tween.finished.connect(func() -> void:
		_hurt_tween = null
	)
	if _animation_state == AnimationState.ATTACK:
		return
	if _has_animation(&"hurt"):
		_animation_state = AnimationState.HURT
		sprite.play(&"hurt")
		_update_formation_member_visuals()

func _has_valid_combat_target() -> bool:
	if not is_instance_valid(_combat_target):
		_combat_target = null
		return false
	if _combat_target == self:
		_combat_target = null
		return false
	if _combat_target.has_method("is_dead") and _combat_target.is_dead():
		_combat_target = null
		return false
	if _combat_target.get("team") == team:
		_combat_target = null
		return false
	return true

func _read_melee_range() -> float:
	if attack_range_shape != null and attack_range_shape.shape is CircleShape2D:
		return (attack_range_shape.shape as CircleShape2D).radius
	return selection_radius

func _update_collision_shapes() -> void:
	selection_radius = maxf(selection_radius, _get_formation_visual_radius())
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = maxf(10.0, selection_radius * 0.55)
	if selection_shape != null and selection_shape.shape is CircleShape2D:
		(selection_shape.shape as CircleShape2D).radius = selection_radius
	if attack_range_shape != null and attack_range_shape.shape is CircleShape2D:
		(attack_range_shape.shape as CircleShape2D).radius = maxf(selection_radius + 8.0, selection_radius * 1.15)

func _draw_status_bar(position: Vector2, width: float, height: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(position, Vector2(width, height)), Color(0.05, 0.05, 0.05, 0.8), true)
	draw_rect(Rect2(position, Vector2(width * clampf(ratio, 0.0, 1.0), height)), color, true)

func _get_strength_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)

func _get_morale_ratio() -> float:
	if max_morale <= 0.0:
		return 0.0
	return current_morale / max_morale

func _emit_state_changed() -> void:
	state_changed.emit()

func _on_sprite_frame_changed() -> void:
	_update_formation_member_visuals()
	if _animation_state == AnimationState.ATTACK and sprite.animation == &"attack" and sprite.frame >= attack_damage_frame:
		_apply_pending_attack_damage()

func _on_sprite_animation_finished() -> void:
	if _animation_state == AnimationState.ATTACK and not _is_dead:
		_apply_pending_attack_damage()
		_set_animation_state(AnimationState.IDLE)
	elif _animation_state == AnimationState.HURT and not _is_dead:
		_update_animation()
	elif _animation_state == AnimationState.DEAD:
		sprite.stop()
	_update_formation_member_visuals()

func _get_team_color() -> Color:
	match team:
		"player":
			return Color(0.45, 0.75, 1.0)
		"enemy":
			return Color(1.0, 0.45, 0.45)
		_:
			return Color(0.75, 0.75, 0.75)

func _ensure_formation_members_root() -> void:
	if _formation_members_root != null:
		return
	_formation_members_root = Node2D.new()
	_formation_members_root.name = "FormationMembers"
	add_child(_formation_members_root)
	move_child(_formation_members_root, get_child_count() - 1)

func _refresh_formation_layout() -> void:
	_ensure_formation_members_root()
	formation_size = maxi(1, formation_size)
	formation_files = maxi(1, formation_files)
	formation_ranks = maxi(1, formation_ranks)
	_formation_member_positions = _build_formation_member_positions()
	_sync_formation_member_nodes()
	_update_formation_member_visuals()

func _build_formation_member_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var files := maxi(1, formation_files)
	var ranks := maxi(1, formation_ranks)
	var columns := mini(files, formation_size)
	var rows := mini(ranks, int(ceil(float(formation_size) / float(columns))))
	for row in range(rows):
		for column in range(columns):
			if positions.size() >= formation_size:
				break
			var x := (float(column) - float(columns - 1) * 0.5) * member_spacing.x
			var y := (float(row) - float(rows - 1) * 0.5) * member_spacing.y
			positions.append(Vector2(x, y))
	return positions

func _sync_formation_member_nodes() -> void:
	while _formation_member_sprites.size() < _formation_member_positions.size():
		var member_sprite := Sprite2D.new()
		member_sprite.centered = true
		member_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_formation_members_root.add_child(member_sprite)
		_formation_member_sprites.append(member_sprite)
	while _formation_member_sprites.size() > _formation_member_positions.size():
		var sprite_to_remove: Sprite2D = _formation_member_sprites.pop_back()
		sprite_to_remove.queue_free()
	for index in range(_formation_member_sprites.size()):
		_formation_member_sprites[index].position = _formation_member_positions[index]

func _update_formation_member_visuals() -> void:
	if sprite == null or _formation_members_root == null:
		return
	var frame_texture := _get_current_frame_texture()
	var visible_members := _get_visible_member_count()
	var member_scale := Vector2.ONE * FORMATION_MEMBER_SCALE * maxf(0.8, size)
	for index in range(_formation_member_sprites.size()):
		var member_sprite := _formation_member_sprites[index]
		var is_visible := index < visible_members and frame_texture != null and not _is_dead
		member_sprite.visible = is_visible
		if not is_visible:
			continue
		member_sprite.texture = frame_texture
		member_sprite.flip_h = sprite.flip_h
		member_sprite.scale = member_scale
		member_sprite.modulate = FORMATION_MEMBER_TINT

func _get_current_frame_texture() -> Texture2D:
	if sprite == null or sprite.sprite_frames == null:
		return null
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return null
	return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)

func _get_visible_member_count() -> int:
	if formation_size <= 0:
		return 0
	var ratio := _get_strength_ratio()
	if ratio <= 0.0:
		return 0
	return clampi(int(ceil(float(formation_size) * ratio)), MIN_VISIBLE_FORMATION_MEMBERS, formation_size)

func _get_formation_visual_radius() -> float:
	if _formation_member_positions.is_empty():
		return selection_radius
	var max_distance := 0.0
	for position in _formation_member_positions:
		max_distance = maxf(max_distance, position.length())
	return maxf(selection_radius, max_distance + maxf(member_spacing.x, member_spacing.y) * 0.75)

func _read_member_spacing(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return member_spacing
