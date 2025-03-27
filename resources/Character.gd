extends Resource
class_name Character

# Basic info
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var is_enemy: bool = false

# Stats
@export var health: int = 100
@export var attack_damage: int = 10
@export var attack_speed: float = 1.0
@export var attack_range: int = 1  # Renamed from range to avoid built-in conflict
@export var armor: int = 0
@export var magic_resist: int = 0
@export var mana_max: int = 100
@export var starting_mana: int = 0  # NEW: Starting mana amount
@export var movement_speed: float = 3.0

# Gameplay
@export var rarity: int = 1  # 1=common, 2=uncommon, 3=rare, 4=epic, 5=legendary
@export var cost: int = 1
@export var shop_weight: int = 1  # Higher value = more common in the shop pool
@export var star_level: int = 1  # 1, 2, or 3 stars

# Traits/synergies
@export var traits: Array = []

# Ability
@export var ability_name: String = ""
@export var ability_description: String = ""
@export var ability_damage: int = 0
@export var ability_mana_cost: int = 0

# Visual customization
@export var color: Color = Color(1, 1, 1)  # Default white, will be used to tint the model

# Get color based on rarity
func get_rarity_color() -> Color:
	match rarity:
		1:  # Common
			return Color(0.5, 0.5, 0.5)  # Gray
		2:  # Uncommon
			return Color(0.2, 0.8, 0.2)  # Green
		3:  # Rare
			return Color(0.2, 0.2, 0.8)  # Blue
		4:  # Epic
			return Color(0.8, 0.2, 0.8)  # Purple
		5:  # Legendary
			return Color(1.0, 0.8, 0.0)  # Gold
		_:
			return Color(1, 1, 1)  # White

# Save this character as a resource file
func save_as_resource():
	var save_path = "res://resources/characters/" + id + ".tres"
	var result = ResourceSaver.save(self, save_path)
	if result == OK:
		print("Character saved: " + save_path)
		return true
	else:
		print("Failed to save character: " + id)
		return false
