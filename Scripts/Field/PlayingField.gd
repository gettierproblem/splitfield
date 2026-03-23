class_name PlayingField
extends Node2D

signal fill_percent_changed(percent: float)
signal barrier_completed()
signal beam_destroyed()

const GRID_WIDTH: int = 200
const GRID_HEIGHT: int = 184
const CELL_SIZE: int = 4
const FIELD_PIXEL_WIDTH: int = GRID_WIDTH * CELL_SIZE   # 800
const FIELD_PIXEL_HEIGHT: int = GRID_HEIGHT * CELL_SIZE  # 736

enum CellState { EMPTY, BARRIER, FILLED, GROWING }

static var field_offset: Vector2 = Vector2(8, 24)

var _grid: PackedByteArray  # Flat array, index = x * GRID_HEIGHT + y
var _total_cells: int
var _filled_cells: int
var _needs_full_redraw: bool
var _dirty_cells: PackedInt32Array  # List of flat indices that changed
var _newly_filled: PackedByteArray  # Flat bool array
var _completed_beam_count: int

var completed_beam_count: int:
	get: return _completed_beam_count

var isolated_ball_count: int:
	get: return _count_isolated_balls()

var fill_percentage: float:
	get: return float(_filled_cells) / float(_total_cells) * 100.0

# References
var _balls_container: Node2D
var _power_ups_container: Node2D
var _active_beam: BarrierBeam

# Visual
var _field_image: Image
var _field_texture: ImageTexture
var _field_sprite: Sprite2D

# Colors — empty is transparent to show psychedelic BG through
var EMPTY_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
var BARRIER_COLOR: Color = Color(0.0, 0.9, 1.0, 1.0)
var FILLED_COLOR: Color = Color(0.05, 0.1, 0.2, 0.75)
var GROWING_COLOR: Color = Color(1.0, 1.0, 0.0, 1.0)
var BORDER_COLOR: Color = Color(0.4, 0.4, 0.5)
var _fill_color_a: Color = Color(0.06, 0.04, 0.18)
var _fill_color_b: Color = Color(0.04, 0.15, 0.18)


func _ready() -> void:
	_total_cells = GRID_WIDTH * GRID_HEIGHT
	_filled_cells = 0
	_completed_beam_count = 0

	_balls_container = get_node("Balls") as Node2D
	_power_ups_container = get_node("PowerUps") as Node2D

	# Set level-specific fill colors
	var fill_colors = LevelPatterns.get_foreground_colors(GameManager.current_level)
	_fill_color_a = fill_colors[0]
	_fill_color_b = fill_colors[1]

	_initialize_grid()
	_initialize_visuals()
	_needs_full_redraw = true

	# Add cursor ship
	var cursor_ship = CursorShip.new()
	add_child(cursor_ship)


func _gi(x: int, y: int) -> int:
	return x * GRID_HEIGHT + y

func _initialize_grid() -> void:
	_grid = PackedByteArray()
	_grid.resize(GRID_WIDTH * GRID_HEIGHT)
	_grid.fill(CellState.EMPTY)
	_newly_filled = PackedByteArray()
	_newly_filled.resize(GRID_WIDTH * GRID_HEIGHT)
	_dirty_cells = PackedInt32Array()


func _initialize_visuals() -> void:
	# Psychedelic background (Sprite2D with shader)
	var bg_shader = load("res://Assets/Shaders/psychedelic_bg.gdshader") as Shader
	if bg_shader != null:
		var bg_material = ShaderMaterial.new()
		bg_material.shader = bg_shader
		var bg_colors = LevelPatterns.get_background_colors(GameManager.current_level)
		bg_material.set_shader_parameter("time_scale", 0.5)
		bg_material.set_shader_parameter("color_intensity", 0.8)
		bg_material.set_shader_parameter("plasma_scale", 8.0)
		bg_material.set_shader_parameter("color_a", bg_colors[0])
		bg_material.set_shader_parameter("color_b", bg_colors[1])

		# Create a white texture to apply the shader to
		var bg_image = Image.create_empty(FIELD_PIXEL_WIDTH, FIELD_PIXEL_HEIGHT, false, Image.FORMAT_RGBA8)
		bg_image.fill(Color.WHITE)
		var bg_texture = ImageTexture.create_from_image(bg_image)

		var bg_sprite = Sprite2D.new()
		bg_sprite.texture = bg_texture
		bg_sprite.centered = false
		bg_sprite.position = Vector2.ZERO
		bg_sprite.material = bg_material
		bg_sprite.z_index = -2  # Behind everything
		add_child(bg_sprite)

	# Grid overlay
	_field_image = Image.create_empty(GRID_WIDTH, GRID_HEIGHT, false, Image.FORMAT_RGBA8)
	_field_texture = ImageTexture.create_from_image(_field_image)

	_field_sprite = Sprite2D.new()
	_field_sprite.texture = _field_texture
	_field_sprite.centered = false
	_field_sprite.scale = Vector2(CELL_SIZE, CELL_SIZE)
	_field_sprite.position = Vector2.ZERO
	_field_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_field_sprite.z_index = -1  # Behind balls, in front of BG
	add_child(_field_sprite)


func _process(_delta: float) -> void:
	if _needs_full_redraw:
		_redraw_field_full()
		_needs_full_redraw = false
		_dirty_cells.clear()
	elif _dirty_cells.size() > 0:
		_redraw_dirty()
		_dirty_cells.clear()


func _get_cell_color(x: int, y: int) -> Color:
	var state: int = _grid[_gi(x, y)]
	if state == CellState.FILLED:
		return _get_filled_gradient(x, y)
	elif state == CellState.BARRIER and _is_barrier_surrounded_by_filled(x, y):
		return _get_filled_gradient(x, y)
	else:
		match state:
			CellState.EMPTY:
				return EMPTY_COLOR
			CellState.BARRIER:
				return BARRIER_COLOR
			CellState.GROWING:
				return GROWING_COLOR
			_:
				return EMPTY_COLOR

func _redraw_field_full() -> void:
	for x in GRID_WIDTH:
		for y in GRID_HEIGHT:
			_field_image.set_pixel(x, y, _get_cell_color(x, y))
	_field_texture.update(_field_image)

func _redraw_dirty() -> void:
	for idx in _dirty_cells:
		@warning_ignore("integer_division")
		var x: int = idx / GRID_HEIGHT
		var y: int = idx % GRID_HEIGHT
		_field_image.set_pixel(x, y, _get_cell_color(x, y))
		# Also redraw neighbors (for barrier merge check)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var nx: int = x + dx
				var ny: int = y + dy
				if nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT:
					_field_image.set_pixel(nx, ny, _get_cell_color(nx, ny))
	_field_texture.update(_field_image)


func _get_filled_gradient(x: int, y: int) -> Color:
	# Diagonal gradient with subtle pattern
	var nx: float = float(x) / GRID_WIDTH
	var ny: float = float(y) / GRID_HEIGHT

	# Two-tone diagonal gradient
	var diag: float = (nx + ny) * 0.5
	# Add a subtle wave for texture
	var wave: float = sin(x * 0.15) * cos(y * 0.12) * 0.1
	var t: float = clampf(diag + wave, 0.0, 1.0)

	# Level-specific gradient colors
	var c1: Color = _fill_color_a
	var c2: Color = _fill_color_b
	var base_color: Color = c1.lerp(c2, t)

	# Subtle diamond/crosshatch pattern for texture
	var pattern: float = absf(sin(x * 0.3) + sin(y * 0.3)) * 0.03
	base_color = base_color.lightened(pattern)

	base_color.a = 0.85
	return base_color


func _is_barrier_surrounded_by_filled(x: int, y: int) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx < 0 or nx >= GRID_WIDTH or ny < 0 or ny >= GRID_HEIGHT:
				continue
			var s: int = _grid[_gi(nx, ny)]
			if s == CellState.EMPTY or s == CellState.GROWING:
				return false
	return true


# Coordinate conversions
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - global_position
	var gx: int = clampi(int(local.x / CELL_SIZE), 0, GRID_WIDTH - 1)
	var gy: int = clampi(int(local.y / CELL_SIZE), 0, GRID_HEIGHT - 1)
	return Vector2i(gx, gy)


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return global_position + Vector2(grid_pos.x * CELL_SIZE + CELL_SIZE / 2.0, grid_pos.y * CELL_SIZE + CELL_SIZE / 2.0)


func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT


func get_cell(pos: Vector2i) -> int:
	if not in_bounds(pos):
		return CellState.BARRIER
	return _grid[_gi(pos.x, pos.y)]


func get_cell_at_world(world_pos: Vector2) -> int:
	return get_cell(world_to_grid(world_pos))


func set_cell(pos: Vector2i, state: int) -> void:
	if not in_bounds(pos):
		return
	var idx: int = _gi(pos.x, pos.y)
	var old: int = _grid[idx]
	_grid[idx] = state

	if old == CellState.FILLED and state != CellState.FILLED:
		_filled_cells -= 1
	elif old != CellState.FILLED and state == CellState.FILLED:
		_filled_cells += 1

	_dirty_cells.push_back(idx)


func is_blocking(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return true
	var s: int = _grid[_gi(pos.x, pos.y)]
	return s == CellState.BARRIER or s == CellState.FILLED


func is_growing(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	return _grid[_gi(pos.x, pos.y)] == CellState.GROWING


# Check if a world-space position is in empty/growable space
func is_open_space(world_pos: Vector2) -> bool:
	var cell: int = get_cell_at_world(world_pos)
	return cell == CellState.EMPTY or cell == CellState.GROWING


# Barrier beam management
func start_beam(world_pos: Vector2, vertical: bool, speed_multiplier: float = 1.0) -> void:
	# Check stale reference
	if _active_beam != null and not is_instance_valid(_active_beam):
		_active_beam = null

	if _active_beam != null and _active_beam.is_growing:
		return

	# Don't start on blocking cells
	var grid_pos: Vector2i = world_to_grid(world_pos)
	if is_blocking(grid_pos):
		return

	var beam_node: Node2D = get_node("ActiveBeam") as Node2D
	# Clean up old beam children
	for child in beam_node.get_children():
		child.queue_free()

	var beam = BarrierBeam.new()
	beam_node.add_child(beam)
	beam.initialize(self, world_pos, vertical)
	beam.set_speed_multiplier(speed_multiplier)
	_active_beam = beam


func on_beam_completed() -> void:
	_active_beam = null
	_completed_beam_count += 1

	# Convert all Growing cells to Barrier
	var total: int = GRID_WIDTH * GRID_HEIGHT
	for idx in total:
		if _grid[idx] == CellState.GROWING:
			_grid[idx] = CellState.BARRIER
			_dirty_cells.push_back(idx)

	flood_fill_after_barrier()

	var pct: float = fill_percentage

	fill_percent_changed.emit(pct)
	barrier_completed.emit()


func on_beam_destroyed() -> void:
	# Kill the beam node
	if _active_beam != null and is_instance_valid(_active_beam):
		_active_beam.is_growing = false
		_active_beam.queue_free()
	_active_beam = null

	# Revert all Growing cells to Empty
	var total: int = GRID_WIDTH * GRID_HEIGHT
	for idx in total:
		if _grid[idx] == CellState.GROWING:
			_grid[idx] = CellState.EMPTY
			_dirty_cells.push_back(idx)
	beam_destroyed.emit()


# BFS flood fill — uses flat PackedByteArray for speed
func flood_fill_after_barrier() -> void:
	var total: int = GRID_WIDTH * GRID_HEIGHT
	var reachable: PackedByteArray = PackedByteArray()
	reachable.resize(total)
	reachable.fill(0)

	# Use PackedInt32Array as queue with index pointer (avoids O(n) pop_front)
	var queue: PackedInt32Array = PackedInt32Array()
	var q_head: int = 0

	# Seed from every ball position
	if _balls_container != null:
		for child in _balls_container.get_children():
			if child is BallBaseGD and is_instance_valid(child):
				var grid_pos: Vector2i = world_to_grid(child.global_position)
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						var cx: int = grid_pos.x + dx
						var cy: int = grid_pos.y + dy
						if cx >= 0 and cx < GRID_WIDTH and cy >= 0 and cy < GRID_HEIGHT:
							var idx: int = cx * GRID_HEIGHT + cy
							if reachable[idx] == 0 and _grid[idx] == CellState.EMPTY:
								reachable[idx] = 1
								queue.push_back(idx)

	# BFS using index pointer
	while q_head < queue.size():
		var idx: int = queue[q_head]
		q_head += 1
		@warning_ignore("integer_division")
		var x: int = idx / GRID_HEIGHT
		var y: int = idx % GRID_HEIGHT

		# Check 4 neighbors inline
		if x > 0:
			var ni: int = idx - GRID_HEIGHT
			if reachable[ni] == 0 and _grid[ni] == CellState.EMPTY:
				reachable[ni] = 1
				queue.push_back(ni)
		if x < GRID_WIDTH - 1:
			var ni: int = idx + GRID_HEIGHT
			if reachable[ni] == 0 and _grid[ni] == CellState.EMPTY:
				reachable[ni] = 1
				queue.push_back(ni)
		if y > 0:
			var ni: int = idx - 1
			if reachable[ni] == 0 and _grid[ni] == CellState.EMPTY:
				reachable[ni] = 1
				queue.push_back(ni)
		if y < GRID_HEIGHT - 1:
			var ni: int = idx + 1
			if reachable[ni] == 0 and _grid[ni] == CellState.EMPTY:
				reachable[ni] = 1
				queue.push_back(ni)

	# Fill unreachable empty cells and track newly filled
	_newly_filled.fill(0)
	for idx in total:
		if _grid[idx] == CellState.EMPTY and reachable[idx] == 0:
			_grid[idx] = CellState.FILLED
			_filled_cells += 1
			_newly_filled[idx] = 1
			_dirty_cells.push_back(idx)


## Check if a world position is within the area that was just filled
## by the most recent barrier completion.
func is_in_newly_filled_area(world_pos: Vector2) -> bool:
	if _newly_filled.size() == 0:
		return false
	var grid_pos: Vector2i = world_to_grid(world_pos)
	if not in_bounds(grid_pos):
		return false

	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var cx: int = grid_pos.x + dx
			var cy: int = grid_pos.y + dy
			if cx >= 0 and cx < GRID_WIDTH and cy >= 0 and cy < GRID_HEIGHT:
				if _newly_filled[_gi(cx, cy)] == 1:
					return true
	return false


# Check if any ball overlaps growing cells (called by BarrierBeam)
func does_ball_overlap_growing() -> bool:
	if _balls_container == null:
		return false

	for child in _balls_container.get_children():
		if child is BallBaseGD and is_instance_valid(child):
			var ball: BallBaseGD = child as BallBaseGD
			var grid_pos: Vector2i = world_to_grid(ball.global_position)
			if in_bounds(grid_pos) and _grid[_gi(grid_pos.x, grid_pos.y)] == CellState.GROWING:
				return true
	return false


# Get a random empty position in the field (for spawning)
func get_random_empty_position() -> Vector2:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for attempts in 1000:
		var x: int = rng.randi_range(5, GRID_WIDTH - 6)
		var y: int = rng.randi_range(5, GRID_HEIGHT - 6)
		if _grid[_gi(x, y)] == CellState.EMPTY:
			return grid_to_world(Vector2i(x, y))
	# Fallback: center of field
	return grid_to_world(Vector2i(GRID_WIDTH / 2, GRID_HEIGHT / 2))


# Count balls that are the sole ball in their connected empty region
func _count_isolated_balls() -> int:
	if _balls_container == null:
		return 0

	var balls: Array = []
	for child in _balls_container.get_children():
		if child is BallBaseGD and is_instance_valid(child):
			balls.append(child)
	if balls.size() <= 1:
		return 0

	# Assign each ball a region ID via BFS — use flat PackedInt32Array
	var total: int = GRID_WIDTH * GRID_HEIGHT
	var region_map: PackedInt32Array = PackedInt32Array()
	region_map.resize(total)
	region_map.fill(-1)

	var region_id: int = 0
	var ball_region: Array = []
	ball_region.resize(balls.size())

	for b in balls.size():
		var start: Vector2i = world_to_grid(balls[b].global_position)
		if not in_bounds(start):
			ball_region[b] = -1
			continue
		var si: int = _gi(start.x, start.y)
		if region_map[si] != -1:
			ball_region[b] = region_map[si]
			continue

		# BFS
		var queue: PackedInt32Array = PackedInt32Array()
		var qh: int = 0
		region_map[si] = region_id
		queue.push_back(si)

		while qh < queue.size():
			var idx: int = queue[qh]
			qh += 1
			@warning_ignore("integer_division")
			var cx: int = idx / GRID_HEIGHT
			var cy: int = idx % GRID_HEIGHT
			if cx > 0:
				var ni: int = idx - GRID_HEIGHT
				if region_map[ni] == -1 and _grid[ni] == CellState.EMPTY:
					region_map[ni] = region_id
					queue.push_back(ni)
			if cx < GRID_WIDTH - 1:
				var ni: int = idx + GRID_HEIGHT
				if region_map[ni] == -1 and _grid[ni] == CellState.EMPTY:
					region_map[ni] = region_id
					queue.push_back(ni)
			if cy > 0:
				var ni: int = idx - 1
				if region_map[ni] == -1 and _grid[ni] == CellState.EMPTY:
					region_map[ni] = region_id
					queue.push_back(ni)
			if cy < GRID_HEIGHT - 1:
				var ni: int = idx + 1
				if region_map[ni] == -1 and _grid[ni] == CellState.EMPTY:
					region_map[ni] = region_id
					queue.push_back(ni)

		ball_region[b] = region_id
		region_id += 1

	# Count how many balls are alone in their region
	var balls_per_region: Array = []
	balls_per_region.resize(region_id)
	for i in region_id:
		balls_per_region[i] = 0
	for r in ball_region:
		if r >= 0:
			balls_per_region[r] += 1

	var isolated: int = 0
	for r in ball_region:
		if r >= 0 and balls_per_region[r] == 1:
			isolated += 1

	return isolated


## Flood fill from a grid position to measure the empty region size
## and find all balls within that same region.
## Returns {"size": int, "balls": Array[BallBaseGD]}
func get_region_size(seed_pos: Vector2i) -> Dictionary:
	var result: Dictionary = {"size": 0, "balls": []}
	var si: int = _gi(seed_pos.x, seed_pos.y)

	if not in_bounds(seed_pos) or _grid[si] != CellState.EMPTY:
		return result

	var total: int = GRID_WIDTH * GRID_HEIGHT
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(total)
	visited.fill(0)

	var queue: PackedInt32Array = PackedInt32Array()
	var qh: int = 0
	visited[si] = 1
	queue.push_back(si)
	var count: int = 0

	while qh < queue.size():
		var idx: int = queue[qh]
		qh += 1
		count += 1
		@warning_ignore("integer_division")
		var x: int = idx / GRID_HEIGHT
		var y: int = idx % GRID_HEIGHT
		if x > 0:
			var ni: int = idx - GRID_HEIGHT
			if visited[ni] == 0 and _grid[ni] == CellState.EMPTY:
				visited[ni] = 1
				queue.push_back(ni)
		if x < GRID_WIDTH - 1:
			var ni: int = idx + GRID_HEIGHT
			if visited[ni] == 0 and _grid[ni] == CellState.EMPTY:
				visited[ni] = 1
				queue.push_back(ni)
		if y > 0:
			var ni: int = idx - 1
			if visited[ni] == 0 and _grid[ni] == CellState.EMPTY:
				visited[ni] = 1
				queue.push_back(ni)
		if y < GRID_HEIGHT - 1:
			var ni: int = idx + 1
			if visited[ni] == 0 and _grid[ni] == CellState.EMPTY:
				visited[ni] = 1
				queue.push_back(ni)

	# Find balls in this region
	if _balls_container != null:
		for child in _balls_container.get_children():
			if child is BallBaseGD and is_instance_valid(child):
				var ball_grid: Vector2i = world_to_grid(child.global_position)
				if in_bounds(ball_grid) and visited[_gi(ball_grid.x, ball_grid.y)] == 1:
					result["balls"].append(child)

	result["size"] = count
	return result


func get_balls_container() -> Node2D:
	return _balls_container


func get_power_ups_container() -> Node2D:
	return _power_ups_container
