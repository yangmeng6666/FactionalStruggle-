extends CharacterBody2D

@export_enum("neutral", "player", "enemy") var team: String = "neutral"
@export var move_speed: float = 120.0
@export var max_hp: int = 100
@export var selection_radius: float = 16.0

const ATTACK_INTERVAL := 0.75
const ATTACK_DAMAGE := 25

enum AnimationState {
	IDLE,
	WALK,
	ATTACK,
	DEAD,
}

var is_selected: bool = false
var current_hp: int = 0
var _animation_state: int = AnimationState.IDLE
var _is_dead: bool = false
var _attack_cooldown: float = 0.0
var _combat_target = null
var _melee_range: float = 0.0
var _manual_move_override: bool = false

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_range_shape: CollisionShape2D = $AttackRange/CollisionShape2D

func _ready() -> void:
	current_hp = max_hp
	_melee_range = _read_melee_range()
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	navigation_agent.avoidance_enabled = false
	navigation_agent.target_position = global_position
	if not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)
	_update_visuals()
	_update_animation()
	queue_redraw()

func _draw() -> void:
	if sprite.sprite_frames != null:
		return

	draw_circle(Vector2.ZERO, 8.0, _get_team_color())
	var ring_color: Color = Color.WHITE if is_selected else Color(0.0, 0.0, 0.0, 0.35)
	var ring_width: float = 3.0 if is_selected else 1.0
	draw_arc(Vector2.ZERO, selection_radius, 0.0, TAU, 32, ring_color, ring_width)

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

	if not _manual_move_override and _has_valid_combat_target():
		var target_position: Vector2 = _combat_target.global_position
		if global_position.distance_to(target_position) <= _melee_range:
			stop_moving()
			if _attack_cooldown <= 0.0:
				play_attack_animation()
				_attack_cooldown = ATTACK_INTERVAL
				_combat_target.take_damage(ATTACK_DAMAGE)
			return
		navigation_agent.target_position = target_position

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
	queue_redraw()

func set_move_target(target: Vector2) -> void:
	if _is_dead:
		return
	_manual_move_override = true
	_combat_target = null
	navigation_agent.target_position = target

func stop_moving() -> void:
	navigation_agent.target_position = global_position
	velocity = Vector2.ZERO
	_update_animation()

func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	_update_visuals()
	queue_redraw()

func contains_world_point(world_point: Vector2) -> bool:
	return global_position.distance_to(world_point) <= selection_radius

func play_attack_animation() -> void:
	if _is_dead:
		return
	_set_animation_state(AnimationState.ATTACK)

func take_damage(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
	current_hp = maxi(0, current_hp - amount)
	if current_hp > 0:
		return
	set_dead(true)
	queue_free()

func set_combat_target(target) -> void:
	if _is_dead:
		return
	if target == self:
		target = null
	if target != null and target.get("team") == team:
		target = null
	_combat_target = target

func get_combat_target():
	if _has_valid_combat_target():
		return _combat_target
	return null

func can_auto_engage() -> bool:
	return not _is_dead and not _manual_move_override

func is_dead() -> bool:
	return _is_dead

func set_dead(value: bool) -> void:
	if _is_dead == value:
		return
	_is_dead = value
	if _is_dead:
		_combat_target = null
		_manual_move_override = false
		stop_moving()
		_set_animation_state(AnimationState.DEAD)
		return
	_set_animation_state(AnimationState.IDLE)

func _update_visuals() -> void:
	scale = Vector2.ONE * (1.15 if is_selected else 1.0)
	modulate = _get_team_color().lerp(Color.WHITE, 0.25 if is_selected else 0.0)

func _update_animation() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if _is_dead:
		_set_animation_state(AnimationState.DEAD)
	elif _animation_state == AnimationState.ATTACK:
		pass
	elif velocity.length_squared() > 1.0:
		_set_animation_state(AnimationState.WALK)
	else:
		_set_animation_state(AnimationState.IDLE)

	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0

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
		AnimationState.DEAD:
			if _has_animation(&"dead"):
				sprite.play(&"dead")
			else:
				sprite.stop()

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

func _on_sprite_animation_finished() -> void:
	if _animation_state == AnimationState.ATTACK and not _is_dead:
		_set_animation_state(AnimationState.IDLE)
	elif _animation_state == AnimationState.DEAD:
		sprite.stop()

func _get_team_color() -> Color:
	match team:
		"player":
			return Color(0.45, 0.75, 1.0)
		"enemy":
			return Color(1.0, 0.45, 0.45)
		_:
			return Color(0.75, 0.75, 0.75)
