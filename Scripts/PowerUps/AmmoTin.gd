class_name AmmoTinGD
extends PowerUpBase

## Ammo tins grant +10 laser cartridge charges.


func _ready() -> void:
	power_up_color = Color(0.2, 0.8, 0.2)
	super()


func _draw() -> void:
	super()
	draw_rect(Rect2(-3, -3, 6, 6), Color(0.4, 0.7, 0.3))
	draw_rect(Rect2(-3, -3, 6, 6), Color.WHITE, false, 1.0)
	draw_line(Vector2(-2, 0), Vector2(2, 0), Color.WHITE, 1.0)


func apply_effect() -> void:
	var game_scene = get_tree().current_scene
	if game_scene.has_method("add_laser_ammo"):
		game_scene.call("add_laser_ammo", 10)
