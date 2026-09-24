class_name Act0TriggerBuilder
extends Node3D

func _ready()->void:
	_gate(Vector3(0,1,-73),"TempleGate","res://scripts/world/temple_gate.gd")
	_interact(Vector3(0,1,-101),"Keeper","keeper")
	_interact(Vector3(0,1,-105),"Covenant","covenant")
	_interact(Vector3(-4.5,1,-82),"Smith","smith")
	_interact(Vector3(0,1,-112),"CatacombsEntry","catacombs")
	for i in range(5):
		_room(Vector3(0,1,-122.0-float(i)*13.0),"CatacombRoom%d"%(i+1),i+1)

func _area(name:String,pos:Vector3)->Area3D:
	var a:=Area3D.new()
	a.name=name
	a.position=pos
	var c:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(5,2.5,3)
	c.shape=shape
	a.add_child(c)
	return a

func _gate(pos:Vector3,name:String,script_path:String)->void:
	var a:=_area(name,pos)
	a.set_script(load(script_path))
	add_child(a)

func _interact(pos:Vector3,name:String,kind:String)->void:
	var a:=_area(name,pos)
	a.set_script(load("res://scripts/world/temple_interaction.gd"))
	a.set("interaction",kind)
	add_child(a)

func _room(pos:Vector3,name:String,index:int)->void:
	var a:=_area(name,pos)
	a.set_script(load("res://scripts/world/catacomb_room_trigger.gd"))
	a.set("room",index)
	add_child(a)
