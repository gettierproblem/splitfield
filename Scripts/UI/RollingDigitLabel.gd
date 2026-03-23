class_name RollingDigitLabel
extends Label

## Arcade-style rolling number display. The displayed value rapidly
## counts toward the target, like a pinball machine scoreboard.

var _displayed_value: int = 0
var _target_value: int = 0
var _roll_speed: float = 8.0
var _accumulator: float = 0.0
var _prefix: String = ""
var _suffix: String = ""
var _comma_format: bool = true

var value: int:
	get:
		return _target_value


func configure(prefix: String, suffix: String = "", roll_speed: float = 8.0, comma_format: bool = true) -> void:
	_prefix = prefix
	_suffix = suffix
	_roll_speed = roll_speed
	_comma_format = comma_format


func set_value(new_value: int, instant: bool = false) -> void:
	_target_value = new_value
	if instant:
		_displayed_value = new_value
		_update_text()


func _process(delta: float) -> void:
	if _displayed_value == _target_value:
		return

	var diff: int = _target_value - _displayed_value
	var abs_diff: int = absi(diff)

	# Speed scales with the size of the difference for snappy feel
	var speed: float = maxf(_roll_speed, abs_diff * 8.0)
	_accumulator += delta * speed

	if _accumulator >= 1.0:
		var steps: int = int(_accumulator)
		_accumulator -= steps

		# Don't overshoot
		if steps >= abs_diff:
			_displayed_value = _target_value
		else:
			_displayed_value += signi(diff) * steps

		_update_text()


func _update_text() -> void:
	var num_str: String
	if _comma_format:
		num_str = _format_with_commas(_displayed_value)
	else:
		num_str = str(_displayed_value)
	text = _prefix + num_str + _suffix


func _format_with_commas(num: int) -> String:
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
