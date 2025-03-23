extends MeshInstance3D

signal tile_clicked(tile)

# Properties
var occupied = false
var occupant = null
var occupying_unit = null
var highlight_color = Color(1.0, 1.0, 0.0, 0.5)  # Yellow highlight
var hover_color = Color(1.0, 1.0, 1.0, 1.0)  # White for hover effect
var valid_placement_color = Color(0.0, 1.0, 0.0, 0.5)  # Green
var invalid_placement_color = Color(1.0, 0.0, 0.0, 0.5)  # Red
var original_color = Color.WHITE
var is_highlighted = false
var is_hovered = false

# Reference to the material
var material = null

func _ready():
	# Create a unique material for this instance if needed
	if not material_override:
		material = StandardMaterial3D.new()
		material_override = material
	else:
		material = material_override
	
	# Store the original color for later restoration
	original_color = get_meta("color", Color.WHITE)
	material.albedo_color = original_color
	
	# Make sure we have a proper collision setup
	var static_body = get_node_or_null("StaticBody3D")
	if static_body:
		# Check if the signal is already connected to avoid errors
		if not static_body.input_event.is_connected(_on_input_event):
			static_body.input_event.connect(_on_input_event)
		
		# Connect mouse tracking signals
		if not static_body.mouse_entered.is_connected(_on_mouse_entered):
			static_body.mouse_entered.connect(_on_mouse_entered)
		
		if not static_body.mouse_exited.is_connected(_on_mouse_exited):
			static_body.mouse_exited.connect(_on_mouse_exited)
	else:
		# If no StaticBody3D exists, create one
		static_body = StaticBody3D.new()
		add_child(static_body)
		
		# Add collision shape if needed
		if static_body.get_child_count() == 0:
			var collision_shape = CollisionShape3D.new()
			var shape = CylinderShape3D.new()
			shape.radius = 1.0  # Match HEX_SIZE
			shape.height = 0.1  # Match HEX_HEIGHT
			collision_shape.shape = shape
			static_body.add_child(collision_shape)
		
		# Connect the signals
		static_body.input_event.connect(_on_input_event)
		static_body.mouse_entered.connect(_on_mouse_entered)
		static_body.mouse_exited.connect(_on_mouse_exited)

# Handle mouse hover enter
func _on_mouse_entered():
	if not is_highlighted:  # Only apply hover effect if not already highlighted
		is_hovered = true
		
		# Create a subtle brightness increase for hover
		var hover_effect_color = original_color.lightened(0.2)
		material.albedo_color = hover_effect_color
		
		# Add some emission for a glowing effect
		material.emission_enabled = true
		material.emission = hover_effect_color
		material.emission_energy_multiplier = 0.3

# Handle mouse hover exit
func _on_mouse_exited():
	is_hovered = false
	
	# If not highlighted, restore original appearance
	if not is_highlighted:
		material.albedo_color = original_color
		material.emission_enabled = false

# Handle mouse interaction
func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("tile_clicked", self)
		print("Tile clicked: ", get_meta("zone"), " Row: ", get_meta("row", -1), " Col: ", get_meta("col", -1))
		
		# Change color on click (not hover)
		toggle_highlight()

# Regular highlight (yellow)
func highlight():
	is_highlighted = true
	
	# Apply a bright highlight color
	material.albedo_color = highlight_color
	
	# Add emission for a stronger effect
	material.emission_enabled = true
	material.emission = highlight_color
	material.emission_energy_multiplier = 0.5

# Highlight for valid placement (green)
func highlight_valid():
	is_highlighted = true
	
	# Apply valid placement color
	material.albedo_color = valid_placement_color
	
	# Add emission for a stronger effect
	material.emission_enabled = true
	material.emission = valid_placement_color
	material.emission_energy_multiplier = 0.5

# Highlight for invalid placement (red)
func highlight_invalid():
	is_highlighted = true
	
	# Apply invalid placement color
	material.albedo_color = invalid_placement_color
	
	# Add emission for a stronger effect
	material.emission_enabled = true
	material.emission = invalid_placement_color
	material.emission_energy_multiplier = 0.5

# Reset to original color
func reset_highlight():
	is_highlighted = false
	
	# If currently hovered, show hover effect
	if is_hovered:
		var hover_effect_color = original_color.lightened(0.2)
		material.albedo_color = hover_effect_color
		material.emission_enabled = true
		material.emission = hover_effect_color
		material.emission_energy_multiplier = 0.3
	else:
		# Otherwise restore to original
		material.albedo_color = original_color
		material.emission_enabled = false

# Toggle highlight for debugging
func toggle_highlight():
	if is_highlighted:
		reset_highlight()
	else:
		highlight()

# Get center position of this tile
func get_center_position():
	return global_position + Vector3(0, 0.1, 0)  # Slight y offset

# Check if tile is occupied
func is_occupied():
	return occupying_unit != null

# Get the unit on this tile
func get_occupying_unit():
	return occupying_unit

# Set the unit on this tile
func set_occupying_unit(unit):
	occupying_unit = unit
	occupied = (unit != null)
