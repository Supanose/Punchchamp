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

# Get the gravity from the project settings so you can sync with rigid body nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Movement state
var current_speed: float = 0.0
var is_sprinting: bool = false
var jump_burst_timer: float = 0.0
var last_jump_time: float = 0.0
var can_jump_burst: bool = true
var has_jumped: bool = false

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

func _try_interact():
	# Try to craft at nearby workbench
	var workbenches = get_tree().get_nodes_in_group("workbench")
	for workbench in workbenches:
		if workbench.nearby_player == self:
			workbench.try_craft()
			break

func _physics_process(delta):
	# Handle jump burst cooldown
	if jump_burst_timer > 0:
		jump_burst_timer -= delta
		if jump_burst_timer <= 0:
			can_jump_burst = true
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			last_jump_time = Time.get_time_dict_from_system()["second"]
			has_jumped = true
			print("Jump!")
		elif can_jump_burst and has_jumped and (Time.get_time_dict_from_system()["second"] - last_jump_time) < jump_burst_window:
			# Jump burst
			var forward_dir = -camera.global_transform.basis.z
			forward_dir.y = 0
			forward_dir = forward_dir.normalized()
			velocity += forward_dir * jump_burst_impulse
			can_jump_burst = false
			jump_burst_timer = jump_burst_cooldown
			has_jumped = false
			print("Jump burst!")
	
	# Reset jump tracking when landing
	if is_on_floor() and not has_jumped:
		has_jumped = false
	
	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	
	# Convert input to camera-relative direction
	var camera_forward = -camera.global_transform.basis.z
	var camera_right = camera.global_transform.basis.x
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	var direction = camera_forward * input_dir.y + camera_right * input_dir.x
	direction = direction.normalized()
	
	# Handle sprint
	is_sprinting = Input.is_action_pressed("sprint") and input_dir.length() > 0.1
	var target_speed = move_speed * (sprint_multiplier if is_sprinting else 1.0)
	
	# Apply snappy acceleration/deceleration
	if direction.length() > 0.1:
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
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
	
	current_weapon = WeaponData.new(weapon_name, damage, speed, reach, knockback, core_part_data["type"])
	
	# Create weapon mesh
	_equip_weapon_visual()
	
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
