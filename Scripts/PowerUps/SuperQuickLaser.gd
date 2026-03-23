class_name SuperQuickLaserGD
extends PowerUpBase


func _ready() -> void:
	power_up_color = Color(0.0, 1.0, 1.0)
	duration = 15.0
	super()


func _draw() -> void:
	super()
	# Lightning bolt icon
	draw_line(Vector2(-2, -4), Vector2(1, -1), Color.WHITE, 2.0)
	draw_line(Vector2(1, -1), Vector2(-1, 1), Color.WHITE, 2.0)
	draw_line(Vector2(-1, 1), Vector2(2, 4), Color.WHITE, 2.0)


func apply_effect() -> void:
	# GameScene handles the timer via signal
	var game_scene = get_tree().current_scene
	if game_scene.has_method("activate_super_quick_laser"):
		game_scene.call("activate_super_quick_laser", duration)
