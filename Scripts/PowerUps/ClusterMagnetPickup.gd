class_name ClusterMagnetPickupGD
extends PowerUpBase

## Cluster magnet pickup grants +10 magnet charges.


func _ready() -> void:
	power_up_color = Color(0.8, 0.2, 0.2)
	super()


func _draw() -> void:
	super()
	draw_arc(Vector2(0, 2), 3.0, PI, TAU, 12, Color.WHITE, 2.0)
	draw_line(Vector2(-3, 2), Vector2(-3, -2), Color(1.0, 0.3, 0.3), 2.0)
	draw_line(Vector2(3, 2), Vector2(3, -2), Color(0.3, 0.3, 1.0), 2.0)


func apply_effect() -> void:
	var game_scene = get_tree().current_scene
	if game_scene.has_method("add_cluster_magnets"):
		game_scene.call("add_cluster_magnets", 10)
