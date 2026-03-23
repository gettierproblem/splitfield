class_name ExplosivesGD
extends PowerUpBase

@export var balls_to_destroy: int = 2


func _ready() -> void:
	power_up_color = Color(1.0, 0.5, 0.0)
	super()


func _draw() -> void:
	super()
	# Bomb icon
	draw_circle(Vector2(0, 1), 3.0, Color.DARK_RED)
	draw_line(Vector2(0, -2), Vector2(2, -4), Color.ORANGE, 1.5)


func apply_effect() -> void:
	# Destroy random balls
	if field == null:
		return
	var balls_container = field.get_balls_container()
	if balls_container == null:
		return

	var destroyed = 0
	var children = balls_container.get_children()
	# Shuffle
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for child in children:
		if destroyed >= balls_to_destroy:
			break
		if child is BallBaseGD and is_instance_valid(child):
			if rng.randf() < 0.5:
				child.on_hit_by_nuke()
				destroyed += 1
