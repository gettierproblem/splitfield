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

	# Apply dark metallic panel background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.10, 0.13)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.25, 0.25, 0.30)
	# Bevel effect — lighter top/left, darker bottom/right
	panel_style.shadow_color = Color(0.05, 0.05, 0.08)
	panel_style.shadow_size = 2
	panel.add_theme_stylebox_override("panel", panel_style)

	_level_label = get_node("HUDPanel/LevelLabel")
	_multiplier_label = get_node("HUDPanel/MultiplierLabel")
	_weapon_label = get_node("HUDPanel/WeaponLabel")
	_weapon_label.visible = false
	_orientation_label = get_node("HUDPanel/OrientationLabel")
	_orientation_label.visible = false
	# Also hide the separator above them
	get_node("HUDPanel/Separator3").visible = false
	get_node("HUDPanel/Separator4").visible = false

	# Color the level label
	_level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))

	# Replace static labels with rolling digit versions — color-coded
	_score_roller = _replace_with_roller(panel, "ScoreLabel", "SCORE  ", "", 20.0)
	_score_roller.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))  # Red digits

	_lives_roller = _replace_with_roller(panel, "LivesLabel", "LIVES  ", "", 20.0, false)
	_lives_roller.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))  # Green digits

	_fill_roller = _replace_with_roller(panel, "FillLabel", "FILL  ", "%", 20.0, false)
	_fill_roller.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))  # Cyan digits

	_bonus_roller = _replace_with_roller(panel, "TimedBonusLabel", "BONUS  ", "", 15.0)

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
	var base_y: float = 340.0

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

	# Laser ammo — icon + count
	var ammo_icon = _AmmoIcon.new()
	ammo_icon.position = Vector2(22, base_y + 73)
	panel.add_child(ammo_icon)

	_laser_ammo_label = Label.new()
	_laser_ammo_label.text = "0"
	_laser_ammo_label.offset_left = 38
	_laser_ammo_label.offset_top = base_y + 64
	_laser_ammo_label.offset_right = 200
	_laser_ammo_label.offset_bottom = base_y + 82
	_laser_ammo_label.add_theme_font_size_override("font_size", 13)
	_laser_ammo_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	panel.add_child(_laser_ammo_label)

	# Cluster magnets — icon + count
	var magnet_icon = _MagnetIcon.new()
	magnet_icon.position = Vector2(22, base_y + 97)
	panel.add_child(magnet_icon)

	_magnet_ammo_label = Label.new()
	_magnet_ammo_label.text = "0"
	_magnet_ammo_label.offset_left = 38
	_magnet_ammo_label.offset_top = base_y + 88
	_magnet_ammo_label.offset_right = 200
	_magnet_ammo_label.offset_bottom = base_y + 106
	_magnet_ammo_label.add_theme_font_size_override("font_size", 13)
	_magnet_ammo_label.add_theme_color_override("font_color", Color(0.8, 0.3, 1.0))
	panel.add_child(_magnet_ammo_label)

	# Separator between loadout and controls
	var sep2 = HSeparator.new()
	sep2.offset_left = 8
	sep2.offset_top = base_y + 114
	sep2.offset_right = 200
	sep2.offset_bottom = base_y + 118
	panel.add_child(sep2)


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
	_laser_ammo_label.text = str(laser_ammo)
	_magnet_ammo_label.text = str(cluster_magnets)

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


# --- HUD Icons ---

class _AmmoIcon extends Node2D:
	func _draw() -> void:
		# Green ammo crate (matches AmmoTin powerup)
		var dark_green = Color(0.15, 0.5, 0.1)
		var light_green = Color(0.3, 0.7, 0.2)
		draw_rect(Rect2(Vector2(-6, -5), Vector2(12, 11)), dark_green)
		draw_line(Vector2(-6, -5), Vector2(6, -5), light_green, 1.5)
		draw_line(Vector2(-6, -5), Vector2(-6, 6), light_green, 1.0)
		draw_line(Vector2(6, -5), Vector2(6, 6), dark_green.darkened(0.3), 1.0)
		draw_line(Vector2(-6, 6), Vector2(6, 6), dark_green.darkened(0.3), 1.0)
		# Red star
		var star_color = Color(0.9, 0.15, 0.1)
		for i in range(5):
			var angle_outer = i * TAU / 5.0 - PI * 0.5
			var angle_inner = (i + 0.5) * TAU / 5.0 - PI * 0.5
			var outer_pt = Vector2(cos(angle_outer), sin(angle_outer)) * 3.5
			var inner_pt = Vector2(cos(angle_inner), sin(angle_inner)) * 1.5
			draw_line(outer_pt, inner_pt, star_color, 1.2)


class _MagnetIcon extends Node2D:
	func _draw() -> void:
		# Red horseshoe magnet (matches ClusterMagnetPickup)
		var magnet_red = Color(0.85, 0.15, 0.1)
		draw_arc(Vector2(0, 1), 4.5, PI, TAU, 16, magnet_red, 3.5)
		draw_line(Vector2(-4.5, 1), Vector2(-4.5, 5), magnet_red, 3.5)
		draw_line(Vector2(4.5, 1), Vector2(4.5, 5), magnet_red, 3.5)
		draw_line(Vector2(-4.5, 4), Vector2(-4.5, 6), Color(0.8, 0.8, 0.85), 3.5)
		draw_line(Vector2(4.5, 4), Vector2(4.5, 6), Color(0.8, 0.8, 0.85), 3.5)
