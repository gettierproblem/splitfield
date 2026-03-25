class_name YummieCakeGD
extends PowerUpBase

## Yummie Cake drops onto the field and detonates on impact,
## spawning 4-7 child yummies (95% Lightning Bolts, 5% Cluster Magnets).
## If it lands in already-cleared area, it sinks and is wasted.

var _detonated: bool = false
var _cake_timer: float = 0.0
const CAKE_FUSE: float = 2.0


func _ready() -> void:
	power_up_color = Color(1.0, 0.7, 0.8)  # Pink cake
	speed = 0  # Drops, doesn't bounce
	super()


func _draw() -> void:
	# Round pink cake (matches original "LOVE MOM" sprite 1102)
	var cake_pink = Color(1.0, 0.75, 0.8)
	var frosting = Color(1.0, 0.95, 0.95)

	# Shadow
	draw_circle(Vector2(1, 2), 9.0, Color(0, 0, 0, 0.2))

	# Main cake body — round
	draw_circle(Vector2.ZERO, 9.0, cake_pink)

	# Scalloped frosting edge — small overlapping white circles around perimeter
	for i in range(10):
		var angle = i * TAU / 10.0
		var scallop_pos = Vector2(cos(angle), sin(angle)) * 7.5
		draw_circle(scallop_pos, 2.5, frosting)

	# Inner decorative area
	draw_circle(Vector2.ZERO, 5.5, cake_pink.lightened(0.1))

	# Red text suggestion (tiny lines to suggest "LOVE MOM")
	var red = Color(0.9, 0.1, 0.1)
	draw_line(Vector2(-3, -2), Vector2(-1, -2), red, 0.8)
	draw_line(Vector2(0, -2), Vector2(2, -2), red, 0.8)
	draw_line(Vector2(-2, 1), Vector2(2, 1), red, 0.8)

	# Cherry on top
	draw_circle(Vector2(0, -8), 2.0, Color.RED)
	draw_circle(Vector2(-0.5, -8.5), 0.8, Color(1.0, 0.5, 0.5, 0.6))  # Cherry highlight


func _process(delta: float) -> void:
	if _detonated:
		return

	_cake_timer += delta
	if _cake_timer >= CAKE_FUSE:
		_detonate()
		return

	if field != null:
		var cell = field.get_cell_at_world(global_position)
		if cell == PlayingField.CellState.FILLED:
			# Landed in already-cleared area - wasted!
			AudioManager.play_sfx("cake_denied")
			_detonated = true
			queue_free()
			return

		# Check barrier hit — detonate early
		var center_cell = field.world_to_grid(global_position)
		if field.is_growing(center_cell):
			_detonate()
			return


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true

	AudioManager.play_sfx("cake_detonate")

	if field == null:
		queue_free()
		return

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
