extends CharacterBody3D

@export var move_speed: float = 8.0
@export var sprint_multiplier: float = 1.8
@export var acceleration: float = 20.0
@export var deceleration: float = 25.0
@export var jump_velocity: float = 4.5
@export var jump_burst_impulse: float = 8.0
@export var jump_burst_cooldown: float = 1.0
@export var jump_burst_window: float = 0.25

@onready var camera: Camera3D = $Camera3D

# Get the gravity from the project settings so you can sync with rigid body nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Movement state
var current_speed: float = 0.0
var is_sprinting: bool = false
var jump_burst_timer: float = 0.0
var last_jump_time: float = 0.0
var can_jump_burst: bool = true

# Camera rotation
var camera_rotation: Vector2 = Vector2.ZERO

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		camera_rotation.x += event.relative.x * 0.003
		camera_rotation.y = clamp(camera_rotation.y + event.relative.y * 0.003, -1.3, 1.3)
		
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
			print("Jump!")
		elif can_jump_burst and (Time.get_time_dict_from_system()["second"] - last_jump_time) < jump_burst_window:
			# Jump burst
			var forward_dir = -camera.global_transform.basis.z
			forward_dir.y = 0
			forward_dir = forward_dir.normalized()
			velocity += forward_dir * jump_burst_impulse
			can_jump_burst = false
			jump_burst_timer = jump_burst_cooldown
			print("Jump burst!")
	
	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
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
