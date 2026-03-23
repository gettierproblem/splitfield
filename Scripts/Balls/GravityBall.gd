class_name GravityBallGD
extends BallBaseGD

@export var gravity_strength: float = 80.0


func _ready() -> void:
	ball_color = Color(0.8, 0.4, 0.1)
	speed = 200.0
	score_value = 150
	super._ready()


func move(delta: float) -> void:
	# Apply gravity to direction
	direction.y += gravity_strength * delta / speed
	direction = direction.normalized()
	super.move(delta)
