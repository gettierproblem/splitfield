class_name MainMenu
extends Control


var _tutorial_page: int = 0
var _tutorial_pages: Array = []

const FPS_OPTIONS: Array = [0, 30, 60, 120, 144, 240]
const FPS_LABELS: Array = ["Unlimited", "30", "60", "120", "144", "240"]
const CONFIG_PATH: String = "user://settings.cfg"

func _ready() -> void:
	AudioManager.stop_music()
	get_node("VBoxContainer/NewGameButton").pressed.connect(_on_new_game)
	get_node("VBoxContainer/HowToPlayButton").pressed.connect(_on_how_to_play)
	get_node("VBoxContainer/OptionsButton").pressed.connect(_on_options)
	get_node("VBoxContainer/QuitButton").pressed.connect(_on_quit)
	if OS.has_feature("web"):
		get_node("VBoxContainer/QuitButton").visible = false
	get_node("HighScoresPanel/ClearButton").pressed.connect(_on_clear_high_scores)
	get_node("OptionsPanel/BackButton").pressed.connect(_on_options_back)
	get_node("TutorialPanel/BackButton").pressed.connect(_on_tutorial_back)
	get_node("TutorialPanel/PrevButton").pressed.connect(_on_tutorial_prev)
	get_node("TutorialPanel/NextButton").pressed.connect(_on_tutorial_next)
	_build_tutorial_pages()
	_setup_fps_option(get_node("OptionsPanel/FPSOption"))
	_load_settings()
	_apply_metallic_styling()
	_load_high_scores()

	# Return to tutorial if coming back from sandbox
	if GameManager.return_to_tutorial:
		GameManager.return_to_tutorial = false
		get_node("VBoxContainer").visible = false
		get_node("HighScoresPanel").visible = false
		get_node("TutorialPanel").visible = true
		_tutorial_page = GameManager.return_to_tutorial_page
		_show_tutorial_page()


func _apply_metallic_styling() -> void:
	# Title glow — golden text with outline feel
	var title = get_node("TitleLabel")
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_color_override("font_outline_color", Color(0.6, 0.4, 0.0))
	title.add_theme_constant_override("outline_size", 3)

	# Metallic button style
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.15, 0.15, 0.18)
	button_style.border_width_left = 1
	button_style.border_width_top = 1
	button_style.border_width_right = 1
	button_style.border_width_bottom = 1
	button_style.border_color = Color(0.35, 0.35, 0.40)
	button_style.corner_radius_top_left = 4
	button_style.corner_radius_top_right = 4
	button_style.corner_radius_bottom_left = 4
	button_style.corner_radius_bottom_right = 4

	var button_hover = button_style.duplicate()
	button_hover.bg_color = Color(0.20, 0.22, 0.25)
	button_hover.border_color = Color(0.45, 0.45, 0.50)

	var button_pressed = button_style.duplicate()
	button_pressed.bg_color = Color(0.10, 0.10, 0.12)

	for btn_name in ["NewGameButton", "HowToPlayButton", "OptionsButton", "QuitButton"]:
		var btn = get_node("VBoxContainer/" + btn_name)
		btn.add_theme_stylebox_override("normal", button_style)
		btn.add_theme_stylebox_override("hover", button_hover)
		btn.add_theme_stylebox_override("pressed", button_pressed)
		btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
		btn.add_theme_color_override("font_hover_color", Color(0.3, 1.0, 0.4))
		btn.add_theme_font_size_override("font_size", 18)

	# High scores panel — dark metallic
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.30, 0.30, 0.35)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	var hs_panel_style = panel_style.duplicate()
	hs_panel_style.bg_color = Color(0.05, 0.05, 0.07, 0.8)
	get_node("HighScoresPanel").add_theme_stylebox_override("panel", hs_panel_style)
	get_node("OptionsPanel").add_theme_stylebox_override("panel", panel_style)

	# Style back/nav buttons in panels
	for btn_path in ["HighScoresPanel/ClearButton", "OptionsPanel/BackButton",
			"TutorialPanel/BackButton", "TutorialPanel/PrevButton", "TutorialPanel/NextButton"]:
		var btn = get_node(btn_path)
		btn.add_theme_stylebox_override("normal", button_style)
		btn.add_theme_stylebox_override("hover", button_hover)
		btn.add_theme_stylebox_override("pressed", button_pressed)
		btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
		btn.add_theme_color_override("font_hover_color", Color(0.3, 1.0, 0.4))


func _on_new_game() -> void:
	GameManager.start_new_game()


func _on_clear_high_scores() -> void:
	var path: String = "user://highscores.json"
	# Delete associated demo files
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.parse_string(file.get_as_text())
		file.close()
		if json is Array:
			for entry in json:
				if entry is Dictionary:
					var demo: String = entry.get("demo", "")
					if demo != "" and FileAccess.file_exists(demo):
						DirAccess.remove_absolute(demo)
		DirAccess.remove_absolute(path)
	_load_high_scores()


func _on_quit() -> void:
	get_tree().quit()


func _on_options() -> void:
	get_node("VBoxContainer").visible = false
	get_node("HighScoresPanel").visible = false
	get_node("OptionsPanel").visible = true


func _on_options_back() -> void:
	get_node("OptionsPanel").visible = false
	get_node("VBoxContainer").visible = true
	get_node("HighScoresPanel").visible = true


func _setup_fps_option(option_btn: OptionButton) -> void:
	option_btn.clear()
	for i in FPS_LABELS.size():
		option_btn.add_item(FPS_LABELS[i], i)
	option_btn.item_selected.connect(_on_fps_selected)


func _on_fps_selected(index: int) -> void:
	Engine.max_fps = FPS_OPTIONS[index]
	_save_settings()


func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		var fps = config.get_value("video", "max_fps", 0)
		Engine.max_fps = fps
		var option_btn = get_node("OptionsPanel/FPSOption")
		var idx = FPS_OPTIONS.find(fps)
		if idx >= 0:
			option_btn.select(idx)


func _save_settings() -> void:
	var config = ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("video", "max_fps", Engine.max_fps)
	config.save(CONFIG_PATH)


func _on_how_to_play() -> void:
	get_node("VBoxContainer").visible = false
	get_node("HighScoresPanel").visible = false
	get_node("TutorialPanel").visible = true
	_tutorial_page = 0
	_show_tutorial_page()


func _on_tutorial_back() -> void:
	get_node("TutorialPanel").visible = false
	get_node("VBoxContainer").visible = true
	get_node("HighScoresPanel").visible = true


func _on_tutorial_prev() -> void:
	if _tutorial_page > 0:
		_tutorial_page -= 1
		_show_tutorial_page()


func _on_tutorial_next() -> void:
	if _tutorial_page < _tutorial_pages.size() - 1:
		_tutorial_page += 1
		_show_tutorial_page()


func _show_tutorial_page() -> void:
	var page = _tutorial_pages[_tutorial_page]
	var content = get_node("TutorialPanel/ContentLabel") as RichTextLabel
	content.text = page["text"]
	# Shrink content label if specimens will fill the rest
	if page.has("specimens"):
		content.size.y = page.get("start_y", 80) - 50
		content.scroll_active = false
		content.fit_content = true
	else:
		content.size.y = 450
		content.scroll_active = false
		content.fit_content = true
	get_node("TutorialPanel/PageLabel").text = "Page %d / %d" % [_tutorial_page + 1, _tutorial_pages.size()]
	get_node("TutorialPanel/PrevButton").disabled = (_tutorial_page == 0)
	get_node("TutorialPanel/NextButton").disabled = (_tutorial_page >= _tutorial_pages.size() - 1)
	_spawn_specimens()


func _clear_specimens() -> void:
	var container = get_node("TutorialPanel/Specimens")
	for child in container.get_children():
		child.queue_free()


func _spawn_specimens() -> void:
	_clear_specimens()
	var container = get_node("TutorialPanel/Specimens")
	var page = _tutorial_pages[_tutorial_page]
	if not page.has("specimens"):
		return

	var entries: Array = page["specimens"]
	var start_y: float = page.get("start_y", 80.0)
	var spacing: float = page.get("spacing", 60.0)

	for i in entries.size():
		var entry = entries[i]
		var row_y: float = start_y + i * spacing

		# Create specimen in a SubViewportContainer so it renders properly in UI
		var vp_size: float = minf(spacing - 4, 50)
		var svpc = SubViewportContainer.new()
		svpc.size = Vector2(vp_size, vp_size)
		svpc.position = Vector2(15, row_y - vp_size * 0.5)
		svpc.stretch = true

		var sv = SubViewport.new()
		sv.size = Vector2i(int(vp_size), int(vp_size))
		sv.transparent_bg = true
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		svpc.add_child(sv)

		var node: Node2D = entry["create"].call()
		node.position = Vector2(vp_size * 0.5, vp_size * 0.5)  # Center in viewport
		node.scale = Vector2(1.8, 1.8)
		node.set_process(false)
		node.set_physics_process(false)
		sv.add_child(node)
		# Defer redraw so it happens after node enters tree
		node.call_deferred("queue_redraw")

		container.add_child(svpc)

		# Description label next to it
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.text = entry["desc"]
		label.position = Vector2(70, row_y - 18)
		label.size = Vector2(580, spacing)
		label.fit_content = true
		label.scroll_active = false
		label.add_theme_font_size_override("normal_font_size", 13)
		container.add_child(label)

		# Clickable overlay to launch sandbox
		if entry.has("sandbox"):
			var btn = Button.new()
			btn.position = Vector2(0, row_y - spacing * 0.5)
			btn.size = Vector2(680, spacing)
			btn.flat = true
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var sandbox_type: String = entry["sandbox"]
			btn.pressed.connect(func():
				GameManager.return_to_tutorial_page = _tutorial_page
				GameManager.start_sandbox(sandbox_type))
			# Highlight on hover
			var hover_style = StyleBoxFlat.new()
			hover_style.bg_color = Color(1, 1, 1, 0.08)
			hover_style.corner_radius_top_left = 4
			hover_style.corner_radius_top_right = 4
			hover_style.corner_radius_bottom_left = 4
			hover_style.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("hover", hover_style)
			container.add_child(btn)

	# Hint text
	if page.has("specimens"):
		var hint = Label.new()
		hint.text = "Click any entry to try it in sandbox mode"
		hint.position = Vector2(0, start_y + entries.size() * spacing + 2)
		hint.size = Vector2(700, 20)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
		container.add_child(hint)

	# Extra text block below specimens (for Bosco/Powerups pages)
	if page.has("extra_text"):
		var extra = RichTextLabel.new()
		extra.bbcode_enabled = true
		extra.text = page["extra_text"]
		extra.position = Vector2(20, page["extra_text_y"])
		extra.size = Vector2(660, 200)
		extra.fit_content = true
		extra.scroll_active = false
		extra.add_theme_font_size_override("normal_font_size", 13)
		container.add_child(extra)


func _build_tutorial_pages() -> void:
	_tutorial_pages = [
		# Page 1: Basics
		{
			"text": """[b][color=yellow]BASICS[/color][/b]

[b]Goal:[/b] Fill 80% or more of the playing field by drawing barriers. Bouncing balls try to destroy your barriers before they complete.

[b]Controls:[/b]
  [color=cyan]Left Click[/color] — Fire barrier
  [color=cyan]Space / Right Click[/color] — Toggle horizontal/vertical orientation
  [color=cyan]ESC[/color] — Pause

[b]Barrier Charge:[/b]
Your barrier speed depends on your charge level. Lightning bolt powerups add 5% charge. Getting hit reduces charge by 10%. Charge carries over between levels.

[b]Scoring:[/b]
  Each completed barrier awards [color=green]%contained x 10[/color] points.
  Bonus points (time, overachiever, isolation) are awarded at level end.
  Score multiplier powerup applies to the level-end bonus."""
		},

		# Page 2: Balls / Enemies
		{
			"text": "[b][color=yellow]BALLS & ENEMIES[/color][/b]",
			"start_y": 100,
			"spacing": 60,
			"specimens": [
				{"create": func(): return PawnBallGD.new(), "desc": "[b][color=red]Pawn Ball[/color][/b]\nBasic bouncing enemy. The most common ball type.", "sandbox": "PawnBall"},
				{"create": func(): return NukeBallGD.new(), "desc": "[b][color=magenta]Nuke Ball[/color][/b]\nBounces with gravity. Detonates when trapped in a small area, destroying all nearby balls. 500 pts per kill.", "sandbox": "NukeBall"},
				{"create": func(): return OrangeBallGD.new(), "desc": "[b][color=orange]Orange Ball[/color][/b]\nAbsorbs momentum from other balls on collision. Unpredictable movement.", "sandbox": "OrangeBall"},
				{"create": func(): return OozeBallGD.new(), "desc": "[b][color=green]Ooze Ball[/color][/b]\nTime bomb! If not trapped quickly, splits into multiple Pawn balls.", "sandbox": "OozeBall"},
				{"create": func(): return GlassBallGD.new(), "desc": "[b][color=cyan]Glass Ball[/color][/b]\nShatters after 3 barrier hits. Two damaged glass balls colliding clears the area.", "sandbox": "GlassBall"},
				{"create": func(): return EyeballGD.new(), "desc": "[b][color=purple]Sentry Eye[/color][/b]\nActively hunts your cursor! Appears at level 20+.", "sandbox": "Eyeball"},
			]
		},

		# Page 3: Bosco
		{
			"text": "[b][color=yellow]BOSCO THE SHARK[/color][/b]",
			"start_y": 100,
			"spacing": 70,
			"specimens": [
				{"create": func(): return _create_bosco_specimen(), "desc": "[b][color=gray]Bosco[/color][/b] — Shark fin that appears at [b]level 10+[/b]. Patrols the edges, periodically dives through the field. Touching his fin or hitting your barrier costs a life. Passes through walls freely.", "sandbox": "Bosco"},
			],
			"extra_text_y": 160,
			"extra_text": """[b]States:[/b]
  [color=gray]Patrolling[/color] — Normal edge movement
  [color=red]Rampage[/color] — 2x speed, charges through field ([color=yellow]10x kill score![/color])
  [color=gray]Tired[/color] — Slow movement after rampage

[b]How to Kill Bosco:[/b]
  Enclose him in a newly completed barrier area.
  [color=green]+800 pts[/color] (regular isolation)
  [color=cyan]+2,500 pts[/color] (glass shatter kill)
  [color=magenta]+5,000 pts[/color] (nuke detonation kill)"""
		},

		# Page 4: Powerups
		{
			"text": "[b][color=yellow]POWERUPS[/color][/b]\nSpawn every 5s. Only one active at a time (except Score Multiplier).",
			"start_y": 110,
			"spacing": 45,
			"specimens": [
				{"create": func(): return LightningBoltGD.new(), "desc": "[b][color=cyan]Lightning Bolt[/color][/b]\n+5% barrier charge. Most common powerup.", "sandbox": "LightningBolt"},
				{"create": func(): return ScoreMultiplierGD.new(), "desc": "[b][color=yellow]Score Multiplier[/color][/b]\nCycles 0.5x/2x/3x/4x. Applied to bonus at level end. One per level.", "sandbox": "ScoreMultiplier"},
				{"create": func(): return ClusterMagnetPickupGD.new(), "desc": "[b][color=red]Cluster Magnet[/color][/b]\n+10 cluster magnet charges.", "sandbox": "ClusterMagnetPickup"},
				{"create": func(): return AmmoTinGD.new(), "desc": "[b][color=green]Ammo Tin[/color][/b]\n+10 laser cartridge charges.", "sandbox": "AmmoTin"},
				{"create": func(): return LifeKeyGD.new(), "desc": "[b][color=goldenrod]Life Key[/color][/b]\n+1-5 extra lives.", "sandbox": "LifeKey"},
				{"create": func(): return YummieCakeGD.new(), "desc": "[b][color=pink]Yummie Cake[/color][/b]\nDetonates on barrier hit, spawning 4-7 child powerups.", "sandbox": "YummieCake"},
			],
		},

		# Page 5: Loadout
		{
			"text": """[b][color=yellow]LOADOUT SYSTEM[/color][/b]

You can load special weapons using ammo collected from powerups.

[b]Controls:[/b]
  [color=cyan]W / Scroll Up[/color] — Load a laser cartridge
  [color=cyan]D / Scroll Down[/color] — Load a cluster magnet
  [color=cyan]Middle Click[/color] — Unload current weapon (returns ammo)

[b][color=cyan]Laser Cartridge[/color][/b]
  Consumes 1 ammo charge. Your next barrier fires at [b]4x speed[/b], then returns to normal.

[b][color=red]Cluster Magnet[/color][/b]
  Consumes 1 charge. Click to place two magnets on opposite walls along your aim axis. Magnets attract all balls with line-of-sight for 5 seconds.

[b]Ammo carries over between levels![/b]"""
		}
	]


func _create_bosco_specimen() -> Node2D:
	var node = Node2D.new()
	node.set_script(load("res://Scripts/UI/BoscoSpecimen.gd"))
	return node


func _load_high_scores() -> void:
	var container = get_node("HighScoresPanel/HighScoresScroll/HighScoresList")
	# Clear existing entries
	for child in container.get_children():
		child.queue_free()

	var path: String = "user://highscores.json"
	if not FileAccess.file_exists(path):
		_add_no_scores_label(container)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.parse_string(file.get_as_text())
	file.close()

	if not (json is Array) or json.is_empty():
		_add_no_scores_label(container)
		return

	for i in range(json.size()):
		var entry = json[i]
		var score: int
		var level: int = 0
		var demo_path: String = ""

		if entry is Dictionary:
			score = int(entry.get("score", 0))
			level = int(entry.get("level", 0))
			demo_path = entry.get("demo", "")
		else:
			# Old format: just an int
			score = int(entry)

		var text: String = "%d.  %s" % [i + 1, _format_number(score)]
		if level > 0:
			text += "  —  Level %d" % level

		var has_demo: bool = demo_path != "" and FileAccess.file_exists(demo_path)

		if has_demo:
			var btn = Button.new()
			btn.text = text
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size = Vector2(0, 28)
			_style_score_button(btn)
			var captured_path = demo_path
			btn.pressed.connect(func(): _play_demo(captured_path))
			container.add_child(btn)
		else:
			var lbl = Label.new()
			lbl.text = text
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
			lbl.custom_minimum_size = Vector2(0, 28)
			container.add_child(lbl)


func _add_no_scores_label(container: VBoxContainer) -> void:
	var lbl = Label.new()
	lbl.text = "No high scores yet!"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(lbl)


func _style_score_button(btn: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 0.6)
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.2, 0.25)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = Color(0.12, 0.15, 0.18, 0.8)
	hover.border_color = Color(0.3, 0.8, 0.4)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	btn.add_theme_color_override("font_hover_color", Color(0.4, 1.0, 0.5))
	btn.add_theme_font_size_override("font_size", 16)


func _play_demo(demo_path: String) -> void:
	DemoRecorder.start_playback(demo_path)


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
