class_name Act1TriggerBuilder
extends Node3D

const ROOM_SCRIPT:=preload("res://scripts/world/act1_room_trigger.gd")
const TEMPLE_SCRIPT:=preload("res://scripts/world/act1_temple_interaction.gd")

func _ready()->void:
	for room in range(1,4):
		_add_room(room)
	_add_temple("KeeperAct1",Act1Layout.KEEPER_HANDOFF,"keeper")
	_add_temple("SmithAct1",Act1Layout.SMITH_HANDOFF,"smith")
	_add_temple("GuardAct1",Act1Layout.GUARD_TRIGGER,"guard")

func _area(name_:String,pos:Vector3,size:Vector3)->Area3D:
	var area:=Area3D.new()
	area.name=name_
	area.position=pos
	var shape_node:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	shape_node.shape=shape
	area.add_child(shape_node)
	return area

func _add_room(room:int)->void:
	var area:=_area("SewerRoom%d"%room,Act1Layout.room_trigger(room),Act1Layout.ROOM_TRIGGER_SIZE)
	area.set_script(ROOM_SCRIPT)
	area.set("room",room)
	add_child(area)

func _add_temple(name_:String,pos:Vector3,kind:String)->void:
	var area:=_area(name_,pos,Act1Layout.TEMPLE_HANDOFF_SIZE)
	area.set_script(TEMPLE_SCRIPT)
	area.set("interaction",kind)
	add_child(area)