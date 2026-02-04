extends CharacterBody3D
class_name Player

@export var move_speed: float = 12.0
@export var sprint_multiplier: float = 2.0
@export var acceleration: float = 25.0
@export var deceleration: float = 30.0
@export var jump_velocity: float = 4.5
@export var jump_burst_impulse: float = 12.0
@export var jump_burst_cooldown: float = 1.0
@export var jump_burst_window: float = 0.25

@onready var camera: Camera3D = $Camera3D
@onready var weapon_anchor: Node3D = $WeaponAnchor
@onready var hitbox_origin: Node3D = $HitboxOrigin
@onready var melee_hitbox: Area3D = $HitboxOrigin/MeleeHitbox
@onready var combatant: Combatant = $Combatant

# MeleeHitbox script reference
var melee_hitbox_script: Script = preload("res://scripts/MeleeHitbox.gd")

# Get the gravity from the project settings so you can sync with rigid body nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Movement state
var current_speed: float = 0.0
var is_sprinting: bool = false
var jump_burst_timer: float = 0.0
var last_jump_time: float = 0.0
var can_jump_burst: bool = true
var has_jumped: bool = false
var time_since_start: float = 0.0

# Camera rotation
var camera_rotation: Vector2 = Vector2.ZERO

# Parts system
var core_part_data: Dictionary = {}
var handle_part_data: Dictionary = {}
var mod_part_data: Dictionary = {}
var current_weapon: WeaponData = null
var weapon_mesh: MeshInstance3D = null

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Ensure player starts on ground
	global_position.y = 2.0
	time_since_start = 0.0
	
	# Set MeleeHitbox script programmatically
	melee_hitbox.set_script(melee_hitbox_script)
	
	# Ensure CollisionShape3D exists for hitbox
	_ensure_hitbox_collision()
	
	# Setup combat system
	combatant.setup(self, current_weapon)
	combatant.health_changed.connect(_on_health_changed)
	combatant.ko_event.connect(_on_ko)
	combatant.stun_started.connect(_on_stun_started)
	combatant.stun_ended.connect(_on_stun_ended)

func _ensure_hitbox_collision():
	# Check if CollisionShape3D already exists
	var collision_shape = melee_hitbox.get_node_or_null("CollisionShape3D")
	if not collision_shape:
		print("Creating CollisionShape3D for MeleeHitbox")
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		
		# Create BoxShape3D
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(2.0, 1, 2.0)  # Default size
		collision_shape.shape = box_shape
		
		# Add to MeleeHitbox
		melee_hitbox.add_child(collision_shape)
	else:
		print("CollisionShape3D already exists in MeleeHitbox")

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		camera_rotation.x -= event.relative.x * 0.003
		camera_rotation.y = clamp(camera_rotation.y - event.relative.y * 0.003, -1.3, 1.3)
		
		# Update camera position based on rotation
		var distance = 8.0
		var height = 5.0
		camera.position = Vector3(
			sin(camera_rotation.x) * distance,
			height + sin(camera_rotation.y) * 2.0,
			cos(camera_rotation.x) * distance
		)
		camera.look_at(global_position + Vector3.UP)
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("ui_accept") and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("attack_light"):
		_try_light_attack()
	elif event.is_action_pressed("attack_heavy"):
		_try_heavy_attack()
	elif event.is_action_pressed("parry"):
		_try_parry()

func _try_interact():
	# Try to craft at nearby workbench
	var workbenches = get_tree().get_nodes_in_group("workbench")
	for workbench in workbenches:
		if workbench.nearby_player == self:
			workbench.try_craft()
			break

func _physics_process(delta):
	# Update time tracking
	time_since_start += delta
	
	# Handle combat states first
	if combatant.current_state == Combatant.CombatState.STUNNED or combatant.current_state == Combatant.CombatState.HITSTOP:
		# Can't move during stun/hitstop
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	# Handle jump burst cooldown
	if jump_burst_timer > 0:
		jump_burst_timer -= delta
		if jump_burst_timer <= 0:
			can_jump_burst = true
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if is_on_floor():
		has_jumped = false
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			has_jumped = true
			last_jump_time = time_since_start
	
	# Handle jump burst (only after initial jump and within window)
	if has_jumped and Input.is_action_just_pressed("jump") and can_jump_burst:
		var time_since_jump = time_since_start - last_jump_time
		if time_since_jump <= jump_burst_window:
			velocity.y = jump_burst_impulse
			can_jump_burst = false
			jump_burst_timer = jump_burst_cooldown
	
	# Handle movement (only if not attacking)
	if combatant.can_act():
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			# Accelerate
			current_speed = move_toward(current_speed, move_speed, acceleration * delta)
			if Input.is_action_pressed("sprint"):
				current_speed = move_toward(current_speed, move_speed * sprint_multiplier, acceleration * delta)
				is_sprinting = true
			else:
				is_sprinting = false
			
			# Apply movement in camera-relative direction
			var camera_forward = camera.global_transform.basis.z.normalized()
			var camera_right = camera.global_transform.basis.x.normalized()
			
			velocity.x = (camera_forward * direction.z + camera_right * direction.x).x * current_speed
			velocity.z = (camera_forward * direction.z + camera_right * direction.x).z * current_speed
		else:
			# Decelerate when no input
			current_speed = move_toward(current_speed, 0.0, deceleration * delta)
			velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	
	move_and_slide()

# Parts and Crafting System
func try_pickup_part(part: PartPickup) -> bool:
	match part.part_type:
		PartPickup.PartType.CORE:
			if core_part_data.is_empty():
				core_part_data = {
					"name": part.get_part_name(),
					"type": part.core_type,
					"damage_mult": part.damage_mult,
					"speed_mult": part.speed_mult,
					"reach_add": part.reach_add,
					"knockback_mult": part.knockback_mult
				}
				return true
		PartPickup.PartType.HANDLE:
			if handle_part_data.is_empty():
				handle_part_data = {
					"name": part.get_part_name(),
					"type": part.handle_type,
					"damage_mult": part.damage_mult,
					"speed_mult": part.speed_mult,
					"reach_add": part.reach_add,
					"knockback_mult": part.knockback_mult
				}
				return true
		PartPickup.PartType.MOD:
			if mod_part_data.is_empty():
				mod_part_data = {
					"name": part.get_part_name(),
					"type": part.mod_type,
					"damage_mult": part.damage_mult,
					"speed_mult": part.speed_mult,
					"reach_add": part.reach_add,
					"knockback_mult": part.knockback_mult
				}
				return true
	return false

func can_craft_weapon() -> bool:
	return not core_part_data.is_empty() and not handle_part_data.is_empty()

func craft_weapon():
	if not can_craft_weapon():
		return
	
	# Create weapon data
	var weapon_name = "%s+%s" % [core_part_data["name"], handle_part_data["name"]]
	if not mod_part_data.is_empty():
		weapon_name += "+%s" % mod_part_data["name"]
	
	var damage = core_part_data["damage_mult"] * handle_part_data["damage_mult"]
	var speed = core_part_data["speed_mult"] * handle_part_data["speed_mult"]
	var reach = core_part_data["reach_add"] + handle_part_data["reach_add"]
	var knockback = core_part_data["knockback_mult"] * handle_part_data["knockback_mult"]
	
	if not mod_part_data.is_empty():
		damage *= mod_part_data["damage_mult"]
		speed *= mod_part_data["speed_mult"]
		reach += mod_part_data["reach_add"]
		knockback *= mod_part_data["knockback_mult"]
	
	# Ensure minimum reach for all weapons
	reach = max(reach, 1.0)
	
	current_weapon = WeaponData.new(weapon_name, damage, speed, reach, knockback, core_part_data["type"])
	
	# Create weapon mesh
	_equip_weapon_visual()
	
	# Update combatant with new weapon
	_update_combatant_weapon()
	
	# Clear parts
	core_part_data.clear()
	handle_part_data.clear()
	mod_part_data.clear()

func _equip_weapon_visual():
	# Remove existing weapon
	if weapon_mesh:
		weapon_mesh.queue_free()
	
	# Create new weapon mesh based on core type
	var mesh: Mesh
	match current_weapon.core_type:
		PartPickup.CoreType.BLADE:
			mesh = create_blade_mesh()
		PartPickup.CoreType.HAMMER:
			mesh = create_hammer_mesh()
	
	weapon_mesh = MeshInstance3D.new()
	weapon_mesh.mesh = mesh
	weapon_anchor.add_child(weapon_mesh)

func create_blade_mesh() -> Mesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.8, 0.05)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.SILVER
	mesh.material = material
	return mesh

func create_hammer_mesh() -> Mesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.3, 0.4, 0.3)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GRAY
	mesh.material = material
	return mesh

func reset_loadout():
	core_part_data.clear()
	handle_part_data.clear()
	mod_part_data.clear()
	current_weapon = null
	if weapon_mesh:
		weapon_mesh.queue_free()
		weapon_mesh = null

func get_parts_display() -> String:
	var parts = []
	if not core_part_data.is_empty(): 
		parts.append(core_part_data["name"])
	if not handle_part_data.is_empty(): 
		parts.append(handle_part_data["name"])
	if not mod_part_data.is_empty(): 
		parts.append(mod_part_data["name"])
	
	return " | ".join(parts) if parts.size() > 0 else "None"

func get_weapon_display() -> String:
	return current_weapon.weapon_name if current_weapon else "None"

# Combat System
func _try_light_attack():
	print("Light attack attempted")
	if not _can_combat():
		print("Cannot combat - state check failed")
		return
	
	print("Starting light attack...")
	if combatant.start_light_attack():
		print("Light attack started, performing sequence")
		# Start attack sequence
		_perform_light_attack()
	else:
		print("Light attack failed to start")

func _try_heavy_attack():
	print("Heavy attack attempted")
	if not _can_combat():
		print("Cannot combat - state check failed")
		return
	
	print("Starting heavy attack...")
	if combatant.start_heavy_attack():
		print("Heavy attack started, performing sequence")
		# Start attack sequence
		_perform_heavy_attack()
	else:
		print("Heavy attack failed to start")

func _try_parry():
	print("Parry attempted")
	if not _can_combat():
		print("Cannot combat - state check failed")
		return
	
	combatant.start_parry()

func _can_combat() -> bool:
	# Check if combat is allowed (only during FIGHT state)
	var game_mode = get_node("/root/Main/GameMode")
	if not game_mode or game_mode.current_state != game_mode.RoundState.FIGHT:
		return false
	
	# Check if combatant can act
	return combatant.can_act()

func _perform_light_attack():
	print("Performing light attack sequence")
	var windup = combatant.get_light_windup()
	var active = combatant.light_active
	var damage = combatant.get_light_damage()
	var knockback = combatant.get_light_knockback()
	var hitstop = combatant.light_hitstop
	
	print("Light attack stats: windup=", windup, " active=", active, " damage=", damage)
	
	# Setup hitbox - cast to MeleeHitbox type
	var hitbox = melee_hitbox as MeleeHitbox
	hitbox.setup_attack(self, damage, knockback, hitstop)
	
	# Attack sequence
	print("Starting windup...")
	await get_tree().create_timer(windup).timeout
	print("Windup complete, activating hitbox")
	_activate_hitbox()
	await get_tree().create_timer(active).timeout
	print("Attack complete, deactivating hitbox")
	_deactivate_hitbox()

func _perform_heavy_attack():
	print("Performing heavy attack sequence")
	var windup = combatant.get_heavy_windup()
	var active = combatant.heavy_active
	var damage = combatant.get_heavy_damage()
	var knockback = combatant.get_heavy_knockback()
	var hitstop = combatant.heavy_hitstop
	
	print("Heavy attack stats: windup=", windup, " active=", active, " damage=", damage)
	
	# Setup hitbox - cast to MeleeHitbox type
	var hitbox = melee_hitbox as MeleeHitbox
	hitbox.setup_attack(self, damage, knockback, hitstop)
	
	# Attack sequence
	print("Starting windup...")
	await get_tree().create_timer(windup).timeout
	print("Windup complete, activating hitbox")
	_activate_hitbox()
	await get_tree().create_timer(active).timeout
	print("Attack complete, deactivating hitbox")
	_deactivate_hitbox()

func _activate_hitbox():
	print("Activating hitbox...")
	# Update hitbox size based on weapon reach
	var reach = combatant.get_attack_reach()
	print("Weapon reach: ", reach)
	print("Current weapon: ", current_weapon)
	if current_weapon:
		print("Weapon data: ", current_weapon.weapon_name, " reach: ", current_weapon.reach)
	else:
		print("No weapon equipped - using unarmed reach")
	
	# Get collision shape safely
	var collision_shape = melee_hitbox.get_node_or_null("CollisionShape3D")
	if not collision_shape:
		print("ERROR: CollisionShape3D not found in MeleeHitbox!")
		return
	
	var shape = collision_shape.shape as BoxShape3D
	if shape:
		shape.size = Vector3(reach, 1, reach)
		print("Hitbox size set to: ", shape.size)
	
	# Create visual debug mesh
	_create_debug_mesh(reach)
	
	# Setup hitbox with damage values
	var hitbox = melee_hitbox as MeleeHitbox
	var damage = combatant.get_light_damage() if combatant.current_state == Combatant.CombatState.ATTACKING_LIGHT else combatant.get_heavy_damage()
	var knockback = combatant.get_light_knockback() if combatant.current_state == Combatant.CombatState.ATTACKING_LIGHT else combatant.get_heavy_knockback()
	var hitstop = combatant.light_hitstop if combatant.current_state == Combatant.CombatState.ATTACKING_LIGHT else combatant.heavy_hitstop
	
	hitbox.setup_attack(self, damage, knockback, hitstop)
	hitbox.activate()
	
	print("Hitbox activated with damage: ", damage, " monitoring: ", melee_hitbox.monitoring)

func _create_debug_mesh(reach: float):
	# Remove existing debug mesh
	var existing_debug = melee_hitbox.get_node_or_null("DebugMesh")
	if existing_debug:
		existing_debug.queue_free()
	
	# Create new debug mesh
	var debug_mesh = MeshInstance3D.new()
	debug_mesh.name = "DebugMesh"
	
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(reach, 1, reach)
	var debug_material = StandardMaterial3D.new()
	debug_material.albedo_color = Color.YELLOW
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_material.albedo_color.a = 0.3
	box_mesh.material = debug_material
	debug_mesh.mesh = box_mesh
	
	melee_hitbox.add_child(debug_mesh)
	print("Created debug mesh with size: ", box_mesh.size)

func _deactivate_hitbox():
	print("Deactivating hitbox...")
	# Remove debug mesh
	var debug_mesh = melee_hitbox.get_node_or_null("DebugMesh")
	if debug_mesh:
		debug_mesh.queue_free()
	
	# Deactivate hitbox - cast to MeleeHitbox type
	var hitbox = melee_hitbox as MeleeHitbox
	hitbox.deactivate()
	print("Hitbox deactivated, monitoring: ", melee_hitbox.monitoring)

# Combat Event Handlers
func _on_health_changed(current: int, maximum: int):
	# Update UI with health changes
	pass

func _on_ko():
	# Notify GameMode of KO
	var game_mode = get_node("/root/Main/GameMode")
	if game_mode:
		game_mode.on_player_ko(self)

func _on_stun_started(duration: float):
	# Player is stunned - movement handled in _physics_process
	pass

func _on_stun_ended():
	# Player can act again
	pass

# Update combatant when weapon changes
func _update_combatant_weapon():
	combatant.weapon_data = current_weapon
