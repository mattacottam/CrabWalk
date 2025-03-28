extends Node

signal combat_tick
signal combat_ended(winner)

# References
@onready var board = get_node("/root/GameBoard")
@onready var battle_manager = get_node_or_null("/root/GameBoard/BattleManager")

# Combat state
var combat_active = false
var player_units = []
var enemy_units = []
var combat_time = 0.0
var tick_interval = 0.01  # Combat ticks every 0.1 seconds
var tick_counter = 0
var max_combat_time = 60.0  # Combat timeout

# Debug settings
var debug_pathfinding = false
var debug_lines = []
var debug_timer = 0.0
var debug_draw_duration = 3.0
var debug_drawer = null  # Reference to a Node2D for drawing
var debug_mesh_instances = []
var debug_material = null
var debug_update_timer = 0.0
var debug_update_interval = 0.05  # Only update debug visuals every 0.5 seconds
var unit_debug_meshes = {}

func _ready():
	if battle_manager:
		battle_manager.battle_started.connect(_on_battle_started)
	
	# Enable debug pathfinding by default
	debug_pathfinding = true
	create_debug_drawer()

func _process(delta):
	if combat_active:
		combat_time += delta
		
		if combat_time >= tick_counter * tick_interval:
			tick_counter += 1
			simulate_combat_tick()
		
		# Combat timeout
		if combat_time >= max_combat_time:
			end_combat("timeout")
	
	# Throttle debug visualization updates
	if debug_pathfinding and debug_mesh_instances.size() > 0:
		debug_timer += delta
		if debug_timer >= debug_draw_duration:
			debug_timer = 0.0
			clear_debug_meshes()

func create_debug_drawer():
	# Create material for debug lines
	debug_material = StandardMaterial3D.new()
	debug_material.albedo_color = Color(1, 0, 0, 1)  # Bright red
	debug_material.emission_enabled = true
	debug_material.emission = Color(1, 0.3, 0.3)
	debug_material.emission_energy_multiplier = 2.0
	
	# Clean up any existing debug meshes
	clear_debug_meshes()

# Clear any existing debug meshes
func clear_debug_meshes():
	for mesh in debug_mesh_instances:
		if is_instance_valid(mesh):
			mesh.queue_free()
	debug_mesh_instances.clear()

func clear_unit_debug_meshes(unit):
	if unit in unit_debug_meshes:
		for mesh in unit_debug_meshes[unit]:
			if is_instance_valid(mesh):
				mesh.queue_free()
		unit_debug_meshes.erase(unit)

func debug_draw_path(path, unit=null):
	# If unit is provided, we'll create a separate drawing for each unit's path
	var mesh_instances = []
	
	# We need at least 2 points to draw a line
	if path.size() < 2:
		return mesh_instances
	
	# Show all segments
	for i in range(path.size() - 1):
		var from_pos = path[i].global_position
		var to_pos = path[i+1].global_position
		
		# Lift lines slightly above the board
		from_pos.y += 0.15
		to_pos.y += 0.15
		
		# Create line mesh
		var line = create_debug_line(from_pos, to_pos)
		mesh_instances.append(line)
		
		# Create spheres at all points
		var start_sphere = create_debug_sphere(from_pos, 0.1) 
		mesh_instances.append(start_sphere)
		
		if i == path.size() - 2:  # Last point
			var end_sphere = create_debug_sphere(to_pos, 0.1)
			mesh_instances.append(end_sphere)
	
	# Store the meshes with their associated unit if provided
	if unit:
		if unit in unit_debug_meshes:
			# Clear old meshes for this unit
			for mesh in unit_debug_meshes[unit]:
				if is_instance_valid(mesh):
					mesh.queue_free()
		
		unit_debug_meshes[unit] = mesh_instances
	else:
		# For general debug meshes not tied to a specific unit
		debug_mesh_instances.append_array(mesh_instances)
	
	return mesh_instances

# Create a 3D line between two points
func create_debug_line(start, end):
	var mesh_instance = MeshInstance3D.new()
	
	# Add to scene first so it's in the tree
	board.add_child(mesh_instance)
	
	# Create line mesh
	var direction = end - start
	var length = direction.length()
	
	# Create a cylinder
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.03
	cylinder.bottom_radius = 0.03
	cylinder.height = length
	mesh_instance.mesh = cylinder
	
	# Set position first (midpoint between start and end)
	mesh_instance.global_position = start + direction * 0.5
	
	# Create a basis that orients the cylinder along the direction
	var z_axis = (end - start).normalized()
	var x_axis = Vector3(0, 1, 0).cross(z_axis).normalized()
	if x_axis.length_squared() < 0.01:
		x_axis = Vector3(1, 0, 0)  # Fallback if parallel to up vector
	var y_axis = z_axis.cross(x_axis).normalized()
	
	var basis = Basis(x_axis, y_axis, z_axis)
	basis = basis.rotated(x_axis, PI/2)  # Rotate to align cylinder with direction
	
	mesh_instance.global_transform.basis = basis
	
	# Apply material
	mesh_instance.material_override = debug_material
	
	return mesh_instance

# Create a sphere at a point
func create_debug_sphere(position, radius):
	var mesh_instance = MeshInstance3D.new()
	
	# Add to scene first
	board.add_child(mesh_instance)
	
	# Create sphere mesh
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	mesh_instance.mesh = sphere
	
	# Position the sphere
	mesh_instance.global_position = position
	
	# Apply material
	mesh_instance.material_override = debug_material
	
	return mesh_instance

func create_debug_drawer_script():
	var script = GDScript.new()
	script.source_code = """
extends Control

var parent = null

func _draw():
	if not parent or parent.debug_lines.size() == 0:
		return
	
	for line in parent.debug_lines:
		var camera = get_viewport().get_camera_3d()
		if camera:
			var from_pos = camera.unproject_position(line[0])
			var to_pos = camera.unproject_position(line[1])
			# Draw thicker, more visible red lines
			draw_line(from_pos, to_pos, Color(1, 0, 0), 3.0)
			# Add small circles at each point for better visibility
			draw_circle(from_pos, 5.0, Color(1, 0.5, 0))
			draw_circle(to_pos, 5.0, Color(1, 0.5, 0))
	
	# Force redraw after a short delay to ensure paths remain visible
	if parent.debug_lines.size() > 0:
		await get_tree().create_timer(0.1).timeout
		queue_redraw()
"""
	script.reload()
	return script

func _on_battle_started():
	start_combat()

func start_combat():
	# Clear state
	combat_active = true
	combat_time = 0.0
	tick_counter = 0
	player_units.clear()
	enemy_units.clear()
	debug_lines.clear()
	
	# Find all units
	gather_units()
	
	# Initialize combat for all units
	for unit in player_units + enemy_units:
		unit.start_combat(self)
	
	print("Combat started with " + str(player_units.size()) + " player units vs " + str(enemy_units.size()) + " enemy units")

func gather_units():
	if not board or not board.tiles:
		return
		
	# Find all player units
	for i in range(board.PLAYER_ROWS):
		for j in range(board.PLAYER_COLS):
			var tile_key = "player_%d_%d" % [i, j]
			var tile = board.tiles.get(tile_key)
			if tile and tile.is_occupied():
				var unit = tile.get_occupying_unit()
				if unit and unit.character_data and not unit.character_data.is_enemy:
					player_units.append(unit)
	
	# Find all enemy units
	for i in range(board.ENEMY_ROWS):
		for j in range(board.ENEMY_COLS):
			var tile_key = "enemy_%d_%d" % [i, j]
			var tile = board.tiles.get(tile_key)
			if tile and tile.is_occupied():
				var unit = tile.get_occupying_unit()
				if unit and unit.character_data and unit.character_data.is_enemy:
					enemy_units.append(unit)

func simulate_combat_tick():
	# Execute one tick of combat simulation
	emit_signal("combat_tick")
	
	# Check win conditions
	check_win_condition()

func check_win_condition():
	# Remove dead units using a for loop instead of filter
	var updated_player_units = []
	for unit in player_units:
		if is_instance_valid(unit) and unit.current_health > 0:
			updated_player_units.append(unit)
	player_units = updated_player_units
	
	var updated_enemy_units = []
	for unit in enemy_units:
		if is_instance_valid(unit) and unit.current_health > 0:
			updated_enemy_units.append(unit)
	enemy_units = updated_enemy_units
	
	# Check for victory conditions
	if player_units.size() == 0:
		end_combat("enemy")
	elif enemy_units.size() == 0:
		end_combat("player")

func end_combat(winner):
	combat_active = false
	
	# Reset all units
	for unit in player_units:
		unit.end_combat()
	
	for unit in enemy_units:
		unit.end_combat()
	
	print("Combat ended, winner: " + winner)
	
	# Inform battle manager
	if battle_manager:
		battle_manager.end_battle()
	
	emit_signal("combat_ended", winner)

func find_path(unit, target_position):
	# Get tiles for pathfinding
	var start_tile = board.get_tile_at_position(unit.global_position)
	var end_tile = board.get_tile_at_position(target_position)
	
	if not start_tile or not end_tile:
		print("Invalid start or end tile")
		return []
	
	if start_tile == end_tile:
		print("Start and end tiles are the same")
		return []
	
	print(unit.character_data.display_name + " finding path from " + 
		  str(start_tile.get_meta("zone", "unknown")) + " Row: " + str(start_tile.get_meta("row", -1)) + 
		  " Col: " + str(start_tile.get_meta("col", -1)) + 
		  " to " + str(end_tile.get_meta("zone", "unknown")) + " Row: " + str(end_tile.get_meta("row", -1)) + 
		  " Col: " + str(end_tile.get_meta("col", -1)))
	
	# Skip complex pathfinding for melee units - just go straight to target
	if unit.character_data and unit.character_data.attack_range <= 1:
		print("Melee unit - using direct path")
		var direct_path = [start_tile, end_tile]
		
		# Visualize path if debugging
		if debug_pathfinding:
			debug_draw_path(direct_path, unit)
			
		return direct_path
	
	# A* pathfinding for ranged units
	var open_set = [start_tile]
	var came_from = {}
	
	# Cost from start to current node
	var g_score = {}
	g_score[start_tile] = 0
	
	# Estimated cost from start to end through current node
	var f_score = {}
	f_score[start_tile] = heuristic_cost_estimate(start_tile, end_tile)
	
	var iterations = 0
	var max_iterations = 1000  # Safety limit
	
	while open_set.size() > 0 and iterations < max_iterations:
		iterations += 1
		
		# Find node with lowest f_score
		var current = open_set[0]
		for tile in open_set:
			if f_score.get(tile, INF) < f_score.get(current, INF):
				current = tile
		
		# If found the end
		if current == end_tile:
			var path = reconstruct_path(came_from, current)
			print("Path found with " + str(path.size()) + " tiles")
			
			# Visualize path if debugging
			if debug_pathfinding:
				debug_draw_path(path, unit)
				
			return path
		
		open_set.erase(current)
		
		# Check neighbors
		var neighbors = get_neighboring_tiles(current)
		for neighbor in neighbors:
			# Skip if occupied by another unit (unless it's the destination and destination is the target)
			if neighbor.is_occupied() and neighbor.get_occupying_unit() != unit and neighbor != end_tile:
				continue
			
			var tentative_g_score = g_score.get(current, INF) + 1  # Cost of 1 for now
			
			if tentative_g_score < g_score.get(neighbor, INF):
				# This path is better
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + heuristic_cost_estimate(neighbor, end_tile)
				
				if not neighbor in open_set:
					open_set.append(neighbor)
	
	if iterations >= max_iterations:
		print("Pathfinding hit iteration limit")
	else:
		print("No path found")
	
	# No path found - try direct path to target
	if start_tile and end_tile:
		print("Returning direct path as fallback")
		var direct_path = [start_tile, end_tile]
		
		# Visualize fallback path if debugging
		if debug_pathfinding:
			debug_draw_path(direct_path, unit)
			
		return direct_path
	
	return []

func heuristic_cost_estimate(from_tile, to_tile):
	# Simple distance-based heuristic
	return from_tile.global_position.distance_to(to_tile.global_position)

func get_neighboring_tiles(tile):
	# Find all adjacent tiles
	var neighbors = []
	var tile_pos = tile.global_position
	
	# For debugging
	var zone = tile.get_meta("zone", "unknown")
	var row = tile.get_meta("row", -1)
	var col = tile.get_meta("col", -1)
	
	for other_tile in board.tiles.values():
		var distance = tile_pos.distance_to(other_tile.global_position)
		
		# Adjust threshold based on hex grid spacing
		# HEX_HORIZ_SPACING might be around 2.0, so neighbors should be close to that
		if distance > 0 and distance < 2.5:
			neighbors.append(other_tile)
	
	print("Tile " + zone + " R:" + str(row) + " C:" + str(col) + " has " + str(neighbors.size()) + " neighbors")
	return neighbors

func reconstruct_path(came_from, current):
	var path = [current]
	
	while current in came_from:
		current = came_from[current]
		path.push_front(current)
	
	# Visualize path if debugging
	if debug_pathfinding:
		debug_draw_path(path)
	
	return path

func set_debug_pathfinding(enabled):
	debug_pathfinding = enabled
	print("Debug pathfinding: " + ("enabled" if enabled else "disabled"))
	
	if enabled:
		# Create debug drawer
		create_debug_drawer()
		
		# Force redraw all current paths
		for unit in player_units + enemy_units:
			if unit.target_unit and unit.current_action == "moving":
				# Re-find path to visualize
				var path = find_path(unit, unit.target_unit.global_position)
				if path.size() > 0:
					debug_draw_path(path)
	else:
		# Clear debug meshes
		clear_debug_meshes()

func get_closest_enemy(unit):
	var enemy_list = enemy_units if unit.character_data and not unit.character_data.is_enemy else player_units
	
	if enemy_list.size() == 0:
		return null
		
	var closest = enemy_list[0]
	var min_distance = INF
	
	for enemy in enemy_list:
		var distance = unit.global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			closest = enemy
	
	return closest

func get_enemies_in_range(unit, range_value):
	var enemy_list = enemy_units if unit.character_data and not unit.character_data.is_enemy else player_units
	var in_range = []
	
	for enemy in enemy_list:
		var distance = unit.global_position.distance_to(enemy.global_position)
		if distance <= range_value:
			in_range.append(enemy)
	
	return in_range

func manual_tick():
	# Force an immediate combat tick
	simulate_combat_tick()
	
	# Only refresh visualization once every few ticks
	if debug_pathfinding and randf() < 0.3:  # 30% chance to update visuals
		for unit in player_units + enemy_units:
			if unit.target_unit and unit.current_action == "moving":
				var path = find_path(unit, unit.target_unit.global_position)
				if path.size() > 0:
					debug_draw_path(path)
					break  # Only visualize one path at a time
