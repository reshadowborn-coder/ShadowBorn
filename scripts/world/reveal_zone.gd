class_name RevealZone
extends Area3D

@export var reveal_id := "temple"
var used := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if used or not body.is_in_group("player"): return
	used = true
	var game := get_tree().get_first_node_in_group("chapter00_game")
	if game and game.has_method("play_world_reveal"):
		game.play_world_reveal(reveal_id)
