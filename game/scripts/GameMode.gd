extends Node

enum RoundState {
	PREP,
	FIGHT,
	END
}

@onready var state_label: Label = $"../UI/StateLabel"
@onready var timer_label: Label = $"../UI/TimerLabel"
@onready var barrier_static_body: StaticBody3D = $"../Barrier/StaticBody3D"
@onready var barrier_mesh: MeshInstance3D = $"../Barrier/MeshInstance3D"
@onready var parts_label: Label = $"../UI/PartsLabel"
@onready var weapon_label: Label = $"../UI/WeaponLabel"

var current_state: RoundState = RoundState.PREP
var prep_timer: float = 60.0
var fight_timer: float = 10.0
var end_timer: float = 3.0

func _ready():
	enter_prep_state()

func _process(delta):
	match current_state:
		RoundState.PREP:
			prep_timer -= delta
			timer_label.text = "PREP: %d" % int(prep_timer)
			
			if prep_timer <= 0:
				enter_fight_state()
		
		RoundState.FIGHT:
			fight_timer -= delta
			timer_label.text = "FIGHT: %d" % int(fight_timer)
			
			if fight_timer <= 0:
				enter_end_state()
		
		RoundState.END:
			end_timer -= delta
			timer_label.text = "Round Over"
			
			if end_timer <= 0:
				enter_prep_state()
	
	# Update UI
	_update_ui()

func _update_ui():
	var player = get_node("../Player")
	if player:
		var parts_display = player.get_parts_display()
		var weapon_display = player.get_weapon_display()
		parts_label.text = "Parts: %s" % parts_display
		weapon_label.text = "Weapon: %s" % weapon_display

func enter_prep_state():
	current_state = RoundState.PREP
	prep_timer = 60.0
	state_label.text = "PREP"
	
	# Enable barrier
	barrier_static_body.collision_layer = 1
	barrier_static_body.collision_mask = 1
	barrier_mesh.visible = true
	
	# Reset player loadout
	var player = get_node("../Player")
	if player:
		player.reset_loadout()

func enter_fight_state():
	current_state = RoundState.FIGHT
	fight_timer = 10.0
	state_label.text = "FIGHT"
	
	# Disable barrier
	barrier_static_body.collision_layer = 0
	barrier_static_body.collision_mask = 0
	barrier_mesh.visible = false

func enter_end_state():
	current_state = RoundState.END
	end_timer = 3.0
	state_label.text = "END"
