extends Control
class_name AIConfigMenu

signal ai_configured(attack_enabled: bool, parry_enabled: bool, movement_enabled: bool, basic_attack_enabled: bool)

@onready var attack_checkbox: CheckBox = $VBoxContainer/AttackToggle
@onready var parry_checkbox: CheckBox = $VBoxContainer/ParryToggle
@onready var movement_checkbox: CheckBox = $VBoxContainer/MovementToggle
@onready var basic_attack_checkbox: CheckBox = $VBoxContainer/BasicAttackToggle
@onready var apply_button: Button = $VBoxContainer/ApplyButton
@onready var close_button: Button = $VBoxContainer/CloseButton

var ai_opponent: AIOpponent = null

func _ready():
	# Connect button signals
	apply_button.pressed.connect(_on_apply_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Set default values
	attack_checkbox.button_pressed = true
	parry_checkbox.button_pressed = true
	movement_checkbox.button_pressed = true
	basic_attack_checkbox.button_pressed = true
	
	# Hide menu initially
	visible = false

func set_ai_opponent(ai: AIOpponent):
	ai_opponent = ai
	print("AI Config Menu: Opponent set")

func show_menu():
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("AI Config Menu opened")

func hide_menu():
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("AI Config Menu closed")

func _on_apply_pressed():
	if not ai_opponent:
		print("No AI opponent to configure")
		return
	
	var attack_enabled = attack_checkbox.button_pressed
	var parry_enabled = parry_checkbox.button_pressed
	var movement_enabled = movement_checkbox.button_pressed
	var basic_attack_enabled = basic_attack_checkbox.button_pressed
	
	ai_opponent.configure_ai(attack_enabled, parry_enabled, movement_enabled, basic_attack_enabled)
	ai_configured.emit(attack_enabled, parry_enabled, movement_enabled, basic_attack_enabled)
	
	print("AI configuration applied - Attack: ", attack_enabled, ", Parry: ", parry_enabled, ", Movement: ", movement_enabled, ", Basic Attack: ", basic_attack_enabled)
	hide_menu()

func _on_close_pressed():
	hide_menu()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		hide_menu()
		get_viewport().set_input_as_handled()
