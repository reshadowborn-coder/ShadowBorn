class_name CatacombsBuilder
extends Node3D

const STONE:=Color(.135,.14,.145)
const FLOOR:=Color(.085,.09,.095)
const BONE:=Color(.43,.41,.36)
const RUST:=Color(.28,.15,.10)
const WOOD:=Color(.20,.13,.08)
const REVENANT:=Color(.20,.19,.22)
var mats:={}
var meshes:={}

func _ready()->void:
	_build()

func mat(c:Color)->StandardMaterial3D:
	var k:=str(c)
	if mats.has(k):
		return mats[k]
	var m:=StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=.95
	mats[k]=m
	return m

func _mesh(s:Vector3,c:Color)->BoxMesh:
	var key:=str(s)+"|"+str(c)
	if meshes.has(key):
		return meshes[key]
	var mesh:=BoxMesh.new()
	mesh.size=s
	mesh.material=mat(c)
	meshes[key]=mesh
	return mesh

func box(n:String,p:Vector3,s:Vector3,c:Color=STONE,parent:Node3D=self)->MeshInstance3D:
	var x:=MeshInstance3D.new()
	x.name=n
	x.mesh=_mesh(s,c)
	x.position=p
	parent.add_child(x)
	return x

func collider(n:String,p:Vector3,s:Vector3,parent:StaticBody3D)->void:
	var shape_node:=CollisionShape3D.new()
	shape_node.name=n+"Shape"
	shape_node.position=p
	var shape:=BoxShape3D.new()
	shape.size=s
	shape_node.shape=shape
	parent.add_child(shape_node)

func solid_box(n:String,p:Vector3,s:Vector3,c:Color,visual:Node3D,collision:StaticBody3D)->void:
	box(n,p,s,c,visual)
	collider(n,p,s,collision)

func capsule(n:String,p:Vector3,radius:float,height:float,c:Color,parent:Node3D)->MeshInstance3D:
	var x:=MeshInstance3D.new()
	x.name=n
	var mesh:=CapsuleMesh.new()
	mesh.radius=radius
	mesh.height=height
	mesh.material=mat(c)
	x.mesh=mesh
	x.position=p
	parent.add_child(x)
	return x

func enemy_root(id:String,p:Vector3,parent:Node3D)->Node3D:
	var root:=Node3D.new()
	root.name="VIS_"+id.to_upper()
	root.position=p
	root.add_to_group("encounter_visual")
	root.set_meta("encounter_id",id)
	parent.add_child(root)
	return root

func build_skeleton(id:String,p:Vector3,parent:Node3D,guarded:bool=false,dark:bool=false)->void:
	var root:=enemy_root(id,p,parent)
	var body_color:=REVENANT if dark else BONE
	capsule("Torso",Vector3(0,.9,0),.34,1.35,body_color,root)
	capsule("Skull",Vector3(0,1.78,0),.27,.55,body_color,root)
	box("LegL",Vector3(-.18,.05,0),Vector3(.17,.9,.17),body_color,root)
	box("LegR",Vector3(.18,.05,0),Vector3(.17,.9,.17),body_color,root)
	box("ArmL",Vector3(-.42,.9,0),Vector3(.14,.85,.14),body_color,root)
	box("ArmR",Vector3(.42,.9,0),Vector3(.14,.85,.14),body_color,root)
	if guarded:
		box("Shield",Vector3(-.62,1.0,-.35),Vector3(1.15,1.65,.16),WOOD,root)
		box("ShieldBand",Vector3(-.62,1.0,-.45),Vector3(1.22,.12,.06),RUST,root)

func build_hound(id:String,p:Vector3,parent:Node3D)->void:
	var root:=enemy_root(id,p,parent)
	var torso:=capsule("Body",Vector3(0,.45,0),.35,1.15,BONE,root)
	torso.rotation_degrees.z=90
	var head:=capsule("Head",Vector3(.62,.58,-.04),.25,.52,BONE,root)
	head.rotation_degrees.z=72
	for leg in [Vector3(-.4,0,-.25),Vector3(-.4,0,.25),Vector3(.35,0,-.25),Vector3(.35,0,.25)]:
		box("Leg",leg,Vector3(.13,.65,.13),BONE,root)

func _build()->void:
	var visual:=Node3D.new()
	visual.name="CatacombVisual"
	add_child(visual)
	var collision:=StaticBody3D.new()
	collision.name="CatacombCollision"
	add_child(collision)

	for i in range(5):
		var z:=Act0Layout.catacomb_room_z(i+1)
		solid_box("Room%02dFloor"%(i+1),Vector3(0,-.2,z),Vector3(12,.4,13),FLOOR,visual,collision)
		solid_box("Room%02dWallL"%(i+1),Vector3(-6,2.2,z),Vector3(.7,4.4,13),STONE,visual,collision)
		solid_box("Room%02dWallR"%(i+1),Vector3(6,2.2,z),Vector3(.7,4.4,13),STONE,visual,collision)
		solid_box("Room%02dArchL"%(i+1),Vector3(-2.8,2.2,z-5.4),Vector3(.8,4.4,.8),STONE,visual,collision)
		solid_box("Room%02dArchR"%(i+1),Vector3(2.8,2.2,z-5.4),Vector3(.8,4.4,.8),STONE,visual,collision)
		solid_box("Room%02dArchTop"%(i+1),Vector3(0,4.1,z-5.4),Vector3(6.4,.7,.8),STONE,visual,collision)
		for j in range(3):
			box("Room%02dBones%02d"%[i+1,j],Vector3(-4.0+j*4.0,.08,z+2.5-(j%2)*4.0),Vector3(1.0,.16,.35),BONE,visual)

	solid_box("Room5Seal",Vector3(0,2.2,-179.0),Vector3(7,4.4,.65),Color(.10,.08,.09),visual,collision)

	build_skeleton("cat_r1_skeleton",Vector3(0,1.0,-124.0),visual)
	build_hound("cat_r2_hound",Vector3(0,0.8,-137.0),visual)
	build_skeleton("cat_r3_guard",Vector3(0,1.0,-150.0),visual,true)
	build_skeleton("cat_r4_revenant",Vector3(0,1.0,-163.0),visual,false,true)
	build_skeleton("cat_r5_skeleton_a",Vector3(-2.0,1.0,-175.5),visual)
	build_skeleton("cat_r5_skeleton_b",Vector3(2.0,1.0,-175.5),visual)
