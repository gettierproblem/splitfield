extends Node

## Demo recording and playback system.
## Records player inputs + master RNG seed each physics frame.
## On playback, restores seed and replays inputs for deterministic reproduction.

enum Mode { IDLE, RECORDING, PLAYBACK }

# Action bitfield constants
const ACT_FIRE: int           = 1
const ACT_TOGGLE_ORIENT: int  = 2
const ACT_LOAD_LASER: int     = 4
const ACT_LOAD_MAGNET: int    = 8
const ACT_UNLOAD: int         = 16
const ACT_NEXT_LEVEL: int     = 64

# File format
const DEMO_MAGIC: String = "SFLD"
const DEMO_VERSION: int = 1

# State
var mode: int = Mode.IDLE
var master_seed: int = 0

# Seed dispenser
var _seed_counter: int = 0

# Recording state
var _input_log: Array = []  # Array of PackedFloat32Array [mouse_x, mouse_y, actions]
var _pending_actions: int = 0  # Actions accumulated from _input() since last physics frame
var _action_mouse_pos: Vector2 = Vector2.ZERO  # Mouse pos at moment of action (for fire accuracy)

# Current frame state (available to other nodes during the same physics step)
# Works for BOTH recording and playback modes.
var _playback_index: int = 0
var _current_frame_mouse: Vector2 = Vector2.ZERO
var _current_frame_actions: int = 0
var _total_frames: int = 0
var _seeking: bool = false
var _seek_target_frame: int = 0
var _awaiting_scene: bool = false  # True while waiting for scene change to complete

# Demo metadata (stored in file header)
var _demo_final_score: int = 0
var _demo_final_level: int = 0
var _demo_date: String = ""
var _demo_file_path: String = ""

# Playback bar reference
var _playback_bar: Node = null

# Debug logging
var _log_file: FileAccess = null
var _logging_enabled: bool = false
var _log_counter: int = 0

signal playback_finished()
signal playback_frame_advanced(frame: int, total: int)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Run before other nodes so playback data is available when they check
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	if mode == Mode.RECORDING:
		# Only record when game is actually running (not paused via pause menu)
		# Exception: record ACT_NEXT_LEVEL even when paused (level complete overlay)
		if not get_tree().paused or _pending_actions & ACT_NEXT_LEVEL:
			_record_frame()
		else:
			_pending_actions = 0  # Discard actions during pause
			_current_frame_actions = 0
	elif mode == Mode.PLAYBACK:
		# Don't advance frames while waiting for a scene change to complete
		if _awaiting_scene:
			return
		# Only advance playback when game is running or we need to process next-level
		if not get_tree().paused:
			_playback_frame()
		else:
			# Check if next frame has ACT_NEXT_LEVEL — peek and process it
			if _playback_index < _input_log.size():
				var next_frame: PackedFloat32Array = _input_log[_playback_index]
				var next_actions: int = int(next_frame[2])
				if next_actions & ACT_NEXT_LEVEL:
					_playback_frame()


# --- Seed Dispenser ---

func seed_rng(rng: RandomNumberGenerator) -> void:
	if mode == Mode.IDLE:
		rng.randomize()
	else:
		_seed_counter += 1
		rng.seed = _derive_seed(_seed_counter)


func seed_global_rng() -> void:
	## Call this to seed Godot's global RNG deterministically.
	if mode == Mode.IDLE:
		randomize()
	else:
		_seed_counter += 1
		seed(_derive_seed(_seed_counter))


func _derive_seed(counter: int) -> int:
	# Deterministic hash from master seed + counter
	return hash(master_seed + counter * 2654435761)


# --- Recording ---

func start_recording() -> void:
	mode = Mode.RECORDING
	master_seed = randi()
	_seed_counter = 0
	_input_log.clear()
	_pending_actions = 0
	_current_frame_actions = 0


func record_action(action: int) -> void:
	## Call from input handlers to log discrete actions this frame.
	if mode == Mode.RECORDING:
		_pending_actions |= action
		# Snapshot mouse position at the moment of the action so fire
		# position is captured exactly, not at the next physics tick.
		_action_mouse_pos = get_viewport().get_mouse_position()


func _record_frame() -> void:
	# If an action was recorded this frame, use the mouse position captured
	# at the moment of the action (more accurate for fire placement).
	# Otherwise use current viewport mouse position.
	var mouse_pos: Vector2
	if _pending_actions != 0:
		mouse_pos = _action_mouse_pos
	else:
		mouse_pos = get_viewport().get_mouse_position()

	# Make current frame data available to other nodes (same as playback)
	_current_frame_mouse = mouse_pos
	_current_frame_actions = _pending_actions

	var frame := PackedFloat32Array([mouse_pos.x, mouse_pos.y, float(_pending_actions)])
	_input_log.append(frame)
	_pending_actions = 0


func stop_and_save() -> String:
	## Stop recording and save to disk. Returns the file path.
	if mode != Mode.RECORDING:
		return ""

	mode = Mode.IDLE

	# Generate filename
	var now := Time.get_datetime_dict_from_system()
	var timestamp := "%04d%02d%02d_%02d%02d%02d" % [
		now["year"], now["month"], now["day"],
		now["hour"], now["minute"], now["second"]]
	var dir_path := "user://demos"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var path := dir_path + "/" + timestamp + ".sfld"

	_demo_final_score = ScoreManager.score
	_demo_final_level = GameManager.current_level
	_demo_date = "%04d-%02d-%02d" % [now["year"], now["month"], now["day"]]

	_save_demo(path)
	_demo_file_path = path
	return path


func _save_demo(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("DemoRecorder: Failed to save demo to " + path)
		return

	# Header
	file.store_buffer(DEMO_MAGIC.to_utf8_buffer())
	file.store_16(DEMO_VERSION)
	file.store_64(master_seed)
	file.store_16(Engine.physics_ticks_per_second)
	file.store_32(_input_log.size())
	file.store_32(_demo_final_score)
	file.store_16(_demo_final_level)
	file.store_pascal_string(_demo_date)

	# Frames
	for frame in _input_log:
		file.store_float(frame[0])  # mouse_x
		file.store_float(frame[1])  # mouse_y
		file.store_16(int(frame[2]))  # actions

	file.close()


# --- Playback ---

func start_playback(path: String) -> bool:
	## Load a demo file and begin playback. Returns true on success.
	if not _load_demo(path):
		return false

	_demo_file_path = path
	mode = Mode.PLAYBACK
	_playback_index = 0
	_seed_counter = 0
	_seeking = false
	_awaiting_scene = true  # Don't advance frames until new scene is ready

	# Start the game
	GameManager.start_new_game()

	# Create playback bar and unblock frame advancement after scene loads
	call_deferred("_on_scene_ready_for_playback")
	return true


func _load_demo(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DemoRecorder: Failed to open demo " + path)
		return false

	# Header
	var magic := file.get_buffer(4).get_string_from_utf8()
	if magic != DEMO_MAGIC:
		push_error("DemoRecorder: Invalid demo file magic")
		file.close()
		return false

	var version := file.get_16()
	if version != DEMO_VERSION:
		push_error("DemoRecorder: Unsupported demo version " + str(version))
		file.close()
		return false

	master_seed = file.get_64()
	var _physics_fps := file.get_16()
	_total_frames = file.get_32()
	_demo_final_score = file.get_32()
	_demo_final_level = file.get_16()
	_demo_date = file.get_pascal_string()

	# Frames
	_input_log.clear()
	_input_log.resize(_total_frames)
	for i in _total_frames:
		var mx := file.get_float()
		var my := file.get_float()
		var actions := file.get_16()
		_input_log[i] = PackedFloat32Array([mx, my, float(actions)])

	file.close()
	return true


func _playback_frame() -> void:
	if _playback_index >= _input_log.size():
		# Frames exhausted — trigger game over with replay options
		# instead of dumping to menu (handles minor desync at higher speeds)
		GameManager.is_game_active = false
		GameManager.game_over.emit()
		return

	var frame: PackedFloat32Array = _input_log[_playback_index]
	_current_frame_mouse = Vector2(frame[0], frame[1])
	_current_frame_actions = int(frame[2])
	_playback_index += 1

	playback_frame_advanced.emit(_playback_index, _total_frames)


func stop_playback() -> void:
	stop_logging()
	mode = Mode.IDLE
	reset_playback_speed()
	_remove_playback_bar()
	playback_finished.emit()
	# Return to main menu
	get_tree().paused = false
	GameManager.return_to_main_menu()


var _replay_speed: float = 1.0  # Preserved across replays

func replay() -> void:
	## Restart playback of the current demo from the beginning.
	stop_logging()
	var path := _demo_file_path
	if path == "":
		return
	_replay_speed = Engine.time_scale
	reset_playback_speed()
	get_tree().paused = false
	_remove_playback_bar()
	mode = Mode.IDLE
	start_playback(path)


# --- Input Proxy ---

func get_mouse_position() -> Vector2:
	## Use instead of get_global_mouse_position() in gameplay code.
	## Returns the recorded/captured position in both recording and playback.
	if mode == Mode.RECORDING or mode == Mode.PLAYBACK:
		return _current_frame_mouse
	return get_viewport().get_mouse_position()


func is_action_this_frame(action: int) -> bool:
	## Check if an action was performed this physics frame.
	## Works in both RECORDING and PLAYBACK modes.
	if mode == Mode.RECORDING or mode == Mode.PLAYBACK:
		return (_current_frame_actions & action) != 0
	return false


func is_playback() -> bool:
	return mode == Mode.PLAYBACK


func is_recording() -> bool:
	return mode == Mode.RECORDING


func get_current_frame() -> int:
	return _playback_index


func get_total_frames() -> int:
	return _total_frames


# --- Seeking ---

var _pre_seek_speed: float = 1.0

func seek_to_frame(target_frame: int) -> void:
	## Seek to a specific frame. Pauses on arrival.
	## Forward: fast-forwards. Backward: restarts game and fast-forwards.
	if mode != Mode.PLAYBACK:
		return

	target_frame = clampi(target_frame, 0, _total_frames - 1)
	if target_frame == _playback_index:
		return

	_pre_seek_speed = Engine.time_scale
	_seeking = true
	_seek_target_frame = target_frame
	AudioManager.stop_music()
	AudioManager.set_sfx_enabled(false)

	if target_frame < _playback_index:
		# Backward seek: restart and fast-forward to target
		_replay_speed = 1.0  # Will be overridden by seek speed
		reset_playback_speed()
		get_tree().paused = false
		_seed_counter = 0
		_playback_index = 0
		GameManager.current_level = 1
		ScoreManager.reset()
		GameManager._kill_counts.clear()
		GameManager._surviving_balls.clear()
		GameManager.barrier_charge = 20.0
		GameManager.laser_ammo = 0
		GameManager.cluster_magnets = 0
		GameManager.is_game_active = true
		DemoRecorder.seed_rng(GameManager._rng)
		_awaiting_scene = false  # Will be set by scene load
		GameManager.load_game_scene()
		# Scene change is deferred; fast-forward starts after scene loads
		_awaiting_scene = true
		call_deferred("_start_seek_after_scene_load")
	else:
		# Forward seek: just fast-forward
		get_tree().paused = false
		set_playback_speed(16.0)


func _start_seek_after_scene_load() -> void:
	_awaiting_scene = false
	set_playback_speed(16.0)


func _check_seek_completion() -> void:
	if _seeking and _playback_index >= _seek_target_frame:
		_seeking = false
		set_playback_speed(_pre_seek_speed)
		AudioManager.set_sfx_enabled(true)
		# Pause on arrival
		get_tree().paused = true
		AudioManager.pause_music()


# --- Playback Bar ---

func _on_scene_ready_for_playback() -> void:
	_awaiting_scene = false
	_create_playback_bar()
	# Restore speed from before replay (1.0 on first play)
	if _replay_speed > 1.0:
		set_playback_speed(_replay_speed)
	start_logging()


func _create_playback_bar() -> void:
	if _playback_bar != null:
		return
	var bar_script := load("res://Scripts/UI/DemoPlaybackBar.gd")
	if bar_script:
		_playback_bar = bar_script.new()
		get_tree().root.add_child(_playback_bar)


func _remove_playback_bar() -> void:
	if _playback_bar != null and is_instance_valid(_playback_bar):
		_playback_bar.queue_free()
		_playback_bar = null


# --- Playback Speed ---

const BASE_PHYSICS_FPS: int = 60

func set_playback_speed(speed: float) -> void:
	## Set playback speed while keeping per-step delta constant.
	## Increases physics_ticks_per_second proportionally to counteract
	## Engine.time_scale's effect on _physics_process(delta).
	## Pauses briefly to reset Godot's physics accumulator cleanly.
	var was_paused := get_tree().paused
	get_tree().paused = true
	Engine.time_scale = speed
	Engine.physics_ticks_per_second = int(BASE_PHYSICS_FPS * speed)
	if not was_paused:
		get_tree().paused = false


func reset_playback_speed() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = BASE_PHYSICS_FPS


# --- Utility ---

func get_demo_file_path() -> String:
	return _demo_file_path


func get_time_string(frame: int) -> String:
	var seconds: float = float(frame) / BASE_PHYSICS_FPS
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]


# --- Debug Logging ---

func start_logging() -> void:
	_log_counter += 1
	var path := "user://demo_log_%d.txt" % _log_counter
	_log_file = FileAccess.open(path, FileAccess.WRITE)
	_logging_enabled = _log_file != null
	if _logging_enabled:
		_log_file.store_line("# Demo playback log #%d time_scale=%.1f" % [_log_counter, Engine.time_scale])
		_log_file.store_line("# master_seed=%d total_frames=%d" % [master_seed, _total_frames])


func stop_logging() -> void:
	if _log_file != null:
		_log_file.close()
		_log_file = null
	_logging_enabled = false


func log_frame_state(field: Node) -> void:
	## Call from GameScene._physics_process AFTER all game logic has run.
	if not _logging_enabled or _log_file == null:
		return

	var frame := _playback_index
	var line := "F%d act=%d mx=%.1f my=%.1f" % [
		frame, _current_frame_actions, _current_frame_mouse.x, _current_frame_mouse.y]

	# Log ball positions
	if field != null and field is PlayingField:
		var pf: PlayingField = field as PlayingField
		line += " fill=%.2f%%" % pf.fill_percentage

		var balls_container = pf.get_balls_container()
		if balls_container:
			var ball_strs: PackedStringArray = []
			for child in balls_container.get_children():
				if child is BallBaseGD and is_instance_valid(child) and child.is_active:
					ball_strs.append("(%d,%d,%.2f,%.2f)" % [
						int(child.global_position.x), int(child.global_position.y),
						child.direction.x, child.direction.y])
			line += " balls=[%s]" % ",".join(ball_strs)

		# Log active beam
		var beam_node = null
		for child in pf.get_children():
			if child is BarrierBeam and is_instance_valid(child) and child.is_growing:
				beam_node = child
				break
		if beam_node:
			line += " beam=growing"

	line += " score=%d lives=%d" % [ScoreManager.score, ScoreManager.lives]
	_log_file.store_line(line)
