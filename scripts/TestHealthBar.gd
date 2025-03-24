extends Node

# A simple script to test the health bar system
# Attach this to any node in your scene to test with keyboard inputs

# References
var selected_unit: Node = null
var units = []

func _ready():
	# Wait for everything to be set up
	await get_tree().process_frame
	
	# Find all units in the scene
	find_units()
	
	print("Health bar test script ready. Press:")
	print("  1-5: Select different units")
	print("  H: Take 10 damage")
	print("  J: Heal 10 health")
	print("  M: Add 20 mana")
	print("  N: Use 25 mana")

func find_units():
	units.clear()
	var board = get_node_or_null("/root/GameBoard")
	if board:
		# Find all BaseCharacter children
		for child in board.get_children():
			if "character_data" in child:
				units.append(child)
	
	print("Found ", units.size(), " units for testing")
	
	# Select the first unit if available
	if units.size() > 0:
		select_unit(units[0])

func select_unit(unit):
	selected_unit = unit
	if selected_unit and "character_data" in selected_unit and selected_unit.character_data:
		print("Selected: ", selected_unit.character_data.display_name)
	else:
		print("Selected unit (no name available)")

func _input(event):
	if event is InputEventKey and event.pressed:
		# Unit selection with number keys
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			var index = event.keycode - KEY_1
			if index < units.size():
				select_unit(units[index])
		
		# Health and mana actions
		if selected_unit:
			match event.keycode:
				KEY_H:  # Take damage
					print("Taking 10 damage")
					selected_unit.take_damage(10)
				
				KEY_J:  # Heal
					print("Healing 10 health")
					selected_unit.heal(10)
				
				KEY_M:  # Add mana
					print("Adding 20 mana")
					selected_unit.add_mana(20)
				
				KEY_N:  # Use mana
					print("Using 25 mana")
					var success = selected_unit.use_mana(25)
					print("Mana use successful: ", success)
