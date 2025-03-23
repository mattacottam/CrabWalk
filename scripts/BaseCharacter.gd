extends CharacterBody3D

# Drag and drop properties
var is_dragging = false
var drag_height = 0.5  # Increased height for floating effect
var drag_plane = null  # Plane for mouse intersection
var drag_offset = Vector3.ZERO
var original_position = Vector3.ZERO
var original_tile = null
var original_y = 0  # Store original height

# Reference to the board
var board = null

# Animation references
@onready var animation_player: AnimationPlayer = $Armature/AnimationPlayer
const IDLE_ANIM = "Unarmed_Idle/mixamo_com"
const DRAG_ANIM = "Fall_and_Loop/mixamo_com"

func _ready():
	# Find the board in the scene
	board = get_node("/root/GameBoard")
	
	if board:
		# Store our starting tile
		original_tile = board.get_tile_at_position(global_position)
		if original_tile:
			original_tile.set_occupying_unit(self)
	else:
		print("WARNING: Board reference not found!")
	
	# Create a plane for drag calculations
	drag_plane = Plane(Vector3.UP, 0)
	
	# Start idle animation
	if animation_player:
		animation_player.play(IDLE_ANIM)

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
