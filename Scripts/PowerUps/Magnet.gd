class_name MagnetGD
extends PowerUpBase


func _ready() -> void:
	power_up_color = Color(1.0, 0.2, 0.2)
	duration = 10.0
	super()


func _draw() -> void:
	super()
	# U magnet shape
	draw_arc(Vector2(0, 2), 3.0, PI, TAU, 12, Color.WHITE, 2.0)
	draw_line(Vector2(-3, 2), Vector2(-3, -2), Color.WHITE, 2.0)
	draw_line(Vector2(3, 2), Vector2(3, -2), Color.WHITE, 2.0)


func apply_effect() -> void:
	var game_scene = get_tree().current_scene
	if game_scene.has_method("activate_magnet"):
		game_scene.call("activate_magnet", duration)
