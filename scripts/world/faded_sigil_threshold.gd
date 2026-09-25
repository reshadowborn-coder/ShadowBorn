class_name FadedSigilThreshold
extends Area3D

var consumed:=false

func _ready()->void:
	body_entered.connect(_enter)
	call_deferred("_sync_saved_state")

func _sync_saved_state()->void:
	var game:=get_tree().get_first_node_in_group("chapter00_game")
	if game and game.act0.faded_sigil_activated:
		consumed=true
		monitoring=false

func _enter(body:Node)->void:
	if consumed or not body.is_in_group("player"):
		return
	var game:=get_tree().get_first_node_in_group("chapter00_game")
	if game==null or not game.has_method("activate_faded_sigil"):
		return
	if game.activate_faded_sigil():
		consumed=true
		monitoring=false
