extends Node3D

# Board surface dimensions
var board_width = 0
var board_depth = 0
var board_margin = 5.0  # Extra space around the playable area for decorations

# Reference to the board surface mesh
var board_surface

# Called when the node enters the scene tree
func _ready():
	pass  # Will be initialized by the main GameBoard script

# Initialize with dimensions from the hex grid
func initialize(hex_grid_width, hex_grid_depth):
	board_width = hex_grid_width + (board_margin * 2)
	board_depth = hex_grid_depth + (board_margin * 2)
	
	create_board_surface()
	position_board()

# Create the physical board surface
func create_board_surface():
	# Create a mesh instance for the board
	board_surface = MeshInstance3D.new()
	add_child(board_surface)
	
	# Create a plane mesh for the board surface
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(board_width, board_depth)
	board_surface.mesh = plane_mesh
	
	# Create a material for the board
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.15, 0.15)  # Dark gray color
	
	# Add some subtle detail to the board
	material.roughness = 0.7
	material.metallic = 0.1
	
	board_surface.material_override = material
	
	# Add collision for the board
	var static_body = StaticBody3D.new()
	board_surface.add_child(static_body)
	
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(board_width, 0.1, board_depth)  # Thin box
	collision_shape.shape = shape
	static_body.add_child(collision_shape)

# Position the board correctly
func position_board():
	# Position slightly below the hex grid to avoid z-fighting
	position.y = -0.15  # Slightly below the hex tiles
	
	# Center the board with the hex grid
	position.x = -board_margin
	position.z = -board_margin

# Add environment decorations
func add_decorations():
	var decorator = Node3D.new()
	decorator.name = "EnvironmentDecorator"
	add_child(decorator)
	
	# Attach the decorator script
	var decorator_script = load("res://scripts/EnvironmentDecorator.gd")
	decorator.set_script(decorator_script)
	
	# Calculate the actual play area (hex grid) dimensions
	var play_area_width = board_width - (board_margin * 2)
	var play_area_depth = board_depth - (board_margin * 2)
	
	# Initialize and generate decorations
	decorator.initialize(board_width, board_depth, play_area_width, play_area_depth, board_margin)
	decorator.generate_decorations(30)  # Generate 30 decorations
