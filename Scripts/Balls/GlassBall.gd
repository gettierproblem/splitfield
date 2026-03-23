class_name GlassBallGD
extends BallBaseGD

@export var durability: int = 3
var _hits: int = 0


func _ready() -> void:
	ball_color = Color(0.7, 0.9, 1.0, 0.7)
	speed = 220.0
	score_value = 120
	super._ready()


func _draw() -> void:
	# Transparent glass effect
	var glass_color = ball_color
	glass_color.a = 0.5 + 0.5 * (1.0 - float(_hits) / durability)
	draw_circle(Vector2.ZERO, radius, glass_color)
	# Crack lines based on hits
	for i in range(_hits):
		var angle = i * TAU / durability
		var start = Vector2.ZERO
		var end = Vector2(cos(angle), sin(angle)) * radius
		draw_line(start, end, Color.WHITE, 1.0)
	# Shine highlight
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.2, Color(1, 1, 1, 0.6))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.8, 0.9, 1.0, 0.8), 1.5)


func should_bounce_on_cell(cell: Vector2i) -> bool:
	var blocking = super.should_bounce_on_cell(cell)
	if blocking:
		_hits += 1
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
