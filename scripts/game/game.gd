extends Node2D

@onready var tilemap_layer = $TileMapLayer

# --- CHUNK SETTINGS ---
@export var chunk_size: int = 32
@export var render_radius_in_chunks: int = 5

# --- PLAYER (assign your CharacterBody2D / player node here) ---
@export var player: Node2D

# --- TILES ---
const TILE_LIGHT = 0
const TILE_DARK = 1
const TILE_WATER = 2

# --- SAND VARIATION ---
@export_range(0.0, 1.0) var dark_tile_frequency: float = 0.2

# --- WATER SETTINGS ---
@export var zone_size: int = 64
@export var water_chance_per_zone: float = 0.35

# DEBUG: set this to true to force a pool in every zone for instant visual confirmation
@export var debug_force_water: bool = false

# Tracks which chunks are already built so we never rebuild them
var generated_chunks: Dictionary = {}

func _ready():
	# Generate initial area around player (or origin if no player assigned yet)
	var start_pos := _get_center_tile()
	update_chunks_around(start_pos)

func _process(_delta):
	# Continuously follow the player/camera
	var center_tile := _get_center_tile()
	update_chunks_around(center_tile)

func _get_center_tile() -> Vector2i:
	if player:
		# Convert player's world position to tilemap coordinates
		var map_pos = tilemap_layer.local_to_map(player.position)
		return Vector2i(map_pos)
	else:
		# Fallback: follow mouse if no player is assigned (good for testing in editor)
		var mouse_pos = get_global_mouse_position()
		var map_pos = tilemap_layer.local_to_map(mouse_pos)
		return Vector2i(map_pos)

func update_chunks_around(center_tile: Vector2i):
	var center_chunk = tile_to_chunk(center_tile)
	var radius = render_radius_in_chunks
	
	for cx in range(center_chunk.x - radius, center_chunk.x + radius + 1):
		for cy in range(center_chunk.y - radius, center_chunk.y + radius + 1):
			var chunk_pos = Vector2i(cx, cy)
			if not generated_chunks.has(chunk_pos):
				generate_chunk(chunk_pos)

func tile_to_chunk(tile_pos: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(tile_pos.x) / chunk_size),
		floori(float(tile_pos.y) / chunk_size)
	)

func generate_chunk(chunk_pos: Vector2i):
	# Seed the RNG with the chunk position so this chunk ALWAYS looks the same
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_pos)
	
	var start_x = chunk_pos.x * chunk_size
	var start_y = chunk_pos.y * chunk_size
	
	# Pass 1: fill the entire chunk with sand
	for x in range(start_x, start_x + chunk_size):
		for y in range(start_y, start_y + chunk_size):
			if rng.randf() < dark_tile_frequency:
				tilemap_layer.set_cell(Vector2i(x, y), TILE_DARK, Vector2i(0, 0))
			else:
				tilemap_layer.set_cell(Vector2i(x, y), TILE_LIGHT, Vector2i(0, 0))
	
	# Pass 2: check all zones that overlap this chunk
	var zone_start_x = floori(float(start_x) / zone_size)
	var zone_end_x   = floori(float(start_x + chunk_size - 1) / zone_size)
	var zone_start_y = floori(float(start_y) / zone_size)
	var zone_end_y   = floori(float(start_y + chunk_size - 1) / zone_size)
	
	for zx in range(zone_start_x, zone_end_x + 1):
		for zy in range(zone_start_y, zone_end_y + 1):
			_place_pool_in_zone(Vector2i(zx, zy), start_x, start_y, chunk_size)
	
	generated_chunks[chunk_pos] = true

func _place_pool_in_zone(zone_pos: Vector2i, chunk_start_x: int, chunk_start_y: int, chunk_size: int):
	var zone_rng = RandomNumberGenerator.new()
	zone_rng.seed = hash(zone_pos)
	
	# Roll for water (or force it in debug mode)
	if not debug_force_water and zone_rng.randf() >= water_chance_per_zone:
		return
	
	var zone_world_x = zone_pos.x * zone_size
	var zone_world_y = zone_pos.y * zone_size
	var padding = 8  # slightly reduced padding so pools aren't hugging zone edges as hard
	
	var center = Vector2i(
		zone_world_x + zone_rng.randi_range(padding, zone_size - padding - 1),
		zone_world_y + zone_rng.randi_range(padding, zone_size - padding - 1)
	)
	
	# Random pool size: bell curve centered on 15, clamped to 10-25
	var pool_size = int(zone_rng.randfn(15.0, 3.0))
	pool_size = clampi(pool_size, 10, 25)
	
	var pool_tiles = _grow_smooth_pool(center, pool_size, zone_rng)
	
	# Only place tiles that fall inside THIS chunk
	var chunk_end_x = chunk_start_x + chunk_size
	var chunk_end_y = chunk_start_y + chunk_size
	
	for tile in pool_tiles:
		if tile.x >= chunk_start_x and tile.x < chunk_end_x:
			if tile.y >= chunk_start_y and tile.y < chunk_end_y:
				tilemap_layer.set_cell(tile, TILE_WATER, Vector2i(0, 0))

func _grow_smooth_pool(center: Vector2i, target_size: int, rng: RandomNumberGenerator) -> Array:
	var pool = [center]
	var frontier = []
	
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			frontier.append(center + Vector2i(dx, dy))
	
	while pool.size() < target_size and frontier.size() > 0:
		var best_score = -1
		var candidates = []
		
		for tile in frontier:
			var score = _count_water_neighbors(tile, pool)
			if score > best_score:
				best_score = score
				candidates = [tile]
			elif score == best_score:
				candidates.append(tile)
		
		var chosen = candidates[rng.randi_range(0, candidates.size() - 1)]
		pool.append(chosen)
		frontier.erase(chosen)
		
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var neighbor = chosen + Vector2i(dx, dy)
				if not pool.has(neighbor) and not frontier.has(neighbor):
					frontier.append(neighbor)
	
	return pool

func _count_water_neighbors(tile: Vector2i, pool: Array) -> int:
	var count = 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if pool.has(tile + Vector2i(dx, dy)):
				count += 1
	return count
