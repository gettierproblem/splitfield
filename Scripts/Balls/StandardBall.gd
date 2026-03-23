class_name StandardBallGD
extends BallBaseGD


func _ready() -> void:
	ball_color = Color(0.2, 0.6, 1.0)
	speed = 240.0
	score_value = 100
	super._ready()
