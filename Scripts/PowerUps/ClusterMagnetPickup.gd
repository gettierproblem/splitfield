class_name ClusterMagnetPickupGD
extends PowerUpBase

## Cluster magnet pickup grants +10 magnet charges.


func _ready() -> void:
	power_up_color = Color(0.8, 0.2, 0.2)
	super()


func _draw() -> void:
	var bob = sin(float(Time.get_ticks_msec()) / 500.0) * 2.0
	var offset = Vector2(0, bob)

	# Shadow
	draw_circle(Vector2(1, 3), 6.0, Color(0, 0, 0, 0.15))

	# Thick red horseshoe magnet
	var magnet_red = Color(0.85, 0.15, 0.1)
	# Horseshoe arc (top curve)
	draw_arc(offset + Vector2(0, 1), 4.5, PI, TAU, 16, magnet_red, 3.5)
	# Left prong
	draw_line(offset + Vector2(-4.5, 1), offset + Vector2(-4.5, 5), magnet_red, 3.5)
	# Right prong
	draw_line(offset + Vector2(4.5, 1), offset + Vector2(4.5, 5), magnet_red, 3.5)
	# Silver pole tips (N/S)
	draw_line(offset + Vector2(-4.5, 4), offset + Vector2(-4.5, 6), Color(0.8, 0.8, 0.85), 3.5)
	draw_line(offset + Vector2(4.5, 4), offset + Vector2(4.5, 6), Color(0.8, 0.8, 0.85), 3.5)
	queue_redraw()


func apply_effect() -> void:
	var game_scene = get_tree().current_scene
	if game_scene.has_method("add_cluster_magnets"):
		game_scene.call("add_cluster_magnets", 10)
