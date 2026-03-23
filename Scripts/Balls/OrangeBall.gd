class_name OrangeBallGD
extends BallBaseGD


func _ready() -> void:
	ball_color = Color(1.0, 0.6, 0.0)
	speed = 200.0
	score_value = 150
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_active or field == null:
		return

	# Absorb momentum from nearby balls
	var balls_container = field.get_balls_container()
	if balls_container == null:
		return

	for child in balls_container.get_children():
		if child is BallBaseGD and child != self and not child is NukeBallGD and is_instance_valid(child):
			var other: BallBaseGD = child
			var dist = global_position.distance_to(other.global_position)
			if dist < radius + other.radius + 4.0:
				# Absorb: slow the other ball, speed up self
				other.speed *= 0.8
				speed = minf(speed * 1.1, 200.0)
