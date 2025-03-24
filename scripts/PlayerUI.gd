extends Control

# UI element references
var gold_label: Label
var level_label: Label
var xp_bar: ProgressBar
var health_bar: ProgressBar
var health_label: Label
var buy_xp_button: Button
var reroll_button: Button
var not_enough_gold_label: Label

# Reference to player data
var player: Node
var shop: Node

func _ready():
	# Set this control to PASS instead of STOP to allow clicks to reach children
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Find all UI elements
	gold_label = get_node_or_null("GoldContainer/GoldLabel")
	level_label = get_node_or_null("LevelContainer/LevelLabel")
	xp_bar = get_node_or_null("LevelContainer/XPBar")
	health_bar = get_node_or_null("HealthContainer/HealthBar")
	health_label = get_node_or_null("HealthContainer/HealthLabel")
	
	# Find buttons - try multiple potential paths
	buy_xp_button = find_node_by_name("BuyXPButton")
	reroll_button = find_node_by_name("RerollButton")
	
	# We'll use a central error message only
	not_enough_gold_label = get_node_or_null("/root/GameBoard/CentralMessageLabel")
	if not not_enough_gold_label:
		not_enough_gold_label = create_central_message_label()
		
	# Print found UI elements for debugging
	print("PlayerUI elements found:")
	print("- gold_label: ", gold_label != null)
	print("- level_label: ", level_label != null)
	print("- xp_bar: ", xp_bar != null)
	print("- health_bar: ", health_bar != null)
	print("- health_label: ", health_label != null)
	print("- buy_xp_button: ", buy_xp_button != null)
	print("- reroll_button: ", reroll_button != null)
	print("- not_enough_gold_label: ", not_enough_gold_label != null)
	
	# Configure child controls
	for child in get_children():
		if child is Button:
			# Buttons should STOP to capture their clicks
			child.mouse_filter = Control.MOUSE_FILTER_STOP
			print("Button mouse filter set to STOP: ", child.name)
		elif child is Control:
			# Container controls should PASS to allow clicks to reach their children
			child.mouse_filter = Control.MOUSE_FILTER_PASS
			print("Control mouse filter set to PASS: ", child.name)
			
			# Configure any nested buttons
			for subchild in child.get_children():
				if subchild is Button:
					subchild.mouse_filter = Control.MOUSE_FILTER_STOP
					print("Nested button mouse filter set to STOP: ", subchild.name)
	
	# Find the player node correctly
	player = get_node_or_null("/root/GameBoard/Player")
	
	# Find the shop
	shop = get_node_or_null("/root/GameBoard/CanvasLayer/ShopUI")
	
	if player:
		# Connect to player signals
		player.gold_changed.connect(_on_gold_changed)
		player.level_changed.connect(_on_level_changed)
		player.xp_changed.connect(_on_xp_changed)
		player.health_changed.connect(_on_health_changed)
		player.not_enough_gold.connect(_on_not_enough_gold)
		
		# Initialize UI with current values
		_on_gold_changed(player.gold)
		_on_level_changed(player.level)
		_on_xp_changed(player.xp, player.get_required_xp())
		_on_health_changed(player.health)
		
		print("PlayerUI: Connected to player signals")
	else:
		push_error("PlayerUI: Could not find Player node")
	
	# Connect button signals
	_connect_buttons()

# Create a central message label that will be used by all UI elements
func create_central_message_label() -> Label:
	var game_board = get_node("/root/GameBoard")
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "MessageLayer"
	canvas_layer.layer = 10 # Make sure it's on top
	game_board.add_child.call_deferred(canvas_layer)
	
	var label = Label.new()
	label.name = "CentralMessageLabel"
	label.text = "Not enough gold!"
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Reddish color
	label.add_theme_font_size_override("font_size", 24)  # Larger text
	
	# Set size and position
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(300, 60)
	label.position = Vector2((get_viewport().get_visible_rect().size.x - 300) / 2, 
							 (get_viewport().get_visible_rect().size.y - 60) / 2)
	
	# Initially hidden
	label.visible = false
	
	canvas_layer.add_child(label)
	return label

# Recursively find a node by name in the scene
func find_node_by_name(node_name: String) -> Node:
	# First try direct child
	var node = get_node_or_null(node_name)
	if node:
		return node
	
	# Then try searching all children recursively
	for child in get_children():
		if child.name == node_name:
			return child
		
		# If this child has children, check them too
		if child.get_child_count() > 0:
			var found = find_node_in_children(child, node_name)
			if found:
				return found
	
	# Not found
	return null

# Helper to recursively search children
func find_node_in_children(parent: Node, node_name: String) -> Node:
	for child in parent.get_children():
		if child.name == node_name:
			return child
		
		# Recursively check this child's children
		if child.get_child_count() > 0:
			var found = find_node_in_children(child, node_name)
			if found:
				return found
	
	return null

func _connect_buttons():
	# Connect buy XP button
	if buy_xp_button:
		if not buy_xp_button.pressed.is_connected(_on_buy_xp_button_pressed):
			buy_xp_button.pressed.connect(_on_buy_xp_button_pressed)
			print("Connected Buy XP button")
		
		# Make sure the button is clickable
		buy_xp_button.focus_mode = Control.FOCUS_ALL
		buy_xp_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		print("PlayerUI: Could not find BuyXPButton - buttons won't be functional")
	
	# Connect reroll button
	if reroll_button:
		if not reroll_button.pressed.is_connected(_on_reroll_button_pressed):
			reroll_button.pressed.connect(_on_reroll_button_pressed)
			print("Connected Reroll button")
		
		# Make sure the button is clickable
		reroll_button.focus_mode = Control.FOCUS_ALL
		reroll_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		print("PlayerUI: Could not find RerollButton - buttons won't be functional")

# Update gold display
func _on_gold_changed(new_amount: int):
	if gold_label:
		gold_label.text = str(new_amount)

# Update level display
func _on_level_changed(new_level: int):
	if level_label:
		level_label.text = str(new_level)

# Update XP progress bar
func _on_xp_changed(new_xp: int, required_xp: int):
	if xp_bar:
		xp_bar.max_value = required_xp
		xp_bar.value = new_xp

# Update health display
func _on_health_changed(new_health: int):
	if health_bar:
		health_bar.value = new_health
	
	if health_label:
		health_label.text = str(new_health) + "/100"

# Handle not enough gold signal
func _on_not_enough_gold():
	print("Not enough gold!")
	if not_enough_gold_label:
		not_enough_gold_label.visible = true
		
		# Hide after delay
		var timer = get_tree().create_timer(1.5)
		await timer.timeout
		
		if is_instance_valid(not_enough_gold_label):
			not_enough_gold_label.visible = false

# Buy XP button pressed
func _on_buy_xp_button_pressed():
	print("Buy XP button pressed")
	if player:
		var success = player.buy_xp()
		print("Buy XP result: ", success)

# Reroll shop button pressed
func _on_reroll_button_pressed():
	print("Reroll button pressed in PlayerUI")
	if player:
		var success = player.pay_reroll()
		print("Reroll payment result: ", success)
		
		if success and shop:
			shop.roll_shop()
			
# Manual connection for debugging
func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_viewport().get_mouse_position()
		#print("Mouse click detected at: ", mouse_pos)
		
		# Check if buttons exist and if they were clicked
		if buy_xp_button and buy_xp_button.get_global_rect().has_point(mouse_pos):
			print("Buy XP button area clicked!")
			_on_buy_xp_button_pressed()
			
		if reroll_button and reroll_button.get_global_rect().has_point(mouse_pos):
			print("Reroll button area clicked!")
			_on_reroll_button_pressed()
