extends Control

# UI element references
@onready var gold_label: Label = $GoldContainer/GoldLabel
@onready var level_label: Label = $LevelContainer/LevelLabel
@onready var xp_bar: ProgressBar = $LevelContainer/XPBar
@onready var health_bar: ProgressBar = $HealthContainer/HealthBar
@onready var health_label: Label = $HealthContainer/HealthLabel

# Reference to player data
var player: Node

func _ready():
	# Find the player node correctly
	player = get_node("/root/GameBoard/Player")
	
	if player:
		# Connect to player signals
		player.gold_changed.connect(_on_gold_changed)
		player.level_changed.connect(_on_level_changed)
		player.xp_changed.connect(_on_xp_changed)
		player.health_changed.connect(_on_health_changed)
		
		# Initialize UI with current values
		_on_gold_changed(player.gold)
		_on_level_changed(player.level)
		_on_xp_changed(player.xp, player.get_required_xp())
		_on_health_changed(player.health)
	else:
		push_error("PlayerUI: Could not find Player node")

# Update gold display
func _on_gold_changed(new_amount: int):
	gold_label.text = str(new_amount)

# Update level display
func _on_level_changed(new_level: int):
	level_label.text = str(new_level)

# Update XP progress bar
func _on_xp_changed(new_xp: int, required_xp: int):
	xp_bar.max_value = required_xp
	xp_bar.value = new_xp

# Update health display
func _on_health_changed(new_health: int):
	health_bar.value = new_health
	health_label.text = str(new_health) + "/100"

# Buy XP button pressed
func _on_buy_xp_button_pressed():
	if player:
		player.buy_xp()

# Reroll shop button pressed
func _on_reroll_button_pressed():
	if player:
		if player.pay_reroll():
			# Find and refresh the shop
			var shop = get_node_or_null("/root/GameBoard/ShopUI")
			if shop:
				shop.roll_shop()
