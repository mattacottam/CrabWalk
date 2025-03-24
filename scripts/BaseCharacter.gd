extends CharacterBody3D

# Character data
var character_data = null

# Drag and drop properties
var is_dragging = false
var drag_height = 0.5  # Increased height for floating effect
var drag_plane = null  # Plane for mouse intersection
var drag_offset = Vector3.ZERO
var original_position = Vector3.ZERO
var original_tile = null
var original_y = 0  # Store original height

# Maximum distance for hex tile snapping
const MAX_SNAP_DISTANCE = 5.0  # Adjust as needed

# Reference to the board and sell zone
var board = null
var sell_zone = null

# Animation references
@onready var animation_player = $Armature/AnimationPlayer if has_node("Armature/AnimationPlayer") else null
const IDLE_ANIM = "Unarmed_Idle/mixamo_com"
const DRAG_ANIM = "Fall_and_Loop/mixamo_com"

# Collision shape for better click detection
var collision_shape

func _ready():
	# Find the board in the scene
	board = get_node("/root/GameBoard")
	
	# Find the sell zone
	sell_zone = get_node_or_null("/root/GameBoard/SellZone")
	
	# Create a collision shape if none exists
	ensure_collision()
	
	if board:
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

# Ensure there's a proper collision shape for clicking
func ensure_collision():
	if not has_node("CollisionShape3D"):
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		
		var shape = CapsuleShape3D.new()
		shape.radius = 0.5
		shape.height = 2.0
		
		collision_shape.shape = shape
		collision_shape.position = Vector3(0, 1.0, 0)  # Center vertically on character
		
		add_child(collision_shape)
		
		# Make sure collision is enabled
		collision_layer = 1
		collision_mask = 0  # Don't need the character to detect collisions, just be clickable

# Set character data (called by shop system)
func set_character_data(data):
	character_data = data

# Get character data
func get_character_data():
	return character_data

func _unhandled_input(event):
	# Only process input if not being handled by UI
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if this unit was clicked
				var ray_result = get_mouse_collision()
				
				if ray_result and (ray_result.collider == self or ray_result.collider.get_parent() == self):
					start_drag(event.position)
			
			elif is_dragging:
				end_drag()
	
	elif event is InputEventMouseMotion and is_dragging:
		update_drag_position(event.position)


func get_mouse_collision():
	# Get the mouse position in 3D space
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return null
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000
	
	# Set up physics query
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
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
		
		# Check if we're over the sell zone
		var over_sell_zone = is_over_sell_zone()
		
		# Show potential placement or sell highlight
		if over_sell_zone:
			if sell_zone:
				sell_zone.highlight_active()
			board.clear_highlight()
		else:
			if sell_zone:
				sell_zone.reset_highlight()
			var closest_tile = board.get_closest_tile(global_position)
			if closest_tile:
				# Only highlight if within maximum snap distance
				var distance = global_position.distance_to(closest_tile.global_position) 
				if distance <= MAX_SNAP_DISTANCE:
					board.highlight_potential_drop(closest_tile)
				else:
					board.clear_highlight()

func end_drag():
	is_dragging = false
	
	# Check if the unit is over the sell zone
	if is_over_sell_zone():
		sell_unit()
		return
	
	# Find the closest tile
	var target_tile = board.get_closest_tile(global_position)
	var distance_to_target = global_position.distance_to(target_tile.global_position)
	
	# Check if the tile is within range and in a valid zone
	if target_tile and distance_to_target <= MAX_SNAP_DISTANCE and board.is_valid_placement_zone(target_tile):
		var occupying_unit = target_tile.get_occupying_unit()
		
		if occupying_unit and occupying_unit != self:
			# Swap with the existing unit
			swap_with_unit(occupying_unit, target_tile)
		else:
			# Move to the new tile
			snap_to_tile(target_tile)
	else:
		# Return to original position if target is invalid or too far
		global_position = original_position
	
	# Clear highlights
	board.clear_highlight()
	if sell_zone:
		sell_zone.reset_highlight()
	
	# Return to idle animation with crossfade
	if animation_player:
		animation_player.play(IDLE_ANIM, 0.3)  # 0.3 seconds crossfade time

func is_over_sell_zone():
	if not sell_zone:
		return false
	
	# Check if we're close to the sell zone's position using distance comparison
	var distance = global_position.distance_to(sell_zone.global_position)
	
	# If we're within 2 units of the sell zone's center, consider it a hit
	return distance < 2.0

func sell_unit():
	# Tell the original tile we're no longer there
	if original_tile:
		original_tile.set_occupying_unit(null)
	
	# Update player gold (assuming you have a Player singleton or similar)
	var player = get_node_or_null("/root/GameBoard/Player")
	if player:
		# Get sell value based on character_data if available
		var sell_value = 3  # Default value
		if character_data != null:
			# Safely check if we can access cost property
			if typeof(character_data) == TYPE_OBJECT and character_data.get("cost") != null:
				sell_value = character_data.cost
			# If it's a dictionary
			elif typeof(character_data) == TYPE_DICTIONARY and "cost" in character_data:
				sell_value = character_data["cost"]
		
		player.add_gold(sell_value)
	
	# Delete the unit
	queue_free()

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
