class_name EyeballGD
extends BallBaseGD

@export var tracking_strength: float = 2.0


func _ready() -> void:
	ball_color = Color(0.2, 0.45, 0.6)  # Blue-gray iris
	speed = 180.0
	score_value = 200
	super._ready()


func _draw() -> void:
	# Shadow
	draw_circle(Vector2(1.5, 1.5), radius + 1.0, Color(0, 0, 0, 0.4))

	# Off-white eyeball body with slight warm tint
	var body_color = Color(0.92, 0.9, 0.85)
	draw_circle(Vector2.ZERO, radius, body_color)

	# Red veins radiating from center
	for i in range(6):
		var angle = i * TAU / 6.0 + 0.3
		var vein_start = Vector2(cos(angle), sin(angle)) * radius * 0.3
		var vein_end = Vector2(cos(angle), sin(angle)) * radius * 0.85
		draw_line(vein_start, vein_end, Color(0.8, 0.1, 0.1, 0.5), 0.8)
		# Small branch
		var mid = vein_start.lerp(vein_end, 0.6)
		var branch_angle = angle + 0.4
		var branch_end = mid + Vector2(cos(branch_angle), sin(branch_angle)) * radius * 0.2
		draw_line(mid, branch_end, Color(0.7, 0.1, 0.1, 0.35), 0.6)

	# Iris (dark green, tracking direction)
	var iris_offset = direction.normalized() * radius * 0.3
	draw_circle(iris_offset, radius * 0.45, ball_color)
	# Iris inner ring
	draw_arc(iris_offset, radius * 0.35, 0, TAU, 16, ball_color.lightened(0.3), 1.0)

	# Pupil
	draw_circle(iris_offset, radius * 0.2, Color(0.02, 0.02, 0.02))

	# Moist reflective highlight
	draw_arc(Vector2(-radius * 0.15, -radius * 0.2), radius * 0.55,
		PI * 0.8, PI * 1.4, 8, Color(1, 1, 1, 0.3), 1.5)
	draw_circle(Vector2(-radius * 0.25, -radius * 0.3), radius * 0.12, Color(1, 1, 1, 0.6))

	# Outline
	draw_arc(Vector2.ZERO, radius, 0, TAU, 36, Color(0.6, 0.55, 0.5, 0.8), 1.8)


func move(delta: float) -> void:
	# Steer toward cursor
	var mouse_pos = get_global_mouse_position()
	var to_mouse = (mouse_pos - global_position).normalized()
	direction = direction.lerp(to_mouse, tracking_strength * delta).normalized()
	queue_redraw()  # Update iris direction
	super.move(delta)
