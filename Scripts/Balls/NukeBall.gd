class_name NukeBallGD
extends BallBaseGD

## Nuke ball bounces with gravity. When trapped in a small area,
## detonates and destroys all balls in the same region.
## Other balls bounce off it normally (handled by BallBase).

@export var gravity_strength: float = 80.0
const DETONATION_THRESHOLD: int = 800  # Region size in cells to trigger detonation


func _ready() -> void:
	ball_color = Color(0.85, 0.15, 0.15)  # Deep metallic red (matches original sprite 301)
	speed = 160.0
	score_value = 300
	radius = 8.0
	super._ready()


func _draw() -> void:
	super._draw()

	# Metallic silver band across middle
	draw_line(Vector2(-radius * 0.7, 0), Vector2(radius * 0.7, 0),
		Color(0.8, 0.8, 0.85, 0.5), 2.0)

	# Radiation trefoil — 3 petal arcs around center
	var trefoil_color = Color(1.0, 0.9, 0.1, 0.7)
	for i in range(3):
		var a = i * TAU / 3.0 - PI * 0.5
		draw_arc(Vector2.ZERO, radius * 0.5, a - 0.4, a + 0.4, 8, trefoil_color, 2.5)

	# Center dot
	draw_circle(Vector2.ZERO, radius * 0.15, Color(1.0, 0.9, 0.1, 0.8))

	# Pulsing red glow when in a small region (approaching detonation)
	if field != null and is_active:
		var grid_pos = field.world_to_grid(global_position)
		var result = field.get_region_size(grid_pos)
		if result["size"] > 0 and result["size"] <= DETONATION_THRESHOLD * 2:
			var pulse = absf(sin(float(Time.get_ticks_msec()) / 150.0))
			draw_circle(Vector2.ZERO, radius + 3.0, Color(1.0, 0.1, 0.1, pulse * 0.3))
			queue_redraw()


func move(delta: float) -> void:
	# Apply gravity - nuke ball bounces like it has weight
	direction.y += gravity_strength * delta / speed
	direction = direction.normalized()
	super.move(delta)


## Called after a barrier is completed to check if the nuke should detonate.
func check_detonation() -> void:
	if not is_active or field == null:
		return

	var grid_pos = field.world_to_grid(global_position)
	var result = field.get_region_size(grid_pos)
	var region_size: int = result["size"]
	var balls_in_region: Array = result["balls"]

	if region_size > 0 and region_size <= DETONATION_THRESHOLD:
		_detonate(balls_in_region)


func _detonate(balls_in_region: Array) -> void:
	AudioManager.play_sfx("nuke_explosion")

	# Destroy all other balls in the same region
	for ball in balls_in_region:
		if ball != self and is_instance_valid(ball):
			ScoreManager.add_regular_score(500)  # 500 per destroyed ball
			GameManager.record_kill(ball.get_type_name())
			ball.queue_free()

	# Check if Bosco is nearby on the perimeter
	for child in field.get_children():
		if child is BoscoShark and is_instance_valid(child) and child.is_alive:
			var dist = global_position.distance_to(child.global_position)
			if dist < 60.0:  # Nuke blast radius
				child.trigger_death("nuke")

	# Destroy self
	GameManager.record_kill("NukeBall")
	queue_free()
