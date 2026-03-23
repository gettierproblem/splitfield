extends Node2D

## Simple static drawing of Bosco's shark fin for the tutorial page.

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var fin_color: Color = Color(0.35, 0.35, 0.45)
	var fin_height: float = 14.0
	var fin_width: float = 10.0

	# Shadow
	draw_polygon(
		PackedVector2Array([
			Vector2(1.5, 1.5),
			Vector2(-fin_width * 0.5 + 1.5, 1.5),
			Vector2(fin_width * 0.2 + 1.5, -fin_height + 1.5)
		]),
		PackedColorArray([Color(0, 0, 0, 0.4)])
	)

	# Main fin
	var fin := PackedVector2Array([
		Vector2(0, 0),
		Vector2(-fin_width * 0.5, 0),
		Vector2(fin_width * 0.2, -fin_height)
	])
	draw_polygon(fin, PackedColorArray([fin_color]))
	draw_line(fin[2], fin[0], fin_color.lightened(0.3), 1.5)
	draw_line(fin[2], fin[1], fin_color.darkened(0.2), 1.0)
	draw_line(fin[0], fin[1], fin_color.darkened(0.1), 1.5)

	# Water ripple
	var ripple_color: Color = Color(0.5, 0.7, 0.9, 0.3)
	draw_line(Vector2(-8, 1), Vector2(8, 1), ripple_color, 1.0)
	draw_line(Vector2(-6, 3), Vector2(6, 3), ripple_color, 0.8)
