class_name BarrierBeam
extends Node2D

var is_growing: bool = false

var _field: PlayingField
var _vertical: bool
var _origin: Vector2i

# Two growth heads
var _head_a: Vector2i
var _head_b: Vector2i
var _head_a_stopped: bool
var _head_b_stopped: bool

var _base_speed: float = 90.0  # cells per second
var _speed_multiplier: float = 1.0
var _accumulator: float


func initialize(field: PlayingField, world_pos: Vector2, vertical: bool) -> void:
	_field = field
	_vertical = vertical
	_origin = field.world_to_grid(world_pos)

	# Don't start beam on barrier/filled cells
	if field.is_blocking(_origin):
		return

	_head_a = _origin
	_head_b = _origin
	_head_a_stopped = false
	_head_b_stopped = false
	is_growing = true

	field.set_cell(_origin, PlayingField.CellState.GROWING)


func set_speed_multiplier(mult: float) -> void:
	_speed_multiplier = mult


func _process(delta: float) -> void:
	if not is_growing:
		return

	# Check for ball collision with growing cells
	if _field.does_ball_overlap_growing():
		is_growing = false
		_field.on_beam_destroyed()
		GameManager.on_life_lost()
		queue_free()
		return

	var speed: float = _base_speed * _speed_multiplier
	_accumulator += delta * speed

	while _accumulator >= 1.0 and is_growing:
		_accumulator -= 1.0
		_grow_heads()

		# Recheck collision after each growth step
		if _field.does_ball_overlap_growing():
			is_growing = false
			_field.on_beam_destroyed()
			GameManager.on_life_lost()
			queue_free()
			return

		if _head_a_stopped and _head_b_stopped:
			is_growing = false
			_field.on_beam_completed()
			queue_free()
			return


func _grow_heads() -> void:
	var dir: Vector2i = Vector2i(0, 1) if _vertical else Vector2i(1, 0)

	# Grow head A (positive direction)
	if not _head_a_stopped:
		var next: Vector2i = _head_a + dir
		if not _field.in_bounds(next) or _field.is_blocking(next):
			_head_a_stopped = true
		else:
			_head_a = next
			_field.set_cell(_head_a, PlayingField.CellState.GROWING)

	# Grow head B (negative direction)
	if not _head_b_stopped:
		var next: Vector2i = _head_b - dir
		if not _field.in_bounds(next) or _field.is_blocking(next):
			_head_b_stopped = true
		else:
			_head_b = next
			_field.set_cell(_head_b, PlayingField.CellState.GROWING)
