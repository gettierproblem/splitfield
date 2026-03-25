class_name PowerUpBase
extends Node2D

## Base class for all yummies (powerups). Yummies bounce around the field
## like balls and can be collected by barrier hit or area enclosure.

@export var duration: float = 10.0
@export var power_up_color: Color = Color.WHITE
@export var speed: float = 120.0

var field: PlayingField
var direction: Vector2
var _collected: bool = false


func _ready() -> void:
	var parent = get_parent()
	while parent != null and not (parent is PlayingField):
		parent = parent.get_parent()
	field = parent as PlayingField

	# Random initial direction
	var rng = RandomNumberGenerator.new()
	DemoRecorder.seed_rng(rng)
	var angle = rng.randf_range(0, TAU)
	direction = Vector2(cos(angle), sin(angle)).normalized()

	z_index = 3
	scale = Vector2(1.8, 1.8)


func _draw() -> void:
	# Floating bob animation
	var bob = sin(float(Time.get_ticks_msec()) / 500.0) * 2.0
	var offset = Vector2(0, bob)

	# Shadow beneath
	draw_circle(Vector2(0, 3), 7.0, Color(0, 0, 0, 0.2))

	# Rounded container circle
	draw_circle(offset, 9.0, power_up_color.darkened(0.5))
	draw_circle(offset, 8.0, power_up_color.darkened(0.2))

	# Bright outline
	draw_arc(offset, 9.0, 0, TAU, 24, power_up_color.lightened(0.3), 1.5)

	# Orbiting sparkle
	var sparkle_t = float(Time.get_ticks_msec()) / 800.0
	var sparkle_pos = offset + Vector2(cos(sparkle_t) * 10.0, sin(sparkle_t) * 10.0)
	var sparkle_alpha = 0.4 + sin(sparkle_t * 3.0) * 0.3
	draw_circle(sparkle_pos, 1.2, Color(1, 1, 1, sparkle_alpha))
	queue_redraw()  # Animate


func _physics_process(delta: float) -> void:
	if _collected:
		return

	# Bounce movement
	if field != null:
		_move_bounce(delta)

	# Check if enclosed by filled or barrier area
	if field != null:
		var cell = field.get_cell_at_world(global_position)
		if cell == PlayingField.CellState.FILLED or cell == PlayingField.CellState.BARRIER:
			collect()


func _move_bounce(dt: float) -> void:
	var pos = global_position
	var movement = direction * speed * dt

	# Check X
	var next_x = pos.x + movement.x
	var check_x = field.world_to_grid(Vector2(next_x + 8.0 * sign(direction.x), pos.y))
	if field.in_bounds(check_x) and field.is_blocking(check_x):
		direction.x = -direction.x
		AudioManager.play_sfx("yummy_bounce")
	else:
		pos.x = next_x

	# Check Y
	var next_y = pos.y + movement.y
	var check_y = field.world_to_grid(Vector2(pos.x, next_y + 8.0 * sign(direction.y)))
	if field.in_bounds(check_y) and field.is_blocking(check_y):
		direction.y = -direction.y
		AudioManager.play_sfx("yummy_bounce")
	else:
		pos.y = next_y

	# Growing beams: collect on contact (unless overridden)
	var center_cell = field.world_to_grid(pos)
	if field.is_growing(center_cell):
		if collected_by_growing_beam():
			collect()
			return
		direction = -direction
		pos = global_position  # Revert position
		AudioManager.play_sfx("yummy_bounce")


	# Boundary clamping
	var field_min = field.global_position + Vector2(8, 8)
	var field_max = field.global_position + Vector2(
		PlayingField.FIELD_PIXEL_WIDTH - 8, PlayingField.FIELD_PIXEL_HEIGHT - 8)

	if pos.x < field_min.x:
		pos.x = field_min.x
		direction.x = abs(direction.x)
		AudioManager.play_sfx("yummy_bounce")
	if pos.x > field_max.x:
		pos.x = field_max.x
		direction.x = -abs(direction.x)
		AudioManager.play_sfx("yummy_bounce")
	if pos.y < field_min.y:
		pos.y = field_min.y
		direction.y = abs(direction.y)
		AudioManager.play_sfx("yummy_bounce")
	if pos.y > field_max.y:
		pos.y = field_max.y
		direction.y = -abs(direction.y)
		AudioManager.play_sfx("yummy_bounce")

	global_position = pos


## Whether this powerup is collected by touching a growing beam.
func collected_by_growing_beam() -> bool:
	return true


func collect() -> void:
	if _collected:
		return
	_collected = true
	AudioManager.play_sfx("powerup_collect")
	apply_effect()
	queue_free()


func apply_effect() -> void:
	pass  # Override in subclasses
