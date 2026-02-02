extends Area3D
class_name PartPickup

enum PartType {
	CORE,
	HANDLE,
	MOD
}

enum CoreType {
	BLADE,
	HAMMER
}

enum HandleType {
	SHORT,
	LONG
}

enum ModType {
	WEIGHT,
	SPIKES
}

@export var part_type: PartType
@export var core_type: CoreType
@export var handle_type: HandleType
@export var mod_type: ModType

@export var damage_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var reach_add: float = 0.0
@export var knockback_mult: float = 1.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready():
	body_entered.connect(_on_body_entered)
	_update_visual()

func _update_visual():
	# Simple color coding for different part types
	var material = StandardMaterial3D.new()
	
	match part_type:
		PartType.CORE:
			match core_type:
				CoreType.BLADE:
					material.albedo_color = Color.RED
				CoreType.HAMMER:
					material.albedo_color = Color.BLUE
		PartType.HANDLE:
			match handle_type:
				HandleType.SHORT:
					material.albedo_color = Color.GREEN
				HandleType.LONG:
					material.albedo_color = Color.YELLOW
		PartType.MOD:
			match mod_type:
				ModType.WEIGHT:
					material.albedo_color = Color.PURPLE
				ModType.SPIKES:
					material.albedo_color = Color.ORANGE
	
	mesh.material_override = material

func _on_body_entered(body: Node):
	if body.name == "Player" and can_pickup():
		var player = body as Player
		if player.try_pickup_part(self):
			queue_free()

func can_pickup() -> bool:
	var game_mode = get_node("/root/Main/GameMode")
	if game_mode:
		return game_mode.current_state == game_mode.RoundState.PREP
	return false

func get_part_name() -> String:
	match part_type:
		PartType.CORE:
			match core_type:
				CoreType.BLADE: return "BladeCore"
				CoreType.HAMMER: return "HammerCore"
		PartType.HANDLE:
			match handle_type:
				HandleType.SHORT: return "ShortHandle"
				HandleType.LONG: return "LongHandle"
		PartType.MOD:
			match mod_type:
				ModType.WEIGHT: return "WeightMod"
				ModType.SPIKES: return "SpikesMod"
	return "Unknown"
