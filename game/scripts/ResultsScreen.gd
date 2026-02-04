extends Control
class_name ResultsScreen

@onready var player_damage_label: Label = $VBoxContainer/PlayerDamageLabel
@onready var player_received_label: Label = $VBoxContainer/PlayerReceivedLabel
@onready var ai_damage_label: Label = $VBoxContainer/AIDamageLabel
@onready var ai_received_label: Label = $VBoxContainer/AIReceivedLabel

func _ready():
	visible = false

func show_results(player_dealt: float, player_received: float, ai_dealt: float, ai_received: float):
	player_damage_label.text = "Player Damage Dealt: %.0f" % player_dealt
	player_received_label.text = "Player Damage Received: %.0f" % player_received
	ai_damage_label.text = "AI Damage Dealt: %.0f" % ai_dealt
	ai_received_label.text = "AI Damage Received: %.0f" % ai_received
	
	visible = true
	
	# Pause the game
	get_tree().paused = true

func hide_results():
	visible = false
	
	# Unpause the game
	get_tree().paused = false

func _unhandled_input(event):
	if visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_results()
		get_viewport().set_input_as_handled()
