extends Control

# References
var character_database: Node
var player: Node
var board: Node

# Array of current shop options
var current_shop_options = []

# Shop slots (buttons)
var shop_slots = []
const NUM_SHOP_SLOTS = 5

# Signals
signal character_purchased(character)

func _ready():
	# Get references
	character_database = get_node_or_null("/root/GameBoard/CharacterDatabase")
	player = get_node_or_null("/root/GameBoard/Player")
	board = get_node_or_null("/root/GameBoard")
	
	if not character_database:
		push_error("ShopUI: Could not find CharacterDatabase")
	if not player:
		push_error("ShopUI: Could not find Player")
	if not board:
		push_error("ShopUI: Could not find GameBoard")
	
	# Set up shop slots
	setup_shop_slots()
	
	# Initial shop roll
	roll_shop()

# Set up the shop slot buttons
func setup_shop_slots():
	var slot_container = $ShopContainer/ShopSlots
	for i in range(NUM_SHOP_SLOTS):
		var slot = slot_container.get_node("ShopSlot" + str(i+1))
		if slot:
			shop_slots.append(slot)
			
			# Connect button press
			slot.pressed.connect(_on_shop_slot_pressed.bind(i))

# Roll new shop options
func roll_shop():
	if not character_database or not player:
		return
	
	# Clear current options
	current_shop_options.clear()
	
	# Get new options based on player level
	var options = character_database.get_shop_roll(player.level, NUM_SHOP_SLOTS)
	current_shop_options = options
	
	# Update shop UI
	update_shop_display()

# Update shop display with current options
func update_shop_display():
	for i in range(NUM_SHOP_SLOTS):
		var slot = shop_slots[i]
		
		if i < current_shop_options.size():
			var char_id = current_shop_options[i]
			var character = character_database.get_character(char_id)
			
			if character:
				# Update button with character info
				slot.text = character.display_name
				
				# Set cost
				var cost_label = slot.get_node_or_null("CostLabel")
				if cost_label:
					cost_label.text = str(character.cost) + "g"
				
				# Set color based on rarity
				var color = character.get_rarity_color()
				var normal_style = slot.get_theme_stylebox("normal")
				normal_style.bg_color = color.darkened(0.7)
				
				# Enable button
				slot.disabled = false
			else:
				# Empty slot if no character
				slot.text = "Empty"
				slot.disabled = true
		else:
			# Empty slot
			slot.text = "Empty"
			slot.disabled = true

# Handle shop slot button press
func _on_shop_slot_pressed(slot_index):
	if not character_database or not player or not board:
		return
	
	if slot_index < current_shop_options.size():
		var char_id = current_shop_options[slot_index]
		var character = character_database.get_character(char_id)
		
		if character:
			# Try to purchase (deduct gold)
			if player.pay_for_character(character):
				# Remove from shop options
				current_shop_options.remove_at(slot_index)
				update_shop_display()
				
				# Spawn character on bench
				spawn_character_on_bench(character)
				
				# Emit purchase signal
				emit_signal("character_purchased", character)
			else:
				# Not enough gold - show message
				$NotEnoughGoldLabel.visible = true
				await get_tree().create_timer(1.5).timeout
				$NotEnoughGoldLabel.visible = false

# Spawn purchased character on the bench
func spawn_character_on_bench(character_data):
	if not board:
		return
	
	# Find the first unoccupied bench tile
	for i in range(board.BENCH_SPACES):
		var tile_key = "bench_%d" % i
		var tile = board.tiles.get(tile_key)
		
		if tile and not tile.occupied:
			# Spawn character scene
			var character_scene = load("res://scenes/characters/BaseCharacter.tscn")
			var character = character_scene.instantiate()
			board.add_child(character)
			
			# Set character data
			character.set_character_data(character_data)
			
			# Position at the tile's center
			character.global_position = tile.get_center_position()
			
			# Set the occupying unit reference
			tile.set_occupying_unit(character)
			
			print("Spawned " + character_data.display_name + " on bench slot %d" % i)
			return
	
	print("No empty bench slots available")
	# Could show a message about bench being full
