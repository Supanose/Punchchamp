extends CharacterBody3D
class_name AIOpponent

@export var move_speed: float = 8.0
@export var detection_range: float = 15.0
@export var attack_range: float = 2.0
@export var reaction_time: float = 0.3

@onready var camera: Camera3D = $Camera3D
@onready var weapon_anchor: Node3D = $WeaponAnchor
@onready var hitbox_origin: Node3D = $HitboxOrigin
@onready var melee_hitbox: Area3D = $HitboxOrigin/MeleeHitbox
@onready var combatant: Combatant = $Combatant
@onready var health_bar: ProgressBar = $HealthBarUI/SubViewport/HealthBar
@onready var hurtbox: Area3D = $Hurtbox

# AI Configuration
var can_attack: bool = true
var can_parry: bool = true
var can_move: bool = true
var can_basic_attack: bool = true
var is_active: bool = false

# AI State
var current_target: Node3D = null
var ai_state: AIState = AIState.IDLE
var state_timer: float = 0.0
var next_action_timer: float = 0.0

enum AIState {
	IDLE,
	CHASING,
	ATTACKING,
	PARRYING,
	STUNNED
}

# Movement
var current_speed: float = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Setup melee hitbox
	var melee_hitbox_script: Script = preload("res://scripts/MeleeHitbox.gd")
	melee_hitbox.set_script(melee_hitbox_script)
	_create_melee_hitbox_collision()
	
	# Setup combat system
	combatant.setup(self, null)
	combatant.health_changed.connect(_on_health_changed)
	combatant.ko_event.connect(_on_ko)
	combatant.stun_started.connect(_on_stun_started)
	combatant.stun_ended.connect(_on_stun_ended)
	
	# Setup hurtbox detection
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	
	# Initialize health bar
	if health_bar:
		health_bar.max_value = combatant.max_health
		health_bar.value = combatant.current_health
	
	# Start inactive
	set_active(false)

func _create_melee_hitbox_collision():
	var existing_shape = melee_hitbox.get_node_or_null("CollisionShape3D")
	if existing_shape:
		return
	
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1, 1, 1)
	collision_shape.shape = box_shape
	
	melee_hitbox.add_child(collision_shape)

func _process(delta):
	if not is_active:
		return
	
	# Update AI behavior
	_update_ai_state(delta)
	_handle_movement(delta)
	
	# Debug AI state
	if Engine.get_frames_drawn() % 60 == 0:  # Print every second
		print("AI State: ", ai_state, " Target: ", current_target.name if current_target else "None", " Active: ", is_active)

func _physics_process(delta):
	if not is_active:
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	move_and_slide()

func set_active(active: bool):
	is_active = active
	if active:
		print("AI Opponent activated")
	else:
		print("AI Opponent deactivated")
		ai_state = AIState.IDLE

func configure_ai(attack_enabled: bool, parry_enabled: bool, movement_enabled: bool, basic_attack_enabled: bool):
	can_attack = attack_enabled
	can_parry = parry_enabled
	can_move = movement_enabled
	can_basic_attack = basic_attack_enabled
	print("AI configured - Attack: ", can_attack, ", Parry: ", can_parry, ", Movement: ", can_move, ", Basic Attack: ", can_basic_attack)

func _update_ai_state(delta):
	state_timer -= delta
	next_action_timer -= delta
	
	# Find target if we don't have one (only check every 0.5 seconds)
	if not current_target:
		if state_timer <= 0:  # Only check periodically
			_find_target()
			state_timer = 0.5  # Check every 0.5 seconds
	
	if not current_target:
		ai_state = AIState.IDLE
		return
	
	# Calculate distance to target
	var distance = global_position.distance_to(current_target.global_position)
	
	match ai_state:
		AIState.IDLE:
			if distance < detection_range:
				ai_state = AIState.CHASING
				print("AI: Target detected, chasing")
		
		AIState.CHASING:
			if distance > detection_range:
				ai_state = AIState.IDLE
				current_target = null
			elif distance <= attack_range and can_basic_attack and next_action_timer <= 0:
				print("AI: Attempting basic attack at distance: ", distance)
				_start_basic_attack()
			elif can_parry and _should_parry():
				_start_parry()
		
		AIState.ATTACKING:
			# Wait for attack to complete
			if combatant.current_state == Combatant.CombatState.IDLE:
				ai_state = AIState.CHASING
				next_action_timer = reaction_time
		
		AIState.PARRYING:
			# Wait for parry to complete
			if combatant.current_state == Combatant.CombatState.IDLE:
				ai_state = AIState.CHASING
				next_action_timer = reaction_time
		
		AIState.STUNNED:
			# Wait for stun to end
			pass

func _find_target():
	# Try to find player by group first
	var player = get_tree().get_first_node_in_group("player")
	
	# Fallback: try to find by name if group fails
	if not player:
		player = get_tree().get_root().get_node_or_null("Main/Player")
		print("AI: Using fallback to find player by name")
	
	print("AI _find_target called - player found: ", player != null)
	if player:
		print("Player position: ", player.global_position)
		print("AI position: ", global_position)
		print("Distance: ", player.global_position.distance_to(global_position))
	
	if player and player.global_position.distance_to(global_position) < detection_range:
		current_target = player
		print("AI: Found player target")
	else:
		print("AI: No target found or out of range")

func _handle_movement(delta):
	if ai_state != AIState.CHASING or not current_target or not can_move:
		# Decelerate when not chasing or movement disabled
		current_speed = move_toward(current_speed, 0.0, 20.0 * delta)
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		return
	
	# Move toward target
	var direction = (current_target.global_position - global_position)
	direction.y = 0
	direction = direction.normalized()
	
	# Only look at target if we're actually moving
	if current_speed > 0.1:
		# Create a look-at position that's level with the AI
		var look_at_pos = current_target.global_position
		look_at_pos.y = global_position.y  # Keep on same level
		look_at(look_at_pos, Vector3.UP)
	
	# Accelerate toward target
	current_speed = move_toward(current_speed, move_speed, 15.0 * delta)
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

func _should_parry() -> bool:
	# Simple parry logic: parry when target is in attack range and facing us
	if not current_target:
		return false
	
	var distance = global_position.distance_to(current_target.global_position)
	if distance > attack_range * 1.5:
		return false
	
	# Check if target is facing us (simplified)
	var to_target = (current_target.global_position - global_position).normalized()
	var forward = -current_target.global_transform.basis.z
	if to_target.dot(forward) > 0.5:
		# Target is facing us, chance to parry
		return randf() < 0.3  # 30% chance to parry
	
	return false

func _start_basic_attack():
	if not can_basic_attack:
		print("AI: Basic attack disabled")
		return
	
	ai_state = AIState.ATTACKING
	print("AI: Starting basic attack")
	
	# Perform a simple attack with fixed damage
	_perform_basic_attack()

func _perform_basic_attack():
	var damage = 10  # Fixed basic damage
	var knockback = 5.0
	var hitstop = 0.1
	
	print("AI performing basic attack - damage: ", damage)
	
	# Simple attack sequence - immediate hitbox activation
	_activate_basic_hitbox(damage, knockback, hitstop)
	
	# Wait a moment then deactivate
	await get_tree().create_timer(0.3).timeout
	_deactivate_hitbox()
	
	# Return to chasing
	ai_state = AIState.CHASING
	next_action_timer = reaction_time

func _activate_basic_hitbox(damage: int, knockback: float, hitstop: float):
	print("AI: Activating basic hitbox")
	
	# Use a fixed reach for basic attacks
	var reach = 2.0
	var collision_shape = melee_hitbox.get_node_or_null("CollisionShape3D")
	if collision_shape:
		var shape = collision_shape.shape as BoxShape3D
		if shape:
			shape.size = Vector3(reach, 1, reach)
	
	# Setup hitbox
	var hitbox = melee_hitbox as MeleeHitbox
	hitbox.setup_attack(self, damage, knockback, hitstop)
	hitbox.activate()

func _perform_light_attack():
	if not combatant.start_light_attack():
		print("AI: Light attack failed to start")
		return
	
	var windup = combatant.get_light_windup()
	var active = combatant.light_active
	var damage = combatant.get_light_damage()
	var knockback = combatant.get_light_knockback()
	var hitstop = combatant.light_hitstop
	
	print("AI performing light attack - damage: ", damage)
	
	# Attack sequence
	await get_tree().create_timer(windup).timeout
	_activate_hitbox(damage, knockback, hitstop)
	await get_tree().create_timer(active).timeout
	_deactivate_hitbox()

func _perform_heavy_attack():
	if not combatant.start_heavy_attack():
		print("AI: Heavy attack failed to start")
		return
	
	var windup = combatant.get_heavy_windup()
	var active = combatant.heavy_active
	var damage = combatant.get_heavy_damage()
	var knockback = combatant.get_heavy_knockback()
	var hitstop = combatant.heavy_hitstop
	
	print("AI performing heavy attack - damage: ", damage)
	
	# Attack sequence
	await get_tree().create_timer(windup).timeout
	_activate_hitbox(damage, knockback, hitstop)
	await get_tree().create_timer(active).timeout
	_deactivate_hitbox()

func _activate_hitbox(damage: int, knockback: float, hitstop: float):
	print("AI: Activating hitbox")
	
	# Update hitbox size based on weapon reach
	var reach = combatant.get_attack_reach()
	var collision_shape = melee_hitbox.get_node_or_null("CollisionShape3D")
	if collision_shape:
		var shape = collision_shape.shape as BoxShape3D
		if shape:
			shape.size = Vector3(reach, 1, reach)
	
	# Setup hitbox
	var hitbox = melee_hitbox as MeleeHitbox
	hitbox.setup_attack(self, damage, knockback, hitstop)
	hitbox.activate()

func _deactivate_hitbox():
	print("AI: Deactivating hitbox")
	var hitbox = melee_hitbox as MeleeHitbox
	hitbox.deactivate()

func _start_parry():
	if not can_parry:
		return
	
	ai_state = AIState.PARRYING
	print("AI: Starting parry")
	combatant.start_parry()

# Combat signal handlers
func _on_health_changed(current: int, maximum: int):
	if health_bar:
		health_bar.value = current
	print("AI Health: ", current, "/", maximum)

func _on_ko():
	print("AI: Knocked out!")
	set_active(false)
	# Respawn after delay
	get_tree().create_timer(3.0).timeout.connect(_respawn)

func _on_stun_started(duration: float):
	print("AI: Stunned for ", duration, " seconds")
	ai_state = AIState.STUNNED

func _on_stun_ended():
	print("AI: Stun ended")
	ai_state = AIState.CHASING

func _respawn():
	# Reset health and position
	combatant.current_health = combatant.max_health
	combatant.health_changed.emit(combatant.current_health, combatant.max_health)
	
	# Reset position (you might want to set spawn points)
	global_position = Vector3(10, 2, 10)
	
	# Reactivate
	set_active(true)

func _on_hurtbox_area_entered(area: Area3D):
	# Check if this is a melee hitbox
	if area.name == "MeleeHitbox":
		# Get the attacker (player)
		var attacker = area.get_parent().get_parent()
		
		# Get damage from the hitbox
		var hitbox = area as MeleeHitbox
		if hitbox and hitbox.is_active:
			combatant.take_damage(hitbox.damage, attacker)
			combatant.apply_hitstop(hitbox.hitstop_duration)
