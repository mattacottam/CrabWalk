extends Node

# References
var board
var character_database

# Character scene to spawn
var character_scene

# UI elements
var spawn_button

func _ready():
	# Get references (using get_parent() is more reliable than node paths)
	board = get_parent()
	
	# Try to find CharacterDatabase using relative path first
	character_database = board.get_node_or_null("CharacterDatabase")
	
	# Fall back to absolute path if needed
	if not character_database:
		character_database = get_node_or_null("/root/GameBoard/CharacterDatabase")
	
	# Load character scene
	character_scene = load("res://scenes/characters/BaseCharacter.tscn")
	if not character_scene:
		push_error("ERROR: Could not load BaseCharacter scene")
	
	# Create UI
	create_spawn_button()

func create_spawn_button():
	# Create canvas layer for UI
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	# Create control node
	var control = Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(control)
	
	# Create button
	spawn_button = Button.new()
	spawn_button.text = "Spawn Unit"
	spawn_button.position = Vector2(20, 100) # Moved down a bit to avoid overlapping
	spawn_button.size = Vector2(120, 40)
	spawn_button.pressed.connect(spawn_unit_on_bench)
	control.add_child(spawn_button)

func spawn_unit_on_bench():
	print("Spawn button pressed")
	
	if not board:
		push_error("ERROR: Board not found")
		return
	
	if not character_scene:
		push_error("ERROR: Character scene not found")
		return
	
	# Create a test character if no database
	var character_data
	if character_database and character_database.characters.size() > 0:
		# Get a random character
		var char_ids = character_database.characters.keys()
		var random_char_id = char_ids[randi() % char_ids.size()]
		character_data = character_database.get_character(random_char_id)
	else:
		# Create a fallback character
		character_data = Character.new()
		character_data.id = "test_unit"
		character_data.display_name = "Test Unit"
		character_data.health = 100
		character_data.attack_damage = 10
		character_data.rarity = 1
		character_data.cost = 1
	
	# Find an empty bench tile
	var empty_tile = find_empty_bench_tile()
	if empty_tile:
		# Spawn the character
		var character = character_scene.instantiate()
		board.add_child(character)
		
		# Set character data
		character.set_character_data(character_data)
		
		# Position at the tile's center
		character.global_position = empty_tile.get_center_position()
		
		# Set the occupying unit reference
		empty_tile.set_occupying_unit(character)
		
		print("Spawned unit on bench")
	else:
		print("No empty bench slots available")

func find_empty_bench_tile():
	for i in range(board.BENCH_SPACES):
		var tile_key = "bench_%d" % i
		if board.tiles.has(tile_key):
			var tile = board.tiles[tile_key]
			if not tile.is_occupied():
				return tile
	return null
