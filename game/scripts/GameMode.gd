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

func enter_prep_state():
	current_state = RoundState.PREP
	prep_timer = 60.0
	state_label.text = "PREP"
	
	# Enable barrier
	barrier_static_body.collision_layer = 1
	barrier_static_body.collision_mask = 1
	barrier_mesh.visible = true

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
