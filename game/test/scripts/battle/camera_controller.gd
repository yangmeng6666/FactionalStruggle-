extends Node2D

@export var move_speed: float = 500.0
@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.6
@export var max_zoom: float = 1.8

@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	camera.make_current()

func _process(delta: float) -> void:
	var direction: Vector2 = Vector2(
		Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left"),
		Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up")
	)

	if direction.length_squared() > 0.0:
		position += direction.normalized() * move_speed * delta

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_apply_zoom(-zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		_apply_zoom(zoom_step)

func _apply_zoom(step: float) -> void:
	var next_zoom: float = clampf(camera.zoom.x + step, min_zoom, max_zoom)
	camera.zoom = Vector2.ONE * next_zoom
