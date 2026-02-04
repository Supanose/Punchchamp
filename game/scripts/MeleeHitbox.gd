extends Area3D
class_name MeleeHitbox

signal hit_landed(victim: Combatant, damage: int, knockback: float)

# Attack data
var attacker: Node
var damage: int
var knockback: float
var hitstop_duration: float

# Active state
var is_active: bool = false
var has_hit: Array[Node] = []

func _ready():
	body_entered.connect(_on_body_entered)
	monitoring = false  # Start disabled

func setup_attack(attacker_node: Node, attack_damage: int, attack_knockback: float, hitstop: float):
	attacker = attacker_node
	damage = attack_damage
	knockback = attack_knockback
	hitstop_duration = hitstop
	has_hit.clear()

func activate():
	is_active = true
	monitoring = true
	has_hit.clear()

func deactivate():
	is_active = false
	monitoring = false

func _on_body_entered(body: Node):
	print("Hitbox detected body: ", body.name)
	if not is_active:
		print("Hitbox not active, ignoring")
		return
	
	# Don't hit self
	if body == attacker:
		print("Hit self, ignoring")
		return
	
	# Don't hit the same target twice in one attack
	if body in has_hit:
		print("Already hit this target, ignoring")
		return
	
	# Check if target has Combatant component
	var combatant = body.get_node_or_null("Combatant")
	if not combatant:
		print("No Combatant component on target")
		return
	
	print("Target has Combatant, checking if can be hit...")
	print("Target state: ", combatant.current_state)
	print("Target can_be_hit: ", combatant.can_be_hit())
	
	# Check if target can be hit
	if not combatant.can_be_hit():
		print("Target cannot be hit (parrying/stunned)")
		return
	
	# Check for parry
	if combatant.is_parrying():
		print("Target is parrying!")
		# Successful parry - stun attacker
		var attacker_combatant = attacker.get_node_or_null("Combatant")
		if attacker_combatant:
			attacker_combatant.apply_stun(0.40)  # Parry attacker stun
		combatant.successful_parry()
		deactivate()
		return
	
	print("Applying hit to target!")
	# Apply hit
	combatant.take_damage(damage, attacker)
	combatant.apply_hitstop(hitstop_duration)
	
	# Flash target red for visual feedback
	_flash_target_red(body)
	
	# Apply knockback
	apply_knockback_to(body)
	
	# Record hit
	has_hit.append(body)
	
	# Emit signal
	hit_landed.emit(combatant, damage, knockback)

func _flash_target_red(target: Node):
	# Flash the target's mesh red temporarily
	var mesh = target.get_node_or_null("MeshInstance3D")
	if mesh:
		var original_material = mesh.material_override
		var flash_material = StandardMaterial3D.new()
		flash_material.albedo_color = Color.RED
		flash_material.unshaded = true
		mesh.material_override = flash_material
		
		# Restore original material after 0.2 seconds
		await target.get_tree().create_timer(0.2).timeout
		mesh.material_override = original_material

func apply_knockback_to(victim: Node):
	var attacker_pos = attacker.global_position
	var victim_pos = victim.global_position
	
	# Calculate knockback direction (away from attacker)
	var knockback_dir = (victim_pos - attacker_pos).normalized()
	knockback_dir.y = 0.5  # Add some upward force
	
	# Apply knockback if victim is a CharacterBody3D
	if victim is CharacterBody3D:
		victim.velocity = knockback_dir * knockback
