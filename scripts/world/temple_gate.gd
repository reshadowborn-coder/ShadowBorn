class_name TempleGate
extends Area3D

var used:=false
var blocker:StaticBody3D

func _ready()->void:
	body_entered.connect(_enter)
	_build_blocker()
	set_process(true)

func _build_blocker()->void:
	blocker=StaticBody3D.new()
	blocker.name="ProgressionBlocker"
	var shape_node:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Act0Layout.TEMPLE_GATE_BLOCKER_SIZE
	shape_node.shape=shape
	blocker.add_child(shape_node)
	add_child(blocker)

func _process(_delta:float)->void:
	if blocker==null:
		set_process(false)
		return
	var game:=get_tree().get_first_node_in_group("chapter00_game")
	if game and game.is_encounter_cleared("shield_boss") and game.act0.faded_sigil_activated:
		blocker.queue_free()
		blocker=null
		set_process(false)

func _enter(body:Node)->void:
	if used or not body.is_in_group("player"):
		return
	var game:=get_tree().get_first_node_in_group("chapter00_game")
	if game==null:
		return
	if not game.is_encounter_cleared("shield_boss"):
		game.story_toast.show_message("The Temple threshold does not answer. Something still waits behind you.")
		return
	if not game.act0.faded_sigil_activated:
		game.story_toast.show_message("A faded sigil stirs before the sealed threshold.")
		return
	if game.enter_temple():
		used=true
		monitoring=false
