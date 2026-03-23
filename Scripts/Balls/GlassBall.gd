class_name GlassBallGD
extends BallBaseGD

@export var durability: int = 3
var _hits: int = 0


var _crack_angles: Array = []  # Store crack directions at hit time


func _ready() -> void:
	ball_color = Color(0.85, 0.9, 0.95, 0.7)  # Translucent white glass
	speed = 220.0
	score_value = 120
	super._ready()


func _draw() -> void:
	# Shadow
	draw_circle(Vector2(1.5, 1.5), radius + 1.0, Color(0, 0, 0, 0.3))

	# Transparent glass body
	var glass_color = ball_color
	glass_color.a = 0.5 + 0.5 * (1.0 - float(_hits) / durability)
	draw_circle(Vector2.ZERO, radius, glass_color)

	# Inner glow — brighter center
	draw_circle(Vector2.ZERO, radius * 0.5, Color(0.95, 0.97, 1.0, 0.3))

	# Branching crack lines based on hits
	for i in range(_hits):
		if i < _crack_angles.size():
			var base_angle = _crack_angles[i]
			# Main crack line
			var end1 = Vector2(cos(base_angle), sin(base_angle)) * radius * 0.9
			draw_line(Vector2.ZERO, end1, Color(1, 1, 1, 0.8), 1.2)
			# Branch 1
			var mid = end1 * 0.6
			var branch_a = base_angle + 0.5
			var branch_end = mid + Vector2(cos(branch_a), sin(branch_a)) * radius * 0.3
			draw_line(mid, branch_end, Color(1, 1, 1, 0.6), 0.8)
			# Branch 2
			var branch_b = base_angle - 0.4
			var branch_end2 = mid + Vector2(cos(branch_b), sin(branch_b)) * radius * 0.25
			draw_line(mid, branch_end2, Color(1, 1, 1, 0.5), 0.8)

	# Glass reflection — curved white highlight arc
	draw_arc(Vector2(-radius * 0.2, -radius * 0.15), radius * 0.6,
		PI * 0.7, PI * 1.5, 10, Color(1, 1, 1, 0.45), 1.8)

	# Small internal light reflections when undamaged
	if _hits == 0:
		draw_circle(Vector2(radius * 0.2, radius * 0.15), 1.0, Color(1, 1, 1, 0.4))
		draw_circle(Vector2(-radius * 0.1, radius * 0.3), 0.8, Color(1, 1, 1, 0.3))

	# Rim light
	draw_arc(Vector2.ZERO, radius, 0, TAU, 36, Color(0.8, 0.85, 0.9, 0.6), 1.5)
	draw_arc(Vector2.ZERO, radius + 0.5, 0, TAU, 36, Color(0.4, 0.4, 0.45, 0.4), 1.0)


func should_bounce_on_cell(cell: Vector2i) -> bool:
	var blocking = super.should_bounce_on_cell(cell)
	if blocking:
		_hits += 1
		_crack_angles.append(randf_range(0, TAU))
		queue_redraw()
		if _hits >= durability:
			_shatter()
			return false
		AudioManager.play_sfx("glass_shatter")
	return blocking


func _shatter() -> void:
	ScoreManager.add_regular_score(score_value)
	GameManager.record_kill("GlassBall")
	AudioManager.play_sfx("glass_shatter")

	# Glass shatter can kill Bosco if nearby
	if field != null:
		for child in field.get_children():
			if child is BoscoShark and is_instance_valid(child) and child.is_alive:
				var dist = global_position.distance_to(child.global_position)
				if dist < 40.0:  # Glass shatter has area effect
					child.trigger_death("glass")

	queue_free()


func on_hit_by_nuke() -> void:
	ScoreManager.add_regular_score(500)  # FAQ: 500 per nuked ball
	AudioManager.play_sfx("glass_shatter")
	queue_free()
