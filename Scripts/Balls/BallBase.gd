class_name BallBaseGD
extends CharacterBody2D

@export var speed: float = 240.0
@export var radius: float = 6.0
@export var ball_color: Color = Color.WHITE
@export var score_value: int = 100

var direction: Vector2
var field: Node  # PlayingField
var is_active: bool = true


func _ready() -> void:
	# Find the PlayingField parent
	var parent = get_parent()
	while parent != null and not parent is PlayingField:
		parent = parent.get_parent()
	field = parent

	# Initialize random direction
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var angle = rng.randf_range(0, TAU)
	direction = Vector2(cos(angle), sin(angle)).normalized()

	# Create visual
	create_visual()


func create_visual() -> void:
	# Draw a circle as placeholder
	queue_redraw()


func _draw() -> void:
	# Outer shadow (slightly offset, elliptical feel)
	draw_circle(Vector2(2.0, 2.0), radius + 1.5, Color(0, 0, 0, 0.45))

	# Rim shadow — dark ring just outside the ball for depth
	draw_arc(Vector2(0.5, 0.5), radius + 0.5, 0, TAU, 36, Color(0, 0, 0, 0.35), 2.0)

	# Base fill
	draw_circle(Vector2.ZERO, radius, ball_color)

	# 6-ring gradient for richer 3D shading
	for i in range(6):
		var t = (i + 1) / 7.0
		var r = radius * (1.0 - t)
		var c = ball_color.lerp(ball_color.lightened(0.55), t * t)  # Non-linear
		c.a = 0.35
		draw_circle(Vector2(-radius * 0.12, -radius * 0.12) * t, r, c)

	# Edge darkening — subtle crescent on the lower-right
	draw_arc(Vector2(radius * 0.15, radius * 0.15), radius * 0.85, 0.3, PI + 0.3, 20,
		ball_color.darkened(0.35), radius * 0.4)

	# Soft specular glow
	var highlight_pos = Vector2(-radius * 0.28, -radius * 0.32)
	draw_circle(highlight_pos, radius * 0.35, Color(1, 1, 1, 0.35))
	# Sharp specular dot
	draw_circle(highlight_pos + Vector2(0.3, 0.3), radius * 0.14, Color(1, 1, 1, 0.85))

	# Metallic sheen arc on upper-left
	draw_arc(Vector2(-radius * 0.1, -radius * 0.1), radius * 0.7, PI * 0.8, PI * 1.4, 12,
		Color(1, 1, 1, 0.2), 1.5)

	# Outline
	draw_arc(Vector2.ZERO, radius, 0, TAU, 36, ball_color.darkened(0.45), 2.0)
	draw_arc(Vector2.ZERO, radius + 0.8, 0, TAU, 36, Color(0, 0, 0, 0.5), 1.2)


func _physics_process(delta: float) -> void:
	if not is_active or field == null:
		return
	move(delta)
	_check_ball_collisions()


## Bounce off other balls - elastic-style direction swap.
func _check_ball_collisions() -> void:
	var container = field.get_balls_container()
	if container == null:
		return

	for child in container.get_children():
		if child is BallBaseGD and child != self and is_instance_valid(child) and child.is_active:
			var other: BallBaseGD = child
			var diff = global_position - other.global_position
			var dist = diff.length()
			var min_dist = radius + other.radius

			if dist < min_dist and dist > 0.1:
				# Push apart
				var normal = diff / dist
				var overlap = min_dist - dist
				global_position += normal * (overlap * 0.5)
				other.global_position -= normal * (overlap * 0.5)

				# Reflect directions off the collision normal
				var dot1 = direction.dot(normal)
				var dot2 = other.direction.dot(normal)

				if dot1 < 0:  # Only bounce if moving toward each other
					direction -= 2.0 * dot1 * normal
				if dot2 > 0:
					other.direction -= 2.0 * dot2 * normal

				direction = direction.normalized()
				other.direction = other.direction.normalized()


func move(delta: float) -> void:
	var total_dist = speed * delta
	var step_size = PlayingField.CELL_SIZE * 0.5  # Half a cell per step to prevent tunneling
	var steps = maxi(1, ceili(total_dist / step_size))
	var step_delta = delta / steps

	for i in range(steps):
		var movement = direction * speed * step_delta
		var pos = global_position

		# Check X movement
		var next_x = pos.x + movement.x
		var check_x = field.world_to_grid(Vector2(next_x + radius * sign(direction.x), pos.y))
		if should_bounce_on_cell(check_x):
			direction.x = -direction.x
		elif field.is_growing(check_x):
			# Hit the growing beam - destroy it and bounce
			direction.x = -direction.x
			field.on_beam_destroyed()
			GameManager.on_life_lost()
			return
		else:
			pos.x = next_x

		# Check Y movement
		var next_y = pos.y + movement.y
		var check_y = field.world_to_grid(Vector2(pos.x, next_y + radius * sign(direction.y)))
		if should_bounce_on_cell(check_y):
			direction.y = -direction.y
		elif field.is_growing(check_y):
			direction.y = -direction.y
			field.on_beam_destroyed()
			GameManager.on_life_lost()
			return
		else:
			pos.y = next_y

		# Also check the cell the ball center is on
		var center_cell = field.world_to_grid(pos)
		if field.is_growing(center_cell):
			field.on_beam_destroyed()
			GameManager.on_life_lost()
			return

		# Boundary clamping
		var field_min = field.global_position + Vector2(radius, radius)
		var field_max = field.global_position + Vector2(PlayingField.FIELD_PIXEL_WIDTH - radius, PlayingField.FIELD_PIXEL_HEIGHT - radius)

		if pos.x < field_min.x:
			pos.x = field_min.x
			direction.x = absf(direction.x)
		if pos.x > field_max.x:
			pos.x = field_max.x
			direction.x = -absf(direction.x)
		if pos.y < field_min.y:
			pos.y = field_min.y
			direction.y = absf(direction.y)
		if pos.y > field_max.y:
			pos.y = field_max.y
			direction.y = -absf(direction.y)

		global_position = pos


func should_bounce_on_cell(cell: Vector2i) -> bool:
	return field.is_blocking(cell)


func on_hit_by_nuke() -> void:
	ScoreManager.add_regular_score(500)  # FAQ: 500 per nuked ball
	GameManager.record_kill(get_type_name())
	queue_free()


func destroy() -> void:
	GameManager.record_kill(get_type_name())
	queue_free()


func get_type_name() -> String:
	return get_script().get_global_name()
