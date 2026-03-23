class_name ScoreMultiplierGD
extends PowerUpBase

## Score Multiplier appears stationary and cycles through values: 1/2, 2, 3, 4.
## The value shown when captured determines the multiplier for the level.

var _values: Array[float] = [0.5, 2.0, 3.0, 4.0]
var _labels: Array[String] = ["1/2", "2x", "3x", "4x"]
var _current_index: int = 0
var _cycle_timer: float = 0.0
var _cycle_speed: float = 0.2  # seconds per value
var _sm_lifetime: float = 20.0
var _sm_collected: bool = false


func _ready() -> void:
	power_up_color = Color(1.0, 1.0, 0.0)
	super()
	speed = 0  # Stationary
	AudioManager.play_sfx("multiplier_appears")


func _process(delta: float) -> void:
	if _sm_collected:
		return
	var dt = delta

	_sm_lifetime -= dt
	if _sm_lifetime <= 0:
		AudioManager.play_sfx("missed_yummy")
		queue_free()
		return

	# Cycle through values
	_cycle_timer += dt
	if _cycle_timer >= _cycle_speed:
		_cycle_timer -= _cycle_speed
		_current_index = (_current_index + 1) % _values.size()

	queue_redraw()

	if field != null:
		var center_cell = field.world_to_grid(global_position)

		# Collected if enclosed by filled area
		var cell = field.get_cell(center_cell)
		if cell == PlayingField.CellState.FILLED:
			_collect_multiplier()
			return

		# Collected if a completed barrier touches it
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var check = Vector2i(center_cell.x + dx, center_cell.y + dy)
				if field.in_bounds(check) and field.get_cell(check) == PlayingField.CellState.BARRIER:
					_collect_multiplier()
					return


func _draw() -> void:
	# Round button with pulsing glow ring
	var t = float(Time.get_ticks_msec()) / 300.0
	var pulse = sin(t) * 0.1
	var bg_color: Color
	if _current_index == 0:
		bg_color = Color(0.6, 0.2, 0.2)  # Red-ish for 1/2
	else:
		bg_color = power_up_color.darkened(0.3 + pulse)

	# Pulsing glow ring
	var glow_alpha = 0.15 + sin(t * 2.0) * 0.1
	var glow_radius = 14.0 + sin(t) * 2.0
	draw_circle(Vector2.ZERO, glow_radius, Color(1.0, 1.0, 0.3, glow_alpha))

	# Main button body
	draw_circle(Vector2.ZERO, 12.0, bg_color)
	draw_circle(Vector2.ZERO, 10.0, bg_color.lightened(0.1))
	draw_arc(Vector2.ZERO, 12.0, 0, TAU, 28, bg_color.lightened(0.35), 1.8)

	# Current value text
	var text_color = Color.RED if _current_index == 0 else Color.WHITE
	draw_string(ThemeDB.fallback_font, Vector2(-8, 5), _labels[_current_index],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)


func _collect_multiplier() -> void:
	if _sm_collected:
		return
	_sm_collected = true

	var mult = _values[_current_index]
	if mult < 1.0:
		AudioManager.play_sfx("multiplier_half")
	else:
		AudioManager.play_sfx("powerup_collect")

	ScoreManager.multiplier = mult
	queue_free()


func apply_effect() -> void:
	# Handled by _collect_multiplier
	pass
