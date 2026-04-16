extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var walkable_ground: Polygon2D = get_node("../MapRoot/WalkableGround")

func _ready() -> void:
	camera.make_current()
	call_deferred("_frame_battlefield")

func _frame_battlefield() -> void:
	var rect: Rect2 = _get_global_walkable_rect()
	var viewport_size: Vector2 = get_viewport_rect().size
	if rect.size == Vector2.ZERO or viewport_size == Vector2.ZERO:
		return

	global_position = rect.get_center()

	var zoom_x: float = rect.size.x / viewport_size.x
	var zoom_y: float = rect.size.y / viewport_size.y
	camera.zoom = Vector2.ONE * maxf(zoom_x, zoom_y)

func _get_global_walkable_rect() -> Rect2:
	if walkable_ground == null or walkable_ground.polygon.is_empty():
		return Rect2()

	var local_rect := _get_polygon_rect(walkable_ground.polygon)
	var top_left := walkable_ground.to_global(local_rect.position)
	var bottom_right := walkable_ground.to_global(local_rect.end)
	return Rect2(top_left, bottom_right - top_left).abs()

func _get_polygon_rect(points: PackedVector2Array) -> Rect2:
	var min_point: Vector2 = points[0]
	var max_point: Vector2 = points[0]

	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)

	return Rect2(min_point, max_point - min_point)
