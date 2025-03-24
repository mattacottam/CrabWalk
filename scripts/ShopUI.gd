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

# UI elements
var reroll_button: Button
var not_enough_gold_label: Label

# Signals
signal character_purchased(character)

func _ready():
	# Set this control to PASS to allow clicks to reach children
	mouse_filter = Control.MOUSE_FILTER_PASS
	print("ShopUI mouse_filter set to PASS")
	
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
	
	# Find UI elements with more robust search
	reroll_button = find_node_by_name("RerollButton")
	
	# Use the central message label instead of a local one
	not_enough_gold_label = get_node_or_null("/root/GameBoard/MessageLayer/CentralMessageLabel")
	if not not_enough_gold_label:
		# The PlayerUI will create this, but if it doesn't exist yet we'll look for it later
		print("Central message label not found, will use it if created later")
	
	print("ShopUI elements found:")
	print("- reroll_button: ", reroll_button != null)
	print("- not_enough_gold_label: ", not_enough_gold_label != null)
	
	# Connect to player signals if available
	if player:
		player.not_enough_gold.connect(_on_not_enough_gold)
	
	# Configure mouse filters properly
	_configure_mouse_filters()
	
	# Set up shop slots
	setup_shop_slots()
	
	# Initial shop roll
	roll_shop()
	
	# Connect reroll button if present
	if reroll_button and not reroll_button.pressed.is_connected(_on_reroll_button_pressed):
		reroll_button.pressed.connect(_on_reroll_button_pressed)
		print("Connected reroll button")

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

# Handle not enough gold signal
func _on_not_enough_gold():
	print("ShopUI: Not enough gold!")
	
	# Try to find the central message label if we don't have it yet
	if not not_enough_gold_label:
		not_enough_gold_label = get_node_or_null("/root/GameBoard/MessageLayer/CentralMessageLabel")
	
	if not_enough_gold_label:
		not_enough_gold_label.visible = true
		
		# Hide after delay
		var timer = get_tree().create_timer(1.5)
		await timer.timeout
		
		if is_instance_valid(not_enough_gold_label):
			not_enough_gold_label.visible = false

# Configure mouse filters for all controls
func _configure_mouse_filters():
	# The main control passes mouse events
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Any containers should pass mouse events
	for child in get_children():
		if child is Control and not child is Button:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
			print("Set Control to PASS: ", child.name)
			
			# Check nested controls
			for subchild in child.get_children():
				if subchild is Control and not subchild is Button:
					subchild.mouse_filter = Control.MOUSE_FILTER_PASS
					print("Set nested Control to PASS: ", subchild.name)
		
		# Buttons should stop mouse events
		if child is Button:
			child.mouse_filter = Control.MOUSE_FILTER_STOP
			child.focus_mode = Control.FOCUS_ALL
			child.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			print("Set Button to STOP: ", child.name)

# Set up the shop slot buttons
func setup_shop_slots():
	var slot_container = find_node_by_name("ShopSlots")
	if not slot_container:
		slot_container = find_node_by_name("ShopContainer")
		if not slot_container:
			push_error("ShopUI: Could not find ShopSlots or ShopContainer")
			return
	
	# Set container to pass mouse events
	if slot_container is Control:
		slot_container.mouse_filter = Control.MOUSE_FILTER_PASS
		print("Set shop slots container to PASS: ", slot_container.name)
	
	# Find shop slot buttons by pattern matching
	shop_slots.clear()
	
	# Try to find ShopSlot buttons directly
	for i in range(NUM_SHOP_SLOTS):
		var slot_name = "ShopSlot" + str(i+1)
		var slot = find_node_by_name(slot_name)
		
		if slot and slot is Button:
			shop_slots.append(slot)
			
			# Configure the button
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.focus_mode = Control.FOCUS_ALL
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
			# Make sure the pressed signal is connected
			if not slot.pressed.is_connected(_on_shop_slot_pressed.bind(i)):
				slot.pressed.connect(_on_shop_slot_pressed.bind(i))
			
			print("Configured shop slot: ", slot.name, " with index ", i)
	
	# If we couldn't find any buttons by name, look for all buttons in the container
	if shop_slots.size() == 0 and slot_container:
		var found_buttons = []
		find_all_buttons(slot_container, found_buttons)
		
		for i in range(min(found_buttons.size(), NUM_SHOP_SLOTS)):
			var slot = found_buttons[i]
			shop_slots.append(slot)
			
			# Configure the button
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.focus_mode = Control.FOCUS_ALL
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
			# Make sure the pressed signal is connected
			if not slot.pressed.is_connected(_on_shop_slot_pressed.bind(i)):
				slot.pressed.connect(_on_shop_slot_pressed.bind(i))
			
			print("Found button and configured as shop slot: ", slot.name, " with index ", i)
	
	print("Found ", shop_slots.size(), " shop slot buttons")

# Find all buttons in a container and its children
func find_all_buttons(parent: Node, result: Array):
	for child in parent.get_children():
		if child is Button:
			result.append(child)
		
		if child.get_child_count() > 0:
			find_all_buttons(child, result)

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
	print("Shop rolled with ", current_shop_options.size(), " characters")

# Update shop display with current options
func update_shop_display():
	for i in range(shop_slots.size()):
		var slot = shop_slots[i]
		
		if i < current_shop_options.size():
			var char_id = current_shop_options[i]
			if char_id.is_empty():
				# Empty slot
				display_empty_slot(slot)
				continue
				
			var character = character_database.get_character(char_id)
			
			if character:
				# Update button with character info
				slot.text = character.display_name
				
				# Set cost
				var cost_label = slot.get_node_or_null("CostLabel")
				if cost_label:
					cost_label.text = str(character.cost) + "g"
				
				# Set color based on character's rarity
				var color = character.get_rarity_color()
				
				# Get each style individually and set its color
				update_button_style(slot, "normal", color.darkened(0.7))
				update_button_style(slot, "hover", color.darkened(0.5))
				update_button_style(slot, "pressed", color.darkened(0.3))
				
				# Add portrait if available
				var portrait_node = slot.get_node_or_null("Portrait")
				if portrait_node and portrait_node is TextureRect:
					# Try to load portrait by character ID
					var portrait_path = "res://resources/portraits/" + character.id + ".svg"
					var portrait = load(portrait_path)
					if portrait:
						portrait_node.texture = portrait
						portrait_node.visible = true
					else:
						portrait_node.visible = false
				
				# Enable button
				slot.disabled = false
			else:
				# Empty slot if no character
				display_empty_slot(slot)
		else:
			# Empty slot
			display_empty_slot(slot)

# Helper function to display an empty slot
func display_empty_slot(slot: Button):
	slot.text = "Empty"
	slot.disabled = true
	
	# Clear style
	update_button_style(slot, "normal", Color(0.2, 0.2, 0.2, 0.8))
	update_button_style(slot, "hover", Color(0.3, 0.3, 0.3, 0.8))
	update_button_style(slot, "pressed", Color(0.4, 0.4, 0.4, 0.8))
	
	# Hide portrait if applicable
	var portrait_node = slot.get_node_or_null("Portrait")
	if portrait_node:
		portrait_node.visible = false

# Helper function to update button style safely
func update_button_style(button: Button, style_name: String, color: Color):
	var style = button.get_theme_stylebox(style_name)
	if style:
		# We need to create a unique copy of the style to avoid affecting other buttons
		var style_copy = style.duplicate()
		style_copy.bg_color = color
		button.add_theme_stylebox_override(style_name, style_copy)

# Handle shop slot button press
func _on_shop_slot_pressed(slot_index):
	print("Shop slot pressed: ", slot_index)
	purchase_character(slot_index)

# Purchase a character by slot index
func purchase_character(slot_index):
	print("ShopUI.purchase_character called for index: ", slot_index)
	
	if not character_database or not player or not board:
		push_error("Missing dependencies in purchase_character")
		return
	
	if slot_index < current_shop_options.size():
		var char_id = current_shop_options[slot_index]
		if char_id.is_empty():
			return  # Empty slot
			
		var character = character_database.get_character(char_id)
		
		if character:
			# Try to purchase (deduct gold)
			if player.pay_for_character(character):
				print("Character purchased: ", character.display_name)
				
				# Mark the slot as empty but keep its position
				current_shop_options[slot_index] = ""
				update_shop_display()
				
				# Spawn character on bench
				spawn_character_on_bench(character)
				
				# Emit purchase signal
				emit_signal("character_purchased", character)
			# Note: The error message is now handled by the not_enough_gold signal
		else:
			print("Invalid character data")
	else:
		print("Invalid slot index: ", slot_index)

# Spawn purchased character on the bench
func spawn_character_on_bench(character_data):
	if not board:
		push_error("Cannot spawn character: board reference is null")
		return
	
	# Find the first unoccupied bench tile
	for i in range(board.BENCH_SPACES):
		var tile_key = "bench_%d" % i
		var tile = board.tiles.get(tile_key)
		
		if tile and not tile.is_occupied():
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

# Handle reroll button press
func _on_reroll_button_pressed():
	print("Reroll button pressed")
	if player and player.pay_reroll():
		roll_shop()
	# Note: Error message for not enough gold is now handled by the not_enough_gold signal

# Manual connection for debugging
func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_viewport().get_mouse_position()
		
		# Check shop slots
		for i in range(shop_slots.size()):
			var slot = shop_slots[i]
			if slot and slot.get_global_rect().has_point(mouse_pos) and not slot.disabled:
				print("Shop slot area clicked: ", i)
				purchase_character(i)
				return
				
		# Check reroll button
		if reroll_button and reroll_button.get_global_rect().has_point(mouse_pos):
			print("Reroll button area clicked!")
			_on_reroll_button_pressed()
