extends CharacterBody3D

# Character data
var character_data = null
var star_level = 1  # Current star level of this unit instance

# Current stats
var current_health: int = 100
var current_mana: int = 0
var max_health: int = 100
var max_mana: int = 100

# Visual elements
var character_mesh = null
var character_material = null
var health_bar_system = null

# Star visuals
var combine_cooldown = false
var star_decorations = []
const STAR_COLORS = {
	1: Color(0.8, 0.8, 0.2),  # Gold
	2: Color(0.6, 0.8, 1.0),  # Light blue
	3: Color(1.0, 0.3, 0.7)   # Pink/purple
}
const STAR_SCALES = {
	1: Vector3(1.0, 1.0, 1.0),
	2: Vector3(1.15, 1.15, 1.15),
	3: Vector3(1.3, 1.3, 1.3)
}

# UI elements
var nameplate = null

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
const IDLE_ANIM = "unarmed idle 01/mixamo_com"
const DRAG_ANIM = "fall a loop/mixamo_com"
const IDLE_COMBAT_ANIM = "standing idle 01/mixamo_com"
const MOVE_ANIM = "standing walk forward/mixamo_com"
const ATTACK_ANIM = "standing melee punch/mixamo_com" 
const TAKE_DAMAGE_ANIM = "standing react small from front/mixamo_com"
const DYING_ANIM = "standing death backward 01/mixamo_com"
const VICTORY_ANIM = "standing idle 03 examine/mixamo_com"

# Collision shape for better click detection
var collision_shape

# Combat state
var combat_system = null
var in_combat = false
var target_unit = null
var current_path = []
var move_speed = 2.0
var current_action = "idle"  # idle, moving, attacking, casting, hurt, dying
var attack_cooldown = 0.0
var attack_cooldown_max = 1.0  # Base cooldown, will be adjusted by attack_speed

func _ready():
	#test_health_damage()
	
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
	
	# If we already have character data, apply it
	if character_data:
		apply_character_visuals()
	
	# Find or create health bar system
	health_bar_system = $UIBillboard/HealthBarSystem
	if not health_bar_system:
		health_bar_system = HealthBarSystem.new(
			max_health if character_data else 100,
			max_mana if character_data else 100
		)
		health_bar_system.name = "HealthBarSystem"
		$UIBillboard.add_child(health_bar_system)
	
	# Initialize stats and update UI
	initialize_stats()
	update_ui()
	
	# Set initial health and mana for display
	if health_bar_system:
		health_bar_system.update_health_display(current_health)
		health_bar_system.update_mana_display(current_mana)
	
	# Initialize star level from character data
	if character_data:
		set_star_level(character_data.star_level)
	else:
		set_star_level(1)
	
	# Trigger automatic combine check (delayed to ensure everything is set up)
	call_deferred("check_for_automatic_combine")

# Initialize character stats from character_data
func initialize_stats():
	if character_data:
		max_health = character_data.health
		current_health = max_health
		max_mana = character_data.mana_max
		
		# Scale stats based on star level
		if character_data.star_level == 2:
			max_health = int(max_health * 1.8)  # 80% increase
			current_health = max_health
		elif character_data.star_level == 3:
			max_health = int(max_health * 3.2)  # 220% increase from level 1
			current_health = max_health
		
		# Use starting_mana from character data if available
		current_mana = character_data.starting_mana
		
		# Make sure current_mana is not more than max_mana
		current_mana = min(current_mana, max_mana)
		
		# Update health bar system
		if health_bar_system:
			health_bar_system.set_max_health(max_health)
			health_bar_system.set_max_mana(max_mana)
			health_bar_system.update_health_display(current_health)
			health_bar_system.update_mana_display(current_mana)

# Update UI elements based on character data
func update_ui():
	var nameplate_node = $UIBillboard/Nameplate
	if nameplate_node:
		# Hide the nameplate
		nameplate_node.visible = false
		
	if character_data and nameplate_node:
		nameplate_node.text = character_data.display_name
		
		# Set nameplate color based on rarity
		var rarity_color = character_data.get_rarity_color()
		nameplate_node.modulate = rarity_color

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

# Set character data and apply visuals
func set_character_data(data):
	character_data = data
	apply_character_visuals()
	initialize_stats()
	update_ui()

# Apply visual customizations based on character data
func apply_character_visuals():
	if not character_data:
		return
	
	# Find the mesh instance to apply materials to
	find_character_mesh(self)
	
	if character_mesh:
		# Either create a new material or get the existing one
		if not character_material:
			character_material = StandardMaterial3D.new()
		
		# Apply character color
		character_material.albedo_color = character_data.color
		
		# Add tint for enemies
		if character_data.is_enemy:
			# Darken color and add red tint for enemies
			character_material.albedo_color = character_material.albedo_color.darkened(0.2)
			character_material.albedo_color = character_material.albedo_color.blend(Color(0.8, 0.2, 0.2))
			
			# Add emission for a subtle glow
			character_material.emission_enabled = true
			character_material.emission = Color(0.8, 0.0, 0.0)
			character_material.emission_energy_multiplier = 0.3
		
		# Apply to mesh
		character_mesh.material_override = character_material
		
		print("Applied visuals for: " + character_data.display_name)
	else:
		print("No suitable mesh found for character visuals")

# Recursively find a suitable mesh to apply materials to
func find_character_mesh(node):
	for child in node.get_children():
		if child is MeshInstance3D:
			character_mesh = child
			return
		
		if child.get_child_count() > 0:
			find_character_mesh(child)
			if character_mesh:
				return

# Get character data
func get_character_data():
	return character_data

# Take damage and update health display
func take_damage(amount: int):
	current_health = max(0, current_health - amount)
	
	if health_bar_system:
		health_bar_system.update_health_display(current_health)
	
	# Check if dead
	if current_health <= 0:
		die()
	
	return current_health

# Heal character and update health display
func heal(amount: int):
	current_health = min(max_health, current_health + amount)
	
	if health_bar_system:
		health_bar_system.update_health_display(current_health)
	
	return current_health

# Add mana and update mana display
func add_mana(amount: int):
	current_mana = min(max_mana, current_mana + amount)
	
	if health_bar_system:
		health_bar_system.update_mana_display(current_mana)
	
	return current_mana

# Use mana for abilities
func use_mana(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		
		if health_bar_system:
			health_bar_system.update_mana_display(current_mana)
		
		return true
	
	return false

# Handle character death
func die():
	# In a real game, you'd add death animation, particle effects, etc.
	print(character_data.display_name + " has died!")
	
	# Maybe add a slight delay before removing
	var timer = get_tree().create_timer(0.5)
	await timer.timeout
	
	# Tell the tile we're no longer there
	if original_tile:
		original_tile.set_occupying_unit(null)
	
	# Remove the character
	queue_free()

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
	# Prevent dragging if this is an enemy unit
	if (character_data and character_data.is_enemy) or in_combat:
		print("Cannot drag unit during combat or enemy units")
		return
		
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
			timer.connect("timeout", func(): world_label.queue_free())
	
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

# Function to test the health bar (for debugging)
func test_health_damage():
	# Add a timer to take damage after a few second
	await get_tree().create_timer(3.0).timeout
	print("Damage taken (100)")
	take_damage(100)
	
	# Add a timer to heal after a second
	await get_tree().create_timer(3.0).timeout
	print("Healed (50)")
	heal(50)
	
	# Add mana
	await get_tree().create_timer(3.0).timeout
	print("Gained mana (50)")
	add_mana(30)

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
			if unit == null or matching_units.has(unit):
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
	var character_scene = load("res://scenes/characters/BaseCharacter.tscn")
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

func start_combat(combat_sys):
	combat_system = combat_sys
	in_combat = true
	current_action = "idle"
	attack_cooldown = 0.0
	
	# Set attack cooldown based on character attack speed
	if character_data:
		attack_cooldown_max = 1.0 / character_data.attack_speed
	
	# Connect to combat tick signal
	if combat_system:
		if not combat_system.combat_tick.is_connected(update_combat):
			combat_system.combat_tick.connect(update_combat)
	
	# Start idle combat animation
	play_animation("idle")

func end_combat():
	in_combat = false
	combat_system = null
	current_path.clear()
	target_unit = null
	
	# Return to regular idle animation
	play_animation("idle")

func update_combat():
	if not in_combat or not combat_system:
		return
	
	# Reduce attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= combat_system.tick_interval
	
	# Main combat state machine
	match current_action:
		"idle":
			# Find target
			find_target()
			
			# If we have a target, either move to it or attack
			if target_unit:
				var distance = global_position.distance_to(target_unit.global_position)
				
				if character_data and distance <= character_data.attack_range * 2.0:
					# In range, attack
					start_attack()
				else:
					# Out of range, move
					print(character_data.display_name + " moving to target")
					move_to_target()
		
		"moving":
			# Check if target still exists
			if not is_instance_valid(target_unit) or target_unit.current_health <= 0:
				current_action = "idle"
				play_animation("idle")
				target_unit = null
				return
			
			# Check if we're in range now
			var distance = global_position.distance_to(target_unit.global_position)
			
			if character_data and distance <= character_data.attack_range * 2.0:
				# In range, attack
				start_attack()
				print(character_data.display_name + " in range, attacking")
			elif current_path.size() == 0:
				# Need to find a new path
				print(character_data.display_name + " finding new path")
				move_to_target()
			else:
				# Continue following path
				continue_movement()
				
			# Only occasionally recalculate path (not every frame)
			# Removed this as it was causing pathing issues
		
		"attacking":
			# Attack is handled automatically once started
			pass
		
		"dying":
			# Death is handled automatically once started
			pass

func find_target():
	if not combat_system:
		return
		
	target_unit = combat_system.get_closest_enemy(self)
	
	if target_unit:
		print(character_data.display_name + " targets " + target_unit.character_data.display_name)

func move_to_target():
	if not target_unit or not combat_system:
		current_action = "idle"
		return
	
	# Calculate path to target
	current_path = combat_system.find_path(self, target_unit.global_position)
	
	if current_path.size() <= 1:
		# No valid path or already at destination
		print(character_data.display_name + " no valid path found, path size: " + str(current_path.size()))
		current_action = "idle"
		return
	
	# Remove the first node (current position) if it's our current tile
	if current_path.size() > 0:
		var current_tile = board.get_tile_at_position(global_position)
		if current_path[0] == current_tile:
			current_path.remove_at(0)
	
	print(character_data.display_name + " path found with " + str(current_path.size()) + " steps")
	
	# Start moving
	current_action = "moving"
	play_animation("move")
	
	# Visualize path if debugging
	if combat_system.debug_pathfinding:
		combat_system.debug_draw_path(current_path)

func continue_movement():
	if current_path.size() == 0:
		current_action = "idle"
		play_animation("idle")
		return
	
	# Get the next tile
	var next_tile = current_path[0]
	var next_pos = next_tile.global_position
	
	# Move slightly above the ground
	next_pos.y = 0.1
	
	# Calculate movement
	var direction = (next_pos - global_position).normalized()
	var distance = global_position.distance_to(next_pos)
	var move_distance = move_speed * combat_system.tick_interval
	
	# Look at where we're going (just the horizontal direction)
	if direction.length_squared() > 0.001:
		var look_target = global_position + Vector3(direction.x, 0, direction.z)
		look_at(look_target, Vector3.UP)
	
	if move_distance >= distance:
		# Reached next node, move to it exactly
		global_position = next_pos
		
		# Update tile occupancy
		var previous_tile = board.get_tile_at_position(original_position)
		if previous_tile and previous_tile != next_tile:
			previous_tile.set_occupying_unit(null)
		
		original_position = global_position
		next_tile.set_occupying_unit(self)
		
		# Remove this node from path
		current_path.remove_at(0)
		
		if current_path.size() == 0:
			# Reached destination
			current_action = "idle"
			play_animation("idle")
	else:
		# Move along path
		global_position += direction * move_distance

func start_attack():
	if not is_instance_valid(target_unit) or target_unit.current_health <= 0:
		current_action = "idle"
		play_animation("idle")
		target_unit = null
		return
	
	# Only attack if cooldown is ready
	if attack_cooldown <= 0:
		# Start attack animation
		current_action = "attacking"
		play_animation("attack")
		
		# Look at target - make sure to face the correct direction
		if is_instance_valid(target_unit):
			# Calculate direction to target
			var target_pos = target_unit.global_position
			
			# Make the unit face the target
			look_at(target_pos, Vector3.UP)
		
		# Deal damage after animation delay
		get_tree().create_timer(0.5).connect("timeout", Callable(self, "deal_attack_damage"))
		
		# Reset cooldown
		attack_cooldown = attack_cooldown_max
	else:
		# Wait in idle until cooldown is ready
		current_action = "idle"
		play_animation("idle")

func deal_attack_damage():
	if not is_instance_valid(target_unit) or target_unit.current_health <= 0:
		current_action = "idle"
		play_animation("idle")
		target_unit = null
		return
	
	# Calculate damage
	var damage = character_data.attack_damage if character_data else 10
	
	# Apply damage to target
	target_unit.take_combat_damage(damage, self)
	
	# Show damage text
	show_damage_text(target_unit.global_position, damage)
	
	# Return to idle state
	current_action = "idle"
	play_animation("idle")

func take_combat_damage(amount, _attacker):
	# Take damage
	current_health = max(0, current_health - amount)
	
	# Update health bar
	if health_bar_system:
		health_bar_system.update_health_display(current_health)
	
	# Play damage animation if not dying
	if current_health > 0:
		play_animation("hurt")
		
		# Return to previous state after animation
		get_tree().create_timer(0.3).connect("timeout", Callable(self, "resume_after_hit"))
	else:
		# Unit is defeated
		die_in_combat()

func resume_after_hit():
	if in_combat:
		current_action = "idle"
		play_animation("idle")

func die_in_combat():
	if not in_combat:
		return
	
	current_action = "dying"
	play_animation("dying")
	
	# Release the current tile
	var current_tile = board.get_tile_at_position(global_position)
	if current_tile:
		current_tile.set_occupying_unit(null)
	
	# Remove from combat lists
	if combat_system:
		combat_system.player_units.erase(self)
		combat_system.enemy_units.erase(self)
	
	# Delay actual removal to allow animation to play
	get_tree().create_timer(2.0).connect("timeout", Callable(self, "queue_free"))

func show_damage_text(pos, amount):
	# Create 3D text to show damage
	var text = Label3D.new()
	
	# Add to scene first before setting position
	board.add_child(text)
	
	# Then set text properties
	text.text = str(amount)
	text.font_size = 64
	text.modulate = Color(1, 0.3, 0.3)
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Position above target unit (after adding to scene)
	text.global_position = pos + Vector3(0, 2, 0)
	
	# Animate and remove
	var tween = board.create_tween()
	tween.tween_property(text, "global_position", text.global_position + Vector3(0, 1, 0), 1.0)
	tween.parallel().tween_property(text, "modulate:a", 0.0, 1.0)
	tween.tween_callback(text.queue_free)

func play_animation(anim_type):
	if not animation_player:
		return
	
	var anim_name = IDLE_ANIM
	
	match anim_type:
		"idle":
			anim_name = IDLE_COMBAT_ANIM if in_combat else IDLE_ANIM
		"move":
			anim_name = MOVE_ANIM
		"attack":
			anim_name = ATTACK_ANIM
		"hurt":
			anim_name = TAKE_DAMAGE_ANIM
		"dying":
			anim_name = DYING_ANIM
		"victory":
			anim_name = VICTORY_ANIM
	
	# Check if the animation exists
	if animation_player.has_animation(anim_name):
		# Play animation with crossfade
		animation_player.play(anim_name, 0.2)
		
		# Set looping for movement and idle animations
		if anim_type == "move" or anim_type == "idle":
			# For Godot 4, we need to connect to the animation_finished signal
			if not animation_player.animation_finished.is_connected(_on_animation_finished):
				animation_player.animation_finished.connect(_on_animation_finished)
	else:
		print("Animation not found: " + anim_name)
		
# Handle animation looping
func _on_animation_finished(anim_name):
	# If this was a movement or idle animation, loop it
	if anim_name == MOVE_ANIM or anim_name == IDLE_COMBAT_ANIM or anim_name == IDLE_ANIM:
		if current_action == "moving" or current_action == "idle":
			# Replay the same animation (with no crossfade for smoother loop)
			animation_player.play(anim_name, 0.0)

func celebrate_victory():
	play_animation("victory")
