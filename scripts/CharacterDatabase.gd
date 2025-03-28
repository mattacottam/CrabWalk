extends Node

# Character pool - all available characters by ID
var characters = {}

# Character pools by rarity (for shop roll mechanics)
var character_pools = {
	1: [], # COMMON
	2: [], # UNCOMMON
	3: [], # RARE
	4: [], # EPIC
	5: []  # LEGENDARY
}

# Shop probabilities by player level [common%, uncommon%, rare%, epic%, legendary%]
const SHOP_ODDS = {
	1: [100, 0, 0, 0, 0],
	2: [70, 30, 0, 0, 0],
	3: [60, 35, 5, 0, 0],
	4: [50, 35, 15, 0, 0],
	5: [40, 35, 20, 5, 0],
	6: [30, 35, 25, 10, 0],
	7: [20, 35, 30, 15, 0],
	8: [15, 25, 35, 20, 5],
	9: [10, 20, 30, 30, 10]
}

func _ready():
	# Reset character pools to ensure we start fresh
	for rarity in character_pools:
		character_pools[rarity].clear()
	
	# Register all characters
	register_all_characters()
	
	# If no characters were found, create test characters
	if characters.size() == 0:
		create_test_characters()
	
	# Debug: Print all registered characters and pools
	print_character_pools()

# Debug: Print all registered characters and pools
func print_character_pools():
	print("=========== CHARACTER DATABASE ===========")
	print("Total characters registered: " + str(characters.size()))
	for rarity in range(1, 6):
		print("Rarity " + str(rarity) + " pool: " + str(character_pools[rarity].size()) + " characters")
		for char_id in character_pools[rarity]:
			print("  - " + characters[char_id].display_name)
	print("=========================================")

# Register all character resources in the game
func register_all_characters():
	# Load all character resources from the characters directory
	var dir = DirAccess.open("res://resources/characters")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path = "res://resources/characters/" + file_name
				print("Loading character resource: " + path)
				var character = load(path)
				if character is Character:
					register_character(character)
				else:
					print("WARNING: Resource is not a Character: " + path)
			file_name = dir.get_next()
	else:
		push_error("Could not access character resources directory, will use test characters instead")

# Create test characters for development
func create_test_characters():
	print("Creating test characters...")
	
	# Warrior
	var warrior = Character.new()
	warrior.id = "warrior"
	warrior.display_name = "Warrior"
	warrior.description = "A front-line fighter with high health and armor."
	warrior.health = 150
	warrior.attack_damage = 15
	warrior.attack_speed = 0.8
	warrior.range = 1
	warrior.armor = 20
	warrior.magic_resist = 10
	warrior.mana_max = 100
	warrior.movement_speed = 2.8
	warrior.rarity = 1
	warrior.cost = 1
	warrior.traits = ["Fighter", "Human"]
	warrior.color = Color(0.8, 0.6, 0.0)  # Goldish brown
	register_character(warrior)
	warrior.save_as_resource()
	
	# Archer
	var archer = Character.new()
	archer.id = "archer"
	archer.display_name = "Archer"
	archer.description = "A ranged attacker with high damage."
	archer.health = 90
	archer.attack_damage = 25
	archer.attack_speed = 1.0
	archer.range = 4
	archer.armor = 5
	archer.magic_resist = 5
	archer.mana_max = 100
	archer.movement_speed = 3.0
	archer.rarity = 2
	archer.cost = 2
	archer.traits = ["Ranger", "Elf"]
	archer.color = Color(0.0, 0.8, 0.2)  # Green
	register_character(archer)
	archer.save_as_resource()
	
	# Mage
	var mage = Character.new()
	mage.id = "mage"
	mage.display_name = "Mage"
	mage.description = "A powerful spellcaster with area damage."
	mage.health = 80
	mage.attack_damage = 10
	mage.attack_speed = 0.7
	mage.range = 3
	mage.armor = 3
	mage.magic_resist = 20
	mage.mana_max = 80
	mage.movement_speed = 2.5
	mage.rarity = 3
	mage.cost = 3
	mage.traits = ["Mage", "Human"]
	mage.color = Color(0.2, 0.4, 0.8)  # Blue
	register_character(mage)
	mage.save_as_resource()
	
	# Tank
	var tank = Character.new()
	tank.id = "tank"
	tank.display_name = "Tank"
	tank.description = "An extremely durable front-line unit."
	tank.health = 200
	tank.attack_damage = 5
	tank.attack_speed = 0.5
	tank.range = 1
	tank.armor = 35
	tank.magic_resist = 35
	tank.mana_max = 120
	tank.movement_speed = 2.0
	tank.rarity = 4
	tank.cost = 4
	tank.traits = ["Guardian", "Dwarf"]
	tank.color = Color(0.7, 0.7, 0.7)  # Gray/Silver
	register_character(tank)
	tank.save_as_resource()
	
	# Assassin
	var assassin = Character.new()
	assassin.id = "assassin"
	assassin.display_name = "Assassin"
	assassin.description = "A stealthy, high-damage unit."
	assassin.health = 70
	assassin.attack_damage = 35
	assassin.attack_speed = 1.2
	assassin.range = 1
	assassin.armor = 8
	assassin.magic_resist = 8
	assassin.mana_max = 60
	assassin.movement_speed = 3.5
	assassin.rarity = 5
	assassin.cost = 5
	assassin.traits = ["Assassin", "Shadow"]
	assassin.color = Color(0.6, 0.0, 0.6)  # Purple
	register_character(assassin)
	assassin.save_as_resource()

# Register a single character
func register_character(character: Character):
	# Add to main dictionary
	characters[character.id] = character
	
	# Add to rarity pool
	if not character.id in character_pools[character.rarity]:
		character_pools[character.rarity].append(character.id)
		print("Registered character: " + character.display_name + " (Rarity: " + str(character.rarity) + ")")
	else:
		print("Character already registered: " + character.display_name)

# Get a character by ID
func get_character(id: String) -> Character:
	if characters.has(id):
		return characters[id]
	return null

# Get random characters based on player level
func get_shop_roll(player_level: int, num_slots: int = 5) -> Array:
	var result = []
	
	# Cap level for odds calculation
	var capped_level = min(player_level, 9)
	
	# Get probabilities for the level
	var odds = SHOP_ODDS[capped_level]
	
	# Fill each slot
	for i in range(num_slots):
		# Determine rarity first
		var rarity_roll = randf() * 100
		var chosen_rarity = 1  # Default to COMMON
		var cumulative_chance = 0
		
		for r in range(5):
			cumulative_chance += odds[r]
			if rarity_roll <= cumulative_chance:
				chosen_rarity = r + 1  # +1 because rarity starts at 1
				break
		
		# Try to get a random character from the chosen rarity pool
		if character_pools[chosen_rarity].size() > 0:
			var char_id = character_pools[chosen_rarity].pick_random()
			result.append(char_id)
		else:
			# Fallback: try to find any character with lower rarity
			var found = false
			for r in range(chosen_rarity, 0, -1):
				if character_pools[r].size() > 0:
					var char_id = character_pools[r].pick_random()
					result.append(char_id)
					found = true
					break
			
			# If still nothing found, try higher rarities
			if not found:
				for r in range(chosen_rarity + 1, 6):
					if character_pools[r].size() > 0:
						var char_id = character_pools[r].pick_random()
						result.append(char_id)
						found = true
						break
			
			# If absolutely nothing found, append a placeholder
			if not found:
				# This should not happen if characters are properly registered
				print("WARNING: No characters available for shop slot")
				result.append("")
	
	return result
