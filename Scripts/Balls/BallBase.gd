class_name BallBaseGD
extends CharacterBody2D

@export var speed: float = 240.0
@export var radius: float = 10.0
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
	DemoRecorder.seed_rng(rng)
	var angle = rng.randf_range(0, TAU)
	direction = Vector2(cos(angle), sin(angle)).normalized()

	# Create visual
	create_visual()


func create_visual() -> void:
	# Draw a circle as placeholder
	queue_redraw()


func _draw() -> void:
	# Shadow
	draw_circle(Vector2(1.5, 1.5), radius + 1.0, Color(0, 0, 0, 0.4))

	# Base fill
	draw_circle(Vector2.ZERO, radius, ball_color)

	# Inner highlight for 3D look
	draw_circle(Vector2(-radius * 0.2, -radius * 0.2), radius * 0.6, ball_color.lightened(0.2))

	# Specular highlight
	draw_circle(Vector2(-radius * 0.28, -radius * 0.3), radius * 0.2, Color(1, 1, 1, 0.5))

	# Outline
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, ball_color.darkened(0.4), 1.5)


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
			direction.x = -direction.x
			if not _on_hit_growing_beam():
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
			if not _on_hit_growing_beam():
				return
		else:
			pos.y = next_y

		# Also check the cell the ball center is on
		var center_cell = field.world_to_grid(pos)
		if field.is_growing(center_cell):
			if not _on_hit_growing_beam():
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


## Called when this ball hits a growing beam. Return true to keep moving, false to stop.
## Default: destroy beam and cost a life.
func _on_hit_growing_beam() -> bool:
	field.on_beam_destroyed()
	GameManager.on_life_lost()
	return false


func on_hit_by_nuke() -> void:
	is_active = false
	ScoreManager.add_regular_score(500)  # FAQ: 500 per nuked ball
	GameManager.record_kill(get_type_name())
	queue_free()


func destroy() -> void:
	is_active = false
	GameManager.record_kill(get_type_name())
	queue_free()


func get_type_name() -> String:
	return get_script().get_global_name()
