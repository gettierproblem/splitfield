class_name LightningBoltGD
extends PowerUpBase

## Lightning bolts recharge barrier speed by 10%.


func _ready() -> void:
	power_up_color = Color(0.3, 0.8, 1.0)
	super()


func _draw() -> void:
	var bob = sin(float(Time.get_ticks_msec()) / 500.0) * 2.0
	var offset = Vector2(0, bob)

	# Shadow
	draw_circle(Vector2(1, 3), 6.0, Color(0, 0, 0, 0.15))

	# Yellow glow behind bolt
	draw_circle(offset, 6.0, Color(1.0, 0.9, 0.1, 0.2))

	# Classic lightning bolt polygon — wide at top, tapers to point
	var bolt = PackedVector2Array([
		offset + Vector2(-2, -7),   # Top left
		offset + Vector2(3, -7),    # Top right
		offset + Vector2(0, -1),    # Right notch in
		offset + Vector2(4, -1),    # Right notch out
		offset + Vector2(-1, 7),    # Bottom point
		offset + Vector2(1, 1),     # Left notch in
		offset + Vector2(-3, 1),    # Left notch out
	])
	var bolt_color = Color(1.0, 0.9, 0.1)
	draw_polygon(bolt, PackedColorArray([bolt_color, bolt_color, bolt_color, bolt_color, bolt_color, bolt_color, bolt_color]))
	draw_polyline(PackedVector2Array([bolt[0], bolt[1], bolt[2], bolt[3], bolt[4], bolt[5], bolt[6], bolt[0]]),
		Color(1.0, 1.0, 0.6), 1.0)
	queue_redraw()


func apply_effect() -> void:
	var game_scene = get_tree().current_scene
	if game_scene.has_method("restore_barrier_charge"):
		game_scene.call("restore_barrier_charge")
