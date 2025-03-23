extends Button

func _ready():
	# Set mouse filter to stop (capture clicks)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Make sure button is enabled and visible
	disabled = false
	visible = true
	
	# Check if pressed signal is connected
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	
	print("Shop item button ready: ", name)

func _on_pressed():
	print("Shop item clicked: ", name)
	# Call the appropriate method in your shop system
	var shop = get_parent()
	while shop and not shop.has_method("purchase_character"):
		shop = shop.get_parent()
	
	if shop and shop.has_method("purchase_character"):
		var index = get_index()
		shop.purchase_character(index)
		print("Purchasing character at index: ", index)
