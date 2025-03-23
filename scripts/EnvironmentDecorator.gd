extends Node3D

# Properties for environment generation
var rng = RandomNumberGenerator.new()
var decoration_density = 0.3  # 0 to 1, higher means more decorations
var decoration_types = {
	"rock_small": {
		"scale_min": Vector3(0.5, 0.5, 0.5),
		"scale_max": Vector3(1.5, 1.5, 1.5),
		"color_min": Color(0.4, 0.4, 0.4),
		"color_max": Color(0.7, 0.7, 0.7),
		"weight": 3  # Higher weight means more common
	},
	"rock_medium": {
		"scale_min": Vector3(1.5, 1.5, 1.5),
		"scale_max": Vector3(3.0, 3.0, 3.0),
		"color_min": Color(0.3, 0.3, 0.3),
		"color_max": Color(0.6, 0.6, 0.6),
		"weight": 2
	},
	"rock_large": {
		"scale_min": Vector3(3.0, 3.0, 3.0),
		"scale_max": Vector3(5.0, 6.0, 5.0),
		"color_min": Color(0.2, 0.2, 0.2),
		"color_max": Color(0.5, 0.5, 0.5),
		"weight": 1
	}
}

# Board dimensions (set by main GameBoard)
var board_width = 0
var board_depth = 0
var play_area_width = 0
var play_area_depth = 0
var margin = 0

# Called when the node enters the scene tree
func _ready():
	rng.randomize()

# Initialize with board dimensions
func initialize(in_board_width, in_board_depth, in_play_width, in_play_depth, in_margin):
	board_width = in_board_width
	board_depth = in_board_depth
	play_area_width = in_play_width
	play_area_depth = in_play_depth
	margin = in_margin

# Generate environment decorations around the playing area
func generate_decorations(count=20):
	for i in range(count):
		# Determine decoration type by weight
		var deco_type = select_weighted_decoration()
		
		# Create a random position around the play area (but not inside it)
		var pos = get_random_position_outside_play_area()
		
		# Create the decoration
		create_decoration(deco_type, pos)

# Select a decoration type based on weight
func select_weighted_decoration():
	var total_weight = 0
	for deco in decoration_types:
		total_weight += decoration_types[deco].weight
	
	var roll = rng.randf_range(0, total_weight)
	var current_weight = 0
	
	for deco in decoration_types:
		current_weight += decoration_types[deco].weight
		if roll <= current_weight:
			return deco
	
	# Fallback
	return decoration_types.keys()[0]

# Get a random position outside the play area but within the board
func get_random_position_outside_play_area():
	var play_start_x = margin
	var play_start_z = margin
	var play_end_x = play_start_x + play_area_width
	var play_end_z = play_start_z + play_area_depth
	
	# Choose one of four areas: top, right, bottom, left
	var area = rng.randi_range(0, 3)
	var pos = Vector3.ZERO
	
	match area:
		0:  # Top
			pos.x = rng.randf_range(0, board_width)
			pos.z = rng.randf_range(0, play_start_z - 1)
		1:  # Right
			pos.x = rng.randf_range(play_end_x + 1, board_width)
			pos.z = rng.randf_range(0, board_depth)
		2:  # Bottom
			pos.x = rng.randf_range(0, board_width)
			pos.z = rng.randf_range(play_end_z + 1, board_depth)
		3:  # Left
			pos.x = rng.randf_range(0, play_start_x - 1)
			pos.z = rng.randf_range(0, board_depth)
	
	return pos

# Create a decoration at the given position
func create_decoration(deco_type, position):
	var mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	# Set position
	mesh_instance.position = position
	
	# Create mesh based on decoration type
	var deco_props = decoration_types[deco_type]
	var mesh
	
	if deco_type.begins_with("rock"):
		# Create a random rock shape
		if rng.randf() > 0.5:
			mesh = BoxMesh.new()
		else:
			mesh = SphereMesh.new()
	
	# Apply the mesh and randomize its scale
	mesh_instance.mesh = mesh
	
	var scale = Vector3(
		rng.randf_range(deco_props.scale_min.x, deco_props.scale_max.x),
		rng.randf_range(deco_props.scale_min.y, deco_props.scale_max.y),
		rng.randf_range(deco_props.scale_min.z, deco_props.scale_max.z)
	)
	
	# Add some random rotation for more natural look
	mesh_instance.rotation_degrees = Vector3(
		rng.randf_range(0, 360),
		rng.randf_range(0, 360),
		rng.randf_range(0, 360)
	)
	
	mesh_instance.scale = scale
	
	# Create a material for the decoration
	var material = StandardMaterial3D.new()
	
	# Mix between min and max color
	var t = rng.randf()
	var color = deco_props.color_min.lerp(deco_props.color_max, t)
	material.albedo_color = color
	
	material.roughness = rng.randf_range(0.7, 1.0)
	mesh_instance.material_override = material
