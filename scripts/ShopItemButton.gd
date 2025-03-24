extends Button

func _ready():
	# Set mouse filter to stop (capture clicks)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Make sure button is enabled and visible
	disabled = false
	visible = true
	
	# Enable focus and make it look clickable
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Check if pressed signal is connected
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	
	print("Shop item button ready: ", name)

func _on_pressed():
	print("Shop item clicked: ", name, " with index: ", get_index())
	
	# Try direct signal to the parent
	var parent = get_parent()
	if parent and parent.has_method("_on_shop_slot_pressed"):
		parent._on_shop_slot_pressed(get_index())
		return
	
	# Find the ShopUI in the scene tree
	var shop = find_shop_ui()
	
	if shop and shop.has_method("purchase_character"):
		var index = get_index()
		shop.purchase_character(index)
		print("Purchasing character at index: ", index)
	else:
		print("Could not find shop or purchase_character method")

# Find the ShopUI node in the scene tree
func find_shop_ui():
	# First try to find it directly from the parent
	var parent = get_parent()
	while parent:
		if parent.has_method("purchase_character"):
			return parent
		parent = parent.get_parent()
	
	# If not found in parent hierarchy, try to find it in the scene
	return get_node("/root/GameBoard/CanvasLayer/ShopUI")

# Implement direct input handling as backup
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Direct mouse click on button: ", name)
		_on_pressed()
		get_viewport().set_input_as_handled()
