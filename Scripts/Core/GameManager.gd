extends Node

signal level_started(level: int)
signal level_completed(level: int)
signal game_over()
signal life_lost()

var current_level: int = 1
var is_game_active: bool = false
var is_paused: bool = false

# Kill/respawn tracking: maps ball type name to kill count
var _kill_counts: Dictionary = {}

# Surviving ball data for carryover (Array of Dictionaries with "type_name" and "direction" keys)
var _surviving_balls: Array = []

# Barrier charge persists between levels
var barrier_charge: float = 20.0

# Ammo persists between levels
var laser_ammo: int = 0
var cluster_magnets: int = 0

var _game_scene: PackedScene
var _rng := RandomNumberGenerator.new()

# Sandbox mode: set to a ball/entity type name to spawn only that + a pawn ball
var sandbox_entity: String = ""
var return_to_tutorial: bool = false
var return_to_tutorial_page: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game_scene = load("res://Scenes/Game/GameScene.tscn") as PackedScene
	_rng.randomize()


func get_current_level_data() -> LevelData:
	# Generate minimal LevelData for compatibility (timed bonus, speed, etc.)
	var level := LevelData.new()
	level.level_number = current_level
	level.ball_speed_multiplier = 1.0 + (get_difficulty_tier() - 1) * 0.15
	level.required_fill_percent = 80.0
	level.power_up_spawn_chance = 0.1 + current_level * 0.01
	level.timed_bonus_start = 3000 + (current_level - 1) * 100
	level.timed_bonus_decay_per_second = 10 + (current_level - 1) * 1
	return level


## Difficulty tier affects ball speed/aggression.
func get_difficulty_tier() -> int:
	if current_level == 1:
		return 2  # Special case
	if current_level <= 9:
		return 1
	if current_level <= 19:
		return 2
	if current_level <= 29:
		return 3
	if current_level <= 39:
		return 4
	return current_level / 10 + 1


## Get wildcard slot count for current level.
func _get_wildcard_slot_count() -> int:
	var lvl := current_level
	if lvl == 1:
		return 2
	if lvl <= 9:
		return 1
	if lvl == 10:
		return 0  # Level 10: hardcoded Nuke only, no wildcards
	if lvl <= 19:
		return 2
	if lvl <= 29:
		return 3
	if lvl <= 39:
		return 4
	return (lvl / 10) * 2 - 2


## Resolve a wildcard slot to a concrete ball type name using
## weighted random selection gated by level number (per levels.md).
func _resolve_wildcard(slot_index: int, total_balls: int) -> String:
	var lvl := current_level

	# Priority 1: Level < 10 — Nuke at level 5, Pawn otherwise
	if lvl < 10:
		return "NukeBall" if lvl == 5 else "PawnBall"

	# Priority 2: Ooze — 1/3 chance, no level gate, requires total balls > 2 and ooze kills < 7
	var ooze_kills: int = _kill_counts.get("OozeBall", 0)
	if total_balls > 2 and ooze_kills < 7 and _rng.randf() < 0.333:
		return "OozeBall"

	# Priority 3: Level 10 or 18 — guaranteed Nuke
	if lvl == 10 or lvl == 18:
		return "NukeBall"

	# Priority 4: Level >= 20, first slot — Sentry Eye
	if lvl >= 20 and slot_index == 0:
		return "Eyeball"

	# Priority 5: Level >= 15 — Glass 1/10
	if lvl >= 15 and _rng.randf() < 0.1:
		return "GlassBall"

	# Priority 6: Level >= 20 — Sentry Eye 1/8
	if lvl >= 20 and _rng.randf() < 0.125:
		return "Eyeball"

	# Priority 7: Level >= 16 — Orange 1/10
	if lvl >= 16 and _rng.randf() < 0.1:
		return "OrangeBall"

	# Priority 8: Fallback — Pawn
	return "PawnBall"


## Generate the list of new balls to spawn for the current level.
## Wildcard resolution only — per levels.md, respawn counters contribute no additional balls.
func generate_new_balls_for_level() -> Array:
	var new_balls: Array = []

	# Special case: level 10 — hardcoded Nuke, no wildcards
	if current_level == 10:
		new_balls.append("NukeBall")
		return new_balls

	# Wildcard slots
	var wildcards := _get_wildcard_slot_count()
	var total_balls: int = _surviving_balls.size() + new_balls.size()
	for i in range(wildcards):
		var type := _resolve_wildcard(i, total_balls + i)
		new_balls.append(type)

	return new_balls


func record_kill(ball_type_name: String) -> void:
	if ball_type_name in _kill_counts:
		_kill_counts[ball_type_name] += 1
	else:
		_kill_counts[ball_type_name] = 1


func clear_kill_counts() -> void:
	_kill_counts.clear()


## Store surviving ball data for carryover to next level.
## Each entry is a Dictionary with "type_name": String and "direction": Vector2.
func set_surviving_balls(balls: Array) -> void:
	_surviving_balls = balls


func get_surviving_balls() -> Array:
	return _surviving_balls


func start_new_game() -> void:
	current_level = 1
	ScoreManager.reset()
	_kill_counts.clear()
	_surviving_balls.clear()
	barrier_charge = 20.0
	laser_ammo = 0
	cluster_magnets = 0
	is_game_active = true
	load_game_scene()


func load_game_scene() -> void:
	get_tree().change_scene_to_file("res://Scenes/Game/GameScene.tscn")


func on_level_completed() -> void:
	is_game_active = false
	level_completed.emit(current_level)


func advance_to_next_level() -> void:
	current_level += 1
	is_game_active = true
	level_started.emit(current_level)
	load_game_scene()


func trigger_game_over() -> void:
	is_game_active = false
	game_over.emit()


func on_life_lost() -> void:
	ScoreManager.lose_life()
	life_lost.emit()

	if ScoreManager.lives <= 0:
		is_game_active = false
		game_over.emit()


func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused


func start_sandbox(entity_type: String) -> void:
	sandbox_entity = entity_type
	current_level = 10 if entity_type == "Bosco" else 1
	ScoreManager.reset()
	_kill_counts.clear()
	_surviving_balls.clear()
	barrier_charge = 20.0
	laser_ammo = 0
	cluster_magnets = 0
	is_game_active = true
	load_game_scene()


func return_to_main_menu() -> void:
	is_paused = false
	get_tree().paused = false
	is_game_active = false
	return_to_tutorial = sandbox_entity != ""
	sandbox_entity = ""
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
