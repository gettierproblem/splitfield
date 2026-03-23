class_name YummieCakeGD
extends PowerUpBase

## Yummie Cake drops onto the field and detonates on impact,
## spawning 4-7 child yummies (95% Lightning Bolts, 5% Cluster Magnets).
## If it lands in already-cleared area, it sinks and is wasted.

var _detonated: bool = false


func _ready() -> void:
	power_up_color = Color(1.0, 0.7, 0.8)  # Pink cake
	speed = 0  # Drops, doesn't bounce
	super()


func _draw() -> void:
	# Cake shape
	draw_rect(Rect2(-7, -4, 14, 8), Color(0.8, 0.5, 0.3))
	# Frosting top
	draw_rect(Rect2(-7, -6, 14, 3), Color(1.0, 0.9, 0.9))
	# Cherry
	draw_circle(Vector2(0, -7), 2.0, Color.RED)
	# Outline
	draw_rect(Rect2(-7, -6, 14, 10), power_up_color.lightened(0.3), false, 1.0)


func _process(delta: float) -> void:
	if _detonated:
		return

	if field != null:
		var cell = field.get_cell_at_world(global_position)
		if cell == PlayingField.CellState.FILLED:
			# Landed in already-cleared area - wasted!
			AudioManager.play_sfx("cake_denied")
			_detonated = true
			queue_free()
			return

		# Check barrier hit or just detonate after brief delay
		var center_cell = field.world_to_grid(global_position)
		if field.is_growing(center_cell):
			_detonate()
			return

	# Also detonate if enclosed
	if field != null:
		var cell = field.get_cell_at_world(global_position)
		if cell == PlayingField.CellState.FILLED:
			_detonate()


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true

	AudioManager.play_sfx("cake_detonate")

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var count = rng.randi_range(4, 7)

	var container = field.get_power_ups_container()
	for i in range(count):
		var child: PowerUpBase
		if rng.randi_range(0, 19) == 5:  # 5% chance
			child = ClusterMagnetPickupGD.new()
		else:
			child = LightningBoltGD.new()

		# Spawn near cake position with slight offset
		child.global_position = global_position + Vector2(
			rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
		container.add_child(child)

	queue_free()


func apply_effect() -> void:
	_detonate()
