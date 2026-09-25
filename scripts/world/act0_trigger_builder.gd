class_name Act0TriggerBuilder
extends Node3D

const TEMPLE_GATE_SCRIPT := preload("res://scripts/world/temple_gate.gd")
const FADED_SIGIL_SCRIPT := preload("res://scripts/world/faded_sigil_threshold.gd")
const TEMPLE_INTERACTION_SCRIPT := preload("res://scripts/world/temple_interaction.gd")
const CATACOMB_ROOM_SCRIPT := preload("res://scripts/world/catacomb_room_trigger.gd")

func _ready()->void:
	_gate(Act0Layout.TEMPLE_GATE_TRIGGER,"TempleGate",TEMPLE_GATE_SCRIPT,Act0Layout.TEMPLE_GATE_TRIGGER_SIZE)
	_gate(Act0Layout.FADED_SIGIL_TRIGGER,"FadedSigil",FADED_SIGIL_SCRIPT,Act0Layout.FADED_SIGIL_TRIGGER_SIZE)
	_interact(Act0Layout.KEEPER_TRIGGER,"Keeper","keeper",Act0Layout.KEEPER_TRIGGER_SIZE)
	_interact(Act0Layout.COVENANT_TRIGGER,"Covenant","covenant",Act0Layout.COVENANT_TRIGGER_SIZE)
	_interact(Act0Layout.SMITH_TRIGGER,"Smith","smith")
	_interact(Act0Layout.MERCHANT_TRIGGER,"Merchant","merchant")
	_interact(Act0Layout.ENGRAVER_TRIGGER,"Engraver","engraver")
	_interact(Act0Layout.CATACOMBS_TRIGGER,"CatacombsEntry","catacombs",Act0Layout.CATACOMB_ENTRY_TRIGGER_SIZE)
	for room in range(1,6):
		_room(Act0Layout.catacomb_room_trigger_position(room),"CatacombRoom%d"%room,room)

func _area(name:String,pos:Vector3,size:Vector3=Act0Layout.TEMPLE_INTERACTION_TRIGGER_SIZE)->Area3D:
	var area:=Area3D.new()
	area.name=name
	area.position=pos
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	area.add_child(collision)
	return area

func _gate(pos:Vector3,name:String,script:Script,size:Vector3)->void:
	var area:=_area(name,pos,size)
	area.set_script(script)
	add_child(area)

func _interact(pos:Vector3,name:String,kind:String,size:Vector3=Act0Layout.TEMPLE_INTERACTION_TRIGGER_SIZE)->void:
	var area:=_area(name,pos,size)
	area.set_script(TEMPLE_INTERACTION_SCRIPT)
	area.set("interaction",kind)
	add_child(area)

func _room(pos:Vector3,name:String,index:int)->void:
	var area:=_area(name,pos,Act0Layout.CATACOMB_ROOM_TRIGGER_SIZE)
	area.set_script(CATACOMB_ROOM_SCRIPT)
	area.set("room",index)
	add_child(area)
