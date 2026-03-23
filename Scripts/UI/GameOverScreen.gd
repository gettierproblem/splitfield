class_name GameOverScreen
extends CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_node("GameOverPanel/VBoxContainer/PlayAgainButton").pressed.connect(_on_play_again)
	get_node("GameOverPanel/VBoxContainer/MainMenuButton").pressed.connect(_on_main_menu)

	GameManager.game_over.connect(_on_game_over)


func _on_game_over() -> void:
	visible = true
	get_node("GameOverPanel").visible = true
	get_node("DimOverlay").visible = true
	get_tree().paused = true

	get_node("GameOverPanel/VBoxContainer/FinalScoreLabel").text = "Final Score: %s" % _format_number(ScoreManager.score)
	get_node("GameOverPanel/VBoxContainer/LevelReachedLabel").text = "Level Reached: %s" % str(GameManager.current_level)
	get_node("GameOverPanel/VBoxContainer/LivesLabel").text = "Lives Remaining: %s" % str(ScoreManager.lives)

	var reason_label = get_node("GameOverPanel/VBoxContainer/TimeOutLabel")
	if ScoreManager.lives <= 0:
		reason_label.text = "Out of lives!"
	else:
		reason_label.text = "Time bonus expired!"

	_save_high_score(ScoreManager.score)


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
