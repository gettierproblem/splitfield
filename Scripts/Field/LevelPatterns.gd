class_name LevelPatterns
extends RefCounted

# 10 level palette sets inspired by original Barrack ppat textures.
# Each entry: { bg_a, bg_b, fill_a, fill_b }
# bg_a/bg_b = background (empty area) shader colors
# fill_a/fill_b = foreground (filled area) gradient colors

static var palettes: Array = [
	# 1: Dark red/black organic (ppat 1000_1 Back + 200_1 Fore)
	{
		"bg_a": Color(0.25, 0.04, 0.02),
		"bg_b": Color(0.08, 0.02, 0.02),
		"fill_a": Color(0.12, 0.04, 0.04),
		"fill_b": Color(0.06, 0.02, 0.08),
	},
	# 2: Blue/green swirl (ppat 1001_2 Back + 201_2 Fore)
	{
		"bg_a": Color(0.02, 0.08, 0.25),
		"bg_b": Color(0.02, 0.15, 0.12),
		"fill_a": Color(0.03, 0.06, 0.18),
		"fill_b": Color(0.02, 0.12, 0.15),
	},
	# 3: Purple/dark blue (ppat 1002_3 Back + 202_3 Fore)
	{
		"bg_a": Color(0.15, 0.02, 0.25),
		"bg_b": Color(0.05, 0.02, 0.15),
		"fill_a": Color(0.08, 0.02, 0.18),
		"fill_b": Color(0.04, 0.04, 0.12),
	},
	# 4: Dark olive/amber (ppat 1003_4 Back + 203_3 Fore)
	{
		"bg_a": Color(0.18, 0.15, 0.02),
		"bg_b": Color(0.06, 0.08, 0.02),
		"fill_a": Color(0.10, 0.08, 0.02),
		"fill_b": Color(0.04, 0.06, 0.04),
	},
	# 5: Red geometric (ppat 1004_5 Back + 204_5 Fore)
	{
		"bg_a": Color(0.30, 0.02, 0.04),
		"bg_b": Color(0.10, 0.02, 0.02),
		"fill_a": Color(0.14, 0.02, 0.02),
		"fill_b": Color(0.06, 0.04, 0.06),
	},
	# 6: Teal/dark cyan (ppat 1005_6 Back + 205_6 Fore)
	{
		"bg_a": Color(0.02, 0.20, 0.22),
		"bg_b": Color(0.02, 0.08, 0.10),
		"fill_a": Color(0.02, 0.10, 0.14),
		"fill_b": Color(0.04, 0.04, 0.10),
	},
	# 7: Deep blue/navy (ppat 1006_7 Back + 206_7 Fore)
	{
		"bg_a": Color(0.02, 0.04, 0.22),
		"bg_b": Color(0.02, 0.02, 0.10),
		"fill_a": Color(0.02, 0.03, 0.16),
		"fill_b": Color(0.03, 0.02, 0.08),
	},
	# 8: Warm magenta/purple (ppat 1007_8 Back + 207_8 Fore)
	{
		"bg_a": Color(0.22, 0.02, 0.18),
		"bg_b": Color(0.08, 0.02, 0.10),
		"fill_a": Color(0.12, 0.02, 0.14),
		"fill_b": Color(0.06, 0.02, 0.08),
	},
	# 9: Dark forest green (ppat 1008_9 Back + 208_9 Fore)
	{
		"bg_a": Color(0.02, 0.18, 0.06),
		"bg_b": Color(0.02, 0.06, 0.04),
		"fill_a": Color(0.02, 0.10, 0.06),
		"fill_b": Color(0.04, 0.04, 0.06),
	},
	# 10: Dark blue-gold nebula (ppat 1009_10 Back + 209_10 Fore)
	{
		"bg_a": Color(0.08, 0.06, 0.25),
		"bg_b": Color(0.18, 0.12, 0.02),
		"fill_a": Color(0.06, 0.04, 0.16),
		"fill_b": Color(0.10, 0.08, 0.04),
	},
]


static func get_palette(level: int) -> Dictionary:
	var idx: int = (level - 1) % palettes.size()
	return palettes[idx]


static func get_background_colors(level: int) -> Array:
	var p = get_palette(level)
	return [p["bg_a"], p["bg_b"]]


static func get_foreground_colors(level: int) -> Array:
	var p = get_palette(level)
	return [p["fill_a"], p["fill_b"]]
