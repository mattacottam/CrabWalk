extends Node3D
class_name HealthBarSystem

# Bar properties
var health_bar_width = 0.75   
var health_bar_height = 0.12
var health_spacing = 0.02
var mana_bar_height = 0.1
var mana_bar_width = 0.75
var vertical_spacing = 0.02

# Health variables
var max_health: int = 100
var current_health: int = 100
var segments: Array[MeshInstance3D] = []
var segments_count: int = 10  # Default number of segments
var health_per_segment: float = 10.0

# Mana variables
var max_mana: int = 100
var current_mana: int = 0
var mana_bar: MeshInstance3D

# References
var health_container: Node3D
var mana_container: Node3D
var background_mesh: MeshInstance3D
var mana_mesh: MeshInstance3D

# Billboard mode - always face camera
var billboard_mode: bool = true

# Materials
var health_material: StandardMaterial3D
var health_background_material: StandardMaterial3D
var mana_material: StandardMaterial3D
var mana_background_material: StandardMaterial3D

func _init(p_max_health: int = 100, p_max_mana: int = 100):
	max_health = p_max_health
	current_health = p_max_health
	max_mana = p_max_mana
	current_mana = 0
	
	# Calculate segments based on max health
	segments_count = calculate_segments(max_health)
	health_per_segment = float(max_health) / segments_count
	
	# Create containers
	health_container = Node3D.new()
	health_container.name = "HealthContainer"
	add_child(health_container)
	
	mana_container = Node3D.new()
	mana_container.name = "ManaContainer"
	add_child(mana_container)
	
	# Calculate positions
	mana_container.position.y = -health_bar_height - vertical_spacing
	
	# Create materials
	create_materials()
	
	# Create health segments and mana bar
	create_health_segments()
	create_mana_bar()

func _ready():
	# Position slightly above character
	global_position.y += 0.2
	
	# Initial update
	update_health_display(current_health)
	update_mana_display(current_mana)

func _process(_delta):
	# Make the bars more visible from an isometric/top-down view
	if billboard_mode:
		var camera = get_viewport().get_camera_3d()
		if camera:
			# Get camera basis
			var camera_forward = -camera.global_transform.basis.z.normalized()
			var _camera_position = camera.global_position
			
			# Calculate a better angle for the health bars
			# Instead of directly facing the camera, tilt them to be more visible
			var up_vector = Vector3(0, 2, 0)
			
			# Create a blend between the camera's forward direction and the up vector
			# The more "up" we blend, the more horizontal the bars will appear
			var blend_factor = 0.5  # Adjust between 0-1 (higher = more horizontal)
			var display_normal = camera_forward.lerp(up_vector, blend_factor).normalized()
			
			# Rotate to face this direction but keep the x-axis horizontal
			var _target_position = global_position + display_normal
			
			# Create a basis with y axis as our display normal and z axis as world up
			var y_axis = display_normal
			var z_axis = Vector3(0, 1, 0)
			var x_axis = z_axis.cross(y_axis).normalized()
			z_axis = y_axis.cross(x_axis).normalized()
			
			global_transform.basis = Basis(x_axis, y_axis, z_axis)

# Calculate number of segments based on max health
func calculate_segments(health: int) -> int:
	# For TFT-style scaling: more health = more segments
	if health <= 100:
		return 5  # Reduced from 10
	elif health <= 200:
		return 8  # Reduced from 10
	elif health <= 300:
		return 10  # Reduced from 15  
	else:
		return 12  # Reduced from 20

# Create all the materials used for the bars
func create_materials():
	# Health bar materials
	health_material = StandardMaterial3D.new()
	health_material.albedo_color = Color(0.2, 0.8, 0.2)  # Green
	health_material.emission_enabled = true
	health_material.emission = Color(0.1, 0.5, 0.1)  # Darker green glow
	health_material.emission_energy_multiplier = 0.3
	
	health_background_material = StandardMaterial3D.new()
	health_background_material.albedo_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray
	health_background_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Mana bar materials
	mana_material = StandardMaterial3D.new()
	mana_material.albedo_color = Color(0.2, 0.2, 0.8)  # Blue
	mana_material.emission_enabled = true
	mana_material.emission = Color(0.1, 0.1, 0.5)  # Darker blue glow
	mana_material.emission_energy_multiplier = 0.3
	
	mana_background_material = StandardMaterial3D.new()
	mana_background_material.albedo_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray
	mana_background_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Make sure materials use correct depth settings
	health_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	mana_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	health_background_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	mana_background_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY

# Create the segmented health bar
func create_health_segments():
	# Calculate segment width with spacing
	var total_spacing = health_spacing * (segments_count - 1)
	var segment_width = (health_bar_width - total_spacing) / segments_count
	
	# Create a background panel
	background_mesh = MeshInstance3D.new()
	background_mesh.name = "HealthBackground"
	var background = BoxMesh.new()
	background.size = Vector3(health_bar_width + 0.04, health_bar_height + 0.04, 0.01)
	background_mesh.mesh = background
	background_mesh.material_override = health_background_material
	background_mesh.position.z = -0.005  # Slightly behind
	health_container.add_child(background_mesh)
	
	# Create each segment
	segments.clear()
	for i in range(segments_count):
		var segment = MeshInstance3D.new()
		segment.name = "Segment" + str(i)
		
		# Create mesh for segment
		var box = BoxMesh.new()
		box.size = Vector3(segment_width, health_bar_height, 0.01)
		segment.mesh = box
		
		# Position the segment
		var x_pos = -health_bar_width/2 + segment_width/2 + i * (segment_width + health_spacing)
		segment.position = Vector3(x_pos, 0, 0)
		
		# Apply material
		segment.material_override = health_material
		
		# Add to container and array
		health_container.add_child(segment)
		segments.append(segment)

# Create the mana bar (solid, not segmented)
func create_mana_bar():
	# Create background
	var mana_bg = MeshInstance3D.new()
	mana_bg.name = "ManaBackground"
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(mana_bar_width + 0.04, mana_bar_height + 0.04, 0.01)
	mana_bg.mesh = bg_mesh
	mana_bg.material_override = mana_background_material
	mana_bg.position.z = -0.005  # Slightly behind
	mana_container.add_child(mana_bg)
	
	# Create foreground mana bar
	mana_mesh = MeshInstance3D.new()
	mana_mesh.name = "ManaBar"
	var bar_mesh = BoxMesh.new()
	bar_mesh.size = Vector3(mana_bar_width, mana_bar_height, 0.01)
	mana_mesh.mesh = bar_mesh
	mana_mesh.material_override = mana_material
	
	# Start with empty mana - position at left edge
	mana_mesh.scale.x = 0.001  # Almost zero, but not zero to avoid scale issues
	
	# Position at left edge for proper scaling
	mana_mesh.position.x = -mana_bar_width/2 + (mana_mesh.scale.x * mana_bar_width)/2
	
	mana_container.add_child(mana_mesh)
	mana_bar = mana_mesh

# Update health bar display based on current health
func update_health_display(new_health: int):
	current_health = clamp(new_health, 0, max_health)
	
	# Calculate how many segments should be visible
	var segments_to_show = ceil(float(current_health) / health_per_segment)
	
	# Update each segment
	for i in range(segments_count):
		if i < segments_to_show:
			# Show this segment
			if i < segments_to_show - 1 or is_equal_approx(fmod(float(current_health), health_per_segment), 0.0):
				# Full segment
				segments[i].visible = true
				segments[i].scale = Vector3(1, 1, 1)
			else:
				# Partial segment (last one)
				var remaining_health = fmod(float(current_health), health_per_segment)
				var fill_amount = remaining_health / health_per_segment
				segments[i].visible = true
				segments[i].scale = Vector3(fill_amount, 1, 1)
				
				# Adjust position to scale from left edge
				var segment_width = health_bar_width / segments_count - health_spacing
				var original_x = segments[i].position.x
				var offset = segment_width * (1 - fill_amount) / 2
				segments[i].position.x = original_x - offset
		else:
			# Hide this segment
			segments[i].visible = false

# Update mana bar display
func update_mana_display(new_mana: int):
	current_mana = clamp(new_mana, 0, max_mana)
	
	# Calculate fill amount
	var fill_amount = float(current_mana) / max_mana
	
	# Update scale and position for left-to-right filling
	if fill_amount > 0.001:  # Avoid very small scales
		mana_bar.scale.x = fill_amount
		
		# Position from the left edge (this is key for left-to-right filling)
		# The bar grows from the left edge towards the right
		mana_bar.position.x = -mana_bar_width/2 + (fill_amount * mana_bar_width)/2
	else:
		# Almost empty
		mana_bar.scale.x = 0.001
		mana_bar.position.x = -mana_bar_width/2

# Set new max health and update the bar
func set_max_health(new_max: int):
	max_health = max(1, new_max)  # Ensure at least 1 health
	
	# Recalculate segments if needed
	var new_segments_count = calculate_segments(max_health)
	if new_segments_count != segments_count:
		segments_count = new_segments_count
		health_per_segment = float(max_health) / segments_count
		
		# Recreate the health bar with new segment count
		for segment in segments:
			segment.queue_free()
		segments.clear()
		background_mesh.queue_free()
		
		create_health_segments()
	else:
		# Just update the health per segment value
		health_per_segment = float(max_health) / segments_count
	
	# Update display
	update_health_display(current_health)

# Set new max mana
func set_max_mana(new_max: int):
	max_mana = max(1, new_max)
	update_mana_display(current_mana)
