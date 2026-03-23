extends Node

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal multiplier_changed(new_multiplier: float)
signal extra_life_earned()

var score: int = 0
var lives: int = 5
var multiplier: float = 1.0:
	set(value):
		multiplier = value
		multiplier_changed.emit(multiplier)

var level: int:
	get:
		return GameManager.current_level

var _next_extra_life_at: int = 0


func _ready() -> void:
	_next_extra_life_at = _get_extra_life_interval(1)


func reset() -> void:
	score = 0
	lives = 5
	multiplier = 1.0
	_next_extra_life_at = _get_extra_life_interval(1)
	score_changed.emit(score)
	lives_changed.emit(lives)
	multiplier_changed.emit(multiplier)


## Points per % of screen cleared, scaled by level bracket.
func _get_fill_points_per_percent() -> int:
	var lvl := level
	# Levels 1-4: 10, 5-9: 20, 10-14: 30, 15-19: 40, 20-24: 50, ...
	var bracket := (lvl - 1) / 5
	return (bracket + 1) * 10


## Calculate over-achiever bonus per FAQ:
## 100 pts per % over 80, 1000 per % over 90, 2500 per % over 95, 20000 for 100%.
static func calc_overachiever_bonus(fill_percent: float) -> int:
	if fill_percent <= 80.0:
		return 0

	var bonus: int = 0
	var over_percent: int = int(fill_percent) - 80

	# 100 points for each % over 80
	bonus += over_percent * 100

	# Additional 1000 points for each % over 90
	if fill_percent > 90.0:
		var over_90: int = int(fill_percent) - 90
		bonus += over_90 * 1000

	# Additional 2500 points for each % over 95
	if fill_percent > 95.0:
		var over_95: int = int(fill_percent) - 95
		bonus += over_95 * 2500

	# 20000 bonus for perfect 100%
	if fill_percent >= 100.0:
		bonus += 20000

	return bonus


func add_fill_score(percentage_filled: float) -> void:
	var points_per_percent := _get_fill_points_per_percent()
	var fill_points := int(percentage_filled * points_per_percent)
	score += fill_points
	score_changed.emit(score)
	_check_extra_life()


## Add bonus points without multiplier. Multiplier is applied at level end screen.
func add_bonus_score(base_points: int) -> void:
	score += base_points
	score_changed.emit(score)
	_check_extra_life()


## Apply the current multiplier to a bonus total and add to score. Used at level end.
func apply_multiplier_and_add(base_bonus: int) -> int:
	var multiplied := int(base_bonus * multiplier)
	score += multiplied
	score_changed.emit(score)
	_check_extra_life()
	return multiplied


## Add regular (non-multiplier) points like nuke detonation.
func add_regular_score(points: int) -> void:
	score += points
	score_changed.emit(score)
	_check_extra_life()


func lose_life() -> void:
	lives = max(0, lives - 1)
	lives_changed.emit(lives)


func gain_life() -> void:
	lives += 1
	lives_changed.emit(lives)


## Extra life interval scales by level bracket per FAQ:
## L1-4: 5000, L5-9: 6000, L10-14: 7000, L15-19: 8500, L20-24: 10000, L25-29: 12500, L30+: 15000
static func _get_extra_life_interval(lvl: int) -> int:
	if lvl <= 4:
		return 5000
	elif lvl <= 9:
		return 6000
	elif lvl <= 14:
		return 7000
	elif lvl <= 19:
		return 8500
	elif lvl <= 24:
		return 10000
	elif lvl <= 29:
		return 12500
	else:
		return 15000


func _check_extra_life() -> void:
	while score >= _next_extra_life_at:
		gain_life()
		extra_life_earned.emit()
		_next_extra_life_at += _get_extra_life_interval(level)
