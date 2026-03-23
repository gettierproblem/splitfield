class_name HUD
extends CanvasLayer

var _level_label: Label
var _multiplier_label: Label
var _weapon_label: Label
var _orientation_label: Label
var _extra_life_label: Label

# Ammo/charge display
var _laser_ammo_label: Label
var _magnet_ammo_label: Label
var _laser_charge_bar: ProgressBar
var _laser_charge_label: Label

# Rolling digit displays
var _score_roller: RollingDigitLabel
var _lives_roller: RollingDigitLabel
var _fill_roller: RollingDigitLabel
var _bonus_roller: RollingDigitLabel


func _ready() -> void:
	var panel = get_node("HUDPanel")
	_level_label = get_node("HUDPanel/LevelLabel")
	_multiplier_label = get_node("HUDPanel/MultiplierLabel")
	_weapon_label = get_node("HUDPanel/WeaponLabel")
	_orientation_label = get_node("HUDPanel/OrientationLabel")

	# Replace static labels with rolling digit versions
	_score_roller = _replace_with_roller(panel, "ScoreLabel", "Score: ", "", 20.0)
	_lives_roller = _replace_with_roller(panel, "LivesLabel", "Lives: ", "", 20.0, false)
	_fill_roller = _replace_with_roller(panel, "FillLabel", "Fill: ", "%", 20.0, false)
	_bonus_roller = _replace_with_roller(panel, "TimedBonusLabel", "Bonus: ", "", 15.0)

	# Create ammo/charge section
	_create_ammo_section(panel)

	# Extra life indicator
	_extra_life_label = Label.new()
	_extra_life_label.text = "+1 LIFE!"
	_extra_life_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_extra_life_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_extra_life_label.add_theme_font_size_override("font_size", 20)
	_extra_life_label.visible = false
	_extra_life_label.offset_left = 816.0
	_extra_life_label.offset_right = 1024.0
	_extra_life_label.offset_top = 120.0
	_extra_life_label.offset_bottom = 145.0
	add_child(_extra_life_label)

	ScoreManager.score_changed.connect(_on_score_changed)
	ScoreManager.lives_changed.connect(_on_lives_changed)
	ScoreManager.multiplier_changed.connect(_on_multiplier_changed)
	ScoreManager.extra_life_earned.connect(_on_extra_life_earned)

	update_all()


func _create_ammo_section(panel: Panel) -> void:
	var base_y: float = 420.0

	# Section header
	var sep = HSeparator.new()
	sep.offset_left = 8
	sep.offset_top = base_y - 10
	sep.offset_right = 200
	sep.offset_bottom = base_y - 6
	panel.add_child(sep)

	var header_label = Label.new()
	header_label.text = "LOADOUT"
	header_label.offset_left = 8
	header_label.offset_top = base_y
	header_label.offset_right = 200
	header_label.offset_bottom = base_y + 18
	header_label.add_theme_font_size_override("font_size", 12)
	header_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(header_label)

	# Laser charge bar
	_laser_charge_label = Label.new()
	_laser_charge_label.text = "Barrier Speed"
	_laser_charge_label.offset_left = 8
	_laser_charge_label.offset_top = base_y + 24
	_laser_charge_label.offset_right = 200
	_laser_charge_label.offset_bottom = base_y + 40
	_laser_charge_label.add_theme_font_size_override("font_size", 11)
	_laser_charge_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	panel.add_child(_laser_charge_label)

	_laser_charge_bar = ProgressBar.new()
	_laser_charge_bar.offset_left = 8
	_laser_charge_bar.offset_top = base_y + 42
	_laser_charge_bar.offset_right = 200
	_laser_charge_bar.offset_bottom = base_y + 56
	_laser_charge_bar.min_value = 0
	_laser_charge_bar.max_value = 100
	_laser_charge_bar.value = 0
	_laser_charge_bar.show_percentage = false

	# Style the progress bar
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	_laser_charge_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.7, 1.0)
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	_laser_charge_bar.add_theme_stylebox_override("fill", fill_style)

	panel.add_child(_laser_charge_bar)

	# Laser ammo
	_laser_ammo_label = Label.new()
	_laser_ammo_label.text = "Ammo: 0"
	_laser_ammo_label.offset_left = 8
	_laser_ammo_label.offset_top = base_y + 64
	_laser_ammo_label.offset_right = 200
	_laser_ammo_label.offset_bottom = base_y + 82
	_laser_ammo_label.add_theme_font_size_override("font_size", 13)
	_laser_ammo_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	panel.add_child(_laser_ammo_label)

	# Cluster magnets
	_magnet_ammo_label = Label.new()
	_magnet_ammo_label.text = "Magnets: 0"
	_magnet_ammo_label.offset_left = 8
	_magnet_ammo_label.offset_top = base_y + 88
	_magnet_ammo_label.offset_right = 200
	_magnet_ammo_label.offset_bottom = base_y + 106
	_magnet_ammo_label.add_theme_font_size_override("font_size", 13)
	_magnet_ammo_label.add_theme_color_override("font_color", Color(0.8, 0.3, 1.0))
	panel.add_child(_magnet_ammo_label)


func _replace_with_roller(parent: Panel, label_name: String, prefix: String,
		suffix: String, roll_speed: float, comma_format: bool = true) -> RollingDigitLabel:
	var original: Label = parent.get_node(label_name)

	var roller = RollingDigitLabel.new()
	roller.name = label_name
	roller.layout_mode = 1
	roller.offset_left = original.offset_left
	roller.offset_top = original.offset_top
	roller.offset_right = original.offset_right
	roller.offset_bottom = original.offset_bottom

	if original.has_theme_color_override("font_color"):
		roller.add_theme_color_override("font_color", original.get_theme_color("font_color"))
	if original.has_theme_font_size_override("font_size"):
		roller.add_theme_font_size_override("font_size", original.get_theme_font_size("font_size"))

	roller.configure(prefix, suffix, roll_speed, comma_format)

	original.queue_free()
	parent.add_child(roller)

	roller.set_value(0, true)
	return roller


func update_all() -> void:
	_on_score_changed(ScoreManager.score)
	_on_lives_changed(ScoreManager.lives)
	_on_multiplier_changed(ScoreManager.multiplier)
	_level_label.text = "Level %s" % str(GameManager.current_level)
	update_fill(0)


func _on_score_changed(score: int) -> void:
	_score_roller.set_value(score)


func _on_lives_changed(lives: int) -> void:
	_lives_roller.set_value(lives)


func _on_multiplier_changed(mult: float) -> void:
	_multiplier_label.visible = mult != 1.0
	_multiplier_label.text = "x%.1f" % mult


func _on_extra_life_earned() -> void:
	_extra_life_label.visible = true
	_extra_life_label.modulate = Color(1, 1, 1, 1)

	var tween = create_tween()
	tween.tween_property(_extra_life_label, "modulate", Color(1, 1, 1, 1), 0.1)
	tween.tween_interval(1.0)
	tween.tween_property(_extra_life_label, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): _extra_life_label.visible = false)

	AudioManager.play_sfx("extra_life")


func update_fill(percent: float) -> void:
	_fill_roller.set_value(int(percent))


func update_weapon(weapon) -> void:
	var weapon_name: String = "Laser Cartridge" if weapon == CursorShip.WeaponType.LASER_CARTRIDGE else "Cluster Magnet"
	_weapon_label.text = "Weapon: %s" % weapon_name
	_weapon_label.add_theme_color_override("font_color",
		Color(0.0, 0.9, 1.0) if weapon == CursorShip.WeaponType.LASER_CARTRIDGE else Color(0.8, 0.3, 1.0))


func update_orientation(vertical: bool) -> void:
	_orientation_label.text = "Direction: %s" % ("Vertical" if vertical else "Horizontal")


func update_ammo(laser_ammo: int, cluster_magnets: int) -> void:
	_laser_ammo_label.text = "Ammo: %s" % str(laser_ammo)
	_magnet_ammo_label.text = "Magnets: %s" % str(cluster_magnets)

	_laser_ammo_label.add_theme_color_override("font_color",
		Color(0.2, 0.8, 0.2) if laser_ammo > 0 else Color(0.5, 0.5, 0.5))
	_magnet_ammo_label.add_theme_color_override("font_color",
		Color(0.8, 0.3, 1.0) if cluster_magnets > 0 else Color(0.5, 0.5, 0.5))


func update_laser_charge(charged: bool) -> void:
	_laser_charge_label.text = "Laser  CHARGED" if charged else "Laser  ready"
	_laser_charge_label.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.2) if charged else Color(0.3, 0.5, 0.6))


func update_barrier_charge(charge: float, max_charge: float) -> void:
	_laser_charge_bar.value = (charge / max_charge) * 100.0


func update_timed_bonus(bonus: int) -> void:
	_bonus_roller.set_value(bonus)

	var ratio: float = clampf(bonus / 3000.0, 0.0, 1.0)
	var c: Color
	if ratio > 0.5:
		c = Color(1.0 - (ratio - 0.5) * 2.0, 1.0, 0.3)
	else:
		c = Color(1.0, ratio * 2.0, 0.1)
	_bonus_roller.add_theme_color_override("font_color", c)


func _exit_tree() -> void:
	if ScoreManager != null:
		ScoreManager.score_changed.disconnect(_on_score_changed)
		ScoreManager.lives_changed.disconnect(_on_lives_changed)
		ScoreManager.multiplier_changed.disconnect(_on_multiplier_changed)
		ScoreManager.extra_life_earned.disconnect(_on_extra_life_earned)
