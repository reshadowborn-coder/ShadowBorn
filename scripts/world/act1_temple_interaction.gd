class_name Act1TempleInteraction
extends Area3D

@export_enum("keeper","smith","guard") var interaction:="keeper"

func _ready()->void:
	body_entered.connect(_enter)

func _enter(body:Node)->void:
	if not body.is_in_group("player"):
		return
	var game:=get_tree().get_first_node_in_group("chapter01_game")
	if game and game.has_method("temple_interact"):
		game.temple_interact(interaction)