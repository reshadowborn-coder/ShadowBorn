class_name RevealZone
extends Area3D

@export var reveal_id := "temple"
var used := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	call_deferred("_sync_saved_state")

func _sync_saved_state()->void:
	var game:=get_tree().get_first_node_in_group("chapter00_game")
	if reveal_id=="temple" and game and game.act0.temple_reveal_seen:
		used=true
		monitoring=false

func _on_body_entered(body: Node) -> void:
	if used or not body.is_in_group("player"):
		return
	var game := get_tree().get_first_node_in_group("chapter00_game")
	if game==null or not game.has_method("play_world_reveal"):
		return
	var played:bool=await game.play_world_reveal(reveal_id)
	if played:
		used=true
		monitoring=false
