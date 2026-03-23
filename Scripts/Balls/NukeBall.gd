class_name NukeBallGD
extends BallBaseGD

## Nuke ball bounces with gravity. When trapped in a small area,
## detonates and destroys all balls in the same region.
## Other balls bounce off it normally (handled by BallBase).

@export var gravity_strength: float = 80.0
const DETONATION_THRESHOLD: int = 800  # Region size in cells to trigger detonation
var _near_detonation: bool = false
var _redraw_timer: float = 0.0

func _ready() -> void:
	ball_color = Color(0.85, 0.15, 0.15)
	speed = 160.0
	score_value = 300
	radius = 10.0
	super._ready()


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
	# Apply gravity - nuke ball bounces like it has weight
	direction.y += gravity_strength * delta / speed
	direction = direction.normalized()
	super.move(delta)


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

	# Destroy all other balls in the same region
	for ball in balls_in_region:
		if ball != self and is_instance_valid(ball):
			ScoreManager.add_regular_score(500)
			GameManager.record_kill(ball.get_type_name())
			ball.queue_free()

	# Check if Bosco is nearby
	for child in field.get_children():
		if child is BoscoShark and is_instance_valid(child) and child.is_alive:
			var dist = global_position.distance_to(child.global_position)
			if dist < 60.0:
				child.trigger_death("nuke")

	# Destroy self
	GameManager.record_kill("NukeBall")
	queue_free()
