class_name GlassBallGD
extends BallBaseGD

@export var durability: int = 3
var _hits: int = 0
var _crack_angles: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	ball_color = Color(0.7, 0.4, 0.9, 0.7)  # Purple glass
	speed = 220.0
	score_value = 120
	DemoRecorder.seed_rng(_rng)
	super._ready()


func _draw() -> void:
	# Shadow
	draw_circle(Vector2(1.5, 1.5), radius + 1.0, Color(0, 0, 0, 0.3))

	# Transparent glass body — gets more cracked/dim with hits
	var glass_color = ball_color
	glass_color.a = 0.5 + 0.5 * (1.0 - float(_hits) / durability)
	draw_circle(Vector2.ZERO, radius, glass_color)

	# Inner glow
	draw_circle(Vector2.ZERO, radius * 0.5, Color(0.85, 0.7, 1.0, 0.3))

	# Crack lines — span full diameter through center
	for i in range(_hits):
		if i < _crack_angles.size():
			var base_angle = _crack_angles[i]
			var dir1 = Vector2(cos(base_angle), sin(base_angle))
			var start_pt = -dir1 * radius * 0.9
			var end_pt = dir1 * radius * 0.9
			# Dark shadow line for contrast
			draw_line(start_pt + Vector2(0.5, 0.5), end_pt + Vector2(0.5, 0.5), Color(0.15, 0.05, 0.2, 0.7), 2.5)
			# Main crack — bright white across full ball
			draw_line(start_pt, end_pt, Color(1, 1, 1, 1.0), 2.0)
			# Branches off the main crack
			var mid1 = start_pt.lerp(end_pt, 0.3)
			var b1_angle = base_angle + PI * 0.5 + 0.3
			draw_line(mid1, mid1 + Vector2(cos(b1_angle), sin(b1_angle)) * radius * 0.5, Color(1, 1, 1, 0.9), 1.5)
			var mid2 = start_pt.lerp(end_pt, 0.65)
			var b2_angle = base_angle - PI * 0.5 - 0.2
			draw_line(mid2, mid2 + Vector2(cos(b2_angle), sin(b2_angle)) * radius * 0.45, Color(1, 1, 1, 0.85), 1.5)
			var mid3 = start_pt.lerp(end_pt, 0.8)
			var b3_angle = base_angle + PI * 0.5 - 0.4
			draw_line(mid3, mid3 + Vector2(cos(b3_angle), sin(b3_angle)) * radius * 0.3, Color(1, 1, 1, 0.7), 1.0)

	# Glass reflection arc
	draw_arc(Vector2(-radius * 0.2, -radius * 0.15), radius * 0.6,
		PI * 0.7, PI * 1.5, 10, Color(1, 1, 1, 0.45), 1.8)

	# Small internal light reflections when undamaged
	if _hits == 0:
		draw_circle(Vector2(radius * 0.2, radius * 0.15), 1.0, Color(1, 1, 1, 0.4))
		draw_circle(Vector2(-radius * 0.1, radius * 0.3), 0.8, Color(1, 1, 1, 0.3))

	# Rim light
	draw_arc(Vector2.ZERO, radius, 0, TAU, 36, Color(0.6, 0.4, 0.8, 0.6), 1.5)
	draw_arc(Vector2.ZERO, radius + 0.5, 0, TAU, 36, Color(0.3, 0.2, 0.4, 0.4), 1.0)


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
				var normal = diff / dist
				var overlap = min_dist - dist
				global_position += normal * (overlap * 0.5)
				other.global_position -= normal * (overlap * 0.5)

				var dot1 = direction.dot(normal)
				var dot2 = other.direction.dot(normal)

				if dot1 < 0:
					direction -= 2.0 * dot1 * normal
				if dot2 > 0:
					other.direction -= 2.0 * dot2 * normal

				direction = direction.normalized()
				other.direction = other.direction.normalized()

				# Two glass balls colliding — destroy all balls in the region
				if other is GlassBallGD:
					_glass_collision_shatter()
					return

				# Non-glass collision: take crack damage
				_hits += 1
				_crack_angles.append(_rng.randf_range(0, TAU))
				AudioManager.play_sfx("glass_shatter")
				queue_redraw()
				if _hits >= durability:
					_shatter()
					return


func _glass_collision_shatter() -> void:
	AudioManager.play_sfx("glass_shatter")

	# Find all balls in this connected empty region and destroy them
	if field != null:
		var grid_pos: Vector2i = field.world_to_grid(global_position)
		var region: Dictionary = field.get_region_size(grid_pos)
		var balls_in_region: Array = region["balls"]

		for ball in balls_in_region:
			if is_instance_valid(ball) and ball != self:
				ball.is_active = false
				ScoreManager.add_regular_score(ball.score_value)
				GameManager.record_kill(ball.get_type_name())
				ball.queue_free()

		# Kill Bosco if in the area
		for child in field.get_children():
			if child is BoscoShark and is_instance_valid(child) and child.is_alive:
				var d = global_position.distance_to(child.global_position)
				if d < 60.0:
					child.trigger_death("glass")

	is_active = false
	ScoreManager.add_regular_score(score_value)
	GameManager.record_kill("GlassBall")
	queue_free()


func _shatter() -> void:
	is_active = false
	ScoreManager.add_regular_score(score_value)
	GameManager.record_kill("GlassBall")
	AudioManager.play_sfx("glass_shatter")

	# Glass shatter can kill Bosco if nearby
	if field != null:
		for child in field.get_children():
			if child is BoscoShark and is_instance_valid(child) and child.is_alive:
				var dist = global_position.distance_to(child.global_position)
				if dist < 40.0:
					child.trigger_death("glass")

	queue_free()


func _on_hit_growing_beam() -> bool:
	_hits += 1
	_crack_angles.append(_rng.randf_range(0, TAU))
	AudioManager.play_sfx("glass_shatter")
	queue_redraw()
	if _hits >= durability:
		_shatter()
	# Beam is also destroyed and life lost
	field.on_beam_destroyed()
	GameManager.on_life_lost()
	return false


func on_hit_by_nuke() -> void:
	is_active = false
	ScoreManager.add_regular_score(500)
	AudioManager.play_sfx("glass_shatter")
	queue_free()
