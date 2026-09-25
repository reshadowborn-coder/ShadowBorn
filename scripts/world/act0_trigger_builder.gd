class_name Act0TriggerBuilder
extends Node3D

func _ready()->void:
	_gate(Act0Layout.TEMPLE_GATE_TRIGGER,"TempleGate","res://scripts/world/temple_gate.gd",Act0Layout.TEMPLE_GATE_TRIGGER_SIZE)
	_gate(Act0Layout.FADED_SIGIL_TRIGGER,"FadedSigil","res://scripts/world/faded_sigil_threshold.gd",Act0Layout.FADED_SIGIL_TRIGGER_SIZE)
	_interact(Act0Layout.KEEPER_TRIGGER,"Keeper","keeper")
	_interact(Act0Layout.COVENANT_TRIGGER,"Covenant","covenant")
	_interact(Act0Layout.SMITH_TRIGGER,"Smith","smith")
	_interact(Act0Layout.MERCHANT_TRIGGER,"Merchant","merchant")
	_interact(Act0Layout.ENGRAVER_TRIGGER,"Engraver","engraver")
	_interact(Act0Layout.CATACOMBS_TRIGGER,"CatacombsEntry","catacombs")
	for room in range(1,6):
		_room(Act0Layout.catacomb_room_trigger_position(room),"CatacombRoom%d"%room,room)

func _area(name:String,pos:Vector3,size:Vector3=Act0Layout.TEMPLE_INTERACTION_TRIGGER_SIZE)->Area3D:
	var a:=Area3D.new()
	a.name=name
	a.position=pos
	var c:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	c.shape=shape
	a.add_child(c)
	return a

func _gate(pos:Vector3,name:String,script_path:String,size:Vector3)->void:
	var a:=_area(name,pos,size)
	a.set_script(load(script_path))
	add_child(a)

func _interact(pos:Vector3,name:String,kind:String)->void:
	var a:=_area(name,pos)
	a.set_script(load("res://scripts/world/temple_interaction.gd"))
	a.set("interaction",kind)
	add_child(a)

func _room(pos:Vector3,name:String,index:int)->void:
	var a:=_area(name,pos,Act0Layout.CATACOMB_ROOM_TRIGGER_SIZE)
	a.set_script(load("res://scripts/world/catacomb_room_trigger.gd"))
	a.set("room",index)
	add_child(a)
