class_name TempleInteraction
extends Area3D

@export_enum("keeper","covenant","smith","merchant","engraver","catacombs") var interaction:="keeper"
var blocker:StaticBody3D

func _ready()->void:
	body_entered.connect(_enter)
	if interaction=="catacombs":
		_build_catacomb_blocker()
		set_process(true)
	else:
		set_process(false)

func _build_catacomb_blocker()->void:
	blocker=StaticBody3D.new()
	blocker.name="ProgressionBlocker"
	var shape_node:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Act0Layout.CATACOMB_GATE_BLOCKER_SIZE
	shape_node.shape=shape
	blocker.add_child(shape_node)
	add_child(blocker)

func _process(_delta:float)->void:
	if blocker==null:
		set_process(false)
		return
	var game:=get_tree().get_first_node_in_group("chapter00_game")
	if game and game.act0.first_forge_done:
		blocker.queue_free()
		blocker=null
		set_process(false)

func _enter(body:Node)->void:
	if not body.is_in_group("player"):
		return
	var game:=get_tree().get_first_node_in_group("chapter00_game")
	if game and game.has_method("temple_interact"):
		game.temple_interact(interaction)
