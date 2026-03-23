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
	_panel.add_theme_stylebox_override("panel", panel_style)

	var overfill_bonus: int = ScoreManager.calc_overachiever_bonus(fill_percent)
	var isolation_count: int = _count_isolated_regions()
	var isolation_score: int = isolation_count * 100
	var subtotal: int = timed_bonus + overfill_bonus + isolation_score
	var multiplier: float = ScoreManager.multiplier
	var total_bonus: int = int(subtotal * multiplier)

	# Color the title green
	_title_label.text = "LEVEL %s COMPLETE" % str(GameManager.current_level)
	_title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))

	# Build reveal sequence: [label_node, value_node, target_value, color]
	var reveal_items: Array = []

	_bonus_achieved_label.text = "BONUS ACHIEVED"
	_bonus_achieved_value.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_bonus_achieved_label.modulate.a = 0
	_bonus_achieved_value.modulate.a = 0
	_bonus_achieved_value.text = "0"
	reveal_items.append([_bonus_achieved_label, _bonus_achieved_value, timed_bonus])

	_isolation_label.text = "ISOLATION  x%s" % str(isolation_count)
	_isolation_value.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_isolation_label.modulate.a = 0
	_isolation_value.modulate.a = 0
	_isolation_value.text = "0"
	reveal_items.append([_isolation_label, _isolation_value, isolation_score])

	if overfill_bonus > 0:
		_overachiever_label.visible = true
		_overachiever_value.visible = true
		_overachiever_label.text = "OVERACHIEVER  %.1f%%" % fill_percent
		_overachiever_value.add_theme_color_override("font_color", Color(0.9, 0.6, 1.0))
		_overachiever_label.modulate.a = 0
		_overachiever_value.modulate.a = 0
		_overachiever_value.text = "0"
		reveal_items.append([_overachiever_label, _overachiever_value, overfill_bonus])
	else:
		_overachiever_label.visible = false
		_overachiever_value.visible = false

	if multiplier != 1.0:
		_multiplier_label.visible = true
		_multiplier_value.visible = true
		_multiplier_label.text = "MULTIPLIER"
		_multiplier_value.text = "x%s" % str(multiplier)
		_multiplier_value.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_multiplier_label.modulate.a = 0
		_multiplier_value.modulate.a = 0
		# Multiplier doesn't count up — just reveals
		reveal_items.append([_multiplier_label, _multiplier_value, -1])
	else:
		_multiplier_label.visible = false
		_multiplier_value.visible = false

	# Resize panel to fit optional rows
	var extra_height: int = 0
	if _overachiever_label.visible:
		extra_height += 56
	if _multiplier_label.visible:
		extra_height += 56
	_panel.offset_top = -180 - extra_height / 2.0
	_panel.offset_bottom = 180 + extra_height / 2.0

	ScoreManager.apply_multiplier_and_add(subtotal)
	ScoreManager.multiplier = 1.0

	_total_bonus_label.text = "TOTAL BONUS"
	_total_bonus_value.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	_total_bonus_label.modulate.a = 0
	_total_bonus_value.modulate.a = 0
	_total_bonus_value.text = "0"
	reveal_items.append([_total_bonus_label, _total_bonus_value, total_bonus])

	_total_score_label.text = "TOTAL SCORE  %s" % _format_number(ScoreManager.score)
	_total_score_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_total_score_label.modulate.a = 0

	_next_level_button.modulate.a = 0
	# Style the next level button
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
	_next_level_button.add_theme_stylebox_override("normal", btn_style)
	_next_level_button.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))

	# Animated tally reveal — each row fades in, then its value counts up from 0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# Play level_tally once at the start
	tween.tween_callback(func(): AudioManager.play_sfx("level_tally"))
	tween.tween_interval(0.3)

	for item in reveal_items:
		var lbl: Label = item[0]
		var val_lbl: Label = item[1]
		var target: int = item[2]

		# Fade in the row
		tween.tween_property(lbl, "modulate:a", 1.0, 0.15)
		tween.parallel().tween_property(val_lbl, "modulate:a", 1.0, 0.15)

		if target > 0:
			# Play show_bonus as the number starts counting up
			var count_duration: float = clampf(float(target) / 5000.0, 0.3, 1.2)
			tween.tween_callback(func(): AudioManager.play_sfx("show_bonus"))
			tween.tween_method(
				func(v: float): val_lbl.text = _format_number(int(v)),
				0.0, float(target), count_duration)
		elif target == 0:
			tween.tween_callback(func(): val_lbl.text = "0")

		# Brief pause before next row
		tween.tween_interval(0.25)

	# Final total score reveal
	tween.tween_callback(func(): AudioManager.play_sfx("show_bonus"))
	tween.tween_property(_total_score_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.3)
	tween.tween_property(_next_level_button, "modulate:a", 1.0, 0.3)


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
