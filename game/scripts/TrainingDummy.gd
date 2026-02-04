extends CharacterBody3D

@onready var combatant: Combatant = $Combatant
@onready var hurtbox: Area3D = $Hurtbox

func _ready():
	# Setup combatant for training dummy
	combatant.setup(self, null)  # No weapon for dummy
	combatant.health_changed.connect(_on_health_changed)
	combatant.ko_event.connect(_on_ko)
	
	# Setup hurtbox detection
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)  # Also check Area3D collisions
	
	print("Training Dummy initialized with health: ", combatant.current_health, "/", combatant.max_health)
	print("Hurtbox collision layer: ", hurtbox.collision_layer)
	print("Hurtbox collision mask: ", hurtbox.collision_mask)
	print("Hurtbox position: ", hurtbox.global_position)
	print("Hurtbox monitoring: ", hurtbox.monitoring)
	
	# Add visual debug for hurtbox
	_add_hurtbox_debug_visual()

func _on_hurtbox_area_entered(area: Area3D):
	print("Hurtbox detected AREA: ", area.name, " from: ", area.get_parent().name if area.get_parent() else "no parent")
	print("Area collision layer: ", area.collision_layer)
	print("Area collision mask: ", area.collision_mask)
	print("Area position: ", area.global_position)
	
	# Check if this is a melee hitbox
	if area.name == "MeleeHitbox":
		print("Melee hitbox detected - applying damage!")
		# Get the attacker (player)
		var attacker = area.get_parent().get_parent()
		print("Attacker: ", attacker.name)
		
		# Get the melee hitbox script to get damage values
		var melee_hitbox_script = area.get_script()
		if melee_hitbox_script:
			print("MeleeHitbox script found, applying damage...")
			# Apply damage directly
			combatant.take_damage(15, attacker)  # Use light attack damage as default
			combatant.apply_hitstop(0.08)  # Light attack hitstop
			
			# Flash red
			_flash_target_red()
			
			# Apply knockback
			_apply_knockback_from(attacker)
		else:
			print("No MeleeHitbox script found")

func _flash_target_red():
	# Flash the target's mesh red temporarily
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh:
		var original_material = mesh.material_override
		var flash_material = StandardMaterial3D.new()
		flash_material.albedo_color = Color.RED
		flash_material.unshaded = true
		mesh.material_override = flash_material
		
		# Restore original material after 0.2 seconds
		await get_tree().create_timer(0.2).timeout
		mesh.material_override = original_material

func _apply_knockback_from(attacker: Node):
	var attacker_pos = attacker.global_position
	var victim_pos = global_position
	
	# Calculate knockback direction (away from attacker)
	var knockback_dir = (victim_pos - attacker_pos).normalized()
	knockback_dir.y = 0.5  # Add some upward force
	
	# Apply knockback (light attack knockback)
	var knockback_force = 6.0
	velocity = knockback_dir * knockback_force
	print("Applied knockback: ", velocity)

func _add_hurtbox_debug_visual():
	# Create a visible mesh for the hurtbox
	var debug_mesh = MeshInstance3D.new()
	debug_mesh.name = "HurtboxDebugMesh"
	hurtbox.add_child(debug_mesh)
	
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.height = 2.0
	var debug_material = StandardMaterial3D.new()
	debug_material.albedo_color = Color.GREEN
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_material.albedo_color.a = 0.2
	capsule_mesh.material = debug_material
	debug_mesh.mesh = capsule_mesh

func _on_hurtbox_body_entered(body: Node):
	print("Hurtbox detected: ", body.name, " from: ", body.get_parent().name if body.get_parent() else "no parent")
	print("Hurtbox position: ", hurtbox.global_position)
	print("Body position: ", body.global_position)

func _on_health_changed(current: int, maximum: int):
	# Training dummy doesn't need UI updates
	print("Training Dummy health: ", current, "/", maximum)

func _on_ko():
	# Training dummy was defeated
	print("Training Dummy defeated!")
	# Respawn after a delay
	await get_tree().create_timer(3.0).timeout
	combatant.reset_health()
	global_position = Vector3(3, 2, 0)  # Reset position
	print("Training Dummy respawned with health: ", combatant.current_health)
