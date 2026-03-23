class_name LifeKeyGD
extends PowerUpBase

## The life key gives 1-5 extra lives.

@export var lives_granted: int = 1


func _ready() -> void:
	power_up_color = Color(1.0, 0.85, 0.2)
	super()

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	lives_granted = rng.randi_range(1, 5)


func _draw() -> void:
	var bob = sin(float(Time.get_ticks_msec()) / 500.0) * 2.0
	var offset = Vector2(0, bob)

	# Shadow
	draw_circle(Vector2(1, 3), 6.0, Color(0, 0, 0, 0.15))

	var gold = Color(0.9, 0.75, 0.15)
	var gold_dark = Color(0.7, 0.55, 0.1)
	var gold_light = Color(1.0, 0.9, 0.4)

	# Round bow (head) — outer ring
	draw_circle(offset + Vector2(0, -3), 3.5, gold)
	draw_circle(offset + Vector2(0, -3), 2.0, gold_dark)  # Inner hole
	# Sheen on bow
	draw_arc(offset + Vector2(0, -3), 3.0, PI * 0.7, PI * 1.3, 8, gold_light, 1.0)

	# Thick shaft
	draw_rect(Rect2(offset + Vector2(-1, 0), Vector2(2, 8)), gold)
	# Left highlight on shaft
	draw_line(offset + Vector2(-1, 0), offset + Vector2(-1, 8), gold_light, 0.8)

	# Teeth at bottom
	draw_rect(Rect2(offset + Vector2(1, 5), Vector2(2.5, 1.5)), gold)
	draw_rect(Rect2(offset + Vector2(1, 7), Vector2(2, 1.2)), gold)
	queue_redraw()


func apply_effect() -> void:
	for i in range(lives_granted):
		ScoreManager.gain_life()
	AudioManager.play_sfx("extra_life")
