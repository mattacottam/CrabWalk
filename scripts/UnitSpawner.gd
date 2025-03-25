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

# Test units checkbox
var test_units_checkbox
var spawn_test_units = false

func _ready():
	# Wait a frame to ensure board is fully initialized
	await get_tree().process_frame
	
	# Create UI
	create_spawn_ui()
	
	# Optionally, spawn test units with varying health values
	if spawn_test_units:
		spawn_test_units_set()

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
	
	# Create test units checkbox
	test_units_checkbox = CheckBox.new()
	test_units_checkbox.text = "Spawn Test Units"
	test_units_checkbox.position = Vector2(300, 130)
	test_units_checkbox.size = Vector2(150, 30)
	test_units_checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
	test_units_checkbox.toggled.connect(_on_test_units_toggled)
	control.add_child(test_units_checkbox)
	
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

func _on_test_units_toggled(toggle):
	spawn_test_units = toggle
	if spawn_test_units:
		spawn_test_units_set()

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
	spawn_unit_on_bench(character_data)

func spawn_unit_on_bench(character_data):
	if not board:
		print("ERROR: Board not found")
		return
		
	for i in range(board.BENCH_SPACES):
		var tile_key = "bench_%d" % i
		var tile = board.tiles.get(tile_key)
		
		if tile and not tile.is_occupied():
			# Spawn character on this tile
			var character = character_scene.instantiate()
			board.add_child(character)
			
			# Ensure star level is set (default to 1 if not present)
			if character_data.star_level <= 0:
				character_data.star_level = 1
				
			# Set character data
			character.set_character_data(character_data)
			
			# Position at the tile's center
			character.global_position = tile.get_center_position()
			
			# Set the occupying unit reference
			tile.set_occupying_unit(character)
			
			print("Spawned " + character_data.display_name + " (Star " + str(character_data.star_level) + ") on bench slot %d" % i)
			
			# Add a delay before checking for combines, without capturing the character reference
			character.combine_cooldown = true
			var timer = get_tree().create_timer(0.2)
			await timer.timeout
			
			# Only proceed if the character still exists
			if is_instance_valid(character):
				character.combine_cooldown = false
				character.check_for_automatic_combine()
			
			return
	
	print("No empty bench slots available")

# Spawn a set of test units with varying health and mana values
func spawn_test_units_set():
	print("Spawning test units with varying health values")
	
	# Clear the bench first
	clear_bench()
	
	# Create different health characters
	var health_values = [100, 200, 300, 400, 50]
	var mana_values = [100, 125, 150, 75, 60]
	
	# Get a list of all character IDs
	var char_ids = []
	for char_id in character_database.characters:
		char_ids.append(char_id)
	
	# Spawn each test unit
	for i in range(min(health_values.size(), board.BENCH_SPACES)):
		# Get a character template
		var char_id = char_ids[i % char_ids.size()]
		var character_data = character_database.characters[char_id].duplicate()
		
		# Modify health and mana
		character_data.health = health_values[i]
		character_data.mana_max = mana_values[i]
		
		# Add a special indicator to the name
		character_data.display_name += " (" + str(health_values[i]) + " HP)"
		
		# Spawn on the bench
		spawn_unit_on_bench(character_data)

# Clear all units from the bench
func clear_bench():
	if not board:
		return
		
	for i in range(board.BENCH_SPACES):
		var tile_key = "bench_%d" % i
		var tile = board.tiles.get(tile_key)
		
		if tile and tile.is_occupied():
			var unit = tile.get_occupying_unit()
			if unit:
				unit.queue_free()
			tile.set_occupying_unit(null)

# Spawn test star level units for combining
func spawn_test_star_units():
	print("Spawning test units for star combining")
	
	# Clear the bench first
	clear_bench()
	
	# Pick a character
	var char_id = "warrior"  # Use warrior as test
	if character_database and character_database.characters.has(char_id):
		var base_character = character_database.characters[char_id]
		
		# Spawn 3 of the same 1-star warrior
		for i in range(3):
			var character_data = base_character.duplicate()
			character_data.star_level = 1
			spawn_unit_on_bench(character_data)
			
		# Also spawn a 2-star warrior with 2 more 1-stars to test cascading combines
		if board.BENCH_SPACES >= 6:
			var upgraded_character = base_character.duplicate()
			upgraded_character.star_level = 2
			spawn_unit_on_bench(upgraded_character)
			
			# Add 2 more 1-stars
			for i in range(2):
				var character_data = base_character.duplicate()
				character_data.star_level = 1
				spawn_unit_on_bench(character_data)
