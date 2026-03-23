class_name PauseMenu
extends CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_node("PausePanel/VBoxContainer/ResumeButton").pressed.connect(_on_resume)
	get_node("PausePanel/VBoxContainer/RestartButton").pressed.connect(_on_restart)
	get_node("PausePanel/VBoxContainer/QuitButton").pressed.connect(_on_quit)
	_apply_metallic_styling()


func _apply_metallic_styling() -> void:
	# Panel background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.35, 0.35, 0.40)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	get_node("PausePanel").add_theme_stylebox_override("panel", panel_style)

	# Title in cyan
	var vbox = get_node("PausePanel/VBoxContainer")
	for child in vbox.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		elif child is Button:
			var btn_style = StyleBoxFlat.new()
			btn_style.bg_color = Color(0.15, 0.15, 0.18)
			btn_style.border_width_left = 1
			btn_style.border_width_top = 1
			btn_style.border_width_right = 1
			btn_style.border_width_bottom = 1
			btn_style.border_color = Color(0.35, 0.35, 0.40)
			btn_style.corner_radius_top_left = 4
			btn_style.corner_radius_top_right = 4
			btn_style.corner_radius_bottom_left = 4
			btn_style.corner_radius_bottom_right = 4
			child.add_theme_stylebox_override("normal", btn_style)
			var hover = btn_style.duplicate()
			hover.bg_color = Color(0.20, 0.22, 0.25)
			child.add_theme_stylebox_override("hover", hover)
			child.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
			child.add_theme_color_override("font_hover_color", Color(0.3, 1.0, 0.4))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	GameManager.toggle_pause()
	var paused: bool = GameManager.is_paused
	visible = paused
	get_node("PausePanel").visible = paused
	AudioManager.play_sfx("pause")


func _on_resume() -> void:
	_toggle_pause()


func _on_restart() -> void:
	GameManager.is_paused = false
	get_tree().paused = false
	visible = false
	GameManager.load_game_scene()


func _on_quit() -> void:
	GameManager.return_to_main_menu()
