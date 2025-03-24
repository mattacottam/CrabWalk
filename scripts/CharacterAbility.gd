extends Node
class_name CharacterAbility

# Reference to the character who owns this ability
var character: Node3D

# Ability state
var cooldown_remaining: float = 0
var mana: float = 0
var is_casting: bool = false
var casting_time_remaining: float = 0

# Ability stats from character_data
var ability_name: String = ""
var ability_description: String = ""
var ability_damage: int = 0
var ability_mana_cost: int = 0

# Visual effects
var casting_effect: Node3D
var ability_range_indicator: Node3D

# Constructor
func _init(owner_character: Node3D):
	character = owner_character
	
	# Read ability stats from character data
	if character.character_data:
		ability_name = character.character_data.ability_name
		ability_description = character.character_data.ability_description
		ability_damage = character.character_data.ability_damage
		ability_mana_cost = character.character_data.ability_mana_cost
		mana = 0  # Start with 0 mana

# Called each frame
func process(delta: float):
	# Reduce cooldown if needed
	if cooldown_remaining > 0:
		cooldown_remaining -= delta
	
	# Process casting time
	if is_casting:
		casting_time_remaining -= delta
		if casting_time_remaining <= 0:
			finish_casting()
	
	# Generate mana over time if not on cooldown
	if cooldown_remaining <= 0 and not is_casting:
		mana += delta * 10  # Basic mana generation rate
		
		# Cap mana at max
		if character.character_data:
			mana = min(mana, character.character_data.mana_max)
		
		# Try to cast if we have enough mana
		if mana >= ability_mana_cost:
			start_casting()

# Start casting the ability
func start_casting():
	if is_casting or cooldown_remaining > 0:
		return
		
	is_casting = true
	casting_time_remaining = 0.5  # 0.5 second cast time
	
	# Create casting effect
	create_casting_effect()
	
	print(character.character_data.display_name + " is casting " + ability_name)

# Called when ability finishes casting
func finish_casting():
	is_casting = false
	mana -= ability_mana_cost
	cooldown_remaining = 5.0  # 5 second cooldown
	
	# Perform the effect based on character type
	execute_ability()
	
	# Remove casting effect
	if casting_effect:
		casting_effect.queue_free()
		casting_effect = null
	
	print(character.character_data.display_name + " used " + ability_name)

# Execute the ability effect based on character type
func execute_ability():
	if not character or not character.character_data:
		return
		
	var char_id = character.character_data.id
	
	match char_id:
		"warrior":
			warrior_ability()
		"archer":
			archer_ability()
		"mage":
			mage_ability()
		"tank":
			tank_ability()
		"assassin":
			assassin_ability()
		"berserker":
			berserker_ability()
		"healer":
			healer_ability()
		"knight":
			knight_ability()
		"druid":
			druid_ability()
		_:
			# Generic ability if no specific one found
			generic_ability()

# Create a visual effect for casting
func create_casting_effect():
	casting_effect = MeshInstance3D.new()
	
	# Create a simple sphere for the effect
	var sphere = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	casting_effect.mesh = sphere
	
	# Create material with emission
	var material = StandardMaterial3D.new()
	material.emission_enabled = true
	
	# Set color based on character type
	if character.character_data:
		var base_color = character.character_data.color
		material.emission = base_color
		material.albedo_color = base_color
	else:
		material.emission = Color(1, 1, 0)  # Default yellow
		
	material.emission_energy_multiplier = 2.0
	casting_effect.material_override = material
	
	# Position above character
	casting_effect.position = Vector3(0, 2.2, 0)
	
	# Add to character
	character.add_child(casting_effect)
	
	# Animate the effect
	var tween = character.create_tween()
	tween.tween_property(casting_effect, "scale", Vector3(1.5, 1.5, 1.5), 0.5)
	tween.tween_property(casting_effect, "scale", Vector3(0.8, 0.8, 0.8), 0.2)

# ----- ABILITY IMPLEMENTATIONS -----

func warrior_ability():
	# Battle Cry: Increases armor for nearby allies for 5 seconds
	var allies = get_nearby_allies(3.0)  # 3 unit radius
	
	for ally in allies:
		# Apply armor buff
		apply_armor_buff(ally, 10, 5.0)  # +10 armor for 5 seconds
	
	# Create visual effect
	create_aoe_effect(Color(0.8, 0.8, 0.2), 3.0)  # Yellow aura

func archer_ability():
	# Aimed Shot: Deals high damage to the furthest enemy
	var target = get_furthest_enemy(10.0)  # 10 unit range
	
	if target:
		deal_damage(target, ability_damage * 2)  # Double damage
		
		# Create arrow effect
		create_projectile_effect(target.global_position, Color(0.0, 0.8, 0.2))

func mage_ability():
	# Fireball: Area damage to enemies
	var enemies = get_nearby_enemies(4.0)  # 4 unit radius
	
	for enemy in enemies:
		deal_damage(enemy, ability_damage)
	
	# Create explosion effect
	create_aoe_effect(Color(1.0, 0.5, 0.0), 4.0)  # Orange explosion

func tank_ability():
	# Taunt: Forces nearby enemies to attack this unit
	var enemies = get_nearby_enemies(3.0)  # 3 unit radius
	
	for enemy in enemies:
		taunt_enemy(enemy, 4.0)  # 4 second taunt
	
	# Create taunt effect
	create_aoe_effect(Color(1.0, 0.0, 0.0), 3.0, 2.0)  # Red pulse

func assassin_ability():
	# Backstab: High damage to lowest health enemy
	var target = get_lowest_health_enemy(3.0)  # 3 unit radius
	
	if target:
		deal_damage(target, ability_damage * 2.5)  # 2.5x damage
		
		# Create teleport effect
		create_teleport_effect(target.global_position)

func berserker_ability():
	# Blood Frenzy: Gains attack speed based on missing health
	var health_percent = 0
	
	if character.character_data:
		var max_health = character.character_data.health
		var current_health = max_health  # We need to track actual health
		
		# For now assume 50% health
		current_health = max_health * 0.5
		health_percent = 1.0 - (current_health / max_health)
	else:
		health_percent = 0.5  # Default 50% if no data
	
	# Apply attack speed buff based on missing health
	var attack_speed_buff = health_percent * 100  # Up to 100% at 0 health
	apply_attack_speed_buff(character, attack_speed_buff, 5.0)  # 5 second buff
	
	# Create rage effect
	create_self_buff_effect(Color(1.0, 0.0, 0.0))  # Red rage

func healer_ability():
	# Healing Light: Heal lowest health ally
	var target = get_lowest_health_ally(4.0)  # 4 unit radius
	
	if target:
		heal_target(target, abs(ability_damage))  # Using absolute value of damage
		
		# Create healing effect
		create_healing_effect(target.global_position)

func knight_ability():
	# Shield Wall: Damage barrier for nearby allies
	var allies = get_nearby_allies(3.0)  # 3 unit radius
	
	for ally in allies:
		apply_shield(ally, 50, 6.0)  # 50 damage shield for 6 seconds
	
	# Create shield effect
	create_aoe_effect(Color(0.7, 0.7, 0.9), 3.0)  # Blue shield

func druid_ability():
	# Entangling Roots: Immobilize enemies
	var enemies = get_nearby_enemies(3.5)  # 3.5 unit radius
	
	for enemy in enemies:
		immobilize_target(enemy, 3.0)  # 3 second immobilize
	
	# Create nature effect
	create_aoe_effect(Color(0.0, 0.8, 0.3), 3.5)  # Green entangle

func generic_ability():
	# Generic ability - just deal damage to nearest enemy
	var target = get_nearest_enemy(3.0)
	
	if target:
		deal_damage(target, ability_damage)
		
		# Generic effect
		create_aoe_effect(Color(0.5, 0.5, 0.5), 2.0)

# ----- UTILITY FUNCTIONS -----

# Get nearby allies within radius
func get_nearby_allies(radius: float) -> Array:
	# This is a placeholder - in a real game, you'd search for actual allies
	var allies = []
	
	# In this demo, we'll just return empty array
	# You would find allies by doing spatial queries or checking all characters
	
	return allies

# Get nearby enemies within radius
func get_nearby_enemies(radius: float) -> Array:
	# This is a placeholder - in a real game, you'd search for actual enemies
	var enemies = []
	
	# In this demo, we'll just return empty array
	# You would find enemies by doing spatial queries or checking all characters
	
	return enemies

# Get the nearest enemy within range
func get_nearest_enemy(max_range: float):
	# Placeholder
	return null

# Get the furthest enemy within range
func get_furthest_enemy(max_range: float):
	# Placeholder
	return null

# Get the enemy with lowest health
func get_lowest_health_enemy(max_range: float):
	# Placeholder
	return null

# Get the ally with lowest health
func get_lowest_health_ally(max_range: float):
	# Placeholder
	return null

# Deal damage to a target
func deal_damage(target, amount: int):
	# Placeholder - would integrate with health system
	print("Dealing " + str(amount) + " damage to target")

# Heal a target
func heal_target(target, amount: int):
	# Placeholder - would integrate with health system
	print("Healing target for " + str(amount) + " health")

# Apply armor buff to a target
func apply_armor_buff(target, amount: int, duration: float):
	# Placeholder - would apply a temporary stat modifier
	print("Applied +" + str(amount) + " armor for " + str(duration) + " seconds")

# Apply attack speed buff to a target
func apply_attack_speed_buff(target, percent: float, duration: float):
	# Placeholder - would apply a temporary stat modifier
	print("Applied +" + str(percent) + "% attack speed for " + str(duration) + " seconds")

# Apply a damage shield
func apply_shield(target, amount: int, duration: float):
	# Placeholder
	print("Applied " + str(amount) + " damage shield for " + str(duration) + " seconds")

# Taunt an enemy to attack this unit
func taunt_enemy(enemy, duration: float):
	# Placeholder - would set target
	print("Taunted enemy for " + str(duration) + " seconds")

# Immobilize a target
func immobilize_target(target, duration: float):
	# Placeholder - would prevent movement
	print("Immobilized target for " + str(duration) + " seconds")

# Create an area of effect visual
func create_aoe_effect(color: Color, radius: float, duration: float = 1.0):
	# Create a disc mesh for the AOE
	var aoe = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.1
	aoe.mesh = cylinder
	
	# Create material
	var material = StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = color
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.6
	aoe.material_override = material
	
	# Position slightly above ground
	aoe.position = Vector3(0, 0.05, 0)
	
	# Add to character
	character.add_child(aoe)
	
	# Animate and remove
	var tween = character.create_tween()
	tween.tween_property(aoe, "scale", Vector3(1.2, 1, 1.2), duration * 0.3)
	tween.tween_property(aoe, "scale", Vector3(1, 1, 1), duration * 0.5)
	tween.tween_property(material, "albedo_color:a", 0.0, duration * 0.2)
	
	# Remove after animation
	await tween.finished
	aoe.queue_free()

# Create a projectile effect
func create_projectile_effect(target_pos: Vector3, color: Color, duration: float = 0.5):
	# Create a small sphere for the projectile
	var projectile = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	projectile.mesh = sphere
	
	# Create material
	var material = StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = color
	material.albedo_color = color
	projectile.material_override = material
	
	# Start above character
	projectile.position = character.global_position + Vector3(0, 1.5, 0)
	
	# Make it global for proper movement
	projectile.top_level = true
	character.get_parent().add_child(projectile)
	
	# Animate to target
	var tween = projectile.create_tween()
	tween.tween_property(projectile, "global_position", target_pos, duration)
	
	# Create impact at the end
	await tween.finished
	
	# Impact effect
	var impact = MeshInstance3D.new()
	impact.mesh = sphere
	impact.mesh.radius = 0.4
	impact.mesh.height = 0.8
	impact.material_override = material
	impact.global_position = target_pos
	impact.top_level = true
	character.get_parent().add_child(impact)
	
	# Animate impact
	var impact_tween = impact.create_tween()
	impact_tween.tween_property(impact, "scale", Vector3(3, 3, 3), 0.2)
	impact_tween.tween_property(material, "albedo_color:a", 0.0, 0.2)
	
	# Remove projectile
	projectile.queue_free()
	
	# Remove impact after animation
	await impact_tween.finished
	impact.queue_free()

# Create a teleport effect
func create_teleport_effect(target_pos: Vector3):
	# Disappear effect at current position
	var disappear = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.6
	cylinder.bottom_radius = 0.6
	cylinder.height = 2.0
	disappear.mesh = cylinder
	
	# Material
	var material = StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = Color(0.5, 0, 0.5)  # Purple
	material.albedo_color = Color(0.5, 0, 0.5, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disappear.material_override = material
	
	# Position at character
	disappear.position = character.position
	character.get_parent().add_child(disappear)
	
	# Animate disappear
	var tween = disappear.create_tween()
	tween.tween_property(disappear, "scale", Vector3(0.1, 1, 0.1), 0.3)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.2)
	
	# Create reappear effect at target
	await tween.finished
	disappear.queue_free()
	
	# Move character (in real game this would be handled differently)
	# character.global_position = target_pos
	
	# Reappear effect
	var reappear = MeshInstance3D.new()
	reappear.mesh = cylinder
	
	var reappear_material = StandardMaterial3D.new()
	reappear_material.emission_enabled = true
	reappear_material.emission = Color(0.5, 0, 0.5)
	reappear_material.albedo_color = Color(0.5, 0, 0.5, 0.8)
	reappear_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	reappear.material_override = reappear_material
	
	reappear.global_position = target_pos
	reappear.scale = Vector3(0.1, 1, 0.1)
	character.get_parent().add_child(reappear)
	
	# Animate reappear
	var reappear_tween = reappear.create_tween()
	reappear_tween.tween_property(reappear, "scale", Vector3(1, 1, 1), 0.3)
	reappear_tween.tween_property(reappear_material, "albedo_color:a", 0.0, 0.3)
	
	await reappear_tween.finished
	reappear.queue_free()

# Create a self buff effect
func create_self_buff_effect(color: Color):
	# Aura effect
	var aura = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	aura.mesh = sphere
	
	# Material
	var material = StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = color
	material.albedo_color = Color(color.r, color.g, color.b, 0.4)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.material_override = material
	
	# Position at character center
	aura.position = Vector3(0, 1, 0)
	character.add_child(aura)
	
	# Animate
	var tween = character.create_tween()
	tween.tween_property(aura, "scale", Vector3(1.2, 1.2, 1.2), 0.5)
	tween.tween_property(aura, "scale", Vector3(1.0, 1.0, 1.0), 0.5)
	tween.tween_property(aura, "scale", Vector3(1.2, 1.2, 1.2), 0.5)
	tween.tween_property(aura, "scale", Vector3(1.0, 1.0, 1.0), 0.5)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.5)
	
	await tween.finished
	aura.queue_free()

# Create a healing effect
func create_healing_effect(target_pos: Vector3):
	# Create healing crosses rising up
	for i in range(5):
		var cross = create_healing_cross()
		cross.global_position = target_pos + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		character.get_parent().add_child(cross)
		
		# Animate rising
		var tween = cross.create_tween()
		tween.tween_property(cross, "position:y", cross.position.y + 3.0, 1.0)
		tween.parallel().tween_property(cross, "scale", Vector3(0.5, 0.5, 0.5), 1.0)
		
		# Fade out near the end
		var material = cross.get_child(0).material_override
		tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.8)
		
		# Remove when done
		await tween.finished
		cross.queue_free()

# Create a healing cross symbol
func create_healing_cross():
	var cross_container = Node3D.new()
	cross_container.top_level = true
	
	# Create two perpendicular boxes
	var vertical = MeshInstance3D.new()
	var horizontal = MeshInstance3D.new()
	
	var v_box = BoxMesh.new()
	v_box.size = Vector3(0.2, 0.8, 0.1)
	vertical.mesh = v_box
	
	var h_box = BoxMesh.new()
	h_box.size = Vector3(0.8, 0.2, 0.1)
	horizontal.mesh = h_box
	
	# Create material
	var material = StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = Color(0.2, 0.9, 0.2)  # Green
	material.albedo_color = Color(0.2, 0.9, 0.2, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	vertical.material_override = material
	horizontal.material_override = material
	
	cross_container.add_child(vertical)
	cross_container.add_child(horizontal)
	
	return cross_container
