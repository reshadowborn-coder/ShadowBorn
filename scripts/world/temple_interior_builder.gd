class_name TempleInteriorBuilder
extends Node3D

const STONE:=Color(0.17,0.18,0.19)
const FLOOR:=Color(0.10,0.105,0.11)
const WOOD:=Color(0.18,0.115,0.07)
const IRON:=Color(0.15,0.15,0.15)
const EMBER:=Color(0.52,0.20,0.07)
const CLOTH:=Color(0.16,0.09,0.08)
var mats:={}

func _ready()->void:
	_build()

func _mat(c:Color)->StandardMaterial3D:
	var k:=str(c)
	if mats.has(k):
		return mats[k]
	var m:=StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=.92
	mats[k]=m
	return m

func box(n:String,p:Vector3,s:Vector3,c:Color=STONE,parent:Node3D=self)->MeshInstance3D:
	var x:=MeshInstance3D.new()
	x.name=n
	var mesh:=BoxMesh.new()
	mesh.size=s
	mesh.material=_mat(c)
	x.mesh=mesh
	x.position=p
	parent.add_child(x)
	return x

func solid_box(n:String,p:Vector3,s:Vector3,visual:Node3D,collision:Node3D,c:Color=STONE)->void:
	box(n,p,s,c,visual)
	var body:=StaticBody3D.new()
	body.name=n+"Collision"
	body.position=p
	var shape_node:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=s
	shape_node.shape=shape
	body.add_child(shape_node)
	collision.add_child(body)

func _build()->void:
	var visual:=Node3D.new()
	visual.name="TempleVisual"
	add_child(visual)
	var collision:=Node3D.new()
	collision.name="TempleCollision"
	add_child(collision)

	box("NaveFloor",Vector3(0,-.2,-86),Vector3(18,.4,30),FLOOR,visual)
	box("ApseFloor",Vector3(0,-.18,-104),Vector3(14,.36,10),FLOOR,visual)
	box("CatacombPassageFloor",Vector3(0,-.18,-112.75),Vector3(8,.36,7.5),FLOOR,visual)

	for x in [-7.0,7.0]:
		solid_box("NaveWall",Vector3(x,3.5,-89),Vector3(.8,7,34),visual,collision,STONE)

	for z in [-79.0,-86.0,-93.0,-100.0]:
		solid_box("ColumnL",Vector3(-5.0,2.7,z),Vector3(.85,5.4,.85),visual,collision,STONE)
		solid_box("ColumnR",Vector3(5.0,2.7,z),Vector3(.85,5.4,.85),visual,collision,STONE)

	# Rear wall is split so the catacomb route is physically traversable.
	solid_box("RearWallL",Vector3(-5.8,4,-109),Vector3(6.4,8,.9),visual,collision,STONE)
	solid_box("RearWallR",Vector3(5.8,4,-109),Vector3(6.4,8,.9),visual,collision,STONE)
	solid_box("RearLintel",Vector3(0,6.6,-109),Vector3(5.2,2.8,.9),visual,collision,STONE)

	solid_box("PassageWallL",Vector3(-4.0,2.2,-112.75),Vector3(.7,4.4,7.5),visual,collision,STONE)
	solid_box("PassageWallR",Vector3(4.0,2.2,-112.75),Vector3(.7,4.4,7.5),visual,collision,STONE)

	box("CovenantDais",Vector3(0,.2,-105),Vector3(7,.4,5),STONE,visual)
	box("CovenantStone",Vector3(0,1.1,-106),Vector3(3.6,1.8,.65),Color(.12,.12,.14),visual)
	_build_smith(Vector3(-4.5,0,-82),visual)
	_build_merchant(Vector3(4.6,0,-82),visual)
	_build_engraver(Vector3(-4.6,0,-91),visual)
	_build_keeper(Vector3(0,0,-101),visual)
	_build_weapon_altar(Vector3(0,0,-105),visual)

func _build_smith(p:Vector3,parent:Node3D)->void:
	var r:=Node3D.new()
	r.name="SmithStation"
	r.position=p
	parent.add_child(r)
	box("Anvil",Vector3(0,.7,0),Vector3(1.4,.45,.65),IRON,r)
	box("Forge",Vector3(-1.2,.8,.4),Vector3(1.3,1.6,1.2),STONE,r)
	box("Ember",Vector3(-1.2,1.15,-.25),Vector3(.75,.25,.08),EMBER,r)

func _build_merchant(p:Vector3,parent:Node3D)->void:
	var r:=Node3D.new()
	r.name="MerchantStation"
	r.position=p
	parent.add_child(r)
	box("Counter",Vector3(0,.65,0),Vector3(3,1.3,.8),WOOD,r)
	box("Shelf",Vector3(0,1.8,.8),Vector3(3.4,.18,.7),WOOD,r)

func _build_engraver(p:Vector3,parent:Node3D)->void:
	var r:=Node3D.new()
	r.name="EngraverStation"
	r.position=p
	parent.add_child(r)
	box("RuneTable",Vector3(0,.7,0),Vector3(2.4,1.1,1.4),STONE,r)
	for i in range(3):
		box("RuneStone",Vector3(-.65+i*.65,1.4,0),Vector3(.32,.32,.32),Color(.19,.15,.23),r)

func _build_keeper(p:Vector3,parent:Node3D)->void:
	var r:=Node3D.new()
	r.name="Keeper"
	r.position=p
	parent.add_child(r)
	box("Body",Vector3(0,1.0,0),Vector3(.75,1.7,.5),CLOTH,r)
	box("Head",Vector3(0,2.05,0),Vector3(.48,.55,.45),Color(.34,.30,.27),r)

func _build_weapon_altar(p:Vector3,parent:Node3D)->void:
	var r:=Node3D.new()
	r.name="ForgottenCovenant"
	r.position=p
	parent.add_child(r)
	box("Altar",Vector3(0,.55,0),Vector3(5,1.1,2.2),STONE,r)
	var names=["SwordShield","Bow","TwoHandAxe","DualDaggers","MageStaff"]
	for i in range(names.size()):
		box(names[i],Vector3(-1.6+i*.8,1.35,0),Vector3(.12,1.0,.12),Color(.12,.13,.16),r)
