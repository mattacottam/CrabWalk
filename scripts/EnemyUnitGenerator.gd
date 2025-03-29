extends Node

# References to other nodes
@onready var board = get_node("/root/GameBoard")
@onready var character_database = get_node("/root/GameBoard/CharacterDatabase")

# Character scene to spawn
var enemy_unit_scene = preload("res://scenes/characters/EnemyUnit.tscn")

# Enemy generation settings
var min_enemies = 1
var max_enemies = 3

# Unit type flags
enum UnitType {MELEE, RANGED, SUPPORT, TANK}

# Control enemy strength progression
var health_multiplier_per_level = 0.10  # 10% more health per level
var damage_multiplier_per_level = 0.08  # 8% more damage per level

# Level based progression
var level_configs = {
	# [min_units, max_units, max_rarity, star_level_chances]
	1: [1, 2, 1, [1.0, 0.0, 0.0]],      # Level 1: 1-2 common units, all 1-star
	2: [2, 3, 1, [1.0, 0.0, 0.0]],      # Level 2: 2-3 common units, all 1-star
	3: [2, 4, 2, [0.9, 0.1, 0.0]],      # Level 3: 2-4 common/uncommon, 10% chance for 2-star
	5: [3, 5, 2, [0.8, 0.2, 0.0]],      # Level 5: 3-5 units, 20% chance for 2-star
	7: [3, 6, 3, [0.7, 0.3, 0.0]],      # Level 7: 3-6 units up to rare, 30% chance for 2-star
	10: [4, 6, 4, [0.6, 0.35, 0.05]],   # Level 10: 4-6 units up to epic, 5% chance for 3-star
	15: [5, 8, 5, [0.5, 0.4, 0.1]]      # Level 15+: 5-8 units all rarities, 10% chance for 3-star
}

func _ready():
	# Wait a frame to ensure board is fully initialized
	await get_tree().process_frame
	print("Enemy Unit Generator initialized")

func generate_enemies_for_level(level: int):
	# Clear any existing enemies first
	clear_all_enemies()
	
	# Get configuration for this level
	var config = get_level_config(level)
	var min_units = config[0]
	var max_units = config[1]
	var max_rarity = config[2]
	var star_chances = config[3]
	
	# Calculate number of enemies for this level
	var num_enemies = randi_range(min_units, max_units)
	
	# Generate enemy team composition
	var enemy_team = generate_team_composition(num_enemies, level, max_rarity, star_chances)
	
	# Place enemies strategically
	place_enemies_strategically(enemy_team)
	
	print("Generated " + str(num_enemies) + " enemies for level " + str(level))

func get_level_config(level: int):
	# Find the highest level config that's less than or equal to current level
	var config_level = 1
	for l in level_configs:
		if level >= l:
			config_level = l
		else:
			break
	
	return level_configs[config_level]

func generate_team_composition(count: int, level: int, max_rarity: int, star_chances: Array):
	var team = []
	
	# Ensure at least one tank if level > 3 and enough enemies
	var need_tank = level > 3 and count >= 3
	
	# Ensure at least one support if level > 7 and enough enemies
	var need_support = level > 7 and count >= 4
	
	# Reserve slots based on requirements
	var remaining_slots = count
	if need_tank: remaining_slots -= 1
	if need_support: remaining_slots -= 1
	
	# Determine melee/ranged ratio based on level
	var melee_percent = max(0.7 - (level * 0.02), 0.4)  # Decreases from 70% to 40% as level increases
	var melee_count = int(remaining_slots * melee_percent)
	var ranged_count = remaining_slots - melee_count
	
	# Generate required unit types
	if need_tank:
		team.append(generate_unit_of_type(UnitType.TANK, level, max_rarity, star_chances))
	
	if need_support:
		team.append(generate_unit_of_type(UnitType.SUPPORT, level, max_rarity, star_chances))
	
	# Generate melee units
	for i in range(melee_count):
		team.append(generate_unit_of_type(UnitType.MELEE, level, max_rarity, star_chances))
		
	# Generate ranged units
	for i in range(ranged_count):
		team.append(generate_unit_of_type(UnitType.RANGED, level, max_rarity, star_chances))
	
	return team

func generate_unit_of_type(unit_type: int, level: int, max_rarity: int, star_chances: Array):
	# Get characters that match the desired type
	var filtered_chars = []
	
	for char_id in character_database.characters:
		var character = character_database.characters[char_id]
		
		if character.rarity <= max_rarity:
			var matches_type = false
			
			match unit_type:
				UnitType.TANK:
					# Tanks have high health and armor, low attack range
					matches_type = character.health >= 120 and character.armor >= 15 and character.attack_range <= 1
				UnitType.MELEE:
					# Melee units have attack range of 1 and aren't tanks
					matches_type = character.attack_range <= 1 and (character.health < 120 or character.armor < 15)
				UnitType.RANGED:
					# Ranged units have attack range > 1
					matches_type = character.attack_range > 1
				UnitType.SUPPORT:
					# Support units have healing or utility abilities
					matches_type = "Support" in character.traits or "Divine" in character.traits or character.ability_damage < 0
			
			if matches_type:
				# Add more copies of lower-rarity characters for weighted selection
				var weight = max_rarity - character.rarity + 1
				for i in range(weight):
					filtered_chars.append(char_id)
	
	# If no matching characters found, fall back to any character within rarity limits
	if filtered_chars.size() == 0:
		for char_id in character_database.characters:
			var character = character_database.characters[char_id]
			if character.rarity <= max_rarity:
				filtered_chars.append(char_id)
	
	# Still nothing? Use any character
	if filtered_chars.size() == 0:
		filtered_chars = character_database.characters.keys()
	
	# Select a random character from filtered list
	var char_id = filtered_chars[randi() % filtered_chars.size()]
	var template_character = character_database.get_character(char_id)
	
	# Create enemy data from template
	var enemy_data = template_character.duplicate()
	enemy_data.is_enemy = true
	enemy_data.id = "enemy_" + enemy_data.id
	enemy_data.display_name = "Enemy " + enemy_data.display_name
	
	# Determine star level based on chances
	var star_roll = randf()
	var star_level = 1
	
	if star_roll > star_chances[0]:
		star_level = 2
		if star_roll > star_chances[0] + star_chances[1] and star_chances[2] > 0:
			star_level = 3
	
	enemy_data.star_level = star_level
	
	# Scale stats based on level and star level
	scale_enemy_stats(enemy_data, level, star_level)
	
	# Store unit type as metadata
	enemy_data.set_meta("unit_type", unit_type)
	
	return enemy_data

func scale_enemy_stats(enemy_data, level: int, star_level: int):
	# Base scaling based on level
	var health_multiplier = 1.0 + (level * health_multiplier_per_level)
	var damage_multiplier = 1.0 + (level * damage_multiplier_per_level)
	
	# Star level scaling
	if star_level == 2:
		health_multiplier *= 1.8
		damage_multiplier *= 1.5
	elif star_level == 3:
		health_multiplier *= 3.2
		damage_multiplier *= 2.2
	
	# Apply scaling
	enemy_data.health = int(enemy_data.health * health_multiplier)
	enemy_data.attack_damage = int(enemy_data.attack_damage * damage_multiplier)
	
	# Slight random variation (±10%)
	var variation = randf_range(0.9, 1.1)
	enemy_data.health = int(enemy_data.health * variation)
	enemy_data.attack_damage = int(enemy_data.attack_damage * variation)

func place_enemies_strategically(enemy_team):
	if not board:
		push_error("Cannot place enemies: board reference invalid")
		return
	
	# Classify available tiles into rows
	var tiles_by_row = {}
	for row in range(board.ENEMY_ROWS):
		tiles_by_row[row] = []
		for col in range(board.ENEMY_COLS):
			var tile_key = "enemy_%d_%d" % [row, col]
			var tile = board.tiles.get(tile_key)
			
			if tile and not tile.is_occupied():
				tiles_by_row[row].append(tile)
	
	# Sort enemy team by unit type priority: Tank > Melee > Support > Ranged
	enemy_team.sort_custom(func(a, b):
		var a_type = a.get_meta("unit_type", UnitType.MELEE)
		var b_type = b.get_meta("unit_type", UnitType.MELEE)
		
		if a_type == UnitType.TANK and b_type != UnitType.TANK:
			return true
		if a_type != UnitType.TANK and b_type == UnitType.TANK:
			return false
		if a_type == UnitType.MELEE and b_type != UnitType.MELEE:
			return true
		if a_type != UnitType.MELEE and b_type == UnitType.MELEE:
			return false
		if a_type == UnitType.SUPPORT and b_type != UnitType.SUPPORT:
			return true
		return false
	)
	
	# Place units by type and row preference
	for enemy_data in enemy_team:
		var unit_type = enemy_data.get_meta("unit_type", UnitType.MELEE)
		var preferred_rows = []
		
		match unit_type:
			UnitType.TANK:
				# Tanks go in front (middle rows)
				preferred_rows = [3, 2, 4, 1, 5, 0, 6]  # Middle to edges
			UnitType.MELEE:
				# Melee units go in front rows
				preferred_rows = [2, 3, 1, 4, 0, 5, 6]  # Front to back
			UnitType.SUPPORT:
				# Support units go in middle rows
				preferred_rows = [2, 3, 4, 1, 5, 0, 6]  # Middle to edges
			UnitType.RANGED:
				# Ranged units go in back rows
				preferred_rows = [5, 6, 4, 3, 2, 1, 0]  # Back to front
		
		# Find best available tile
		var placed = false
		for row in preferred_rows:
			if row < board.ENEMY_ROWS and tiles_by_row[row].size() > 0:
				# Choose a tile - tanks prefer center column, others random
				var chosen_tile
				
				if unit_type == UnitType.TANK:
					# Find most central tile
					var center_col = board.ENEMY_COLS / 2
					var min_distance = 999
					
					for tile in tiles_by_row[row]:
						var col = int(tile.get_meta("col", 0))
						var distance = abs(col - center_col)
						if distance < min_distance:
							min_distance = distance
							chosen_tile = tile
				else:
					# Random tile in preferred row
					chosen_tile = tiles_by_row[row][randi() % tiles_by_row[row].size()]
				
				# Place the enemy
				spawn_enemy_at_tile(enemy_data, chosen_tile)
				
				# Remove tile from available tiles
				tiles_by_row[row].erase(chosen_tile)
				
				placed = true
				break
		
		if not placed:
			# If preferred placement failed, find any available tile
			for row in range(board.ENEMY_ROWS):
				if tiles_by_row[row].size() > 0:
					var chosen_tile = tiles_by_row[row][randi() % tiles_by_row[row].size()]
					spawn_enemy_at_tile(enemy_data, chosen_tile)
					tiles_by_row[row].erase(chosen_tile)
					break

func spawn_enemy_at_tile(enemy_data, tile):
	# Spawn enemy unit
	var enemy_unit = enemy_unit_scene.instantiate()
	board.add_child(enemy_unit)
	
	# Set character data 
	enemy_unit.set_character_data(enemy_data)
	
	# Explicitly set star level again to ensure it's correct
	enemy_unit.set_star_level(enemy_data.star_level)
	
	# Position at the tile's center
	enemy_unit.global_position = tile.get_center_position()
	
	# Set the occupying unit reference
	tile.set_occupying_unit(enemy_unit)
	
	# Make sure Components node exists and has proper child components
	var components = enemy_unit.get_node_or_null("Components")
	if not components:
		components = Node.new()
		components.name = "Components"
		enemy_unit.add_child(components)
	
	# Create and properly name the CombatComponent
	var combat_component = components.get_node_or_null("CombatComponent")
	if not combat_component:
		combat_component = CombatComponent.new(enemy_unit)
		combat_component.name = "CombatComponent"
		components.add_child(combat_component)
	
	# Create and properly name the AbilityComponent
	var ability_component = components.get_node_or_null("AbilityComponent")
	if not ability_component:
		ability_component = AbilityComponent.new(enemy_unit)
		ability_component.name = "AbilityComponent"
		components.add_child(ability_component)
	
	print("Placed " + enemy_data.display_name + " (Type: " + str(enemy_data.get_meta("unit_type")) + ", Star: " + str(enemy_data.star_level) + ")")
	
	return enemy_unit

# Initialize the components for an enemy unit
func initialize_enemy_components(unit):
	# Add and initialize the combat component
	var combat_component_node = unit.get_node_or_null("Components/CombatComponent")
	
	if combat_component_node:
		var combat_component = CombatComponent.new(unit)
		combat_component_node.replace_by(combat_component)
	else:
		var components = unit.get_node_or_null("Components")
		if components:
			var combat_component = CombatComponent.new(unit)
			combat_component.name = "CombatComponent"
			components.add_child(combat_component)
	
	# Add and initialize the ability component
	var ability_component_node = unit.get_node_or_null("Components/AbilityComponent")
	
	if ability_component_node:
		var ability_component = AbilityComponent.new(unit)
		ability_component_node.replace_by(ability_component)
	else:
		var components = unit.get_node_or_null("Components")
		if components:
			var ability_component = AbilityComponent.new(unit)
			ability_component.name = "AbilityComponent"
			components.add_child(ability_component)

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
