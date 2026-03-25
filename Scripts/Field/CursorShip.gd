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
var _last_scroll_time: float = 0.0
const SCROLL_DEBOUNCE: float = 0.3  # seconds before scroll-down can load magnet after unload

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
	if DemoRecorder.is_playback():
		global_position = DemoRecorder.get_mouse_position()
	else:
		global_position = get_global_mouse_position()

	var field = get_parent() as PlayingField
	if field != null:
		var pos: Vector2 = global_position
		var field_min: Vector2 = field.global_position
		var field_max: Vector2 = field_min + Vector2(PlayingField.FIELD_PIXEL_WIDTH, PlayingField.FIELD_PIXEL_HEIGHT)
		_visible = pos.x >= field_min.x and pos.x <= field_max.x \
				and pos.y >= field_min.y and pos.y <= field_max.y

		var game_active: bool = GameManager.is_game_active and not GameManager.is_paused

		if DemoRecorder.is_playback():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif not _visible or not game_active:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	queue_redraw()


func _physics_process(_delta: float) -> void:
	# Emit signals from DemoRecorder action flags — works in both recording and playback.
	# During recording, _input() only records flags; signals fire here for consistent timing.
	if DemoRecorder.is_action_this_frame(DemoRecorder.ACT_TOGGLE_ORIENT):
		_vertical = not _vertical
		orientation_changed.emit(_vertical)
	if DemoRecorder.is_action_this_frame(DemoRecorder.ACT_LOAD_LASER):
		load_laser_requested.emit()
	if DemoRecorder.is_action_this_frame(DemoRecorder.ACT_LOAD_MAGNET):
		load_magnet_requested.emit()
	if DemoRecorder.is_action_this_frame(DemoRecorder.ACT_UNLOAD):
		unload_requested.emit()


func _input(event: InputEvent) -> void:
	# During playback, skip real input (handled by _physics_process)
	if DemoRecorder.is_playback():
		return

	# Only record action flags here — actual signal emission happens in _physics_process
	if event is InputEventMouseButton and event.pressed:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			DemoRecorder.record_action(DemoRecorder.ACT_TOGGLE_ORIENT)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_handle_scroll_up()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_scroll_down()
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			DemoRecorder.record_action(DemoRecorder.ACT_UNLOAD)

	# Touchpad pan gesture → treat as scroll wheel
	if event is InputEventPanGesture:
		if event.delta.y < -0.5:
			_handle_scroll_up()
		elif event.delta.y > 0.5:
			_handle_scroll_down()

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		match key_event.keycode:
			KEY_SPACE:
				DemoRecorder.record_action(DemoRecorder.ACT_TOGGLE_ORIENT)
			KEY_W:
				DemoRecorder.record_action(DemoRecorder.ACT_LOAD_LASER)
			KEY_D:
				DemoRecorder.record_action(DemoRecorder.ACT_LOAD_MAGNET)


func _handle_scroll_up() -> void:
	if _loaded_weapon == WeaponType.CLUSTER_MAGNET:
		DemoRecorder.record_action(DemoRecorder.ACT_UNLOAD)
		_last_scroll_time = Time.get_ticks_msec() / 1000.0
	elif not _has_charged_shot:
		var now = Time.get_ticks_msec() / 1000.0
		if now - _last_scroll_time > SCROLL_DEBOUNCE:
			DemoRecorder.record_action(DemoRecorder.ACT_LOAD_LASER)
			_last_scroll_time = now


func _handle_scroll_down() -> void:
	if _has_charged_shot:
		DemoRecorder.record_action(DemoRecorder.ACT_UNLOAD)
		_last_scroll_time = Time.get_ticks_msec() / 1000.0
	elif _loaded_weapon == WeaponType.CLUSTER_MAGNET:
		# Already magnet — ignore
		pass
	else:
		var now = Time.get_ticks_msec() / 1000.0
		if now - _last_scroll_time > SCROLL_DEBOUNCE:
			DemoRecorder.record_action(DemoRecorder.ACT_LOAD_MAGNET)
			_last_scroll_time = now


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
	var glow_color: Color
	if _has_charged_shot:
		glow_color = Color(1.0, 0.9, 0.2, 0.8)
	else:
		glow_color = Color(0.0, 0.9, 1.0, 0.6)

	# Soft outer glow
	var glow_alpha = 0.12 + sin(float(Time.get_ticks_msec()) / 400.0) * 0.05
	draw_circle(Vector2.ZERO, 14.0, Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha))

	# Ship body
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)
	])
	draw_polygon(body, PackedColorArray([ship_color]))
	var outline: PackedVector2Array = PackedVector2Array([body[0], body[1], body[2], body[3], body[0]])
	draw_polyline(outline, ship_color.lightened(0.3), 1.2)

	# Center jewel
	draw_circle(Vector2.ZERO, 2.0, glow_color)

	if _vertical:
		# Nozzles with gradient
		var nozzle_up: PackedVector2Array = PackedVector2Array([Vector2(-3, -6), Vector2(0, -13), Vector2(3, -6)])
		draw_polygon(nozzle_up, PackedColorArray([glow_color, glow_color.lightened(0.3), glow_color]))
		var nozzle_down: PackedVector2Array = PackedVector2Array([Vector2(-3, 6), Vector2(0, 13), Vector2(3, 6)])
		draw_polygon(nozzle_down, PackedColorArray([glow_color, glow_color.lightened(0.3), glow_color]))
		draw_dashed_line(Vector2(0, -13), Vector2(0, -30), glow_color, 1.0, 3.0)
		draw_dashed_line(Vector2(0, 13), Vector2(0, 30), glow_color, 1.0, 3.0)
	else:
		var nozzle_left: PackedVector2Array = PackedVector2Array([Vector2(-6, -3), Vector2(-13, 0), Vector2(-6, 3)])
		draw_polygon(nozzle_left, PackedColorArray([glow_color, glow_color.lightened(0.3), glow_color]))
		var nozzle_right: PackedVector2Array = PackedVector2Array([Vector2(6, -3), Vector2(13, 0), Vector2(6, 3)])
		draw_polygon(nozzle_right, PackedColorArray([glow_color, glow_color.lightened(0.3), glow_color]))
		draw_dashed_line(Vector2(-13, 0), Vector2(-30, 0), glow_color, 1.0, 3.0)
		draw_dashed_line(Vector2(13, 0), Vector2(30, 0), glow_color, 1.0, 3.0)

	# Crackling effect when laser-charged
	if _has_charged_shot:
		var t = float(Time.get_ticks_msec()) / 100.0
		for i in range(4):
			var angle = fmod(t + i * 1.57, TAU)
			var dist = 6.0 + sin(t * 3.0 + i) * 3.0
			var spark_end = Vector2(cos(angle) * dist, sin(angle) * dist)
			draw_line(Vector2.ZERO, spark_end, Color(1.0, 1.0, 0.5, 0.6), 1.0)


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
