class_name ProgressBar3D
extends Node3D

var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var size: Vector3 = Vector3(1, 0.1, 0.1)
var max_value: float = 100.0
var value: float = 100.0

func _init():
	mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	
	material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.8, 0.2)  # Green
	mesh_instance.material_override = material
	
	add_child(mesh_instance)

func _process(_delta):
	# Update the mesh scale based on health percentage
	var scale_factor = max(value / max_value, 0.01)  # Prevent zero scale
	mesh_instance.scale = Vector3(scale_factor, 1, 1)
	
	# Update position to remain centered
	mesh_instance.position.x = (scale_factor - 1) * size.x * 0.5
