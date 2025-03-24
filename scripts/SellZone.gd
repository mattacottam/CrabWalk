extends Node3D

# Visual properties
@onready var mesh_instance = $MeshInstance3D

var default_color = Color(0.8, 0.2, 0.2, 0.3)  # Semi-transparent red
var active_color = Color(1.0, 0.0, 0.0, 0.5)   # Brighter, more solid red when active

# Called when the node enters the scene tree
func _ready():
	setup_appearance()
	ensure_proper_collision()

# Ensure proper collision setup
func ensure_proper_collision():
	# Check if we have a static body
	var static_body = $MeshInstance3D/StaticBody3D
	if not static_body:
		static_body = StaticBody3D.new()
		static_body.name = "StaticBody3D"
		$MeshInstance3D.add_child(static_body)
	
	# Check if we have a collision shape
	var collision_shape = static_body.get_node_or_null("CollisionShape3D")
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		static_body.add_child(collision_shape)
	
	# Make sure the shape is proper
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(3, 0.1, 3)  # Match the mesh size
	collision_shape.shape = box_shape
	
	# Make sure collision is properly set up
	static_body.collision_layer = 2  # Use a different layer than characters
	static_body.collision_mask = 0

# Set up the visual appearance of the sell zone
func setup_appearance():
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
		
		# Create mesh (simple plane with some size)
		var plane_mesh = PlaneMesh.new()
		plane_mesh.size = Vector2(3, 3)  # Adjust size as needed
		mesh_instance.mesh = plane_mesh
	
	# Create and apply the material
	var material = StandardMaterial3D.new()
	material.albedo_color = default_color
	material.emission_enabled = true
	material.emission = Color(0.8, 0.2, 0.2)
	material.emission_energy_multiplier = 0.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	
	# Print debug info
	print("SellZone setup complete")

# Highlight when unit is hovering over the zone
func highlight_active():
	if mesh_instance and mesh_instance.material_override:
		mesh_instance.material_override.albedo_color = active_color
		mesh_instance.material_override.emission_energy_multiplier = 1.0

# Reset highlight when unit leaves
func reset_highlight():
	if mesh_instance and mesh_instance.material_override:
		mesh_instance.material_override.albedo_color = default_color
		mesh_instance.material_override.emission_energy_multiplier = 0.5
