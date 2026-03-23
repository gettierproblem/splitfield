class_name OrangeBallGD
extends BallBaseGD


func _ready() -> void:
	ball_color = Color(1.0, 0.6, 0.0)
	speed = 200.0
	score_value = 150
	super._ready()


func _draw() -> void:
	# Flame corona — flickering flame licks around the perimeter
	var t = float(Time.get_ticks_msec()) / 200.0
	for i in range(8):
		var angle = i * TAU / 8.0 + sin(t + i) * 0.3
		var flame_len = radius * (0.4 + sin(t * 2.0 + i * 1.7) * 0.2)
		var tip = Vector2(cos(angle), sin(angle)) * (radius + flame_len)
		var base_l = Vector2(cos(angle - 0.25), sin(angle - 0.25)) * radius * 0.9
		var base_r = Vector2(cos(angle + 0.25), sin(angle + 0.25)) * radius * 0.9
		var flame_color = Color(1.0, 0.3 + sin(t + i) * 0.2, 0.0, 0.5)
		draw_polygon(PackedVector2Array([base_l, tip, base_r]), PackedColorArray([flame_color, flame_color, flame_color]))

	super._draw()

	# Bright yellow-white center glow
	draw_circle(Vector2.ZERO, radius * 0.35, Color(1.0, 0.95, 0.5, 0.4))
	draw_circle(Vector2.ZERO, radius * 0.15, Color(1.0, 1.0, 0.8, 0.5))
	queue_redraw()  # Animate flames


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_active or field == null:
		return

	# Absorb momentum from nearby balls
	var balls_container = field.get_balls_container()
	if balls_container == null:
		return

	for child in balls_container.get_children():
		if child is BallBaseGD and child != self and not child is NukeBallGD and is_instance_valid(child):
			var other: BallBaseGD = child
			var dist = global_position.distance_to(other.global_position)
			if dist < radius + other.radius + 4.0:
				# Absorb: slow the other ball, speed up self
				other.speed *= 0.8
				speed = minf(speed * 1.1, 200.0)
