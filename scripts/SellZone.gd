extends Area3D

# References
var player: Node
var camera: Camera3D

# Visual properties
var default_color: Color = Color(0.8, 0.1, 0.1, 0.5)  # Red semi-transparent
var highlight_color: Color = Color(1.0, 0.3, 0.3, 0.7)  # Brighter red when unit is over

# UI elements
var sell_label: Label3D

func _ready():
	camera = get_viewport().get_camera_3d()
	player = get_node_or_null("/root/GameBoard/Player")
	
	if not player:
		push_error("SellZone: Could not find Player node")
	
	# Set up visual representation (mesh)
	var mesh_instance = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 2.0
	cylinder.bottom_radius = 2.0
	cylinder.height = 0.1
	mesh_instance.mesh = cylinder
	add_child(mesh_instance)
	
	# Create material
	var material = StandardMaterial3D.new()
	material.albedo_color = default_color
	material.emission_enabled = true
	material.emission = default_color
	material.emission_energy_multiplier = 0.3
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	
	# Add 3D text label
	sell_label = Label3D.new()
	sell_label.text = "SELL"
	sell_label.font_size = 128
	sell_label.position = Vector3(0, 1, 0)
	sell_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sell_label)
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# When a unit enters the sell zone
func _on_body_entered(body):
	if body.is_dragging and body.has_method("get_character_data"):
		# Highlight the sell zone
		highlight()

# When a unit exits the sell zone
func _on_body_exited(_body):
	# Return to default appearance
	reset_highlight()

# Handle unit dropping in the sell zone
func handle_unit_drop(unit) -> bool:
	# Only sell if we have a player reference
	if player and unit.has_method("get_character_data"):
		var character_data = unit.get_character_data()
		if character_data:
			# Sell the character and get gold
			player.sell_character(character_data)
			
			# Play sell effect
			play_sell_effect()
			
			# Reset visual state
			reset_highlight()
			return true
	
	return false

# Play a visual effect when selling
func play_sell_effect():
	# Flash the sell zone
	var material = get_child(0).material_override
	var original_emission = material.emission
	var original_energy = material.emission_energy_multiplier
	
	material.emission = Color(1, 1, 1, 1)
	material.emission_energy_multiplier = 1.0
	
	# Reset after a short time
	await get_tree().create_timer(0.3).timeout
	
	material.emission = original_emission
	material.emission_energy_multiplier = original_energy

# Highlight the sell zone
func highlight():
	var material = get_child(0).material_override
	material.albedo_color = highlight_color
	material.emission = highlight_color
	material.emission_energy_multiplier = 0.5

# Reset highlight
func reset_highlight():
	var material = get_child(0).material_override
	material.albedo_color = default_color
	material.emission = default_color
	material.emission_energy_multiplier = 0.3
