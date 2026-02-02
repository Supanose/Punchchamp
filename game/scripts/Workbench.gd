extends Area3D
class_name Workbench

signal player_entered_workbench(player: Player)
signal player_exited_workbench(player: Player)

var nearby_player: Player = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("workbench")
	print("Workbench ready and added to group")

func _on_body_entered(body: Node):
	print("Workbench: Body entered: ", body.name)
	if body.name == "Player":
		nearby_player = body as Player
		print("Workbench: Player is now nearby")
		player_entered_workbench.emit(nearby_player)

func _on_body_exited(body: Node):
	print("Workbench: Body exited: ", body.name)
	if body.name == "Player" and nearby_player == body:
		nearby_player = null
		print("Workbench: Player is no longer nearby")
		player_exited_workbench.emit(body as Player)

func can_craft() -> bool:
	var game_mode = get_node("/root/Main/GameMode")
	if game_mode:
		var can_craft = game_mode.current_state == game_mode.RoundState.PREP and nearby_player != null
		print("Workbench: Can craft? State: ", game_mode.current_state, " nearby: ", nearby_player != null, " result: ", can_craft)
		return can_craft
	print("Workbench: No game mode found")
	return false

func try_craft():
	print("Workbench: try_craft called")
	if not can_craft():
		print("Workbench: Cannot craft - can_craft() returned false")
		return false
	
	if nearby_player and nearby_player.can_craft_weapon():
		print("Workbench: Player can craft weapon")
		nearby_player.craft_weapon()
		return true
	else:
		print("Workbench: Player cannot craft weapon - missing parts")
	return false
