extends Node

# Reference to the game board
@onready var board = get_node("/root/GameBoard")
@onready var character_database = get_node("/root/GameBoard/CharacterDatabase")

# Character scene to spawn
var character_scene = preload("res://scenes/characters/BaseCharacter.tscn")

# UI elements
var spawn_button
var character_dropdown
var canvas_layer
var dropdown_options = []

func _ready():
	# Wait a frame to ensure board is fully initialized
	await get_tree().process_frame
	
	# Create UI
	create_spawn_ui()

func create_spawn_ui():
	# Create canvas layer for UI with proper settings
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10  # Higher layer to be above other UI
	add_child(canvas_layer)
	
	# Create control node with proper mouse settings
	var control = Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass through if not hitting controls
	canvas_layer.add_child(control)
	
	# Create character dropdown
	character_dropdown = OptionButton.new()
	character_dropdown.position = Vector2(300, 70)
	character_dropdown.size = Vector2(150, 30)
	character_dropdown.mouse_filter = Control.MOUSE_FILTER_STOP
	control.add_child(character_dropdown)
	
	# Populate dropdown with characters
	populate_character_dropdown()
	
	# Create button
	spawn_button = Button.new()
	spawn_button.text = "Spawn Unit"
	spawn_button.position = Vector2(300, 20)
	spawn_button.size = Vector2(150, 40)
	
	# Make sure mouse input works
	spawn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect the pressed signal
	spawn_button.pressed.connect(spawn_selected_unit)
	
	control.add_child(spawn_button)
	
	print("Spawn UI created and connected")

func populate_character_dropdown():
	if not character_database:
		print("ERROR: Character database not found")
		return
		
	# Clear existing items
	character_dropdown.clear()
	dropdown_options.clear()
	
	# Add option for random character
	character_dropdown.add_item("Random Character")
	dropdown_options.append("random")
	
	# Add all characters from database
	for char_id in character_database.characters:
		var character = character_database.characters[char_id]
		var display_name = character.display_name
		var rarity_text = ""
		
		# Add rarity indicator
		match character.rarity:
			1: rarity_text = " (Common)"
			2: rarity_text = " (Uncommon)" 
			3: rarity_text = " (Rare)"
			4: rarity_text = " (Epic)"
			5: rarity_text = " (Legendary)"
		
		character_dropdown.add_item(display_name + rarity_text)
		dropdown_options.append(char_id)

func spawn_selected_unit():
	if not board:
		print("ERROR: Board not found")
		return
	
	print("Trying to spawn unit")
	
	# Get selected character
	var selected_index = character_dropdown.selected
	var character_id = dropdown_options[selected_index]
	var character_data = null
	
	# Handle random selection
	if character_id == "random":
		var random_index = randi() % (dropdown_options.size() - 1) + 1  # Skip "random" option
		character_id = dropdown_options[random_index]
	
	# Get character data
	if character_database and character_database.characters.has(character_id):
		character_data = character_database.characters[character_id]
	
	if not character_data:
		print("ERROR: Character data not found for ID: " + character_id)
		return
	
	# Find the first unoccupied bench tile
	for i in range(board.BENCH_SPACES):
		var tile_key = "bench_%d" % i
		var tile = board.tiles.get(tile_key)
		
		if tile and not tile.is_occupied():
			# Spawn character on this tile
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
