class_name AmmoTinGD
extends PowerUpBase

## Ammo tins grant +10 laser cartridge charges.


func _ready() -> void:
	power_up_color = Color(0.2, 0.8, 0.2)
	super()


func _draw() -> void:
	var bob = sin(float(Time.get_ticks_msec()) / 500.0) * 2.0
	var offset = Vector2(0, bob)

	# Shadow
	draw_circle(Vector2(1, 3), 6.0, Color(0, 0, 0, 0.15))

	# 3D-look green crate
	var dark_green = Color(0.15, 0.5, 0.1)
	var light_green = Color(0.3, 0.7, 0.2)
	# Front face
	draw_rect(Rect2(offset + Vector2(-6, -5), Vector2(12, 11)), dark_green)
	# Top bevel
	draw_line(offset + Vector2(-6, -5), offset + Vector2(6, -5), light_green, 1.5)
	# Left bevel
	draw_line(offset + Vector2(-6, -5), offset + Vector2(-6, 6), light_green, 1.0)
	# Right/bottom shadow
	draw_line(offset + Vector2(6, -5), offset + Vector2(6, 6), dark_green.darkened(0.3), 1.0)
	draw_line(offset + Vector2(-6, 6), offset + Vector2(6, 6), dark_green.darkened(0.3), 1.0)
	# Red 5-pointed star in center
	var star_color = Color(0.9, 0.15, 0.1)
	var star_center = offset
	for i in range(5):
		var angle_outer = i * TAU / 5.0 - PI * 0.5
		var angle_inner = (i + 0.5) * TAU / 5.0 - PI * 0.5
		var outer_pt = star_center + Vector2(cos(angle_outer), sin(angle_outer)) * 3.5
		var inner_pt = star_center + Vector2(cos(angle_inner), sin(angle_inner)) * 1.5
		var next_outer = star_center + Vector2(cos(angle_outer + TAU / 5.0), sin(angle_outer + TAU / 5.0)) * 3.5
		draw_polygon(PackedVector2Array([star_center, outer_pt, inner_pt]),
			PackedColorArray([star_color, star_color, star_color]))
		draw_polygon(PackedVector2Array([star_center, inner_pt, next_outer]),
			PackedColorArray([star_color, star_color, star_color]))
	queue_redraw()


func apply_effect() -> void:
	var game_scene = get_tree().current_scene
	if game_scene.has_method("add_laser_ammo"):
		game_scene.call("add_laser_ammo", 10)
