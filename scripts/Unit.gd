extends CharacterBody3D
class_name Unit

# Character data
var character_data = null
var star_level = 1

# Current stats
var current_health: int = 100
var current_mana: int = 0
var max_health: int = 100
var max_mana: int = 100

# Components and references
var stats_component = null
var visual_component = null
var health_bar_system = null
var board = null

# Visual elements
var character_mesh = null
var character_material = null

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

# Tile and position tracking
var original_tile = null # Added this to fix the error

# Combat state
var combat_system = null
var in_combat = false
var target_unit = null
var attack_cooldown = 0.0
var current_action = "idle"  # idle, moving, attacking, casting, hurt, dying
var current_path = []  # Added declaration to fix error

# Animation references
@onready var animation_player = $Armature/AnimationPlayer if has_node("Armature/AnimationPlayer") else null
const IDLE_ANIM = "unarmed idle 01/mixamo_com"
const DRAG_ANIM = "fall a loop/mixamo_com"
const IDLE_COMBAT_ANIM = "standing idle 01/mixamo_com"
const MOVE_ANIM = "standing run forward/mixamo_com"
const ATTACK_ANIM = "standing melee punch/mixamo_com" 
const TAKE_DAMAGE_ANIM = "standing react small from front/mixamo_com"
const DYING_ANIM = "standing death forward 01/mixamo_com"
const VICTORY_ANIM = "standing idle 03 examine/mixamo_com"

func _ready():
	# Find the board in the scene
	if not board:
		board = get_node_or_null("/root/GameBoard")
	
	# Check if the health bar system exists
	health_bar_system = get_node_or_null("UIBillboard/HealthBarSystem")
	
	# If it doesn't exist, create it
	if not health_bar_system:
		health_bar_system = HealthBarSystem.new(max_health, max_mana)
		health_bar_system.name = "HealthBarSystem"
		
		# Make sure UIBillboard exists
		var ui_billboard = get_node_or_null("UIBillboard")
		if not ui_billboard:
			ui_billboard = Node3D.new()
			ui_billboard.name = "UIBillboard"
			add_child(ui_billboard)
			
		# Add the health bar system to UIBillboard
		$UIBillboard.add_child(health_bar_system)

# Initialize character stats from character_data
func initialize_stats():
	if character_data:
		max_health = character_data.health
		current_health = max_health
		max_mana = character_data.mana_max
		
		# Scale stats based on star level
		if character_data.star_level == 2:
			max_health = int(max_health * 1.8)
			current_health = max_health
		elif character_data.star_level == 3:
			max_health = int(max_health * 3.2)
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
		nameplate_node.visible = false
		
	if character_data and nameplate_node:
		nameplate_node.text = character_data.display_name
		
		# Set nameplate color based on rarity
		var rarity_color = character_data.get_rarity_color()
		nameplate_node.modulate = rarity_color

# Ensure there's a proper collision shape for clicking
func ensure_collision():
	if not has_node("CollisionShape3D"):
		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		
		var shape = CapsuleShape3D.new()
		shape.radius = 0.5
		shape.height = 2.0
		
		collision_shape.shape = shape
		collision_shape.position = Vector3(0, 1.0, 0)  # Center vertically on character
		
		add_child(collision_shape)
		
		# Make sure collision is enabled
		collision_layer = 1
		collision_mask = 0

func ensure_board_reference():
	if not board:
		board = get_node_or_null("/root/GameBoard")
		if not board:
			push_error("Unable to find GameBoard reference - functionality may be limited")
			return false
	return true

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
		var timer = get_tree().create_timer(0.3)
		timer.timeout.connect(func(): resume_after_hit())
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
	var current_tile = null
	if board:
		current_tile = board.get_tile_at_position(global_position)
	
	if current_tile:
		current_tile.set_occupying_unit(null)
	
	# Remove from combat lists
	if combat_system:
		combat_system.player_units.erase(self)
		combat_system.enemy_units.erase(self)
	
	# Delay actual removal to allow animation to play
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): queue_free())

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
	# Virtual method to be implemented by subclasses
	pass

# Set the star level for this unit
func set_star_level(level: int):
	star_level = clamp(level, 1, 3)
	
	# Update character data's star level as well
	if character_data:
		character_data.star_level = star_level
	
	# Implementation details moved to StarLevelComponent

# For Combat System
func start_combat(combat_sys):
	ensure_board_reference()
	combat_system = combat_sys
	in_combat = true
	current_action = "idle"
	attack_cooldown = 0.0
	
	# Virtual method to be further implemented by subclasses
	pass

func end_combat():
	in_combat = false
	combat_system = null
	current_path.clear()  # Now this will work with the declaration above
	target_unit = null
	
	# Return to regular idle animation
	play_animation("idle")

# Play animation with proper handling
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
