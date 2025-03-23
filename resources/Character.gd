class_name Character
extends Resource

# Core properties
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# Visuals
@export var portrait: Texture2D
@export var model_scene: PackedScene

# Gameplay stats
@export var health: int = 100
@export var attack_damage: int = 10
@export var attack_speed: float = 1.0
@export var range: int = 1
@export var armor: int = 0
@export var magic_resist: int = 0
@export var mana_max: int = 100
@export var movement_speed: float = 3.0

# Shop info
enum Rarity {COMMON = 1, UNCOMMON = 2, RARE = 3, EPIC = 4, LEGENDARY = 5}
@export var rarity: int = 1 # COMMON
@export var cost: int = 1
@export var shop_weight: int = 1  # For shop pool weighting

# Trait system
@export var traits: Array[String] = []

# Ability info
@export var ability_name: String = ""
@export var ability_description: String = ""
@export var ability_damage: int = 0
@export var ability_mana_cost: int = 100

func _init(p_id: String = "", p_name: String = "", p_cost: int = 1, p_rarity: int = 1):
	id = p_id
	display_name = p_name
	cost = p_cost
	rarity = p_rarity

# Get a color representing the unit's rarity
func get_rarity_color() -> Color:
	match rarity:
		1: # COMMON
			return Color(0.5, 0.5, 0.5)  # Gray
		2: # UNCOMMON
			return Color(0.0, 0.5, 0.0)  # Green
		3: # RARE
			return Color(0.0, 0.0, 0.8)  # Blue
		4: # EPIC
			return Color(0.5, 0.0, 0.8)  # Purple
		5: # LEGENDARY
			return Color(0.8, 0.6, 0.0)  # Gold
	return Color.WHITE
