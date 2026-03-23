class_name BoscoManager
extends Node

## Manages Bosco the shark's lifecycle: spawn timing, patrol sounds,
## host ball takeover, and isolation checks.

var _field: PlayingField
var _bosco: BoscoShark
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _spawn_timer: float
var _patrol_sound_timer: float
var _bosco_active: bool = false

const INITIAL_SPAWN_DELAY: float = 12.0
const RESPAWN_DELAY: float = 15.0
const PATROL_SOUND_INTERVAL: float = 8.0
const SPAWN_CHECK_INTERVAL: float = 3.0


func initialize_for_level(field: PlayingField) -> void:
	_field = field
	_bosco = null
	_bosco_active = false
	_spawn_timer = INITIAL_SPAWN_DELAY
	_patrol_sound_timer = 0.0
	_rng.randomize()

	AudioManager.play_sfx("bosco_patrol")


func _process(delta: float) -> void:
	# Bosco only spawns at level 10+
	if GameManager.current_level < 10:
		return

	if _bosco_active:
		if _bosco == null or not is_instance_valid(_bosco):
			_bosco_active = false
			_bosco = null
			_spawn_timer = RESPAWN_DELAY
		return

	# Not active - run spawn timer
	_spawn_timer -= delta

	# Play patrol sound periodically while lurking
	_patrol_sound_timer -= delta
	if _patrol_sound_timer <= 0:
		_patrol_sound_timer = PATROL_SOUND_INTERVAL
		AudioManager.play_sfx("bosco_patrol")

	if _spawn_timer <= 0:
		_spawn_timer = SPAWN_CHECK_INTERVAL
		_try_spawn_bosco()


func _try_spawn_bosco() -> void:
	if _field == null:
		return

	var balls_container = _field.get_balls_container()
	if balls_container == null or balls_container.get_child_count() == 0:
		return

	var children = balls_container.get_children()
	var index: int = _rng.randi_range(0, children.size() - 1)
	var host = children[index]

	if not (host is BallBaseGD) or not is_instance_valid(host):
		return

	var perim_pos: float = _world_to_perimeter(host.global_position)

	host.queue_free()

	_bosco = BoscoShark.new()
	_field.add_child(_bosco)
	_bosco.initialize(_field, perim_pos)
	_bosco_active = true

	AudioManager.play_sfx("bosco_gotcha")


func _world_to_perimeter(world_pos: Vector2) -> float:
	var grid_pos: Vector2i = _field.world_to_grid(world_pos)
	var x: int = clampi(grid_pos.x, 0, 199)
	var y: int = clampi(grid_pos.y, 0, 183)

	var dist_top: int = y
	var dist_bottom: int = 183 - y
	var dist_left: int = x
	var dist_right: int = 199 - x

	var min_dist: int = mini(mini(dist_top, dist_bottom), mini(dist_left, dist_right))

	if min_dist == dist_top:
		return float(x)
	if min_dist == dist_right:
		return float(200 + y)
	if min_dist == dist_bottom:
		return float(384 + (199 - x))
	return float(584 + (183 - y))


func check_bosco_isolation(kill_method: String = "regular") -> void:
	if _bosco != null and is_instance_valid(_bosco) and _bosco.is_alive:
		_bosco.check_if_isolated(kill_method)


func get_active_bosco() -> BoscoShark:
	if _bosco != null and is_instance_valid(_bosco) and _bosco.is_alive:
		return _bosco
	return null
