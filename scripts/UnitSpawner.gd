extends Node

# Reference to the game board
@onready var board = get_node("/root/GameBoard")

# Character scene to spawn
var character_scene = preload("res://scenes/characters/BaseCharacter.tscn")

# UI elements
var spawn_button

func _ready():
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
	spawn_button.position = Vector2(20, 20)
	spawn_button.size = Vector2(120, 40)
	spawn_button.pressed.connect(spawn_unit_on_bench)
	control.add_child(spawn_button)

func spawn_unit_on_bench():
	if not board:
		print("ERROR: Board not found")
		return
	
	print("Trying to spawn unit. Available bench tiles:")
	
	# Find the first unoccupied bench tile
	for i in range(board.BENCH_SPACES):
		var tile_key = "bench_%d" % i
		var tile = board.tiles.get(tile_key)
		
		print("Checking tile " + tile_key + ": " + str(tile != null))
		
		if tile:
			print("- Occupied: " + str(tile.occupied))
		
		if tile and not tile.occupied:
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
