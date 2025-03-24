@tool
extends EditorScript

# This script can generate multiple character resources at once
# Run with File > Run (Shift+Ctrl+X on Windows/Linux, Shift+Cmd+X on Mac)

func _run():
	# Create all characters
	create_berserker()
	create_healer()
	create_knight()
	create_druid()
	
	print("All characters created successfully!")

func create_berserker():
	var berserker = Character.new()
	
	# Basic info
	berserker.id = "berserker"
	berserker.display_name = "Berserker"
	berserker.description = "A frenzied warrior who deals more damage as health decreases."
	
	# Stats
	berserker.health = 120
	berserker.attack_damage = 20
	berserker.attack_speed = 1.2
	berserker.range = 1
	berserker.armor = 8
	berserker.magic_resist = 5
	berserker.mana_max = 90
	berserker.starting_mana = 0  # Starts with no mana
	berserker.movement_speed = 3.2
	
	# Gameplay
	berserker.rarity = 3  # Rare
	berserker.cost = 3
	berserker.shop_weight = 1
	
	# Traits/synergies
	berserker.traits = ["Berserker", "Orcish"]
	
	# Ability
	berserker.ability_name = "Blood Frenzy"
	berserker.ability_description = "Gains attack speed and damage as health decreases"
	berserker.ability_damage = 10
	berserker.ability_mana_cost = 50
	
	# Visual customization
	berserker.color = Color(0.9, 0.1, 0.1)  # Bright red
	
	save_character(berserker)

func create_healer():
	var healer = Character.new()
	
	# Basic info
	healer.id = "healer"
	healer.display_name = "Priestess"
	healer.description = "A devoted healer who restores health to nearby allies."
	
	# Stats
	healer.health = 90
	healer.attack_damage = 8
	healer.attack_speed = 0.8
	healer.range = 3
	healer.armor = 5
	healer.magic_resist = 15
	healer.mana_max = 120
	healer.starting_mana = 20  # Starts with some mana
	healer.movement_speed = 2.6
	
	# Gameplay
	healer.rarity = 3  # Rare
	healer.cost = 3
	healer.shop_weight = 1
	
	# Traits/synergies
	healer.traits = ["Support", "Divine"]
	
	# Ability
	healer.ability_name = "Healing Light"
	healer.ability_description = "Restores 30 health to the lowest health ally"
	healer.ability_damage = -30  # Negative damage = healing
	healer.ability_mana_cost = 60
	
	# Visual customization
	healer.color = Color(1.0, 0.9, 0.4)  # Light gold
	
	save_character(healer)

func create_knight():
	var knight = Character.new()
	
	# Basic info
	knight.id = "knight"
	knight.display_name = "Knight"
	knight.description = "A valiant defender who shields allies from harm."
	
	# Stats
	knight.health = 140
	knight.attack_damage = 12
	knight.attack_speed = 0.9
	knight.range = 1
	knight.armor = 25
	knight.magic_resist = 15
	knight.mana_max = 100
	knight.starting_mana = 0  # Starts with no mana
	knight.movement_speed = 2.8
	
	# Gameplay
	knight.rarity = 2  # Uncommon
	knight.cost = 2
	knight.shop_weight = 1
	
	# Traits/synergies
	knight.traits = ["Guardian", "Noble"]
	
	# Ability
	knight.ability_name = "Shield Wall"
	knight.ability_description = "Creates a barrier that absorbs damage for nearby allies"
	knight.ability_damage = 0
	knight.ability_mana_cost = 70
	
	# Visual customization
	knight.color = Color(0.7, 0.7, 0.9)  # Light blue/silver
	
	save_character(knight)

func create_druid():
	var druid = Character.new()
	
	# Basic info
	druid.id = "druid"
	druid.display_name = "Druid"
	druid.description = "A nature mage who controls plants and animals."
	
	# Stats
	druid.health = 100
	druid.attack_damage = 14
	druid.attack_speed = 0.85
	druid.range = 3
	druid.armor = 8
	druid.magic_resist = 20
	druid.mana_max = 90
	druid.starting_mana = 30  # Starts with significant mana
	druid.movement_speed = 3.0
	
	# Gameplay
	druid.rarity = 2  # Uncommon
	druid.cost = 2
	druid.shop_weight = 1
	
	# Traits/synergies
	druid.traits = ["Shapeshifter", "Nature"]
	
	# Ability
	druid.ability_name = "Entangling Roots"
	druid.ability_description = "Immobilizes enemies in a target area for 3 seconds"
	druid.ability_damage = 15
	druid.ability_mana_cost = 65
	
	# Visual customization
	druid.color = Color(0.2, 0.8, 0.3)  # Vibrant green
	
	save_character(druid)

func save_character(character: Character):
	var save_path = "res://resources/characters/" + character.id + ".tres"
	var result = ResourceSaver.save(character, save_path)
	
	if result == OK:
		print(character.display_name + " character saved successfully!")
	else:
		print("Failed to save " + character.display_name + " character. Error code: " + str(result))
