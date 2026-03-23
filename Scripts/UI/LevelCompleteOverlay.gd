class_name LevelCompleteOverlay
extends CanvasLayer

var _title_label: Label
var _bonus_achieved_label: Label
var _bonus_achieved_value: Label
var _isolation_label: Label
var _isolation_value: Label
var _overachiever_label: Label
var _overachiever_value: Label
var _multiplier_label: Label
var _multiplier_value: Label
var _total_bonus_label: Label
var _total_bonus_value: Label
var _total_score_label: Label
var _next_level_button: Button
var _panel: Panel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_panel = get_node("LevelCompletePanel")
	var vbox = _panel.get_node("VBoxContainer")

	_title_label = vbox.get_node("TitleLabel")
	_bonus_achieved_label = vbox.get_node("BonusAchievedLabel")
	_bonus_achieved_value = vbox.get_node("BonusAchievedValue")
	_isolation_label = vbox.get_node("IsolationLabel")
	_isolation_value = vbox.get_node("IsolationValue")
	_overachiever_label = vbox.get_node("OverachieverLabel")
	_overachiever_value = vbox.get_node("OverachieverValue")
	_multiplier_label = vbox.get_node("MultiplierLabel")
	_multiplier_value = vbox.get_node("MultiplierValue")
	_total_bonus_label = vbox.get_node("TotalBonusLabel")
	_total_bonus_value = vbox.get_node("TotalBonusValue")
	_total_score_label = vbox.get_node("TotalScoreLabel")
	_next_level_button = vbox.get_node("NextLevelButton")

	_next_level_button.pressed.connect(_on_next_level)


func show_level_complete(fill_percent: float, timed_bonus: int = 0) -> void:
	visible = true
	_panel.visible = true
	get_tree().paused = true

	var overfill_bonus: int = ScoreManager.calc_overachiever_bonus(fill_percent)
	var isolation_count: int = _count_isolated_regions()
	var isolation_score: int = isolation_count * 100
	var subtotal: int = timed_bonus + overfill_bonus + isolation_score
	var multiplier: float = ScoreManager.multiplier
	var total_bonus: int = int(subtotal * multiplier)

	_title_label.text = "LEVEL %s COMPLETE" % str(GameManager.current_level)
	_bonus_achieved_label.text = "BONUS ACHIEVED"
	_bonus_achieved_value.text = _format_number(timed_bonus)
	_isolation_label.text = "ISOLATION  x%s" % str(isolation_count)
	_isolation_value.text = _format_number(isolation_score)

	if overfill_bonus > 0:
		_overachiever_label.visible = true
		_overachiever_value.visible = true
		_overachiever_label.text = "OVERACHIEVER  %.1f%%" % fill_percent
		_overachiever_value.text = _format_number(overfill_bonus)
	else:
		_overachiever_label.visible = false
		_overachiever_value.visible = false

	# Show multiplier row only when not 1x
	if multiplier != 1.0:
		_multiplier_label.visible = true
		_multiplier_value.visible = true
		_multiplier_label.text = "MULTIPLIER"
		_multiplier_value.text = "x%s" % str(multiplier)
	else:
		_multiplier_label.visible = false
		_multiplier_value.visible = false

	# Apply multiplied bonus to score, then reset multiplier for next level
	ScoreManager.apply_multiplier_and_add(subtotal)
	ScoreManager.multiplier = 1.0

	_total_bonus_label.text = "TOTAL BONUS"
	_total_bonus_value.text = _format_number(total_bonus)
	_total_score_label.text = "TOTAL SCORE  %s" % _format_number(ScoreManager.score)


func _count_isolated_regions() -> int:
	var game_scene = get_parent()
	var playing_field = game_scene.get_node("PlayingField") if game_scene else null
	if playing_field != null:
		return playing_field.isolated_ball_count
	return 0


func _on_next_level() -> void:
	get_tree().paused = false
	visible = false
	GameManager.advance_to_next_level()


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
