class_name GameOverScreen
extends CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_node("GameOverPanel/VBoxContainer/PlayAgainButton").pressed.connect(_on_play_again)
	get_node("GameOverPanel/VBoxContainer/MainMenuButton").pressed.connect(_on_main_menu)

	GameManager.game_over.connect(_on_game_over)


func _on_game_over() -> void:
	if GameManager.sandbox_entity != "":
		GameManager.return_to_main_menu()
		return
	AudioManager.play_sfx("game_over")
	AudioManager.stop_music()
	visible = true
	get_node("GameOverPanel").visible = true
	get_node("DimOverlay").visible = true
	get_tree().paused = true

	# Apply metallic panel styling
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
	get_node("GameOverPanel").add_theme_stylebox_override("panel", panel_style)

	# Color-coded labels
	get_node("GameOverPanel/VBoxContainer/FinalScoreLabel").text = "Final Score: %s" % _format_number(ScoreManager.score)
	get_node("GameOverPanel/VBoxContainer/FinalScoreLabel").add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	get_node("GameOverPanel/VBoxContainer/LevelReachedLabel").text = "Level Reached: %s" % str(GameManager.current_level)
	get_node("GameOverPanel/VBoxContainer/LivesLabel").text = "Lives Remaining: %s" % str(ScoreManager.lives)

	var reason_label = get_node("GameOverPanel/VBoxContainer/TimeOutLabel")
	if ScoreManager.lives <= 0:
		reason_label.text = "Out of lives!"
	else:
		reason_label.text = "Time bonus expired!"

	# Style buttons
	_style_button(get_node("GameOverPanel/VBoxContainer/PlayAgainButton"))
	_style_button(get_node("GameOverPanel/VBoxContainer/MainMenuButton"))

	_save_high_score(ScoreManager.score)


func _style_button(btn: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.35, 0.40)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = Color(0.20, 0.22, 0.25)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	btn.add_theme_color_override("font_hover_color", Color(0.3, 1.0, 0.4))


func _on_play_again() -> void:
	get_tree().paused = false
	visible = false
	GameManager.start_new_game()


func _on_main_menu() -> void:
	get_tree().paused = false
	visible = false
	GameManager.return_to_main_menu()


func _save_high_score(score: int) -> void:
	var path: String = "user://highscores.json"
	var scores: Array = []

	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.parse_string(file.get_as_text())
		file.close()
		if json is Array:
			for item in json:
				scores.append(int(item))

	scores.append(score)
	scores.sort()
	scores.reverse()
	if scores.size() > 10:
		scores.resize(10)

	var out_file = FileAccess.open(path, FileAccess.WRITE)
	out_file.store_string(JSON.stringify(scores))
	out_file.close()


func _exit_tree() -> void:
	if GameManager != null:
		GameManager.game_over.disconnect(_on_game_over)


func _format_number(num: int) -> String:
	var s: String = str(absi(num))
	var result: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	if num < 0:
		result = "-" + result
	return result
