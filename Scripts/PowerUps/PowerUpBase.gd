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
var _lifetime: float = 30.0  # Expires after 30 seconds


func _ready() -> void:
	var parent = get_parent()
	while parent != null and not (parent is PlayingField):
		parent = parent.get_parent()
	field = parent as PlayingField

	# Random initial direction
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var angle = rng.randf_range(0, TAU)
	direction = Vector2(cos(angle), sin(angle)).normalized()

	z_index = 3


func _draw() -> void:
	# Diamond shape
	var points = PackedVector2Array([
		Vector2(0, -8),
		Vector2(8, 0),
		Vector2(0, 8),
		Vector2(-8, 0)
	])
	draw_polygon(points, PackedColorArray([power_up_color]))
	var outline = PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	draw_polyline(outline, power_up_color.lightened(0.4), 1.5)


func _process(delta: float) -> void:
	if _collected:
		return
	var dt = delta

	_lifetime -= dt
	if _lifetime <= 0:
		AudioManager.play_sfx("missed_yummy")
		queue_free()
		return

	# Bounce movement
	if field != null:
		_move_bounce(dt)

	# Check if enclosed by filled area
	if field != null:
		var cell = field.get_cell_at_world(global_position)
		if cell == PlayingField.CellState.FILLED:
			collect()


func _move_bounce(dt: float) -> void:
	var pos = global_position
	var movement = direction * speed * dt

	# Check X
	var next_x = pos.x + movement.x
	var check_x = field.world_to_grid(Vector2(next_x + 8.0 * sign(direction.x), pos.y))
	if field.in_bounds(check_x) and field.is_blocking(check_x):
		direction.x = -direction.x
	else:
		pos.x = next_x

	# Check Y
	var next_y = pos.y + movement.y
	var check_y = field.world_to_grid(Vector2(pos.x, next_y + 8.0 * sign(direction.y)))
	if field.in_bounds(check_y) and field.is_blocking(check_y):
		direction.y = -direction.y
	else:
		pos.y = next_y

	# Check if hit a growing beam - collect on barrier hit
	var center_cell = field.world_to_grid(pos)
	if field.is_growing(center_cell):
		collect()
		return

	# Boundary clamping
	var field_min = field.global_position + Vector2(8, 8)
	var field_max = field.global_position + Vector2(
		PlayingField.FIELD_PIXEL_WIDTH - 8, PlayingField.FIELD_PIXEL_HEIGHT - 8)

	if pos.x < field_min.x:
		pos.x = field_min.x
		direction.x = abs(direction.x)
	if pos.x > field_max.x:
		pos.x = field_max.x
		direction.x = -abs(direction.x)
	if pos.y < field_min.y:
		pos.y = field_min.y
		direction.y = abs(direction.y)
	if pos.y > field_max.y:
		pos.y = field_max.y
		direction.y = -abs(direction.y)

	global_position = pos


func collect() -> void:
	if _collected:
		return
	_collected = true
	AudioManager.play_sfx("powerup_collect")
	apply_effect()
	queue_free()


func apply_effect() -> void:
	pass  # Override in subclasses
