extends Area3D
class_name Workbench

signal player_entered_workbench(player: Player)
signal player_exited_workbench(player: Player)

var nearby_player: Player = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("workbench")

func _on_body_entered(body: Node):
	if body.name == "Player":
		nearby_player = body as Player

func _on_body_exited(body: Node):
	if body.name == "Player" and nearby_player == body:
		nearby_player = null

func can_craft() -> bool:
	var game_mode = get_node("/root/Main/GameMode")
	if game_mode:
		return game_mode.current_state == game_mode.RoundState.PREP and nearby_player != null
	return false

func try_craft():
	if not can_craft():
		return false
	
	if nearby_player and nearby_player.can_craft_weapon():
		nearby_player.craft_weapon()
		return true
	return false
