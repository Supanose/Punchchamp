extends Node
class_name Combatant

signal health_changed(current_health: int, max_health: int)
signal ko_event
signal stun_started(duration: float)
signal stun_ended

# Health system
@export var max_health: int = 100
var current_health: int

# Combat states
enum CombatState {
	IDLE,
	ATTACKING_LIGHT,
	ATTACKING_HEAVY,
	PARRYING,
	STUNNED,
	HITSTOP
}
var current_state: CombatState = CombatState.IDLE

# Combat timers
var attack_timer: float = 0.0
var parry_timer: float = 0.0
var stun_timer: float = 0.0
var hitstop_timer: float = 0.0

# Combat stats (base values)
@export var base_light_damage: int = 8
@export var base_heavy_damage: int = 18
@export var base_light_knockback: float = 6.0
@export var base_heavy_knockback: float = 12.0

# Attack timing (base values)
@export var light_windup: float = 0.08
@export var light_active: float = 0.10
@export var light_recovery: float = 0.18
@export var heavy_windup: float = 0.16
@export var heavy_active: float = 0.12
@export var heavy_recovery: float = 0.35

# Parry timing
@export var parry_window: float = 0.14
@export var parry_whiff_recovery: float = 0.25
@export var parry_attacker_stun: float = 0.40

# Hitstop timing
@export var light_hitstop: float = 0.08
@export var heavy_hitstop: float = 0.12

# References
var character_body: CharacterBody3D
var weapon_data: WeaponData

func _ready():
	current_health = max_health

func setup(body: CharacterBody3D, weapon: WeaponData = null):
	character_body = body
	weapon_data = weapon

func _process(delta):
	# Handle timers
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()
	
	if parry_timer > 0:
		parry_timer -= delta
		if parry_timer <= 0:
			_end_parry()
	
	if stun_timer > 0:
		stun_timer -= delta
		if stun_timer <= 0:
			_end_stun()
	
	if hitstop_timer > 0:
		hitstop_timer -= delta
		if hitstop_timer <= 0:
			_end_hitstop()

# Health system
func take_damage(damage: int, attacker: Node = null):
	if current_state == CombatState.STUNNED:
		return  # Can't take damage while stunned
	
	current_health -= damage
	current_health = max(0, current_health)
	
	print("Combatant taking damage: ", damage, " from: ", attacker.name if attacker else "unknown")
	print("Current health after: ", current_health, "/", max_health)
	
	# Track damage for GameMode
	var gamemode = get_tree().get_first_node_in_group("gamemode")
	if gamemode:
		if attacker:
			# Check if attacker is player or AI
			if attacker.is_in_group("player"):
				gamemode.player_damage_dealt += damage
				if self.is_in_group("player"):
					gamemode.player_damage_received += damage
				else:
					gamemode.ai_damage_received += damage
			else:
				# Assume AI attacker
				gamemode.ai_damage_dealt += damage
				if self.is_in_group("player"):
					gamemode.player_damage_received += damage
				else:
					gamemode.ai_damage_received += damage
	
	# Spawn damage number
	_spawn_damage_number(damage)
	
	# Check for KO
	if current_health <= 0:
		current_health = 0
		knock_out()
	
	# Emit damage event for other systems
	damage_taken.emit(damage, attacker)

func _spawn_damage_number(damage: int):
	# Load damage number scene
	var damage_scene = preload("res://scenes/DamageNumber.tscn")
	var damage_number = damage_scene.instantiate()
	
	# Add to scene tree
	get_tree().current_scene.add_child(damage_number)
	
	# Show damage above this character
	var spawn_pos = character_body.global_position if character_body else Vector3.ZERO
	damage_number.show_damage(damage, spawn_pos)

func heal(amount: int):
	current_health += amount
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)

func reset_health():
	current_health = max_health
	health_changed.emit(current_health, max_health)

# Combat state checks
func can_act() -> bool:
	return current_state == CombatState.IDLE

func can_be_hit() -> bool:
	return current_state != CombatState.PARRYING

func is_parrying() -> bool:
	return current_state == CombatState.PARRYING

# Attack system
func start_light_attack():
	if not can_act():
		return false
	
	current_state = CombatState.ATTACKING_LIGHT
	attack_timer = light_windup + light_active + light_recovery
	return true

func start_heavy_attack():
	if not can_act():
		return false
	
	current_state = CombatState.ATTACKING_HEAVY
	attack_timer = heavy_windup + heavy_active + heavy_recovery
	return true

func _end_attack():
	current_state = CombatState.IDLE

# Parry system
func start_parry():
	if not can_act():
		return false
	
	current_state = CombatState.PARRYING
	parry_timer = parry_window
	return true

func _end_parry():
	if current_state == CombatState.PARRYING:
		# Whiff - apply recovery
		current_state = CombatState.STUNNED
		stun_timer = parry_whiff_recovery
		stun_started.emit(parry_whiff_recovery)

func successful_parry():
	# Cancel incoming attack and apply stun to attacker
	current_state = CombatState.IDLE
	parry_timer = 0

# Stun system
func apply_stun(duration: float):
	current_state = CombatState.STUNNED
	stun_timer = duration
	stun_started.emit(duration)

func _end_stun():
	current_state = CombatState.IDLE
	stun_ended.emit()

# Hitstop system
func apply_hitstop(duration: float):
	current_state = CombatState.HITSTOP
	hitstop_timer = duration
	# Pause the game locally
	Engine.time_scale = 0.1

func _end_hitstop():
	current_state = CombatState.IDLE
	Engine.time_scale = 1.0

# Get attack damage based on weapon stats
func get_light_damage() -> int:
	var damage = base_light_damage
	if weapon_data:
		damage *= weapon_data.damage_mult
	return int(damage)

func get_heavy_damage() -> int:
	var damage = base_heavy_damage
	if weapon_data:
		damage *= weapon_data.damage_mult
	return int(damage)

# Get attack knockback based on weapon stats
func get_light_knockback() -> float:
	var knockback = base_light_knockback
	if weapon_data:
		knockback *= weapon_data.knockback_mult
	return knockback

func get_heavy_knockback() -> float:
	var knockback = base_heavy_knockback
	if weapon_data:
		knockback *= weapon_data.knockback_mult
	return knockback

# Get attack timing based on weapon stats
func get_light_windup() -> float:
	var windup = light_windup
	if weapon_data:
		windup /= weapon_data.speed_mult
	return windup

func get_heavy_windup() -> float:
	var windup = heavy_windup
	if weapon_data:
		windup /= weapon_data.speed_mult
	return windup

# Get attack reach based on weapon stats
func get_attack_reach() -> float:
	if weapon_data:
		return weapon_data.reach
	return 2.0  # Base reach for unarmed
