class_name PawnBallGD
extends BallBaseGD

var is_attracted_by_magnet: bool = false
var magnet_target: Vector2 = Vector2.ZERO

@export var magnet_pull_strength: float = 150.0


func _ready() -> void:
	ball_color = Color(0.9, 0.9, 0.2)
	speed = 200.0
	score_value = 100
	super._ready()


func _draw() -> void:
	# Pawn chess piece shape (simplified circle with flat top)
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_circle(Vector2(0, -radius * 0.4), radius * 0.5, ball_color.lightened(0.2))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, ball_color.darkened(0.2), 1.5)


func move(delta: float) -> void:
	if is_attracted_by_magnet:
		var to_magnet = (magnet_target - global_position).normalized()
		direction = direction.lerp(to_magnet, magnet_pull_strength * delta / speed).normalized()
	super.move(delta)
