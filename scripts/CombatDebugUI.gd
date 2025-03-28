extends Control

var combat_system
var battle_manager

func _ready():
	# Find references
	combat_system = get_node_or_null("/root/GameBoard/CombatSystem")
	battle_manager = get_node_or_null("/root/GameBoard/BattleManager")
	
	# Setup UI elements
	create_debug_ui()
	
	# Wait until next frame to properly get viewport size
	await get_tree().process_frame
	
	# Update panel position
	var panel = get_node_or_null("DebugPanel")
	if panel:
		panel.position = Vector2(get_viewport().size.x - 300, 10)

func create_debug_ui():
	# Create debug panel on the right side
	var panel = Panel.new()
	panel.name = "DebugPanel"
	panel.position = Vector2(get_viewport().size.x - 300, 10)  # Position on right side
	panel.size = Vector2(250, 150)  # Larger panel
	add_child(panel)
	
	# Create toggle pathfinding button
	var toggle_button = Button.new()
	toggle_button.name = "TogglePathfindingButton"
	toggle_button.text = "Toggle Pathfinding Debug"
	toggle_button.position = Vector2(10, 10)
	toggle_button.size = Vector2(180, 30)
	toggle_button.pressed.connect(_on_toggle_pathfinding)
	panel.add_child(toggle_button)
	
	# Create manual battle trigger button (for testing)
	var battle_button = Button.new()
	battle_button.name = "ManualBattleButton"
	battle_button.text = "Simulate One Combat Tick"
	battle_button.position = Vector2(10, 50)
	battle_button.size = Vector2(180, 30)
	battle_button.pressed.connect(_on_manual_battle_tick)
	panel.add_child(battle_button)
	
	# Add debug move speed slider
	var speed_label = Label.new()
	speed_label.text = "Move Speed:"
	speed_label.position = Vector2(10, 90)
	panel.add_child(speed_label)
	
	var speed_slider = HSlider.new()
	speed_slider.name = "MoveSpeedSlider"
	speed_slider.min_value = 0.5
	speed_slider.max_value = 10.0
	speed_slider.step = 0.5
	speed_slider.value = 2.0
	speed_slider.position = Vector2(10, 110)
	speed_slider.size = Vector2(180, 20)
	speed_slider.value_changed.connect(_on_move_speed_changed)
	panel.add_child(speed_slider)

func _on_toggle_pathfinding():
	if combat_system:
		var new_state = !combat_system.debug_pathfinding
		combat_system.set_debug_pathfinding(new_state)

func _on_manual_battle_tick():
	if combat_system:
		if combat_system.combat_active:
			combat_system.manual_tick()
		else:
			# If combat isn't active, start a test battle
			if battle_manager:
				battle_manager.start_battle()

func _on_move_speed_changed(value):
	# Update all units' move speed
	if combat_system:
		print("Setting move speed to: " + str(value))
		for unit in combat_system.player_units + combat_system.enemy_units:
			unit.move_speed = value
