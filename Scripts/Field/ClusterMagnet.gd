class_name ClusterMagnet
extends Node2D

## A wall-mounted magnet that attracts pawn balls. Two are placed on
## opposite walls along the barrier line. They overheat and dissipate
## after a few seconds.

var pull_strength: float = 1600.0
var duration: float = 5.0

var _timer: float
var _field: PlayingField
var _pulse_phase: float


func initialize(field: PlayingField, wall_pos: Vector2) -> void:
	_field = field
	global_position = wall_pos
	_timer = duration
	z_index = 5


func _process(delta: float) -> void:
	var dt: float = delta
	_timer -= dt
	_pulse_phase += dt * 4.0

	if _timer <= 0:
		queue_free()
		return

	# Pull all balls toward this wall magnet (only if path is clear)
	if _field != null:
		var balls_container: Node2D = _field.get_balls_container()
		if balls_container != null:
			for child in balls_container.get_children():
				if child is BallBaseGD and is_instance_valid(child):
					var ball: BallBaseGD = child as BallBaseGD
					var to_ball: Vector2 = ball.global_position - global_position
					var dist: float = to_ball.length()
					var max_range: float = 400.0
					if dist < max_range and dist > 5.0:
						# Don't pull if the next cell toward the magnet is blocking
						var pull_dir: Vector2 = -to_ball.normalized()
						var next_pos: Vector2 = ball.global_position + pull_dir * PlayingField.CELL_SIZE * 2.0
						var next_cell: Vector2i = _field.world_to_grid(next_pos)
						if _field.is_blocking(next_cell):
							continue

						# Also check line of sight through grid
						if not _has_line_of_sight(ball.global_position):
							continue

						var falloff: float = 1.0 - (dist / max_range)
						ball.direction = ball.direction.lerp(pull_dir, pull_strength * falloff * dt / ball.speed).normalized()

	queue_redraw()


## Check if there's a clear path (no barriers/filled cells) between
## the magnet and a target position, using grid-based raycasting.
func _has_line_of_sight(target_pos: Vector2) -> bool:
	var start: Vector2i = _field.world_to_grid(global_position)
	var end: Vector2i = _field.world_to_grid(target_pos)

	# Bresenham-style line walk through grid cells
	var dx: int = absi(end.x - start.x)
	var dy: int = absi(end.y - start.y)
	var sx: int = 1 if start.x < end.x else -1
	var sy: int = 1 if start.y < end.y else -1
	var err: int = dx - dy

	var x: int = start.x
	var y: int = start.y
	while true:
		if x == end.x and y == end.y:
			break

		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

		var pos: Vector2i = Vector2i(x, y)
		if _field.in_bounds(pos) and _field.is_blocking(pos):
			return false
	return true


func _draw() -> void:
	var fade: float = clampf(_timer / duration, 0.0, 1.0)
	var pulse: float = sin(_pulse_phase) * 0.3 + 0.7

	# Glow around magnet
	var glow_color: Color = Color(0.8, 0.2, 0.2, 0.2 * fade * pulse)
	draw_circle(Vector2.ZERO, 20.0, glow_color)

	# Magnet U-shape
	var magnet_color: Color = Color(0.9, 0.2, 0.2, fade)
	draw_arc(Vector2.ZERO, 6.0, PI * 0.2, PI * 0.8, 12, magnet_color, 3.0)
	draw_line(Vector2(-5.0, -3.0), Vector2(-5.0, 6.0), magnet_color, 3.0)
	draw_line(Vector2(5.0, -3.0), Vector2(5.0, 6.0), magnet_color, 3.0)

	# Red/blue tips
	draw_line(Vector2(-5.0, 4.0), Vector2(-5.0, 6.0), Color(1.0, 0.3, 0.3, fade), 3.0)
	draw_line(Vector2(5.0, 4.0), Vector2(5.0, 6.0), Color(0.3, 0.3, 1.0, fade), 3.0)

	# Overheating glow as time runs out
	if fade < 0.4:
		var heat: float = 1.0 - (fade / 0.4)
		var heat_color: Color = Color(1.0, 0.5, 0.0, heat * 0.5 * pulse)
		draw_circle(Vector2.ZERO, 10.0, heat_color)
