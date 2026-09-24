class_name EncounterTrigger
extends Area3D

@export var encounter_id := "hound"
@export var enemy_hp := 12.0
@export var enemy_def := 2.0
@export var enemy_damage := 2.0
var consumed := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	call_deferred("_sync_saved_state")

func _sync_saved_state() -> void:
	var game := get_tree().get_first_node_in_group("chapter00_game")
	if game and game.is_encounter_cleared(encounter_id):
		consumed = true
		monitoring = false

func _on_body_entered(body: Node3D) -> void:
	if consumed or not body.is_in_group("player"):
		return
	var game := get_tree().get_first_node_in_group("chapter00_game")
	if game == null:
		return
	if game.is_encounter_cleared(encounter_id):
		consumed = true
		monitoring = false
		return
	# Do not consume on start. A failed encounter must be triggerable again
	# after the player returns to the checkpoint and re-enters this Area3D.
	game.begin_encounter(encounter_id,{"hp":enemy_hp,"def":enemy_def,"damage":enemy_damage})
