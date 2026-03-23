class_name BoscoShark
extends Node2D

## Bosco the shark. Primarily patrols the playfield perimeter but
## periodically dives through the field interior.

enum BoscoState {
	PATROLLING,
	DIVING,
	GOTCHA,
	BALL_HIT,
	RAMPAGE,
	TIRED,
	KILLED
}

var _field: PlayingField
var _state: int = BoscoState.PATROLLING
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Movement
var _perimeter_position: float
var _perimeter_direction: int = 1  # +1 or -1
var _direction: Vector2  # Used during field dives
const BASE_SPEED: float = 140.0
var _speed: float = BASE_SPEED

# Perimeter dimensions
const GRID_W: int = 200
const GRID_H: int = 184
const TOTAL_PERIMETER: int = 2 * (GRID_W + GRID_H) - 4  # 764

# Dive timing
var _dive_timer: float
const MIN_DIVE_INTERVAL: float = 4.0
const MAX_DIVE_INTERVAL: float = 10.0

# State timers
var _state_timer: float
const GOTCHA_DURATION: float = 1.0
const BALL_HIT_DURATION: float = 0.5
const RAMPAGE_DURATION: float = 5.0
const TIRED_DURATION: float = 3.0
const DEATH_SPIN_DURATION: float = 2.0

# Death spin
var _rotation_angle: float

# Cigar ash trail
var _ash_trail: Array = []  # Array of {pos: Vector2, age: float}
var _ash_timer: float
const ASH_INTERVAL: float = 0.08
const ASH_LIFETIME: float = 2.0

# Scoring
var _kill_method: String = "regular"
var _was_rampage: bool = false

# Collision radius
const FIN_RADIUS: float = 10.0

var is_alive: bool:
	get:
		return _state != BoscoState.KILLED

var in_rampage: bool:
	get:
		return _state == BoscoState.RAMPAGE


func initialize(field: PlayingField, start_pos: float) -> void:
	_field = field
	_rng.randomize()
	_perimeter_position = start_pos
	_state = BoscoState.PATROLLING
	_speed = BASE_SPEED
	_dive_timer = _rng.randf_range(MIN_DIVE_INTERVAL, MAX_DIVE_INTERVAL)
	global_position = _perimeter_to_world(_perimeter_position)
	z_index = 4


func _process(delta: float) -> void:
	match _state:
		BoscoState.PATROLLING:
			_move_along_perimeter(delta)
			_check_collisions()
			_dive_timer -= delta
			if _dive_timer <= 0:
				_start_dive()

		BoscoState.DIVING:
			_move_through_field(delta)
			_check_collisions()

		BoscoState.GOTCHA:
			_state_timer -= delta
			if _state_timer <= 0:
				_set_state(BoscoState.PATROLLING)

		BoscoState.BALL_HIT:
			_state_timer -= delta
			if _state_timer <= 0:
				_set_state(BoscoState.RAMPAGE)

		BoscoState.RAMPAGE:
			_move_through_field(delta)
			_check_collisions()
			_state_timer -= delta
			if _state_timer <= 0:
				_set_state(BoscoState.TIRED)

		BoscoState.TIRED:
			_move_along_perimeter(delta)
			_state_timer -= delta
			if _state_timer <= 0:
				_set_state(BoscoState.PATROLLING)

		BoscoState.KILLED:
			_state_timer -= delta
			_rotation_angle += delta * 15.0
			if _state_timer <= 0:
				var base_score: int
				match _kill_method:
					"glass":
						base_score = 2500
					"nuke":
						base_score = 5000
					_:
						base_score = 800
				var kill_multiplier: int = 10 if _was_rampage else 1
				ScoreManager.add_bonus_score(base_score * kill_multiplier)
				GameManager.record_kill("Bosco")
				AudioManager.play_sfx("bosco_killed")
				queue_free()
				return

	_update_ash_trail(delta)
	queue_redraw()


func _set_state(new_state: int) -> void:
	_state = new_state
	match new_state:
		BoscoState.PATROLLING:
			_speed = BASE_SPEED
			_dive_timer = _rng.randf_range(MIN_DIVE_INTERVAL, MAX_DIVE_INTERVAL)
			_perimeter_position = _world_to_perimeter(global_position)
			AudioManager.play_sfx("bosco_patrol")
		BoscoState.DIVING:
			_speed = BASE_SPEED
		BoscoState.GOTCHA:
			_state_timer = GOTCHA_DURATION
			_speed = 0
			AudioManager.play_sfx("bosco_gotcha")
		BoscoState.BALL_HIT:
			_state_timer = BALL_HIT_DURATION
			_speed = 0
			AudioManager.play_sfx("bosco_ball_hit")
		BoscoState.RAMPAGE:
			_state_timer = RAMPAGE_DURATION
			_speed = BASE_SPEED * 2.0
			var angle: float = _rng.randf_range(0, TAU)
			_direction = Vector2(cos(angle), sin(angle))
			AudioManager.play_sfx("bosco_rampage")
		BoscoState.TIRED:
			_state_timer = TIRED_DURATION
			_speed = BASE_SPEED * 0.5
			_perimeter_position = _world_to_perimeter(global_position)
			AudioManager.play_sfx("bosco_tired")
		BoscoState.KILLED:
			_state_timer = DEATH_SPIN_DURATION
			_speed = 0


func _start_dive() -> void:
	var field_center: Vector2 = _field.global_position + Vector2(
		PlayingField.FIELD_PIXEL_WIDTH * 0.5, PlayingField.FIELD_PIXEL_HEIGHT * 0.5)
	var to_center: Vector2 = (field_center - global_position).normalized()

	var jitter: float = _rng.randf_range(-0.8, 0.8)
	_direction = to_center.rotated(jitter).normalized()
	_state = BoscoState.DIVING
	_speed = BASE_SPEED


func _move_along_perimeter(dt: float) -> void:
	_perimeter_position += _perimeter_direction * _speed / PlayingField.CELL_SIZE * dt

	if _perimeter_position >= TOTAL_PERIMETER:
		_perimeter_position -= TOTAL_PERIMETER
	if _perimeter_position < 0:
		_perimeter_position += TOTAL_PERIMETER

	global_position = _perimeter_to_world(_perimeter_position)


func _move_through_field(dt: float) -> void:
	var pos: Vector2 = global_position + _direction * _speed * dt

	var field_min: Vector2 = _field.global_position + Vector2(FIN_RADIUS, FIN_RADIUS)
	var field_max: Vector2 = _field.global_position + Vector2(
		PlayingField.FIELD_PIXEL_WIDTH - FIN_RADIUS, PlayingField.FIELD_PIXEL_HEIGHT - FIN_RADIUS)

	var hit_edge: bool = false
	if pos.x < field_min.x:
		pos.x = field_min.x
		_direction.x = absf(_direction.x)
		hit_edge = true
	if pos.x > field_max.x:
		pos.x = field_max.x
		_direction.x = -absf(_direction.x)
		hit_edge = true
	if pos.y < field_min.y:
		pos.y = field_min.y
		_direction.y = absf(_direction.y)
		hit_edge = true
	if pos.y > field_max.y:
		pos.y = field_max.y
		_direction.y = -absf(_direction.y)
		hit_edge = true

	global_position = pos

	if hit_edge and _state == BoscoState.DIVING:
		_perimeter_position = _world_to_perimeter(global_position)
		_set_state(BoscoState.PATROLLING)


func _perimeter_to_world(pos: float) -> Vector2:
	pos = fmod(fmod(pos, TOTAL_PERIMETER) + TOTAL_PERIMETER, TOTAL_PERIMETER)

	var grid_x: int
	var grid_y: int

	if pos < GRID_W:
		grid_x = int(pos)
		grid_y = 0
	elif pos < GRID_W + GRID_H - 1:
		grid_x = GRID_W - 1
		grid_y = int(pos - GRID_W) + 1
	elif pos < 2 * GRID_W + GRID_H - 2:
		grid_x = GRID_W - 1 - int(pos - GRID_W - GRID_H + 1)
		grid_y = GRID_H - 1
	else:
		grid_x = 0
		grid_y = GRID_H - 1 - int(pos - 2 * GRID_W - GRID_H + 2)

	return _field.grid_to_world(Vector2i(grid_x, grid_y))


func _world_to_perimeter(world_pos: Vector2) -> float:
	var grid_pos: Vector2i = _field.world_to_grid(world_pos)
	var x: int = clampi(grid_pos.x, 0, GRID_W - 1)
	var y: int = clampi(grid_pos.y, 0, GRID_H - 1)

	var dist_top: int = y
	var dist_bottom: int = (GRID_H - 1) - y
	var dist_left: int = x
	var dist_right: int = (GRID_W - 1) - x
	var min_dist: int = mini(mini(dist_top, dist_bottom), mini(dist_left, dist_right))

	if min_dist == dist_top:
		return float(x)
	if min_dist == dist_right:
		return float(GRID_W + y)
	if min_dist == dist_bottom:
		return float(GRID_W + GRID_H - 2 + (GRID_W - 1 - x))
	return float(2 * GRID_W + GRID_H - 3 + (GRID_H - 1 - y))


func _check_collisions() -> void:
	if _field == null or _state == BoscoState.KILLED:
		return

	# Check collision with CursorShip
	for child in _field.get_children():
		if child is CursorShip and is_instance_valid(child):
			var dist: float = global_position.distance_to(child.global_position)
			if dist < FIN_RADIUS + 8.0:
				GameManager.on_life_lost()
				_set_state(BoscoState.GOTCHA)
				return

	# Check collision with growing beam
	var grid_pos: Vector2i = _field.world_to_grid(global_position)
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var check: Vector2i = Vector2i(grid_pos.x + dx, grid_pos.y + dy)
			if _field.in_bounds(check) and _field.is_growing(check):
				_field.on_beam_destroyed()
				GameManager.on_life_lost()
				_set_state(BoscoState.GOTCHA)
				return


func on_hit_by_ball() -> void:
	if _state == BoscoState.KILLED:
		return
	_set_state(BoscoState.BALL_HIT)


func trigger_death(kill_method: String = "regular") -> void:
	if _state == BoscoState.KILLED:
		return
	_was_rampage = _state == BoscoState.RAMPAGE
	_kill_method = kill_method
	_set_state(BoscoState.KILLED)


func check_if_isolated(kill_method: String = "regular") -> void:
	if _state == BoscoState.KILLED or _field == null:
		return
	if _field.is_in_newly_filled_area(global_position):
		trigger_death(kill_method)


func _update_ash_trail(dt: float) -> void:
	_ash_timer -= dt
	if _ash_timer <= 0 and _speed > 0:
		_ash_timer = ASH_INTERVAL
		_ash_trail.append({"pos": global_position, "age": 0.0})

	var i: int = _ash_trail.size() - 1
	while i >= 0:
		_ash_trail[i]["age"] += dt
		if _ash_trail[i]["age"] > ASH_LIFETIME:
			_ash_trail.remove_at(i)
		i -= 1


func _draw() -> void:
	# Draw ash trail
	for ash in _ash_trail:
		var alpha: float = 1.0 - ash["age"] / ASH_LIFETIME
		var local_ash: Vector2 = ash["pos"] - global_position
		draw_circle(local_ash, 1.5, Color(0.5, 0.5, 0.5, alpha * 0.4))

	if _state == BoscoState.KILLED:
		for i in range(4):
			var angle: float = _rotation_angle + i * TAU / 4.0
			var line_end: Vector2 = Vector2(cos(angle) * 12.0, sin(angle) * 12.0)
			draw_line(Vector2.ZERO, line_end, Color.YELLOW, 1.5)
		var fade: float = _state_timer / DEATH_SPIN_DURATION
		_draw_fin_shape(Color(0.35, 0.35, 0.45, fade))
		return

	var base_color: Color
	match _state:
		BoscoState.RAMPAGE:
			base_color = Color(0.8, 0.2, 0.2)
		BoscoState.TIRED:
			base_color = Color(0.3, 0.3, 0.4)
		BoscoState.GOTCHA:
			base_color = Color(0.9, 0.9, 0.2)
		_:
			base_color = Color(0.35, 0.35, 0.45)

	_draw_fin_shape(base_color)

	# Water ripple at base
	var t: float = Time.get_ticks_msec() / 400.0
	var ripple1: float = sin(t) * 3.0
	var ripple2: float = sin(t + 1.5) * 2.0
	var ripple_color: Color = Color(0.5, 0.7, 0.9, 0.3)
	draw_line(Vector2(-8 + ripple1, 1), Vector2(8 + ripple1, 1), ripple_color, 1.0)
	draw_line(Vector2(-6 + ripple2, 3), Vector2(6 + ripple2, 3), ripple_color, 0.8)

	if _state == BoscoState.RAMPAGE:
		var pulse: float = sin(Time.get_ticks_msec() / 100.0)
		draw_circle(Vector2.ZERO, 14.0 + pulse * 2.0, Color(1.0, 0.0, 0.0, 0.15))


func _draw_fin_shape(fin_color: Color) -> void:
	var fin_height: float = 14.0
	var fin_width: float = 10.0

	var shadow_fin: PackedVector2Array = PackedVector2Array([
		Vector2(1.5, 1.5),
		Vector2(-fin_width * 0.5 + 1.5, 1.5),
		Vector2(fin_width * 0.2 + 1.5, -fin_height + 1.5)
	])
	draw_polygon(shadow_fin, PackedColorArray([Color(0, 0, 0, 0.4)]))

	var fin: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0),
		Vector2(-fin_width * 0.5, 0),
		Vector2(fin_width * 0.2, -fin_height)
	])
	draw_polygon(fin, PackedColorArray([fin_color]))
	draw_line(fin[2], fin[0], fin_color.lightened(0.3), 1.5)
	draw_line(fin[2], fin[1], fin_color.darkened(0.2), 1.0)
	draw_line(fin[0], fin[1], fin_color.darkened(0.1), 1.5)
