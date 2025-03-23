extends CharacterBody3D

# Character data reference
var character_data: Character = null

# Drag and drop properties
var is_dragging = false
var drag_height = 0.5  # Increased height for floating effect
var drag_plane = null  # Plane for mouse intersection
var drag_offset = Vector3.ZERO
var original_position = Vector3.ZERO
var original_tile = null
var original_y = 0  # Store original height

# References to game objects
var board = null
var sell_zone = null

# Animation references
@onready var animation_player: AnimationPlayer = $Armature/AnimationPlayer
const IDLE_ANIM = "Unarmed_Idle/mixamo_com" # Use the actual animation name from your character
const DRAG_ANIM = "Fall_and_Loop/mixamo_com" # Use the actual animation name from your character

# Visual elements
var model: Node3D
var health_bar: ProgressBar3D

func _ready():
	if animation_player:
		print("Available animations:")
		for anim in animation_player.get_animation_list():
			print("- " + anim)
	
	# Find the board in the scene
	board = get_node("/root/GameBoard")
	
	if board:
		# Find the sell zone
		sell_zone = get_node_or_null("/root/GameBoard/SellZone")
		
		# Store our starting tile
		original_tile = board.get_tile_at_position(global_position)
		if original_tile:
			original_tile.set_occupying_unit(self)
	else:
		push_error("WARNING: Board reference not found!")
	
	# Create a plane for drag calculations
	drag_plane = Plane(Vector3.UP, 0)
	
	# Start idle animation
	if animation_player:
		animation_player.play(IDLE_ANIM)
	
	# Setup health bar and other visuals based on character data
	setup_visuals()

# Set character data
func set_character_data(data: Character):
	character_data = data
	setup_visuals()

# Get character data
func get_character_data() -> Character:
	return character_data

# Setup visual elements based on character data
func setup_visuals():
	if character_data:
		# Set up health bar
		if not health_bar:
			# Create 3D health bar above character
			health_bar = ProgressBar3D.new()
			health_bar.size = Vector3(1.0, 0.1, 0.1)
			health_bar.position = Vector3(0, 2.0, 0)
			add_child(health_bar)
		
		# Set health
		health_bar.max_value = character_data.health
		health_bar.value = character_data.health
		
		# You could also change the model or add other visual elements here
		# based on the character data (rarity glow, etc.)
		
		# Add a glow based on rarity
		add_rarity_glow()

# Add a glow effect based on character rarity
func add_rarity_glow():
	if character_data:
		# Create a glow effect as a mesh
		var glow = MeshInstance3D.new()
		glow.name = "RarityGlow"
		
		# Create a cylinder mesh as the glow
		var cylinder_mesh = CylinderMesh.new()
		cylinder_mesh.top_radius = 0.8
		cylinder_mesh.bottom_radius = 0.8
		cylinder_mesh.height = 0.05
		glow.mesh = cylinder_mesh
		
		# Position at the character's feet
		glow.position = Vector3(0, 0.03, 0)
		
		# Create material with emission based on rarity
		var material = StandardMaterial3D.new()
		material.albedo_color = character_data.get_rarity_color()
		material.emission_enabled = true
		material.emission = character_data.get_rarity_color()
		material.emission_energy_multiplier = 0.5
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.material_override = material
		
		add_child(glow)

func _input(event):
	if not board:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if this unit was clicked
				var ray_result = get_mouse_collision()
				
				if ray_result and ray_result.collider == self:
					start_drag(event.position)
					
			elif is_dragging:
				end_drag()
				
	elif event is InputEventMouseMotion and is_dragging:
		update_drag_position(event.position)

func get_mouse_collision():
	# Get the mouse position in 3D space
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000
	
	# Set up physics query
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	
	# Do the raycast
	var space_state = get_world_3d().direct_space_state
	return space_state.intersect_ray(query)

func start_drag(mouse_pos):
	is_dragging = true
	
	# Save our starting position and tile
	original_position = global_position
	original_y = global_position.y
	original_tile = board.get_tile_at_position(global_position)
	
	# Calculate drag offset to maintain relative position
	var camera = get_viewport().get_camera_3d()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	# Find intersection with drag plane at current height
	drag_plane = Plane(Vector3.UP, global_position.y)
	var intersection = drag_plane.intersects_ray(ray_origin, ray_dir)
	
	if intersection:
		drag_offset = global_position - intersection
	
	# Raise the unit while dragging for visual feedback (floating effect)
	drag_plane = Plane(Vector3.UP, drag_height)
	
	# Play the dragging animation with crossfade
	if animation_player:
		animation_player.play(DRAG_ANIM, 0.3)  # 0.3 seconds crossfade time

func update_drag_position(mouse_pos):
	var camera = get_viewport().get_camera_3d()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	var intersection = drag_plane.intersects_ray(ray_origin, ray_dir)
	
	if intersection:
		global_position = intersection + drag_offset
		
		# Show potential placement
		var closest_tile = board.get_closest_tile(global_position)
		if closest_tile:
			board.highlight_potential_drop(closest_tile)

func end_drag():
	is_dragging = false
	
	# Check if unit is over the sell zone
	if sell_zone and sell_zone.get_overlapping_bodies().has(self):
		# Sell the unit and remove it
		if sell_zone.handle_unit_drop(self):
			# Clean up original tile reference
			if original_tile:
				original_tile.set_occupying_unit(null)
			
			# Remove the unit
			queue_free()
			return
	
	# Find the closest tile
	var target_tile = board.get_closest_tile(global_position)
	
	if target_tile and board.is_valid_placement_zone(target_tile):
		var occupying_unit = target_tile.get_occupying_unit()
		
		if occupying_unit and occupying_unit != self:
			# Swap with the existing unit
			swap_with_unit(occupying_unit, target_tile)
		else:
			# Move to the new tile
			snap_to_tile(target_tile)
	else:
		# Return to original position if target is invalid
		global_position = original_position
	
	# Clear highlight
	board.clear_highlight()
	
	# Return to idle animation with crossfade
	if animation_player:
		animation_player.play(IDLE_ANIM, 0.3)  # 0.3 seconds crossfade time

func swap_with_unit(other_unit, target_tile):
	# Move other unit to our original position/tile
	other_unit.global_position = original_position
	
	if original_tile:
		original_tile.set_occupying_unit(other_unit)
	
	# Move this unit to target position/tile
	var center_pos = target_tile.get_center_position()
	global_position = Vector3(center_pos.x, original_y, center_pos.z)
	target_tile.set_occupying_unit(self)

func snap_to_tile(tile):
	# Move to the tile's center position
	var center_pos = tile.get_center_position()
	global_position = Vector3(center_pos.x, original_y, center_pos.z)
	
	# Update occupancy
	if original_tile != tile:
		if original_tile:
			original_tile.set_occupying_unit(null)
		
		tile.set_occupying_unit(self)
