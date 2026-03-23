class_name PauseMenu
extends CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_node("PausePanel/VBoxContainer/ResumeButton").pressed.connect(_on_resume)
	get_node("PausePanel/VBoxContainer/RestartButton").pressed.connect(_on_restart)
	get_node("PausePanel/VBoxContainer/QuitButton").pressed.connect(_on_quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	GameManager.toggle_pause()
	var paused: bool = GameManager.is_paused
	visible = paused
	get_node("PausePanel").visible = paused


func _on_resume() -> void:
	_toggle_pause()


func _on_restart() -> void:
	GameManager.is_paused = false
	get_tree().paused = false
	visible = false
	GameManager.load_game_scene()


func _on_quit() -> void:
	GameManager.return_to_main_menu()
