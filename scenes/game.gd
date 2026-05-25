extends Node2D

@onready var tilemap_layer = $TileMapLayer

# These appear in the Inspector when you click the 'game' node.
# You can change them there without editing code.
@export var map_width_in_tiles: int = 40
@export var map_height_in_tiles: int = 30

# How often dark-sand appears. 0.0 = never, 1.0 = everywhere.
# The slider only goes from 0 to 1 in the inspector.
@export_range(0.0, 1.0) var dark_tile_frequency: float = 0.15

const TILE_LIGHT = 0
const TILE_DARK = 1

func _ready():
	# Seed the random number generator so every run is different
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Clear any old tiles from previous runs
	tilemap_layer.clear()
	
	# Calculate the starting corner so the map is centered on (0, 0)
	# Example: if width is 40, we start at -20 and go to +19
	var start_x = -map_width_in_tiles / 2
	var end_x = map_width_in_tiles / 2
	
	var start_y = -map_height_in_tiles / 2
	var end_y = map_height_in_tiles / 2
	
	# Place the tiles
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			if rng.randf() < dark_tile_frequency:
				tilemap_layer.set_cell(Vector2i(x, y), TILE_DARK, Vector2i(0, 0))
			else:
				tilemap_layer.set_cell(Vector2i(x, y), TILE_LIGHT, Vector2i(0, 0))
