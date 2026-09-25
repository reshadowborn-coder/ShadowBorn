class_name Act1RoomTrigger
extends Area3D

@export_range(1,3) var room:=1

func _ready()->void:
	body_entered.connect(_enter)

func _enter(body:Node)->void:
	if not body.is_in_group("player"):
		return
	var game:=get_tree().get_first_node_in_group("chapter01_game")
	if game and game.has_method("enter_sewer_room"):
		game.enter_sewer_room(room)