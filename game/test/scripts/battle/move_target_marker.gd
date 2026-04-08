extends Node2D

const OUTER_RADIUS := 18.0
const INNER_RADIUS := 7.0
const LINE_LENGTH := 10.0
const OUTER_WIDTH := 2.0
const INNER_WIDTH := 1.5
const LIFETIME := 0.45

func _ready() -> void:
	z_index = 10
	modulate = Color(0.55, 0.85, 1.0, 0.95)
	scale = Vector2.ONE * 0.65
	queue_redraw()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.15, LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)

func _draw() -> void:
	draw_arc(Vector2.ZERO, OUTER_RADIUS, 0.0, TAU, 48, Color.WHITE, OUTER_WIDTH)
	draw_arc(Vector2.ZERO, INNER_RADIUS, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.45), INNER_WIDTH)
	draw_line(Vector2.LEFT * LINE_LENGTH, Vector2.RIGHT * LINE_LENGTH, Color.WHITE, 2.0)
	draw_line(Vector2.UP * LINE_LENGTH, Vector2.DOWN * LINE_LENGTH, Color.WHITE, 2.0)
