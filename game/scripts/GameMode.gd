extends Node

enum RoundState {
	WAITING,  # New state for manual round start
	PREP,
	FIGHT,
	RESULTS  # New state for results screen
}

@onready var state_label: Label = $"../UI/StateLabel"
@onready var timer_label: Label = $"../UI/TimerLabel"
@onready var barrier_static_body: StaticBody3D = $"../Barrier/StaticBody3D"
@onready var barrier_mesh: MeshInstance3D = $"../Barrier/MeshInstance3D"
@onready var parts_label: Label = $"../UI/PartsLabel"
@onready var weapon_label: Label = $"../UI/WeaponLabel"

# AI System
var ai_opponent: AIOpponent = null
var ai_config_menu: AIConfigMenu = null
var results_screen: ResultsScreen = null

# Round state
var current_state: RoundState = RoundState.WAITING
var prep_timer: float = 15.0
var fight_timer: float = 15.0
var end_timer: float = 3.0
var winner_text: String = ""

# Damage tracking
var player_damage_dealt: float = 0.0
var player_damage_received: float = 0.0
var ai_damage_dealt: float = 0.0
var ai_damage_received: float = 0.0

func _ready():
	# Wait a frame before setting up to ensure all nodes are ready
	await get_tree().process_frame
	
	# Setup AI system
	_setup_ai_system()
	
	# Start in waiting state
	enter_waiting_state()

func _setup_ai_system():
	# Get existing AI opponent from scene
	ai_opponent = get_node("../AIOpponent")
	if ai_opponent:
		print("AI opponent found in scene")
	else:
		print("ERROR: AI opponent not found in scene!")
	
	# Get existing AI config menu from scene
	ai_config_menu = get_node("../AIConfigMenu")
	if ai_config_menu:
		print("AI config menu found in scene")
	else:
		print("ERROR: AI config menu not found in scene!")
	
	# Get results screen from scene
	results_screen = get_node("../ResultsScreen")
	if results_screen:
		print("Results screen found in scene")
	else:
		print("ERROR: Results screen not found in scene!")
	
	# Configure AI menu
	if ai_config_menu and ai_opponent:
		ai_config_menu.set_ai_opponent(ai_opponent)
	
	# Connect AI signals
	if ai_opponent:
		var ai_combatant = ai_opponent.get_node_or_null("Combatant")
		if ai_combatant:
			ai_combatant.ko_event.connect(_on_ai_ko)
			print("AI combatant signals connected")
		else:
			print("ERROR: AI combatant not found!")
	
	print("AI System setup complete")

func _unhandled_input(event):
	# Toggle AI config menu with F1 key
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		if ai_config_menu:
			ai_config_menu.show_menu()
		get_viewport().set_input_as_handled()
	
	# Manual round start with left click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match current_state:
			RoundState.WAITING:
				enter_prep_state()
				get_viewport().set_input_as_handled()
			RoundState.RESULTS:
				# Reset everything and start new round
				_reset_round()
				enter_prep_state()
				get_viewport().set_input_as_handled()

func _process(delta):
	match current_state:
		RoundState.WAITING:
			state_label.text = "CLICK TO START ROUND"
			timer_label.text = ""
		
		RoundState.PREP:
			prep_timer -= delta
			timer_label.text = "PREP: %d" % int(prep_timer)
			
			if prep_timer <= 0:
				enter_fight_state()
		
		RoundState.FIGHT:
			fight_timer -= delta
			timer_label.text = "FIGHT: %d" % int(fight_timer)
			
			if fight_timer <= 0:
				enter_results_state()
		
		RoundState.RESULTS:
			# Results screen - no timer, wait for click
			state_label.text = "ROUND OVER"
			timer_label.text = "CLICK TO CONTINUE"
	
	# Update UI
	_update_ui()

func _update_ui():
	var player = get_node("../Player")
	if player:
		var parts_display = player.get_parts_display()
		var weapon_display = player.get_weapon_display()
		parts_label.text = "Parts: %s" % parts_display
		weapon_label.text = "Weapon: %s" % weapon_display

func enter_waiting_state():
	current_state = RoundState.WAITING
	state_label.text = "CLICK TO START ROUND"
	timer_label.text = ""
	
	# Reset damage tracking
	_reset_damage_tracking()

func enter_prep_state():
	current_state = RoundState.PREP
	prep_timer = 15.0
	state_label.text = "PREP"
	
	# Enable barrier
	barrier_static_body.collision_layer = 1
	barrier_static_body.collision_mask = 1
	barrier_mesh.visible = true
	
	# Reset player health and loadout
	var player = get_node("../Player")
	if player:
		player.reset_loadout()
		var combatant = player.get_node_or_null("Combatant")
		if combatant:
			combatant.reset_health()
	
	# Reset AI health and deactivate
	if ai_opponent:
		ai_opponent.set_active(false)
		var ai_combatant = ai_opponent.get_node_or_null("Combatant")
		if ai_combatant:
			ai_combatant.reset_health()

func enter_fight_state():
	current_state = RoundState.FIGHT
	fight_timer = 15.0
	state_label.text = "FIGHT"
	
	# Disable barrier
	barrier_static_body.collision_layer = 0
	barrier_static_body.collision_mask = 0
	barrier_mesh.visible = false
	
	# Activate AI opponent
	if ai_opponent:
		print("GameMode: Activating AI opponent for FIGHT phase")
		ai_opponent.set_active(true)
	else:
		print("GameMode: No AI opponent found!")

func enter_results_state():
	current_state = RoundState.RESULTS
	state_label.text = "ROUND OVER"
	timer_label.text = "CLICK TO CONTINUE"
	
	# Deactivate AI
	if ai_opponent:
		ai_opponent.set_active(false)
	
	# Show results screen
	_show_results_screen()

func _show_results_screen():
	if results_screen:
		results_screen.show_results(player_damage_dealt, player_damage_received, ai_damage_dealt, ai_damage_received)
	else:
		# Fallback to console output
		print("=== ROUND RESULTS ===")
		print("Player Damage Dealt: ", player_damage_dealt)
		print("Player Damage Received: ", player_damage_received)
		print("AI Damage Dealt: ", ai_damage_dealt)
		print("AI Damage Received: ", ai_damage_received)
		print("===================")

func _reset_damage_tracking():
	player_damage_dealt = 0.0
	player_damage_received = 0.0
	ai_damage_dealt = 0.0
	ai_damage_received = 0.0

func _reset_round():
	# Hide results screen if visible
	if results_screen and results_screen.visible:
		results_screen.hide_results()
	
	# Reset positions
	_reset_positions()
	
	# Reset damage tracking
	_reset_damage_tracking()
	
	print("Round reset complete")

func _reset_positions():
	# Reset player position
	var player = get_node("../Player")
	if player:
		player.global_position = Vector3(0, 2, 0)
	
	# Reset AI position
	if ai_opponent:
		ai_opponent.global_position = Vector3(10, 2, 10)
	
	# Reset pickups (you can expand this as needed)
	var pickups = get_node("../Pickups")
	if pickups:
		# Reset pickup positions here if needed
		pass

func on_player_ko(player: Node):
	# A player has been knocked out
	winner_text = "AI Opponent"
	enter_results_state()

func _on_ai_ko():
	# AI has been knocked out
	winner_text = "Player"
	enter_results_state()
