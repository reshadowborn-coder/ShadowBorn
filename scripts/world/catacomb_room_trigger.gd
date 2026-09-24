class_name CatacombRoomTrigger
extends Area3D

@export_range(1,5) var room:=1

func _ready()->void:
	body_entered.connect(_enter)

func _enter(body:Node)->void:
	if not body.is_in_group("player"):
		return
	var game:=get_tree().get_first_node_in_group("chapter00_game")
	if game and game.has_method("enter_catacomb_room"):
		# body_entered already debounces a single crossing. Do not permanently
		# consume the trigger: death/retry and save/resume need it again.
		game.enter_catacomb_room(room)
