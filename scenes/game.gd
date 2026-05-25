extends Node2D

@onready var tilemap_layer = $TileMapLayer

@export var chunk_size: int = 32
@export var render_radius_in_chunks: int = 5
@export var dark_tile_frequency: float = 0.15

const TILE_LIGHT = 0
const TILE_DARK = 1

# Stores which chunks we've already built so we don't rebuild them
var generated_chunks: Dictionary = {}

func _ready():
	update_chunks_around(Vector2i(0, 0))

func _process(_delta):
	# If you add a player later, pass their tile position here instead
	update_chunks_around(Vector2i(0, 0))

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
	var rng = RandomNumberGenerator.new()
	# Seed the RNG based on chunk position so the SAME chunk always looks identical
	rng.seed = hash(chunk_pos)
	
	var start_x = chunk_pos.x * chunk_size
	var start_y = chunk_pos.y * chunk_size
	
	for x in range(start_x, start_x + chunk_size):
		for y in range(start_y, start_y + chunk_size):
			if rng.randf() < dark_tile_frequency:
				tilemap_layer.set_cell(Vector2i(x, y), TILE_DARK, Vector2i(0, 0))
			else:
				tilemap_layer.set_cell(Vector2i(x, y), TILE_LIGHT, Vector2i(0, 0))
	
	generated_chunks[chunk_pos] = true
