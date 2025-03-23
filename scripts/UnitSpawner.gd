extends Node

# Reference to the game board
@onready var board = get_node("/root/GameBoard")

# Character scene to spawn
var character_scene = preload("res://scenes/characters/BaseCharacter.tscn")

# UI elements
var spawn_button
var canvas_layer

func _ready():
	# Wait a frame to ensure board is fully initialized
	await get_tree().process_frame
	
	# Create UI
	create_spawn_button()

func create_spawn_button():
	# Create canvas layer for UI with proper settings
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10  # Higher layer to be above other UI
	add_child(canvas_layer)
	
	# Create control node with proper mouse settings
	var control = Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass through if not hitting controls
	canvas_layer.add_child(control)
	
	# Create button
	spawn_button = Button.new()
	spawn_button.text = "Spawn Unit"
	spawn_button.position = Vector2(300, 20)
	spawn_button.size = Vector2(120, 40)
	
	# Make sure mouse input works
	spawn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect the pressed signal using newer syntax
	spawn_button.pressed.connect(spawn_unit_on_bench)
	
	control.add_child(spawn_button)
	
	print("Spawn button created and connected")

func spawn_unit_on_bench():
	if not board:
		print("ERROR: Board not found")
		return
	
	print("Trying to spawn unit")
	
	# Find the first unoccupied bench tile
	for i in range(board.BENCH_SPACES):
		var tile_key = "bench_%d" % i
		var tile = board.tiles.get(tile_key)
		
		if tile and not tile.is_occupied():
			# Spawn character on this tile
			var character = character_scene.instantiate()
			board.add_child(character)
			
			# Position at the tile's center
			character.global_position = tile.get_center_position()
			
			# Set the occupying unit reference
			tile.set_occupying_unit(character)
			
			print("Spawned unit on bench slot %d" % i)
			return
	
	print("No empty bench slots available")
