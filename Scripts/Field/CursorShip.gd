class_name CursorShip
extends Node2D

enum WeaponType { LASER_CARTRIDGE, CLUSTER_MAGNET }

signal load_laser_requested()
signal load_magnet_requested()
signal unload_requested()
signal orientation_changed(vertical: bool)

var _vertical: bool = false
var _visible: bool = true
var _loaded_weapon: int = WeaponType.LASER_CARTRIDGE
var _has_charged_shot: bool = false

var is_vertical: bool:
	get: return _vertical

var loaded_weapon: int:
	get: return _loaded_weapon

var has_charged_shot: bool:
	get: return _has_charged_shot


func set_charged_shot(charged: bool) -> void:
	_has_charged_shot = charged


func set_loaded_weapon(weapon: int) -> void:
	_loaded_weapon = weapon


func _ready() -> void:
	z_index = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()

	var field = get_parent() as PlayingField
	if field != null:
		var pos: Vector2 = global_position
		var field_min: Vector2 = field.global_position
		var field_max: Vector2 = field_min + Vector2(PlayingField.FIELD_PIXEL_WIDTH, PlayingField.FIELD_PIXEL_HEIGHT)
		_visible = pos.x >= field_min.x and pos.x <= field_max.x \
				and pos.y >= field_min.y and pos.y <= field_max.y

		var game_active: bool = GameManager.is_game_active and not GameManager.is_paused

		if not _visible or not game_active:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_vertical = not _vertical
			orientation_changed.emit(_vertical)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			load_laser_requested.emit()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			load_magnet_requested.emit()
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			unload_requested.emit()

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		match key_event.keycode:
			KEY_TAB:
				_vertical = not _vertical
				orientation_changed.emit(_vertical)
			KEY_W:
				load_laser_requested.emit()
			KEY_D:
				load_magnet_requested.emit()


func _draw() -> void:
	if not _visible:
		return
	if not GameManager.is_game_active or GameManager.is_paused:
		return

	if _loaded_weapon == WeaponType.CLUSTER_MAGNET:
		_draw_magnet_ship()
	else:
		_draw_laser_ship()


func _draw_laser_ship() -> void:
	var ship_color: Color = Color(0.9, 0.85, 0.7)
	# Glow cyan normally, bright yellow when charged
	var glow_color: Color
	if _has_charged_shot:
		glow_color = Color(1.0, 0.9, 0.2, 0.8)
	else:
		glow_color = Color(0.0, 0.9, 1.0, 0.6)

	var body: PackedVector2Array = PackedVector2Array([
		Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)
	])
	draw_polygon(body, PackedColorArray([ship_color]))
	var outline: PackedVector2Array = PackedVector2Array([body[0], body[1], body[2], body[3], body[0]])
	draw_polyline(outline, ship_color.lightened(0.3), 1.0)

	if _vertical:
		var nozzle_up: PackedVector2Array = PackedVector2Array([Vector2(-3, -6), Vector2(0, -12), Vector2(3, -6)])
		draw_polygon(nozzle_up, PackedColorArray([glow_color]))
		var nozzle_down: PackedVector2Array = PackedVector2Array([Vector2(-3, 6), Vector2(0, 12), Vector2(3, 6)])
		draw_polygon(nozzle_down, PackedColorArray([glow_color]))
		draw_dashed_line(Vector2(0, -12), Vector2(0, -28), glow_color, 1.0, 3.0)
		draw_dashed_line(Vector2(0, 12), Vector2(0, 28), glow_color, 1.0, 3.0)
	else:
		var nozzle_left: PackedVector2Array = PackedVector2Array([Vector2(-6, -3), Vector2(-12, 0), Vector2(-6, 3)])
		draw_polygon(nozzle_left, PackedColorArray([glow_color]))
		var nozzle_right: PackedVector2Array = PackedVector2Array([Vector2(6, -3), Vector2(12, 0), Vector2(6, 3)])
		draw_polygon(nozzle_right, PackedColorArray([glow_color]))
		draw_dashed_line(Vector2(-12, 0), Vector2(-28, 0), glow_color, 1.0, 3.0)
		draw_dashed_line(Vector2(12, 0), Vector2(28, 0), glow_color, 1.0, 3.0)


func _draw_magnet_ship() -> void:
	var ship_color: Color = Color(0.9, 0.85, 0.7)
	var magnet_color: Color = Color(0.8, 0.3, 1.0, 0.7)

	# Central body
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)
	])
	draw_polygon(body, PackedColorArray([ship_color]))
	var outline: PackedVector2Array = PackedVector2Array([body[0], body[1], body[2], body[3], body[0]])
	draw_polyline(outline, ship_color.lightened(0.3), 1.0)

	# Magnet icon on cursor
	draw_arc(Vector2.ZERO, 10.0, PI * 0.25, PI * 0.75, 12, magnet_color, 2.5)
	draw_line(Vector2(-7.0, -5.0), Vector2(-7.0, 8.0), Color(1.0, 0.3, 0.3, 0.7), 2.5)
	draw_line(Vector2(7.0, -5.0), Vector2(7.0, 8.0), Color(0.3, 0.3, 1.0, 0.7), 2.5)

	# Show aiming lines — magnets go perpendicular to aim direction
	var aim_color: Color = Color(0.8, 0.3, 1.0, 0.4)
	if _vertical:
		# Aiming vertical -> magnets go up/down
		draw_dashed_line(Vector2(0, -12), Vector2(0, -28), aim_color, 1.0, 3.0)
		draw_dashed_line(Vector2(0, 12), Vector2(0, 28), aim_color, 1.0, 3.0)
	else:
		# Aiming horizontal -> magnets go left/right
		draw_dashed_line(Vector2(-12, 0), Vector2(-28, 0), aim_color, 1.0, 3.0)
		draw_dashed_line(Vector2(12, 0), Vector2(28, 0), aim_color, 1.0, 3.0)

	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = sin(t * 3.0) * 0.3 + 0.7
	var pulse_color: Color = Color(0.5, 0.3, 1.0, 0.15 * pulse)
	draw_circle(Vector2.ZERO, 18.0, pulse_color)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
