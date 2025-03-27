extends Node

# References to other nodes
@onready var board = get_node("/root/GameBoard")
@onready var character_database = get_node("/root/GameBoard/CharacterDatabase")

# Character scene to spawn
var character_scene = preload("res://scenes/characters/BaseCharacter.tscn")

# Enemy generation settings
var difficulty_level = 1
var min_enemies = 1
var max_enemies = 3

# Control enemy strength progression
var health_multiplier_per_level = 0.15  # 15% more health per level
var damage_multiplier_per_level = 0.10  # 10% more damage per level

func _ready():
	# Wait a frame to ensure board is fully initialized
	await get_tree().process_frame
	print("Enemy Unit Generator initialized")

func generate_enemies_for_level(level: int):
	# Clear any existing enemies first
	clear_all_enemies()
	
	# Scale difficulty based on level
	difficulty_level = level
	min_enemies = min(1 + int(level / 2), 5)
	max_enemies = min(3 + int(level / 2), 8)
	
	# Calculate number of enemies for this level
	var num_enemies = randi_range(min_enemies, max_enemies)
	
	# Generate and place enemies
	for i in range(num_enemies):
		var enemy_data = generate_enemy_character()
		place_enemy_on_board(enemy_data)
	
	print("Generated " + str(num_enemies) + " enemies for level " + str(level))

func generate_enemy_character():
	# Get a random character as template
	var char_id = get_random_character_for_level()
	var template_character = character_database.get_character(char_id)
	
	if not template_character:
		push_error("Failed to get character template")
		return null
	
	# Create a duplicate to modify
	var enemy_data = template_character.duplicate()
	
	# Mark as enemy
	enemy_data.is_enemy = true
	
	# Modify ID to ensure no auto-combining with player units
	enemy_data.id = "enemy_" + enemy_data.id
	
	# Modify name to indicate it's an enemy
	enemy_data.display_name = "Enemy " + enemy_data.display_name
	
	# Scale stats based on difficulty
	scale_enemy_stats(enemy_data)
	
	return enemy_data

func scale_enemy_stats(enemy_data):
	# Increase health and damage based on difficulty
	var health_multiplier = 1.0 + (difficulty_level * health_multiplier_per_level)
	var damage_multiplier = 1.0 + (difficulty_level * damage_multiplier_per_level)
	
	enemy_data.health = int(enemy_data.health * health_multiplier)
	enemy_data.attack_damage = int(enemy_data.attack_damage * damage_multiplier)
	
	# Random variation (±10%)
	var variation = randf_range(0.9, 1.1)
	enemy_data.health = int(enemy_data.health * variation)
	enemy_data.attack_damage = int(enemy_data.attack_damage * variation)
	
	# Scale star level based on current level
	if difficulty_level >= 5:
		# Level 5+: Chance for 2-star units
		enemy_data.star_level = 1 + (1 if randf() < 0.3 else 0)
	if difficulty_level >= 9:
		# Level 9+: Chance for 3-star units
		enemy_data.star_level = 1 + (1 if randf() < 0.4 else 0) + (1 if randf() < 0.2 else 0)

func get_random_character_for_level():
	# Filter characters by appropriate rarity for current level
	var available_characters = []
	
	# Higher levels introduce higher rarity enemies
	var max_rarity = min(1 + int(difficulty_level / 2), 5)
	
	for char_id in character_database.characters:
		var character = character_database.characters[char_id]
		if character.rarity <= max_rarity:
			# Add more copies of lower-rarity chars for weighted randomness
			var weight = max_rarity - character.rarity + 1
			for i in range(weight):
				available_characters.append(char_id)
	
	if available_characters.size() == 0:
		push_error("No suitable characters found for enemy generation")
		return null
	
	# Pick a random character from available options
	return available_characters[randi() % available_characters.size()]

func place_enemy_on_board(enemy_data):
	if not enemy_data or not board:
		push_error("Cannot place enemy: invalid data or board reference")
		return
	
	# Find an unoccupied enemy tile
	var available_tiles = []
	
	for row in range(board.ENEMY_ROWS):
		for col in range(board.ENEMY_COLS):
			var tile_key = "enemy_%d_%d" % [row, col]
			var tile = board.tiles.get(tile_key)
			
			if tile and not tile.is_occupied():
				available_tiles.append(tile)
	
	if available_tiles.size() == 0:
		push_error("No available enemy tiles")
		return
	
	# Choose a random available tile
	var chosen_tile = available_tiles[randi() % available_tiles.size()]
	
	# Spawn enemy unit
	var enemy_unit = character_scene.instantiate()
	board.add_child(enemy_unit)
	
	# Set character data
	enemy_unit.set_character_data(enemy_data)
	
	# Position at the tile's center
	enemy_unit.global_position = chosen_tile.get_center_position()
	
	# Set the occupying unit reference
	chosen_tile.set_occupying_unit(enemy_unit)
	
	print("Placed enemy " + enemy_data.display_name + " on board")

func clear_all_enemies():
	if not board:
		return
	
	# Clear all units from enemy tiles
	for row in range(board.ENEMY_ROWS):
		for col in range(board.ENEMY_COLS):
			var tile_key = "enemy_%d_%d" % [row, col]
			var tile = board.tiles.get(tile_key)
			
			if tile and tile.is_occupied():
				var unit = tile.get_occupying_unit()
				if unit and unit.character_data and unit.character_data.is_enemy:
					unit.queue_free()
					tile.set_occupying_unit(null)
	
	print("Cleared all enemies from board")
