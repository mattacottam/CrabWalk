extends Unit
class_name PlayerUnit

# Drag and drop properties
var is_dragging = false
var drag_height = 0.5  # Increased height for floating effect
var drag_plane = null  # Plane for mouse intersection
var drag_offset = Vector3.ZERO
var original_position = Vector3.ZERO
var original_y = 0  # Store original height

# Maximum distance for hex tile snapping
const MAX_SNAP_DISTANCE = 5.0  # Adjust as needed

# Reference to the sell zone
var sell_zone = null

# Status flags
var combine_cooldown = false
var star_decorations = []

func _ready():
	# Call parent _ready first
	super._ready()
	
	# Find the board in the scene
	board = get_node("/root/GameBoard")
	
	# Find the sell zone
	sell_zone = get_node_or_null("/root/GameBoard/SellZone")
	
	# Create a collision shape if none exists
	ensure_collision()
	
	# Create a plane for drag calculations
	drag_plane = Plane(Vector3.UP, 0)
	
	if board:
		# Store our starting tile
		original_tile = board.get_tile_at_position(global_position)
		if original_tile:
			original_tile.set_occupying_unit(self)
	
	# Start idle animation
	if animation_player:
		animation_player.play(IDLE_ANIM)
		
	# Create and initialize components
	initialize_components()
		
	# If we already have character data, apply it
	if character_data:
		apply_character_visuals()
		
	# Update UI
	update_ui()
	
	# Initialize star level from character data
	if character_data:
		set_star_level(character_data.star_level)
	else:
		set_star_level(1)
	
	# Trigger automatic combine check (delayed to ensure everything is set up)
	call_deferred("check_for_automatic_combine")

# Add this new function to PlayerUnit:
func initialize_components():
	# Make sure Components node exists
	var components = get_node_or_null("Components")
	if not components:
		components = Node.new()
		components.name = "Components"
		add_child(components)
	
	# Add and initialize the combat component
	var combat_component_node = components.get_node_or_null("CombatComponent")
	
	if not combat_component_node:
		var combat_component = CombatComponent.new(self)
		combat_component.name = "CombatComponent"
		components.add_child(combat_component)
	
	# Add and initialize the ability component
	var ability_component_node = components.get_node_or_null("AbilityComponent")
	
	if not ability_component_node:
		var ability_component = AbilityComponent.new(self)
		ability_component.name = "AbilityComponent"
		components.add_child(ability_component)

func _unhandled_input(event):
	# Skip if in combat or board is null
	if in_combat or not board:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if this unit was clicked
				var ray_result = get_mouse_collision()
				
				if ray_result and (ray_result.collider == self or ray_result.collider.get_parent() == self):
					print("Unit clicked: " + str(character_data.display_name if character_data else "Unknown"))
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
	# Prevent dragging if this is an enemy unit
	if character_data and character_data.is_enemy:
		print("Cannot drag enemy units")
		return
		
	is_dragging = true
	
	# Save our starting position and tile
	original_position = global_position
	original_y = global_position.y
	
	if board:
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
	if not board:
		return
		
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
	
	if not board:
		return
	
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
			
		# Check for automatic combining after move
		call_deferred("check_for_automatic_combine")
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
	if not board:
		return
		
	# Tell the original tile we're no longer there
	if original_tile:
		original_tile.set_occupying_unit(null)
	
	# Update player gold (assuming you have a Player singleton or similar)
	var player = get_node_or_null("/root/GameBoard/Player")
	if player:
		# Get base cost from character data
		var base_cost = 1  # Default value
		
		if character_data and character_data.get("cost") != null:
			base_cost = character_data.cost
		
		# Calculate sell value based on star level
		var sell_value = 0
		
		if base_cost == 1: # No sell penalty for 1-cost units.
			match star_level:
				1:
					sell_value = 1
				2:
					sell_value = 3
				3:
					sell_value = 9
		else:
			match star_level:
				1:
					# 1-star: just the base cost
					sell_value = base_cost
				2:
					# 2-star: (cost × 3) - 1 (the price of three 1-stars, minus 1)
					sell_value = (base_cost * 3) - 1
				3:
					# 3-star: (cost × 9) - 2 (the price of nine 1-stars, minus 2)
					sell_value = (base_cost * 9) - 1
		
		# Ensure value is at least 1
		sell_value = max(sell_value, 1)
		
		print("Selling " + str(star_level) + "-star unit for " + str(sell_value) + " gold")
		
		# Add gold
		player.add_gold(sell_value)
		
		# Create the gold text effect
		if is_instance_valid(board):
			# Create the animation and capture position BEFORE deleting the unit
			var pos = global_position
			
			# Create the Label3D as a child of board, not of this unit
			var world_label = Label3D.new()
			world_label.text = "+" + str(sell_value) + " gold"
			world_label.font_size = 72
			world_label.modulate = Color(1.0, 0.84, 0.0)  # Gold color
			world_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			world_label.position = pos + Vector3(0, 2, 0)
			board.add_child(world_label)
			
			# Animate the label
			var tween = board.create_tween()
			tween.tween_property(world_label, "position", world_label.position + Vector3(0, 1.5, 0), 0.8)
			tween.parallel().tween_property(world_label, "modulate:a", 0.0, 0.8)
			
			# Create an independent timer in the board to remove the label
			var timer = get_tree().create_timer(0.8)
			timer.timeout.connect(func(): world_label.queue_free())
	
	# Delete the unit immediately
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

# Set the star level for this unit
func set_star_level(level: int):
	star_level = clamp(level, 1, 3)
	
	# Update character data's star level as well
	if character_data:
		character_data.star_level = star_level
	
	# Update scale based on star level
	scale = STAR_SCALES[star_level]
	
	# Create star decorations
	update_star_decorations()

# Create visual star decorations
func update_star_decorations():
	# Remove any existing star decorations
	for star in star_decorations:
		if is_instance_valid(star):
			star.queue_free()
	star_decorations.clear()
	
	# Create stars based on star level
	var star_color = STAR_COLORS[star_level]
	
	for i in range(star_level):
		var star = create_star_mesh(star_color)
		add_child(star)
		
		# Position stars horizontally above the unit
		var offset = (i - (star_level-1)/2.0) * 0.3  # Center the stars
		star.position = Vector3(offset, 2.2, 0)
		star_decorations.append(star)

# Create a star mesh
func create_star_mesh(color: Color) -> MeshInstance3D:
	var star = MeshInstance3D.new()
	
	# Use a simple shape for the star (can be improved later)
	var sphere = SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	star.mesh = sphere
	
	# Create glowing material
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	star.material_override = material
	
	return star

# Check if this unit can combine with another
func can_combine_with(other_unit) -> bool:
	if not character_data or not other_unit or not other_unit.character_data:
		return false
		
	# Must be same character, same star level, and both must be the same type (player or enemy)
	return (character_data.id == other_unit.character_data.id and 
	   star_level == other_unit.star_level and 
	   star_level < 3 and
	   character_data.is_enemy == other_unit.character_data.is_enemy)

# Find all matching units on the board of the same type and star level
func find_matching_units():
	var matching_units = [self]  # Start with self
	
	if not board or not character_data:
		return matching_units
	
	# Look through all tiles for matching units
	for tile_key in board.tiles:
		var tile = board.tiles[tile_key]
		if tile.is_occupied():
			var unit = tile.get_occupying_unit()
			
			# Skip self and already included units
			if unit == null or unit == self or matching_units.has(unit):
				continue
				
			# Check if it's the same type and star level AND same enemy status
			if (unit.character_data and 
			   unit.character_data.id == character_data.id and 
			   unit.star_level == star_level and
			   unit.character_data.is_enemy == character_data.is_enemy):
				matching_units.append(unit)
	
	return matching_units

# Check for automatic combining opportunities
func check_for_automatic_combine():
	# Don't combine if already on cooldown
	if combine_cooldown:
		return
		
	# Don't combine enemy units automatically
	if character_data and character_data.is_enemy:
		return
		
	# Make sure we can combine (star level < 3)
	if star_level >= 3 or not character_data:
		return
	
	# Find all matching units
	var matching_units = find_matching_units()
	print("Found " + str(matching_units.size()) + " matching units for " + character_data.display_name)
	
	# If we have EXACTLY 3 matching units, combine them
	if matching_units.size() == 3:
		# Set cooldown to prevent recursion
		combine_cooldown = true
		
		# Perform the combination
		combine_units(matching_units)
		
		# Reset cooldown after a delay
		var timer = get_tree().create_timer(1.0)
		await timer.timeout
		combine_cooldown = false

# Combine three units into one higher star level unit
func combine_units(units_to_combine):
	# Choose the first unit's tile as the target
	var target_tile = board.get_tile_at_position(units_to_combine[0].global_position)
	
	# Free the original tiles
	for unit in units_to_combine:
		var tile = board.get_tile_at_position(unit.global_position)
		if tile:
			tile.set_occupying_unit(null)
	
	# Create new unit at the target tile
	var character_scene = load("res://scenes/characters/PlayerUnit.tscn")
	var new_unit = character_scene.instantiate()
	board.add_child(new_unit)
	
	# Copy character data but increase star level
	var new_char_data = units_to_combine[0].character_data.duplicate()
	var new_star_level = units_to_combine[0].star_level + 1
	new_char_data.star_level = new_star_level
	
	# Set up the new unit
	new_unit.set_character_data(new_char_data)
	# Explicitly set star level again to make sure it's correct
	new_unit.set_star_level(new_star_level)
	
	# Position at the target tile
	new_unit.global_position = target_tile.get_center_position()
	target_tile.set_occupying_unit(new_unit)
	
	# Create a visual effect for the combination
	create_combine_effect(target_tile.global_position)
	
	# Remove the original units
	for unit in units_to_combine:
		unit.queue_free()
	
	# Add a delay before checking for further combinations to prevent recursion issues
	var timer = get_tree().create_timer(0.5)
	await timer.timeout
	
	# Check for further combinations (for cascading combines)
	if is_instance_valid(new_unit):
		new_unit.check_for_automatic_combine()

# Create visual effect for combining
func create_combine_effect(pos: Vector3):
	# Create particle effect node
	var particles = GPUParticles3D.new()
	particles.position = pos
	particles.position.y += 1.0  # Raise a bit
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.lifetime = 1.5
	particles.emitting = true
	particles.amount = 30
	
	# Create particle material
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.5
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.gravity = Vector3(0, 2, 0)
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.scale_min = 0.2
	material.scale_max = 0.5
	material.color = STAR_COLORS[min(star_level + 1, 3)]
	particles.process_material = material
	
	# Create mesh for particles
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh
	
	# Add to scene and start
	board.add_child(particles)
	
	# Remove after effect completes
	var timer = get_tree().create_timer(particles.lifetime * 1.5)
	await timer.timeout
	particles.queue_free()
