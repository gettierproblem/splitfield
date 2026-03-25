class_name BoscoShark
extends Node2D

## Bosco the shark. Seeks the player's cursor/ship position, phases through
## barriers and filled areas. States: hunting, gotcha, ball_hit, rampage, tired, killed.

enum BoscoState {
	HUNTING,
	GOTCHA,
	BALL_HIT,
	RAMPAGE,
	TIRED,
	KILLED
}

var _field: PlayingField
var _state: int = BoscoState.HUNTING
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Movement — Bosco steers toward the player
var _velocity: Vector2 = Vector2.ZERO
const BASE_SPEED: float = 160.0
var _speed: float = BASE_SPEED
const TRACKING_WEIGHT: float = 2.5  # How aggressively Bosco steers toward player

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
	DemoRecorder.seed_rng(_rng)
	_state = BoscoState.HUNTING
	_speed = BASE_SPEED
	# Start at a random edge position
	var perim_total: int = 2 * (200 + 184) - 4
	var p: float = fmod(start_pos, float(perim_total))
	global_position = _perimeter_to_world(p)
	# Initial velocity aimed inward
	var field_center: Vector2 = _field.global_position + Vector2(
		PlayingField.FIELD_PIXEL_WIDTH * 0.5, PlayingField.FIELD_PIXEL_HEIGHT * 0.5)
	_velocity = (field_center - global_position).normalized() * _speed
	z_index = 4


func _physics_process(delta: float) -> void:
	match _state:
		BoscoState.HUNTING:
			_seek_player(delta)
			_check_collisions()

		BoscoState.GOTCHA:
			_state_timer -= delta
			if _state_timer <= 0:
				_set_state(BoscoState.HUNTING)

		BoscoState.BALL_HIT:
			_state_timer -= delta
			if _state_timer <= 0:
				_set_state(BoscoState.RAMPAGE)

		BoscoState.RAMPAGE:
			_seek_player(delta)
			_check_collisions()
			_state_timer -= delta
			if _state_timer <= 0:
				_set_state(BoscoState.TIRED)

		BoscoState.TIRED:
			_drift(delta)
			_check_collisions()
			_state_timer -= delta
			if _state_timer <= 0:
				_set_state(BoscoState.HUNTING)

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
		BoscoState.HUNTING:
			_speed = BASE_SPEED
			AudioManager.play_sfx("bosco_patrol")
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
			AudioManager.play_sfx("bosco_rampage")
		BoscoState.TIRED:
			_state_timer = TIRED_DURATION
			_speed = BASE_SPEED * 0.5
			AudioManager.play_sfx("bosco_tired")
		BoscoState.KILLED:
			_state_timer = DEATH_SPIN_DURATION
			_speed = 0


func _get_player_position() -> Vector2:
	if _field == null:
		return global_position
	for child in _field.get_children():
		if child is CursorShip and is_instance_valid(child):
			return child.global_position
	# Fallback: field center
	return _field.global_position + Vector2(
		PlayingField.FIELD_PIXEL_WIDTH * 0.5, PlayingField.FIELD_PIXEL_HEIGHT * 0.5)


func _seek_player(dt: float) -> void:
	var target: Vector2 = _get_player_position()
	var desired: Vector2 = (target - global_position).normalized() * _speed
	_velocity = _velocity.lerp(desired, TRACKING_WEIGHT * dt)
	global_position += _velocity * dt
	_clamp_to_field()


func _drift(dt: float) -> void:
	# Tired: slow drift, less aggressive tracking
	var target: Vector2 = _get_player_position()
	var desired: Vector2 = (target - global_position).normalized() * _speed
	_velocity = _velocity.lerp(desired, TRACKING_WEIGHT * 0.3 * dt)
	global_position += _velocity * dt
	_clamp_to_field()


func _clamp_to_field() -> void:
	if _field == null:
		return
	var field_min: Vector2 = _field.global_position + Vector2(4, 4)
	var field_max: Vector2 = _field.global_position + Vector2(
		PlayingField.FIELD_PIXEL_WIDTH - 4, PlayingField.FIELD_PIXEL_HEIGHT - 4)
	global_position.x = clampf(global_position.x, field_min.x, field_max.x)
	global_position.y = clampf(global_position.y, field_min.y, field_max.y)


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


func _perimeter_to_world(pos: float) -> Vector2:
	var grid_w: int = 200
	var grid_h: int = 184
	var total: int = 2 * (grid_w + grid_h) - 4
	pos = fmod(fmod(pos, float(total)) + float(total), float(total))
	var grid_x: int
	var grid_y: int
	if pos < grid_w:
		grid_x = int(pos)
		grid_y = 0
	elif pos < grid_w + grid_h - 1:
		grid_x = grid_w - 1
		grid_y = int(pos - grid_w) + 1
	elif pos < 2 * grid_w + grid_h - 2:
		grid_x = grid_w - 1 - int(pos - grid_w - grid_h + 1)
		grid_y = grid_h - 1
	else:
		grid_x = 0
		grid_y = grid_h - 1 - int(pos - 2 * grid_w - grid_h + 2)
	return _field.grid_to_world(Vector2i(grid_x, grid_y))


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
	# Draw smoke trail
	for ash in _ash_trail:
		var age_ratio: float = ash["age"] / ASH_LIFETIME
		var alpha: float = (1.0 - age_ratio) * 0.4
		var local_ash: Vector2 = ash["pos"] - global_position
		local_ash.y -= age_ratio * 4.0
		var smoke_size: float = 1.0 + age_ratio * 2.0
		if age_ratio > 0.5:
			smoke_size *= (1.0 - (age_ratio - 0.5) * 1.5)
		draw_circle(local_ash, maxf(0.5, smoke_size), Color(0.6, 0.6, 0.65, alpha))

	if _state == BoscoState.KILLED:
		var death_progress: float = 1.0 - _state_timer / DEATH_SPIN_DURATION
		for i in range(6):
			var angle: float = _rotation_angle + i * TAU / 6.0
			var dist: float = 8.0 + death_progress * 8.0
			var particle_pos: Vector2 = Vector2(cos(angle) * dist, sin(angle) * dist)
			var particle_color: Color = Color(1.0, 1.0 - death_progress * 0.8, 0.0, 1.0 - death_progress * 0.5)
			draw_circle(particle_pos, 2.0 - death_progress * 1.0, particle_color)
			draw_line(Vector2.ZERO, particle_pos * 0.8, particle_color, 1.5)
		var fade: float = _state_timer / DEATH_SPIN_DURATION
		_draw_fin_shape(Color(0.35, 0.35, 0.45, fade))
		return

	var base_color: Color
	match _state:
		BoscoState.RAMPAGE:
			base_color = Color(0.85, 0.15, 0.1)
		BoscoState.TIRED:
			base_color = Color(0.3, 0.3, 0.4)
		BoscoState.GOTCHA:
			base_color = Color(0.9, 0.9, 0.2)
		_:
			base_color = Color(0.35, 0.35, 0.45)

	_draw_fin_shape(base_color)

	# Wake lines behind fin
	if _velocity.length() > 10.0:
		var behind: Vector2 = -_velocity.normalized()
		var t: float = Time.get_ticks_msec() / 300.0
		var wake_color: Color = Color(0.5, 0.7, 0.9, 0.25)
		for i in range(3):
			var offset: float = 6.0 + i * 4.0
			var wave: float = sin(t + i * 1.2) * 2.0
			var perp: Vector2 = Vector2(-behind.y, behind.x) * wave
			draw_line(behind * offset + perp - Vector2(2, 0), behind * offset + perp + Vector2(2, 0), wake_color, 0.8)

	# Water ripple at base
	var t: float = Time.get_ticks_msec() / 400.0
	var ripple1: float = sin(t) * 3.5
	var ripple2: float = sin(t + 1.5) * 2.5
	var ripple3: float = sin(t + 3.0) * 1.5
	var ripple_color: Color = Color(0.5, 0.7, 0.9, 0.3)
	draw_line(Vector2(-9 + ripple1, 1), Vector2(9 + ripple1, 1), ripple_color, 1.2)
	draw_line(Vector2(-7 + ripple2, 3), Vector2(7 + ripple2, 3), ripple_color, 0.8)
	draw_line(Vector2(-4 + ripple3, 5), Vector2(4 + ripple3, 5), Color(0.5, 0.7, 0.9, 0.15), 0.6)

	if _state == BoscoState.RAMPAGE:
		var pulse: float = sin(Time.get_ticks_msec() / 80.0)
		draw_circle(Vector2.ZERO, 16.0 + pulse * 3.0, Color(1.0, 0.0, 0.0, 0.2))
		draw_circle(Vector2.ZERO, 10.0 + pulse * 2.0, Color(1.0, 0.2, 0.0, 0.15))


func _draw_fin_shape(fin_color: Color) -> void:
	var fin_height: float = 16.0
	var fin_width: float = 14.0

	if _state == BoscoState.TIRED:
		fin_height *= 0.75

	if _state == BoscoState.RAMPAGE:
		fin_height *= 1.15
		fin_width *= 1.15

	# Shadow
	var shadow_offset: Vector2 = Vector2(2.0, 2.0)
	var shadow_fin: PackedVector2Array = PackedVector2Array([
		shadow_offset + Vector2(fin_width * 0.3, 0),
		shadow_offset + Vector2(-fin_width * 0.3, 2),
		shadow_offset + Vector2(-fin_width * 0.45, 0),
		shadow_offset + Vector2(-fin_width * 0.15, -fin_height * 0.3),
		shadow_offset + Vector2(fin_width * 0.15, -fin_height),
		shadow_offset + Vector2(fin_width * 0.3, -fin_height * 0.6),
	])
	draw_polygon(shadow_fin, PackedColorArray([Color(0, 0, 0, 0.35)]))

	# Organic 6-point fin shape
	var fin: PackedVector2Array = PackedVector2Array([
		Vector2(fin_width * 0.3, 0),
		Vector2(-fin_width * 0.3, 2),
		Vector2(-fin_width * 0.45, 0),
		Vector2(-fin_width * 0.15, -fin_height * 0.3),
		Vector2(fin_width * 0.15, -fin_height),
		Vector2(fin_width * 0.3, -fin_height * 0.6),
	])
	draw_polygon(fin, PackedColorArray([fin_color]))

	# Inner lighter gradient overlay
	var inner_fin: PackedVector2Array = PackedVector2Array([
		Vector2(fin_width * 0.15, -1),
		Vector2(-fin_width * 0.1, -fin_height * 0.25),
		Vector2(fin_width * 0.1, -fin_height * 0.85),
		Vector2(fin_width * 0.2, -fin_height * 0.5),
	])
	draw_polygon(inner_fin, PackedColorArray([fin_color.lightened(0.15)]))

	# Cartilage/ridge lines
	draw_line(Vector2(fin_width * 0.15, -fin_height), Vector2(fin_width * 0.05, -2),
		fin_color.darkened(0.2), 1.0)
	draw_line(Vector2(fin_width * 0.15, -fin_height), Vector2(-fin_width * 0.2, -1),
		fin_color.darkened(0.15), 0.8)

	# Edge outlines
	draw_polyline(fin, fin_color.darkened(0.3), 1.5)
	draw_line(fin[4], fin[5], fin_color.lightened(0.25), 1.2)
