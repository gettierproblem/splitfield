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
	super()
	# Key icon
	draw_circle(Vector2(0, -2), 2.5, Color.GOLD)
	draw_circle(Vector2(0, -2), 1.5, power_up_color)
	draw_line(Vector2(0, 0), Vector2(0, 4), Color.GOLD, 1.5)
	draw_line(Vector2(0, 3), Vector2(2, 3), Color.GOLD, 1.5)
	draw_line(Vector2(0, 4), Vector2(2, 4), Color.GOLD, 1.5)


func apply_effect() -> void:
	for i in range(lives_granted):
		ScoreManager.gain_life()
	AudioManager.play_sfx("extra_life")
