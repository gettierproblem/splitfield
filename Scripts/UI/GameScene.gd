class_name GameScene
extends Node2D

var _field: PlayingField
var _hud: HUD
var _pause_menu: PauseMenu
var _game_over_screen: GameOverScreen
var _level_complete_overlay: LevelCompleteOverlay

# Power-up spawn timer
var _power_up_timer: float = 5.0
const POWER_UP_SPAWN_INTERVAL: float = 5.0
var _multiplier_spawned: bool = false

# Bosco manager
var _bosco_manager: BoscoManager

# Barrier charge system (persists between levels via GameManager)
var _barrier_charge: float
const MAX_BARRIER_CHARGE: float = 80.0

# Fill tracking
var _last_fill_percent: float
var _last_fill_delta: float

# Timed bonus
var _timed_bonus: float
var _timed_bonus_decay_per_second: float

# Loadout system
var _cursor_ship: CursorShip
var _laser_ammo: int
var _cluster_magnets: int
var _laser_charged: bool = false
var _magnet_loaded: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _level_complete: bool = false
var _fps_label: Label


func _ready() -> void:
	_rng.randomize()

	_field = get_node("PlayingField")
	_hud = get_node("HUD")
	_pause_menu = get_node("PauseMenu")
	_game_over_screen = get_node("GameOverScreen")
	_level_complete_overlay = get_node("LevelCompleteOverlay")

	_field.fill_percent_changed.connect(_on_fill_percent_changed)
	_field.barrier_completed.connect(_on_barrier_completed)
	_field.beam_destroyed.connect(_on_beam_destroyed)

	GameManager.life_lost.connect(_on_life_lost)

	var level_data = GameManager.get_current_level_data()
	_timed_bonus = level_data.timed_bonus_start
	_timed_bonus_decay_per_second = level_data.timed_bonus_decay_per_second

	# Restore ammo and barrier charge from previous level
	_laser_ammo = GameManager.laser_ammo
	_cluster_magnets = GameManager.cluster_magnets
	_barrier_charge = GameManager.barrier_charge

	_spawn_balls_for_level()

	# Start gameplay music — cycles through tracks and loops
	var tracks: Array[String] = ["gameplay1", "gameplay2"]
	AudioManager.play_music_playlist(tracks)

	# Initialize Bosco manager
	_bosco_manager = BoscoManager.new()
	add_child(_bosco_manager)
	_bosco_manager.initialize_for_level(_field)

	_hud.update_all()
	_hud.update_timed_bonus(int(_timed_bonus))
	_hud.update_ammo(_laser_ammo, _cluster_magnets)
	_hud.update_laser_charge(_laser_charged)
	_hud.update_barrier_charge(_barrier_charge, MAX_BARRIER_CHARGE)

	# FPS counter — top-left overlay
	var fps_layer = CanvasLayer.new()
	fps_layer.layer = 100
	add_child(fps_layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(12, 4)
	_fps_label.add_theme_font_size_override("font_size", 12)
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	fps_layer.add_child(_fps_label)

	call_deferred("_connect_cursor_ship")


func _connect_cursor_ship() -> void:
	for child in _field.get_children():
		if child is CursorShip:
			_cursor_ship = child
			_cursor_ship.load_laser_requested.connect(_on_load_laser_requested)
			_cursor_ship.load_magnet_requested.connect(_on_load_magnet_requested)
			_cursor_ship.unload_requested.connect(_on_unload_requested)
			_cursor_ship.orientation_changed.connect(_on_orientation_changed)
			_hud.update_orientation(false)
			break


func _on_load_laser_requested() -> void:
	if _laser_charged:
		return
	elif _laser_ammo > 0:
		_laser_ammo -= 1
		_laser_charged = true
		_magnet_loaded = false
		_cursor_ship.set_charged_shot(true)
		_cursor_ship.set_loaded_weapon(CursorShip.WeaponType.LASER_CARTRIDGE)
		AudioManager.play_sfx("weapon_switch")
	else:
		AudioManager.play_sfx("empty_click")
	_hud.update_ammo(_laser_ammo, _cluster_magnets)
	_hud.update_laser_charge(_laser_charged)
	_hud.update_weapon(CursorShip.WeaponType.CLUSTER_MAGNET if _magnet_loaded else CursorShip.WeaponType.LASER_CARTRIDGE)


func _on_load_magnet_requested() -> void:
	if _magnet_loaded:
		return
	elif _cluster_magnets > 0:
		_cluster_magnets -= 1
		_magnet_loaded = true
		if _laser_charged:
			_laser_charged = false
			_laser_ammo += 1
			_cursor_ship.set_charged_shot(false)
		_cursor_ship.set_loaded_weapon(CursorShip.WeaponType.CLUSTER_MAGNET)
		AudioManager.play_sfx("weapon_switch")
	else:
		AudioManager.play_sfx("empty_click")
	_hud.update_ammo(_laser_ammo, _cluster_magnets)
	_hud.update_laser_charge(_laser_charged)
	_hud.update_weapon(CursorShip.WeaponType.CLUSTER_MAGNET if _magnet_loaded else CursorShip.WeaponType.LASER_CARTRIDGE)


func _on_unload_requested() -> void:
	if _laser_charged:
		_laser_charged = false
		_laser_ammo += 1
		_cursor_ship.set_charged_shot(false)
		_hud.update_ammo(_laser_ammo, _cluster_magnets)
		_hud.update_laser_charge(false)
	elif _magnet_loaded:
		_magnet_loaded = false
		_cluster_magnets += 1
		_cursor_ship.set_loaded_weapon(CursorShip.WeaponType.LASER_CARTRIDGE)
		_cursor_ship.set_charged_shot(false)
		_hud.update_ammo(_laser_ammo, _cluster_magnets)
		_hud.update_weapon(CursorShip.WeaponType.LASER_CARTRIDGE)


func _on_orientation_changed(vertical: bool) -> void:
	_hud.update_orientation(vertical)


func _process(delta: float) -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if _level_complete:
		return

	# Timed bonus countdown
	if _timed_bonus > 0:
		_timed_bonus = maxf(0, _timed_bonus - _timed_bonus_decay_per_second * delta)
		_hud.update_timed_bonus(int(_timed_bonus))

		if _timed_bonus <= 0:
			_level_complete = true
			GameManager.trigger_game_over()
			return

	# Power-up spawning: every 5 seconds, only if no active non-multiplier powerup on field
	_power_up_timer -= delta
	if _power_up_timer <= 0:
		_power_up_timer = POWER_UP_SPAWN_INTERVAL
		if not _has_active_non_multiplier_power_up():
			_try_spawn_power_up()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _level_complete:
			return

		var mouse_pos: Vector2 = get_global_mouse_position()
		var field_min: Vector2 = _field.global_position
		var field_max: Vector2 = field_min + Vector2(PlayingField.FIELD_PIXEL_WIDTH, PlayingField.FIELD_PIXEL_HEIGHT)

		if mouse_pos.x >= field_min.x and mouse_pos.x <= field_max.x \
				and mouse_pos.y >= field_min.y and mouse_pos.y <= field_max.y:
			var vertical: bool = _cursor_ship.is_vertical if _cursor_ship else false

			if _magnet_loaded:
				_fire_cluster_magnet(mouse_pos, vertical)
				_magnet_loaded = false
				if _cursor_ship:
					_cursor_ship.set_loaded_weapon(CursorShip.WeaponType.LASER_CARTRIDGE)
					_cursor_ship.set_charged_shot(_laser_charged)
				_hud.update_weapon(CursorShip.WeaponType.LASER_CARTRIDGE)
			else:
				# Fire barrier beam
				var charge_ratio: float = _barrier_charge / MAX_BARRIER_CHARGE
				var beam_speed: float = 0.5 + charge_ratio * 1.5
				var was_laser: bool = _laser_charged

				if _laser_charged:
					beam_speed = 4.0
					_laser_charged = false
					if _cursor_ship:
						_cursor_ship.set_charged_shot(false)
					_hud.update_laser_charge(false)

				AudioManager.play_sfx("laser_fire" if was_laser else "barrier_fire")
				_field.start_beam(mouse_pos, vertical, beam_speed)


func _fire_cluster_magnet(world_pos: Vector2, vertical: bool) -> void:
	var origin: Vector2i = _field.world_to_grid(world_pos)
	var wall_a: Vector2
	var wall_b: Vector2

	if vertical:
		wall_a = _field.grid_to_world(_trace_to_edge(origin, Vector2i(0, -1)))
		wall_b = _field.grid_to_world(_trace_to_edge(origin, Vector2i(0, 1)))
	else:
		wall_a = _field.grid_to_world(_trace_to_edge(origin, Vector2i(-1, 0)))
		wall_b = _field.grid_to_world(_trace_to_edge(origin, Vector2i(1, 0)))

	var magnet_a = ClusterMagnet.new()
	_field.add_child(magnet_a)
	magnet_a.initialize(_field, wall_a)

	var magnet_b = ClusterMagnet.new()
	_field.add_child(magnet_b)
	magnet_b.initialize(_field, wall_b)

	AudioManager.play_sfx("magnet_fire")


func _trace_to_edge(origin: Vector2i, dir: Vector2i) -> Vector2i:
	var pos: Vector2i = origin
	while true:
		var next_pos: Vector2i = pos + dir
		if not _field.in_bounds(next_pos) or _field.is_blocking(next_pos):
			return pos
		pos = next_pos
	return pos


func _spawn_balls_for_level() -> void:
	var level_data = GameManager.get_current_level_data()
	var balls_container = _field.get_balls_container()
	var speed_mult: float = level_data.ball_speed_multiplier

	# Step 1: Respawn surviving balls from previous level
	var survivors = GameManager.get_surviving_balls()
	for data in survivors:
		var ball = _create_ball_by_type_name(data["type_name"])
		if ball != null:
			ball.global_position = _field.get_random_empty_position()
			ball.speed *= speed_mult
			ball.direction = data["direction"]
			balls_container.add_child(ball)

	# Step 2: Generate and spawn new balls
	var new_balls = GameManager.generate_new_balls_for_level()
	for type_name in new_balls:
		var ball = _create_ball_by_type_name(type_name)
		if ball != null:
			ball.global_position = _field.get_random_empty_position()
			ball.speed *= speed_mult
			balls_container.add_child(ball)

	# Ensure at least some balls on level 1
	if GameManager.current_level == 1 and balls_container.get_child_count() < 4:
		var needed: int = 4 - balls_container.get_child_count()
		for i in range(needed):
			var pawn = PawnBallGD.new()
			pawn.global_position = _field.get_random_empty_position()
			pawn.speed *= speed_mult
			balls_container.add_child(pawn)

	# Clear kill counts for this level
	GameManager.clear_kill_counts()


func _create_ball_by_type_name(type_name: String) -> BallBaseGD:
	match type_name:
		"PawnBall":
			return PawnBallGD.new()
		"StandardBall":
			return StandardBallGD.new()
		"GravityBall":
			return GravityBallGD.new()
		"Eyeball":
			return EyeballGD.new()
		"NukeBall":
			return NukeBallGD.new()
		"OrangeBall":
			return OrangeBallGD.new()
		"GlassBall":
			return GlassBallGD.new()
		"OozeBall":
			return OozeBallGD.new()
		"Bosco":
			return null
		"Shark":
			return null
		_:
			return PawnBallGD.new()


func _on_fill_percent_changed(percent: float) -> void:
	_hud.update_fill(percent)
	_last_fill_delta = percent - _last_fill_percent
	_last_fill_percent = percent

	# Collect any powerups now enclosed by filled area
	_collect_enclosed_powerups()

	var level_data = GameManager.get_current_level_data()
	if percent >= level_data.required_fill_percent:
		_level_complete = true
		var timed_bonus_awarded: int = int(_timed_bonus)
		ScoreManager.add_fill_score(percent)

		# Save state for carryover
		_save_surviving_balls()
		GameManager.barrier_charge = _barrier_charge
		GameManager.laser_ammo = _laser_ammo
		GameManager.cluster_magnets = _cluster_magnets

		AudioManager.stop_music()
		AudioManager.play_sfx("level_ended")
		GameManager.on_level_completed()
		_level_complete_overlay.show_level_complete(percent, timed_bonus_awarded)


func _on_barrier_completed() -> void:
	if not _level_complete:
		AudioManager.play_sfx("barrier_complete")

	var contained_score: int = int(roundf(_last_fill_delta)) * 10
	if contained_score > 0:
		ScoreManager.add_regular_score(contained_score)

	# Check if Bosco is now trapped
	if _bosco_manager:
		_bosco_manager.check_bosco_isolation()

	# Check if any nuke balls should detonate
	for child in _field.get_balls_container().get_children():
		if child is NukeBallGD and is_instance_valid(child):
			child.check_detonation()


func _on_beam_destroyed() -> void:
	AudioManager.play_sfx("barrier_destroyed")


func _on_life_lost() -> void:
	AudioManager.play_sfx("life_lost")
	_barrier_charge = maxf(0.0, _barrier_charge - MAX_BARRIER_CHARGE * 0.1)
	_hud.update_barrier_charge(_barrier_charge, MAX_BARRIER_CHARGE)

	var tween = create_tween()
	var orig_pos = _field.position
	tween.tween_property(_field, "position", orig_pos + Vector2(5, 0), 0.05)
	tween.tween_property(_field, "position", orig_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(_field, "position", orig_pos + Vector2(0, 5), 0.05)
	tween.tween_property(_field, "position", orig_pos, 0.05)


# Power-up activation methods (called by yummy scripts)
func restore_barrier_charge() -> void:
	_barrier_charge = minf(MAX_BARRIER_CHARGE, _barrier_charge + MAX_BARRIER_CHARGE * 0.05)
	_hud.update_barrier_charge(_barrier_charge, MAX_BARRIER_CHARGE)


func add_laser_ammo(count: int) -> void:
	_laser_ammo += count
	_hud.update_ammo(_laser_ammo, _cluster_magnets)


func add_cluster_magnets(count: int) -> void:
	_cluster_magnets += count
	_hud.update_ammo(_laser_ammo, _cluster_magnets)


func _has_active_non_multiplier_power_up() -> bool:
	for child in _field.get_power_ups_container().get_children():
		if not (child is ScoreMultiplierGD) and is_instance_valid(child):
			return true
	return false


func _try_spawn_power_up() -> void:
	var lvl: int = GameManager.current_level
	var power_up: PowerUpBase = _resolve_yummy_type(lvl)

	power_up.global_position = _field.get_random_empty_position()
	_field.get_power_ups_container().add_child(power_up)


func _resolve_yummy_type(lvl: int) -> PowerUpBase:
	# Build weighted pool
	var pool: Array = [
		{"create": func(): return LightningBoltGD.new(), "weight": 40},
		{"create": func(): return ClusterMagnetPickupGD.new(), "weight": 8},
		{"create": func(): return AmmoTinGD.new(), "weight": 8},
		{"create": func(): return YummieCakeGD.new(), "weight": 6},
		{"create": func(): return LifeKeyGD.new(), "weight": 5},
	]

	if not _multiplier_spawned:
		pool.append({"create": func():
			_multiplier_spawned = true
			return ScoreMultiplierGD.new(), "weight": 20})

	# Sum weights and pick
	var total_weight: int = 0
	for entry in pool:
		total_weight += entry["weight"]

	var roll: int = _rng.randi_range(0, total_weight - 1)
	var cumulative: int = 0
	for entry in pool:
		cumulative += entry["weight"]
		if roll < cumulative:
			return entry["create"].call()

	return LightningBoltGD.new()


func _collect_enclosed_powerups() -> void:
	for child in _field.get_power_ups_container().get_children():
		if child is PowerUpBase and is_instance_valid(child):
			var cell = _field.get_cell_at_world(child.global_position)
			if cell == PlayingField.CellState.FILLED:
				child.collect()


func _save_surviving_balls() -> void:
	var survivors: Array = []
	var balls_container = _field.get_balls_container()
	for child in balls_container.get_children():
		if child is BallBaseGD and is_instance_valid(child):
			survivors.append({"type_name": child.get_type_name(), "direction": child.direction})
	GameManager.set_surviving_balls(survivors)


func _exit_tree() -> void:
	if GameManager != null:
		GameManager.life_lost.disconnect(_on_life_lost)
	if _cursor_ship != null and is_instance_valid(_cursor_ship):
		_cursor_ship.load_laser_requested.disconnect(_on_load_laser_requested)
		_cursor_ship.load_magnet_requested.disconnect(_on_load_magnet_requested)
		_cursor_ship.unload_requested.disconnect(_on_unload_requested)
		_cursor_ship.orientation_changed.disconnect(_on_orientation_changed)
