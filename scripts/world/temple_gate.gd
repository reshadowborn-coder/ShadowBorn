class_name TempleGate
extends Area3D
var used:=false
func _ready()->void: body_entered.connect(_enter)
func _enter(body:Node)->void:
	if used or not body.is_in_group("player"): return
	var game:=get_tree().get_first_node_in_group("chapter00_game")
	if game and game.is_encounter_cleared("shield_boss"):
		used=true
		game.enter_temple()
