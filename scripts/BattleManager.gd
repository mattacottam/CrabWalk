extends Node

signal battle_started
signal battle_ended(victory)
signal level_changed(new_level)

# References
@onready var board = get_node("/root/GameBoard")
@onready var enemy_generator = get_node("/root/GameBoard/EnemyUnitGenerator")
@onready var player = get_node("/root/GameBoard/Player")

# Battle state
var battle_in_progress = false
var current_level = 1
var victory = false

# UI elements
var start_battle_button
var battle_results_label
var level_label
var ui_container

func _ready():
	# Create UI elements
	create_battle_ui()
	
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	# Initialize with level 1 enemies
	enemy_generator.generate_enemies_for_level(current_level)

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if start_battle_button and start_battle_button.get_global_rect().has_point(event.position) and not start_battle_button.disabled:
			print("Start battle button clicked!")
			_on_start_battle_pressed()
			get_viewport().set_input_as_handled()

func create_battle_ui():
	# Create canvas layer for UI
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 5
	add_child(canvas_layer)
	
	# Create UI control
	ui_container = Control.new()
	ui_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_container.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas_layer.add_child(ui_container)
	
	# Create battle panel
	var panel = Panel.new()
	panel.position = Vector2(500, 10)
	panel.size = Vector2(250, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_container.add_child(panel)
	
	# Create level label
	level_label = Label.new()
	level_label.text = "Level: " + str(current_level)
	level_label.position = Vector2(520, 20)
	level_label.size = Vector2(200, 30)
	ui_container.add_child(level_label)
	
	# Create start battle button
	start_battle_button = Button.new()
	start_battle_button.text = "Start Battle"
	start_battle_button.position = Vector2(520, 60)
	start_battle_button.size = Vector2(200, 40)
	start_battle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	start_battle_button.focus_mode = Control.FOCUS_ALL
	ui_container.add_child(start_battle_button)
	
	# Connect button signal - make sure we use the correct connect syntax
	if not start_battle_button.pressed.is_connected(_on_start_battle_pressed):
		start_battle_button.pressed.connect(_on_start_battle_pressed)
	
	# Create battle results label
	battle_results_label = Label.new()
	battle_results_label.position = Vector2(520, 110)
	battle_results_label.size = Vector2(200, 40)
	battle_results_label.visible = false
	ui_container.add_child(battle_results_label)
	
	print("Battle UI created, button connected: ", start_battle_button.pressed.is_connected(_on_start_battle_pressed))

func _on_start_battle_pressed():
	if battle_in_progress:
		return
	
	start_battle()

func start_battle():
	battle_in_progress = true
	emit_signal("battle_started")
	
	# Disable UI interactions during battle
	start_battle_button.disabled = true
	
	print("Battle started at level " + str(current_level))
	
	# In a real implementation, you'd run the battle simulation here
	# For now, we'll just simulate a battle with a timer
	simulate_battle()

func simulate_battle():
	# For debugging: just simulate a battle with a timer
	var battle_time = 2.0  # 2 seconds
	
	# Determine outcome (for now, just random with increasing difficulty)
	var difficulty_factor = 0.1 + (current_level * 0.05)  # Gets harder as level increases
	victory = randf() > difficulty_factor  # Chance of defeat increases with level
	
	# Wait for battle to complete
	await get_tree().create_timer(battle_time).timeout
	
	end_battle()

func end_battle():
	battle_in_progress = false
	emit_signal("battle_ended", victory)
	
	# Show results
	battle_results_label.text = "Victory!" if victory else "Defeat!"
	battle_results_label.visible = true
	
	# Handle post-battle actions
	if victory:
		# Reward player (add gold)
		if player:
			var gold_reward = 5 + current_level
			player.add_gold(gold_reward)
			print("Rewarded player with " + str(gold_reward) + " gold")
		
		# Advance to next level
		current_level += 1
		emit_signal("level_changed", current_level)
		level_label.text = "Level: " + str(current_level)
		
		# Update button text
		start_battle_button.text = "Start Level " + str(current_level)
		
		# Generate new enemies for next level
		enemy_generator.clear_all_enemies()
		enemy_generator.generate_enemies_for_level(current_level)
	else:
		# Game over or retry
		start_battle_button.text = "Retry Level " + str(current_level)
		
		# Clear and regenerate the same level
		enemy_generator.clear_all_enemies()
		enemy_generator.generate_enemies_for_level(current_level)
	
	# Re-enable UI
	start_battle_button.disabled = false

func reset_game():
	# Reset to level 1
	current_level = 1
	level_label.text = "Level: " + str(current_level)
	start_battle_button.text = "Start Level " + str(current_level)
	battle_results_label.visible = false
	
	# Clear enemies and generate new ones for level 1
	enemy_generator.clear_all_enemies()
	enemy_generator.generate_enemies_for_level(current_level)
	
	# Reset player state (if needed)
	# For example, reset gold, health, etc.
	
	print("Game reset to level 1")
