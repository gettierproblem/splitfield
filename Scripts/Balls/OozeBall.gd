class_name OozeBallGD
extends BallBaseGD

## Ooze balls are ticking time bombs. If not trapped quickly in a small area,
## they split into Pawn balls. Occasionally spawns a Nuke instead.

var _fuse_timer: float = 0.0
var _fuse_duration: float = 20.0  # seconds before splitting
var _detonated: bool = false


func _ready() -> void:
	ball_color = Color(0.4, 0.8, 0.1)  # Sickly green
	speed = 180.0
	radius = 7.0
	score_value = 200
	super._ready()

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	_fuse_duration = rng.randf_range(15.0, 25.0)


func _draw() -> void:
	# Oozing, bubbly look
	var pulse = sin(float(Time.get_ticks_msec()) / 300.0) * 0.15
	var ooze_color = ball_color.lightened(pulse)

	draw_circle(Vector2(1.5, 1.5), radius + 1.0, Color(0, 0, 0, 0.5))
	draw_circle(Vector2.ZERO, radius, ooze_color)

	# Bubbles
	var t = float(Time.get_ticks_msec()) / 1000.0
	for i in range(3):
		var angle = t * 2.0 + i * TAU / 3.0
		var r = radius * 0.4
		var bubble_pos = Vector2(cos(angle) * r, sin(angle) * r)
		draw_circle(bubble_pos, 1.5, Color(0.6, 1.0, 0.3, 0.5))

	# Fuse indicator - gets redder as time runs out
	var fuse_ratio = clampf(_fuse_timer / _fuse_duration, 0.0, 1.0)
	var fuse_color = Color(1.0, fuse_ratio, 0.0, 0.6)
	draw_arc(Vector2.ZERO, radius + 2.0, 0, TAU * (1.0 - fuse_ratio), 16, fuse_color, 2.0)

	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, ball_color.darkened(0.3), 1.5)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_active or field == null or _detonated:
		return

	_fuse_timer += delta
	queue_redraw()

	# Check if trapped in a small area - disarm
	if _fuse_timer > 2.0:  # Give a brief grace period
		var grid_pos = field.world_to_grid(global_position)
		var empty_count = 0
		for dx in range(-5, 6):
			for dy in range(-5, 6):
				var check = Vector2i(grid_pos.x + dx, grid_pos.y + dy)
				if field.in_bounds(check) and field.get_cell(check) == PlayingField.CellState.EMPTY:
					empty_count += 1

		if empty_count < 30:
			# Disarmed by trapping - just destroy quietly
			ScoreManager.add_regular_score(score_value)
			AudioManager.play_sfx("nuke_explosion")
			queue_free()
			return

	# Timer expired - split!
	if _fuse_timer >= _fuse_duration:
		_split()


func _split() -> void:
	_detonated = true
	var balls_container = field.get_balls_container()

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Split into 2-3 pawn balls, with small chance of a nuke
	var count = rng.randi_range(2, 3)
	for i in range(count):
		var new_ball: BallBaseGD
		if rng.randf() < 0.1:  # 10% chance of nuke
			new_ball = NukeBallGD.new()
		else:
			new_ball = PawnBallGD.new()

		# Spawn near current position with random direction
		new_ball.global_position = global_position + Vector2(
			rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
		balls_container.add_child(new_ball)

	AudioManager.play_sfx("glass_shatter")
	queue_free()
