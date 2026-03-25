class_name DemoPlaybackBar
extends CanvasLayer

## Playback transport bar shown at the bottom of the screen during demo playback.
## Shows progress slider, time display, speed controls, and stop button.

var _slider: HSlider
var _time_label: Label
var _level_label: Label
var _speed_btn: Button
var _pause_btn: Button
var _panel: Panel
var _dragging: bool = false
var _current_speed: float = 1.0

const BAR_HEIGHT: int = 40
const SPEEDS: Array = [1.0, 2.0, 4.0, 8.0]


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_current_speed = DemoRecorder._replay_speed
	_build_ui()
	DemoRecorder.playback_frame_advanced.connect(_on_frame_advanced)
	DemoRecorder.playback_finished.connect(_on_playback_finished)


func _build_ui() -> void:
	# Dark semi-transparent panel at bottom
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -BAR_HEIGHT
	_panel.offset_bottom = 0

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	panel_style.border_width_top = 1
	panel_style.border_color = Color(0.3, 0.3, 0.35)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# HBox layout
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 10
	hbox.offset_right = -10
	hbox.offset_top = 4
	hbox.offset_bottom = -4
	hbox.add_theme_constant_override("separation", 10)
	_panel.add_child(hbox)

	# "DEMO" label
	var demo_label = Label.new()
	demo_label.text = "DEMO"
	demo_label.add_theme_font_size_override("font_size", 12)
	demo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hbox.add_child(demo_label)

	# Pause/Play button
	_pause_btn = Button.new()
	_pause_btn.text = "||"
	_pause_btn.custom_minimum_size = Vector2(32, 0)
	_pause_btn.pressed.connect(_on_pause_play)
	_style_button(_pause_btn)
	hbox.add_child(_pause_btn)

	# Speed button
	var speed_btn = Button.new()
	speed_btn.text = "%dx" % int(_current_speed)
	speed_btn.custom_minimum_size = Vector2(40, 0)
	speed_btn.pressed.connect(_on_speed_cycle)
	_style_button(speed_btn)
	hbox.add_child(speed_btn)
	_speed_btn = speed_btn

	# Progress slider
	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.max_value = maxi(DemoRecorder.get_total_frames(), 1)
	_slider.value = 0
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.drag_started.connect(_on_drag_started)
	_slider.drag_ended.connect(_on_drag_ended)
	hbox.add_child(_slider)

	# Time label
	_time_label = Label.new()
	_time_label.text = "0:00 / 0:00"
	_time_label.add_theme_font_size_override("font_size", 12)
	_time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_time_label.custom_minimum_size = Vector2(90, 0)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(_time_label)

	# Level label
	_level_label = Label.new()
	_level_label.text = "Level 1"
	_level_label.add_theme_font_size_override("font_size", 12)
	_level_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	_level_label.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(_level_label)

	# Replay button
	var replay_btn = Button.new()
	replay_btn.text = "Replay"
	replay_btn.custom_minimum_size = Vector2(55, 0)
	replay_btn.pressed.connect(_on_replay)
	_style_button(replay_btn)
	hbox.add_child(replay_btn)

	# Stop button
	var stop_btn = Button.new()
	stop_btn.text = "Stop"
	stop_btn.custom_minimum_size = Vector2(50, 0)
	stop_btn.pressed.connect(_on_stop)
	_style_button(stop_btn)
	hbox.add_child(stop_btn)


func _style_button(btn: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.35, 0.40)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = Color(0.20, 0.22, 0.25)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	btn.add_theme_font_size_override("font_size", 11)


func _on_frame_advanced(frame: int, total: int) -> void:
	if not _dragging:
		_slider.max_value = total
		_slider.value = frame

	var current_time = DemoRecorder.get_time_string(frame)
	var total_time = DemoRecorder.get_time_string(total)
	_time_label.text = "%s / %s" % [current_time, total_time]
	_level_label.text = "Level %d" % GameManager.current_level


func _on_drag_started() -> void:
	_dragging = true


func _on_drag_ended(value_changed: bool) -> void:
	_dragging = false
	if value_changed:
		var target = int(_slider.value)
		DemoRecorder.seek_to_frame(target)
		# Seek pauses on arrival
		_pause_btn.text = ">"


func _on_pause_play() -> void:
	get_tree().paused = not get_tree().paused
	_pause_btn.text = ">" if get_tree().paused else "||"
	if get_tree().paused:
		AudioManager.pause_music()
	else:
		AudioManager.resume_music()


func _on_speed_cycle() -> void:
	var idx = SPEEDS.find(_current_speed)
	idx = (idx + 1) % SPEEDS.size()
	_current_speed = SPEEDS[idx]
	DemoRecorder.set_playback_speed(_current_speed)
	_update_speed_label()


func _update_speed_label() -> void:
	_speed_btn.text = "%dx" % int(_current_speed)


func _on_replay() -> void:
	get_tree().paused = true
	DemoRecorder.replay()


func _on_stop() -> void:
	DemoRecorder.stop_playback()


func _on_playback_finished() -> void:
	queue_free()
