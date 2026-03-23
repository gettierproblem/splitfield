class_name LightningBoltGD
extends PowerUpBase

## Lightning bolts recharge barrier speed by 10%.


func _ready() -> void:
	power_up_color = Color(0.3, 0.8, 1.0)
	super()


func _draw() -> void:
	super()
	# Lightning bolt icon
	draw_line(Vector2(0, -5), Vector2(-2, -1), Color.YELLOW, 2.0)
	draw_line(Vector2(-2, -1), Vector2(2, -1), Color.YELLOW, 2.0)
	draw_line(Vector2(2, -1), Vector2(0, 5), Color.YELLOW, 2.0)


func apply_effect() -> void:
	var game_scene = get_tree().current_scene
	if game_scene.has_method("restore_barrier_charge"):
		game_scene.call("restore_barrier_charge")
