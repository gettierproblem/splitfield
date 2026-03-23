class_name PawnBallGD
extends BallBaseGD

var is_attracted_by_magnet: bool = false
var magnet_target: Vector2 = Vector2.ZERO

@export var magnet_pull_strength: float = 150.0


func _ready() -> void:
	ball_color = Color(0.75, 0.75, 0.78)  # Silver-gray metallic (matches original sprite 300)
	speed = 200.0
	score_value = 100
	super._ready()


func _draw() -> void:
	super._draw()
	# Metallic sheen — bright arc on upper-left for polished metal look
	draw_arc(Vector2(-radius * 0.05, -radius * 0.05), radius * 0.65, PI * 0.9, PI * 1.5, 10,
		Color(0.9, 0.92, 0.95, 0.3), 2.0)


func move(delta: float) -> void:
	if is_attracted_by_magnet:
		var to_magnet = (magnet_target - global_position).normalized()
		direction = direction.lerp(to_magnet, magnet_pull_strength * delta / speed).normalized()
	super.move(delta)
