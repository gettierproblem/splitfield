class_name EyeballGD
extends BallBaseGD

@export var tracking_strength: float = 2.0


func _ready() -> void:
	ball_color = Color(1.0, 0.2, 0.2)
	speed = 180.0
	score_value = 200
	super._ready()


func _draw() -> void:
	# White eyeball body
	draw_circle(Vector2.ZERO, radius, Color.WHITE)
	# Iris (red)
	var iris_offset = direction.normalized() * radius * 0.3
	draw_circle(iris_offset, radius * 0.5, ball_color)
	# Pupil
	draw_circle(iris_offset, radius * 0.25, Color.BLACK)
	# Outline
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.LIGHT_GRAY, 1.5)


func move(delta: float) -> void:
	# Steer toward cursor
	var mouse_pos = get_global_mouse_position()
	var to_mouse = (mouse_pos - global_position).normalized()
	direction = direction.lerp(to_mouse, tracking_strength * delta).normalized()
	queue_redraw()  # Update iris direction
	super.move(delta)
