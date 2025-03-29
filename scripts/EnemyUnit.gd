extends Unit
class_name EnemyUnit

# Movement and pathfinding
var move_speed = 5.0
var path_update_timer = 0.0
var path_update_interval = 0.1  # Update path every 0.1 seconds

# Enemy-specific behavior
var aggression_level = 1.0  # 0.0 to 1.0, higher values make enemy more aggressive
var preferred_target_type = null  # Can specify certain unit types to prioritize
var attack_cooldown_max: float = 1.0

func _ready():
	super._ready()
	
	# Ensure character data is marked as enemy
	if character_data:
		character_data.is_enemy = true
	
	# Store our starting tile
	if board:
		original_tile = board.get_tile_at_position(global_position)
		if original_tile:
			original_tile.set_occupying_unit(self)
	
	# Start idle animation
	if animation_player:
		animation_player.play(IDLE_ANIM)

# Override die to handle enemy death
func die():
	print("Enemy " + character_data.display_name + " has died!")
	
	# Maybe add a slight delay before removing
	var timer = get_tree().create_timer(0.5)
	await timer.timeout
	
	# Tell the tile we're no longer there
	if original_tile:
		original_tile.set_occupying_unit(null)
	
	# Remove the character
	queue_free()

# Override start_combat with enemy-specific behavior
func start_combat(combat_sys):
	super.start_combat(combat_sys)
	
	# Set attack cooldown based on character attack speed
	if character_data:
		attack_cooldown_max = 1.0 / character_data.attack_speed
	
	# Connect to combat tick signal
	if combat_system:
		if not combat_system.combat_tick.is_connected(update_combat):
			combat_system.combat_tick.connect(update_combat)
	
	# Start idle combat animation
	play_animation("idle")

# Update enemy during combat
func update_combat():
	if not in_combat or not combat_system:
		return
	
	# Reduce attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= combat_system.tick_interval
	
	# Reduce path update timer
	if path_update_timer > 0:
		path_update_timer -= combat_system.tick_interval
	
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
					move_to_target()
		
		"moving":
			# Check if target still exists
			if not is_instance_valid(target_unit) or target_unit.current_health <= 0:
				current_action = "idle"
				play_animation("idle")
				target_unit = null
				if combat_system:
					combat_system.clear_unit_debug_meshes(self)  # Clear debug path
				return
			
			# Check if we're in range now
			var distance = global_position.distance_to(target_unit.global_position)
			
			if character_data and distance <= character_data.attack_range * 2.0:
				# In range, attack
				start_attack()
				if combat_system:
					combat_system.clear_unit_debug_meshes(self)  # Clear debug path
			elif current_path.size() == 0 or path_update_timer <= 0:
				# Need to find a new path (either ran out of path or time to update)
				move_to_target()
			else:
				# Continue following path
				continue_movement()
		
		"attacking":
			# Attack is handled automatically once started
			pass
		
		"dying":
			# Death is handled automatically once started
			pass

# Find a target for the enemy
func find_target():
	if not combat_system:
		return
		
	target_unit = combat_system.get_closest_enemy(self)

# Move toward target
func move_to_target():
	if not target_unit or not combat_system:
		current_action = "idle"
		return
	
	# Always use the target's CURRENT position
	var target_position = target_unit.global_position
	
	# Calculate path to target
	current_path = combat_system.find_path(self, target_position)
	
	if current_path.size() <= 1:
		# No valid path or already at destination
		current_action = "idle"
		return
	
	# Remove the first node (current position) if it's our current tile
	if current_path.size() > 0:
		var current_tile = board.get_tile_at_position(global_position)
		if current_path[0] == current_tile:
			current_path.remove_at(0)
	
	# Reset path update timer
	path_update_timer = path_update_interval
	
	# Start moving
	current_action = "moving"
	play_animation("move")

# Continue following the current path
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
	
	# Always look at the target if it's valid
	if is_instance_valid(target_unit):
		face_target(target_unit.global_position)
	else:
		# If no target, look at where we're going
		if direction.length_squared() > 0.001:
			face_target(global_position + direction)
	
	if move_distance >= distance:
		# Reached next node, move to it exactly
		global_position = next_pos
		
		# Update tile occupancy
		var previous_tile = board.get_tile_at_position(global_position)
		if previous_tile and previous_tile != next_tile:
			previous_tile.set_occupying_unit(null)
		
		next_tile.set_occupying_unit(self)
		
		# Remove this node from path
		current_path.remove_at(0)
		
		if current_path.size() == 0:
			# Reached destination
			current_action = "idle"
			play_animation("idle")
			if combat_system:
				combat_system.clear_unit_debug_meshes(self)  # Clear debug path
	else:
		# Move along path
		global_position += direction * move_distance

# Face toward a target position
func face_target(target_position):
	# Calculate direction vector in the horizontal plane
	var direction = target_position - global_position
	direction.y = 0  # Keep only horizontal component
	
	if direction.length_squared() > 0.001:
		# Models are likely facing the wrong way - rotate 180 degrees
		var target_pos = global_position + direction
		look_at(target_pos, Vector3.UP)
		
		# Add 180 degree rotation to face correctly
		rotate_y(PI)

# Start an attack against the target
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
			face_target(target_unit.global_position)
		
		# Deal damage after animation delay
		get_tree().create_timer(0.5).connect("timeout", Callable(self, "deal_attack_damage"))
		
		# Reset cooldown
		attack_cooldown = attack_cooldown_max
	else:
		# Wait in idle until cooldown is ready
		current_action = "idle"
		play_animation("idle")

# Deal damage to the target
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

# Take damage during combat
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

# Resume previous state after being hit
func resume_after_hit():
	if in_combat:
		current_action = "idle"
		play_animation("idle")

# Die during combat
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

# Show floating damage text
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
