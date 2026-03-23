class_name NukeBallGD
extends BallBaseGD

## Nuke ball bounces with gravity. When trapped in a small area,
## detonates and destroys all balls in the same region.
## Other balls bounce off it normally (handled by BallBase).

const GRAVITY: float = 400.0  # pixels/s^2 — ~9.8 m/s^2 game equivalent
const DETONATION_THRESHOLD: int = 800
var _near_detonation: bool = false
var _redraw_timer: float = 0.0
var _velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	ball_color = Color(0.85, 0.15, 0.15)
	speed = 160.0
	score_value = 300
	radius = 10.0
	super._ready()
	# Initialize velocity from direction and speed
	_velocity = direction * speed


func _physics_process(delta: float) -> void:
	_redraw_timer -= delta
	if _redraw_timer <= 0:
		_redraw_timer = 0.05  # 20 FPS for orbit animation
		queue_redraw()
	super._physics_process(delta)


func _draw() -> void:
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var orbit_color = Color(0.2, 1.0, 0.3, 0.9)
	var orbit_r: float = radius * 1.3
	var segs: int = 16

	# Two rings with different rotation speeds on each axis
	# Ring 1
	var rx1: float = t * 4.0
	var ry1: float = t * 1.5
	# Ring 2
	var rx2: float = t * 1.2 + PI * 0.3
	var ry2: float = t * 3.5

	# Shadow
	draw_circle(Vector2(2.0, 2.0), radius + 1.5, Color(0, 0, 0, 0.45))

	# Back halves (behind ball)
	_draw_orbit(orbit_r, rx1, ry1, segs, orbit_color, false)
	_draw_orbit(orbit_r, rx2, ry2, segs, orbit_color, false)

	# Red ball
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_circle(Vector2.ZERO, radius * 0.8, ball_color.lightened(0.12))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 36, ball_color.darkened(0.4), 1.5)
	draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.3, Color(1, 1, 1, 0.15))

	# Front halves (in front of ball)
	_draw_orbit(orbit_r, rx1, ry1, segs, orbit_color, true)
	_draw_orbit(orbit_r, rx2, ry2, segs, orbit_color, true)

	# Pulsing red glow when approaching detonation (set by check_detonation)
	if _near_detonation:
		var pulse = absf(sin(t * 10.0))
		draw_circle(Vector2.ZERO, radius + 3.0, Color(1.0, 0.1, 0.1, pulse * 0.3))

	queue_redraw()


func _draw_orbit(r: float, rot_x: float, rot_y: float, segs: int, color: Color, front: bool) -> void:
	# Generate a circle in 3D, rotate around X then Y, project to 2D
	# Use z-depth to determine front/back
	for i in range(segs):
		var a0: float = i * TAU / segs
		var a1: float = (i + 1) * TAU / segs
		var mid_a: float = (a0 + a1) * 0.5

		var z_mid: float = _orbit_z(mid_a, r, rot_x, rot_y)
		if (z_mid > 0) != front:
			continue

		var p0: Vector2 = _orbit_xy(a0, r, rot_x, rot_y)
		var p1: Vector2 = _orbit_xy(a1, r, rot_x, rot_y)
		draw_line(p0, p1, color, 1.8)


func _orbit_xy(a: float, r: float, rot_x: float, rot_y: float) -> Vector2:
	# Start with circle in XY plane: (cos(a)*r, sin(a)*r, 0)
	var x: float = cos(a) * r
	var y: float = sin(a) * r
	var z: float = 0.0

	# Rotate around X axis
	var cy: float = y * cos(rot_x) - z * sin(rot_x)
	var cz: float = y * sin(rot_x) + z * cos(rot_x)
	y = cy
	z = cz

	# Rotate around Y axis
	var cx: float = x * cos(rot_y) + z * sin(rot_y)
	cz = -x * sin(rot_y) + z * cos(rot_y)
	x = cx

	return Vector2(x, y)


func _orbit_z(a: float, r: float, rot_x: float, rot_y: float) -> float:
	var x: float = cos(a) * r
	var y: float = sin(a) * r
	var z: float = 0.0

	var cz: float = y * sin(rot_x) + z * cos(rot_x)
	z = cz

	cz = -x * sin(rot_y) + z * cos(rot_y)
	return cz


func move(delta: float) -> void:
	if field == null:
		return

	# Apply gravity to Y velocity
	_velocity.y += GRAVITY * delta

	# Sub-step movement to prevent tunneling
	var total_dist = _velocity.length() * delta
	var step_size = PlayingField.CELL_SIZE * 0.5
	var steps = maxi(1, ceili(total_dist / step_size))
	var step_delta = delta / steps

	var bounced: bool = false

	for step in steps:
		var movement = _velocity * step_delta
		var pos = global_position

		# Check X
		var next_x = pos.x + movement.x
		var check_x = field.world_to_grid(Vector2(next_x + radius * sign(_velocity.x), pos.y))
		if should_bounce_on_cell(check_x):
			_velocity.x = -_velocity.x
			bounced = true
		elif field.is_growing(check_x):
			_velocity.x = -_velocity.x
			field.on_beam_destroyed()
			GameManager.on_life_lost()
			return
		else:
			pos.x = next_x

		# Check Y
		var next_y = pos.y + movement.y
		var check_y = field.world_to_grid(Vector2(pos.x, next_y + radius * sign(_velocity.y)))
		if should_bounce_on_cell(check_y):
			_velocity.y = -_velocity.y
			bounced = true
		elif field.is_growing(check_y):
			_velocity.y = -_velocity.y
			field.on_beam_destroyed()
			GameManager.on_life_lost()
			return
		else:
			pos.y = next_y

		# Center cell check
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
			_velocity.x = absf(_velocity.x)
			bounced = true
		if pos.x > field_max.x:
			pos.x = field_max.x
			_velocity.x = -absf(_velocity.x)
			bounced = true
		if pos.y < field_min.y:
			pos.y = field_min.y
			_velocity.y = absf(_velocity.y)
			bounced = true
		if pos.y > field_max.y:
			pos.y = field_max.y
			_velocity.y = -absf(_velocity.y)
			bounced = true

		global_position = pos

	if bounced:
		AudioManager.play_sfx("nuke_warning" if _near_detonation else "nuke_bounce")

	# Keep direction in sync for ball-ball collisions
	direction = _velocity.normalized()
	speed = _velocity.length()


## Called after a barrier is completed to check if the nuke should detonate.
func check_detonation() -> void:
	if not is_active or field == null:
		return

	var grid_pos = field.world_to_grid(global_position)
	var result = field.get_region_size(grid_pos)
	var region_size: int = result["size"]
	var balls_in_region: Array = result["balls"]

	_near_detonation = region_size > 0 and region_size <= DETONATION_THRESHOLD * 2

	if region_size > 0 and region_size <= DETONATION_THRESHOLD:
		_detonate(balls_in_region)


func _detonate(balls_in_region: Array) -> void:
	AudioManager.play_sfx("nuke_explosion")

	var death_positions: Array[Vector2] = [global_position]

	# Destroy all other balls in the same region
	for ball in balls_in_region:
		if ball != self and is_instance_valid(ball):
			death_positions.append(ball.global_position)
			ScoreManager.add_regular_score(500)
			GameManager.record_kill(ball.get_type_name())
			ball.queue_free()

	# Check if Bosco is nearby
	for child in field.get_children():
		if child is BoscoShark and is_instance_valid(child) and child.is_alive:
			var dist = global_position.distance_to(child.global_position)
			if dist < 60.0:
				child.trigger_death("nuke")

	# Spawn electricity effects at each death position
	var effect = _NukeEffect.new()
	effect.positions = death_positions
	effect.field = field
	effect.fill_pos = global_position
	field.add_child(effect)

	# Destroy self
	GameManager.record_kill("NukeBall")
	queue_free()


class _NukeEffect extends Node2D:
	var positions: Array[Vector2] = []
	var field: Node = null
	var fill_pos: Vector2
	var _timer: float = 0.5
	var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var _bolts: Array = []  # Array of bolt data for drawing

	func _ready() -> void:
		z_index = 10
		_rng.randomize()
		_generate_bolts()

	func _process(delta: float) -> void:
		_timer -= delta
		# Regenerate bolts every few frames for flickering effect
		if fmod(_timer, 0.08) < delta:
			_generate_bolts()
		queue_redraw()
		if _timer <= 0:
			# Fill the nuked region
			if field != null and is_instance_valid(field):
				field.fill_region_at(fill_pos)
			queue_free()

	func _generate_bolts() -> void:
		_bolts.clear()
		for pos in positions:
			# 3 bolts per position radiating outward
			for i in 3:
				var angle = _rng.randf_range(0, TAU)
				var bolt: Array[Vector2] = []
				var p = pos
				bolt.append(p)
				var seg_count = _rng.randi_range(3, 6)
				for s in seg_count:
					var seg_len = _rng.randf_range(6.0, 14.0)
					angle += _rng.randf_range(-0.8, 0.8)
					p = p + Vector2(cos(angle), sin(angle)) * seg_len
					bolt.append(p)
				_bolts.append(bolt)

	func _draw() -> void:
		var alpha = clampf(_timer / 0.5, 0.0, 1.0)
		# Draw glow circles at each position
		for pos in positions:
			var local = pos - global_position
			draw_circle(local, 15.0, Color(0.3, 0.5, 1.0, alpha * 0.25))

		# Draw lightning bolts
		for bolt in _bolts:
			for i in range(bolt.size() - 1):
				var p0: Vector2 = bolt[i] - global_position
				var p1: Vector2 = bolt[i + 1] - global_position
				# Glow
				draw_line(p0, p1, Color(0.4, 0.6, 1.0, alpha * 0.4), 3.0)
				# Core
				draw_line(p0, p1, Color(0.7, 0.85, 1.0, alpha * 0.9), 1.5)
