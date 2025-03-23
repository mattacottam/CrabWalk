extends Node3D

# References to the different board sections
@onready var player_arena = $PlayerArena
@onready var middle_zone = $MiddleZone
@onready var enemy_arena = $EnemyArena
@onready var bench = $Bench

# Dimensions for each section
const PLAYER_ROWS = 7
const PLAYER_COLS = 4
const MIDDLE_ROWS = 7
const MIDDLE_COLS = 3
const ENEMY_ROWS = 7
const ENEMY_COLS = 4
const BENCH_SPACES = 10

# Size properties of the hex tiles
const HEX_SIZE = 1.0  # Radius of the hexagon
const HEX_HEIGHT = 0.1  # Height of the hex tile
const HEX_HORIZ_SPACING = HEX_SIZE * 2.0  # Horizontal spacing between hex centers
const HEX_VERT_SPACING = HEX_SIZE * 0.866 * 2  # Vertical spacing between hex centers

# Camera properties
var camera
var camera_target_position
var camera_zoom_min = 5.0
var camera_zoom_max = 20.0
var camera_zoom_speed = 0.5
var camera_zoom_level = 5
var board_width
var board_height
var board_center

# Colors for different zones
var player_color = Color(0.2, 0.5, 0.8, 1.0)  # Blue
var middle_color = Color(0.5, 0.5, 0.5, 1.0)  # Gray
var enemy_color = Color(0.3, 0.6, 0.8, 1.0)   # DarkBlue
var bench_color = Color(0.6, 1, 0.6, 1.0)   # LightGreen

# Highlight colors for placement
var valid_placement_color = Color(0.0, 1.0, 0.0, 0.5)    # Green
var invalid_placement_color = Color(1.0, 0.0, 0.0, 0.5)  # Red

# Dictionary to store all tiles for easy lookup
var tiles = {}
var highlighted_tile = null

# Called when the node enters the scene tree for the first time
func _ready():
	generate_player_arena()
	generate_middle_zone()
	generate_enemy_arena()
	generate_bench()
	
	# Debug tile dictionary
	print("Tile dictionary contains " + str(tiles.size()) + " tiles")
	print("Bench tiles:")
	for i in range(BENCH_SPACES):
		var key = "bench_%d" % i
		print("- " + key + ": " + str(tiles.has(key)))
	
	# Position the camera to view the entire board
	setup_camera()
	
	# Enable physics process for smooth camera movement
	set_physics_process(true)

# Process camera movement with smooth interpolation
func _physics_process(delta):
	if camera and camera.position != camera_target_position:
		# Smoothly interpolate camera position
		camera.position = camera.position.lerp(camera_target_position, delta * 5.0)

# Generates the player's hex grid (7x4)
func generate_player_arena():
	for row in range(PLAYER_ROWS):
		for col in range(PLAYER_COLS):
			var hex = create_hex_tile(player_color)
			player_arena.add_child(hex)
			
			# Position the hex using offset coordinates
			# Odd rows are offset by half a hex width
			var x_offset = 0
			if row % 2 == 1:
				x_offset = HEX_SIZE * 0.75
			
			hex.position = Vector3(
				col * HEX_HORIZ_SPACING + x_offset,
				0,
				row * HEX_VERT_SPACING
			)
			
			# Tag this tile for identification
			hex.set_meta("zone", "player")
			hex.set_meta("row", row)
			hex.set_meta("col", col)
			
			# Store in our tiles dictionary using a unique key
			var tile_key = "player_%d_%d" % [row, col]
			tiles[tile_key] = hex

# Generates the middle zone hex grid (7x3)
func generate_middle_zone():
	for row in range(MIDDLE_ROWS):
		for col in range(MIDDLE_COLS):
			var hex = create_hex_tile(middle_color)
			middle_zone.add_child(hex)
			
			# Position the hex using offset coordinates
			var x_offset = 0
			if row % 2 == 1:
				x_offset = HEX_SIZE * 0.75
			
			# Position the middle zone to the right of the player arena
			hex.position = Vector3(
				col * HEX_HORIZ_SPACING + x_offset,
				0,
				row * HEX_VERT_SPACING
			)
			
			# Tag this tile
			hex.set_meta("zone", "middle")
			hex.set_meta("row", row)
			hex.set_meta("col", col)
			
			# Store in our tiles dictionary
			var tile_key = "middle_%d_%d" % [row, col]
			tiles[tile_key] = hex
	
	# Position the middle zone to the right of the player arena
	middle_zone.position.x = PLAYER_COLS * HEX_HORIZ_SPACING

# Generates the enemy hex grid (7x4)
func generate_enemy_arena():
	for row in range(ENEMY_ROWS):
		for col in range(ENEMY_COLS):
			var hex = create_hex_tile(enemy_color)
			enemy_arena.add_child(hex)
			
			# Position the hex using offset coordinates
			var x_offset = 0
			if row % 2 == 1:
				x_offset = HEX_SIZE * 0.75
			
			hex.position = Vector3(
				col * HEX_HORIZ_SPACING + x_offset,
				0,
				row * HEX_VERT_SPACING
			)
			
			# Tag this tile
			hex.set_meta("zone", "enemy")
			hex.set_meta("row", row)
			hex.set_meta("col", col)
			
			# Store in our tiles dictionary
			var tile_key = "enemy_%d_%d" % [row, col]
			tiles[tile_key] = hex
	
	# Position the enemy arena to the right of the middle zone
	enemy_arena.position.x = (PLAYER_COLS + MIDDLE_COLS) * HEX_HORIZ_SPACING

# Generates the bench (10 spaces in a single row)
func generate_bench():
	for i in range(BENCH_SPACES):
		var hex = create_hex_tile(bench_color)
		bench.add_child(hex)
		
		# Position the hex in a straight line
		hex.position = Vector3(i * HEX_HORIZ_SPACING, 0, 0)
		
		# Tag this tile
		hex.set_meta("zone", "bench")
		hex.set_meta("index", i)
		
		# Store in our tiles dictionary
		var tile_key = "bench_%d" % i
		tiles[tile_key] = hex
	
	# Position the bench below the player arena with some spacing
	bench.position = Vector3(
		1,
		0,
		(PLAYER_ROWS + 1) * HEX_VERT_SPACING
	)

# Helper to create a hex tile with the given color
func create_hex_tile(color):
	# Create a new mesh instance for the hex
	var hex_instance = MeshInstance3D.new()
	hex_instance.name = "HexTile"
	
	# Create a cylinder mesh with 6 sides to make a hexagon
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = HEX_SIZE
	cylinder_mesh.bottom_radius = HEX_SIZE
	cylinder_mesh.height = HEX_HEIGHT
	cylinder_mesh.radial_segments = 6
	
	hex_instance.mesh = cylinder_mesh
	
	# Setup material
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	hex_instance.material_override = material
	
	# Add collision with clean setup
	var static_body = StaticBody3D.new()
	static_body.name = "StaticBody3D"
	hex_instance.add_child(static_body)
	
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var shape = CylinderShape3D.new()
	shape.radius = HEX_SIZE
	shape.height = HEX_HEIGHT
	collision_shape.shape = shape
	static_body.add_child(collision_shape)
	
	# Store the color as metadata
	hex_instance.set_meta("color", color)
	
	# Attach the script - make sure path is correct
	var script = load("res://scripts/HexTile.gd")
	if script:
		hex_instance.set_script(script)
	else:
		print("ERROR: Could not load HexTile script!")
	
	return hex_instance

# Set up the camera to view the entire board
func setup_camera():
	camera = Camera3D.new()
	add_child(camera)
	
	# Calculate the board dimensions
	board_width = (PLAYER_COLS + MIDDLE_COLS + ENEMY_COLS) * HEX_HORIZ_SPACING
	board_height = max(PLAYER_ROWS * HEX_VERT_SPACING, BENCH_SPACES * HEX_HORIZ_SPACING)
	board_center = Vector3(board_width / 2, 0, board_height / 2)
	
	# Initial camera zoom level
	camera_zoom_level = board_height
	update_camera_position()
	
	# Look at the center of the board
	camera.look_at(board_center, Vector3.UP)

# Update camera position based on zoom level
func update_camera_position():
	camera_target_position = Vector3(
		board_width / 2,  # Center horizontally
		camera_zoom_level * 0.7,  # Height increases with zoom
		board_height * 0.5 + camera_zoom_level * 0.5  # Distance increases with zoom
	)
	camera.position = camera_target_position
	camera.look_at(board_center, Vector3.UP)

# Handle input for camera control
func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in
			camera_zoom_level = max(camera_zoom_level - camera_zoom_speed, camera_zoom_min)
			update_camera_position()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out
			camera_zoom_level = min(camera_zoom_level + camera_zoom_speed, camera_zoom_max)
			update_camera_position()
			get_viewport().set_input_as_handled()

# Find the closest tile to a world position
func get_closest_tile(world_position):
	var closest_tile = null
	var closest_distance = INF
	
	# Convert to absolute world position for proper comparison
	var adjusted_world_pos = world_position
	
	# Check all tiles for the closest one
	for tile in tiles.values():
		var tile_world_pos = tile.global_position
		var distance = tile_world_pos.distance_to(adjusted_world_pos)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_tile = tile
	
	return closest_tile

# Get tile at a specific world position (uses closest tile logic)
func get_tile_at_position(world_position):
	return get_closest_tile(world_position)

# Highlight a tile to show where unit will be dropped
func highlight_potential_drop(tile):
	if highlighted_tile == tile:
		return
		
	if highlighted_tile:
		highlighted_tile.reset_highlight()
	
	if tile:
		# Check if the tile is in a valid zone for placement
		if is_valid_placement_zone(tile):
			tile.highlight_valid()
		else:
			tile.highlight_invalid()
		highlighted_tile = tile

# Check if a tile is in a valid zone for unit placement
func is_valid_placement_zone(tile):
	var zone = tile.get_meta("zone", "")
	return zone == "player" or zone == "bench"

# Clear any highlights
func clear_highlight():
	if highlighted_tile:
		highlighted_tile.reset_highlight()
		highlighted_tile = null
