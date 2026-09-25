class_name TempleInteriorBuilder
extends Node3D

const STONE:=Color(0.17,0.18,0.19)
const FLOOR:=Color(0.10,0.105,0.11)
const WOOD:=Color(0.18,0.115,0.07)
const IRON:=Color(0.15,0.15,0.15)
const EMBER:=Color(0.52,0.20,0.07)
const CLOTH:=Color(0.16,0.09,0.08)
const SKIN:=Color(0.34,0.30,0.27)
const LEATHER:=Color(0.20,0.13,0.08)
const RUNE:=Color(0.24,0.18,0.31)
const ASH_CLOTH:=Color(0.10,0.105,0.12)
const NPC_IDLE_SCRIPT:=preload("res://scripts/world/temple_npc_idle.gd")
var mats:={}
var meshes:={}
var capsule_meshes:={}

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

func _mesh(s:Vector3,c:Color)->BoxMesh:
	var key:=str(s)+"|"+str(c)
	if meshes.has(key):
		return meshes[key]
	var mesh:=BoxMesh.new()
	mesh.size=s
	mesh.material=_mat(c)
	meshes[key]=mesh
	return mesh

func _capsule_mesh(radius:float,height:float,c:Color)->CapsuleMesh:
	var key:="%0.3f|%0.3f|%s"%[radius,height,str(c)]
	if capsule_meshes.has(key):
		return capsule_meshes[key]
	var mesh:=CapsuleMesh.new()
	mesh.radius=radius
	mesh.height=height
	mesh.radial_segments=8
	mesh.rings=4
	mesh.material=_mat(c)
	capsule_meshes[key]=mesh
	return mesh

func capsule(n:String,p:Vector3,radius:float,height:float,c:Color,parent:Node3D)->MeshInstance3D:
	var x:=MeshInstance3D.new()
	x.name=n
	x.mesh=_capsule_mesh(radius,height,c)
	x.position=p
	parent.add_child(x)
	return x

func box(n:String,p:Vector3,s:Vector3,c:Color=STONE,parent:Node3D=self)->MeshInstance3D:
	var x:=MeshInstance3D.new()
	x.name=n
	x.mesh=_mesh(s,c)
	x.position=p
	parent.add_child(x)
	return x

func solid_box(n:String,p:Vector3,s:Vector3,visual:Node3D,collision:StaticBody3D,c:Color=STONE)->void:
	box(n,p,s,c,visual)
	var shape_node:=CollisionShape3D.new()
	shape_node.name=n+"Shape"
	shape_node.position=p
	var shape:=BoxShape3D.new()
	shape.size=s
	shape_node.shape=shape
	collision.add_child(shape_node)

func _build()->void:
	var visual:=Node3D.new()
	visual.name="TempleVisual"
	add_child(visual)
	var collision:=StaticBody3D.new()
	collision.name="TempleCollision"
	add_child(collision)

	solid_box("NaveFloor",Vector3(0,-.2,-86),Vector3(18,.4,30),visual,collision,FLOOR)
	solid_box("ApseFloor",Vector3(0,-.18,-104),Vector3(14,.36,10),visual,collision,FLOOR)
	solid_box("CatacombPassageFloor",Vector3(0,-.18,-112.75),Vector3(8,.36,7.5),visual,collision,FLOOR)

	for x in [-7.0,7.0]:
		# Continuous from the Temple threshold to the rear wall. The previous
		# short wall left a side escape gap between nave and apse.
		solid_box("NaveWall",Vector3(x,3.5,-90),Vector3(.8,7,38),visual,collision,STONE)

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
	_build_covenant_focus(visual)
	_build_smith(Act0Layout.floor_anchor(Act0Layout.SMITH_TRIGGER),visual)
	_build_merchant(Act0Layout.floor_anchor(Act0Layout.MERCHANT_TRIGGER),visual)
	_build_engraver(Act0Layout.floor_anchor(Act0Layout.ENGRAVER_TRIGGER),visual)
	_build_keeper(Act0Layout.floor_anchor(Act0Layout.KEEPER_TRIGGER),visual)
	_build_weapon_altar(Act0Layout.floor_anchor(Act0Layout.COVENANT_TRIGGER),visual)

func _build_covenant_focus(parent:Node3D)->void:
	box("CovenantSpineL",Vector3(-2.6,2.2,-106.45),Vector3(.42,4.4,.42),STONE,parent)
	box("CovenantSpineR",Vector3(2.6,2.2,-106.45),Vector3(.42,4.4,.42),STONE,parent)
	box("CovenantCrown",Vector3(0,4.15,-106.45),Vector3(5.6,.42,.42),STONE,parent)
	box("CovenantRuneCore",Vector3(0,2.0,-105.62),Vector3(.28,1.15,.12),RUNE,parent)
	var cross:=box("CovenantRuneCross",Vector3(0,2.0,-105.58),Vector3(1.15,.20,.10),RUNE,parent)
	cross.rotation_degrees.z=8.0

func _build_npc_root(n:String,profile:String,position:Vector3,yaw:float,body_color:Color,accent:Color,parent:Node3D,phase:float)->Node3D:
	var r:=Node3D.new()
	r.name=n
	r.position=position
	r.rotation_degrees.y=yaw
	r.set_script(NPC_IDLE_SCRIPT)
	r.motion_profile=profile
	r.phase=phase

	capsule("Body",Vector3(0,1.12,0),.34,1.45,body_color,r)
	capsule("Head",Vector3(0,2.05,-.02),.25,.52,SKIN,r)
	box("Shoulders",Vector3(0,1.52,0),Vector3(.92,.18,.38),accent,r)
	box("ArmL",Vector3(-.43,1.12,0),Vector3(.15,.86,.16),body_color,r)
	box("ArmR",Vector3(.43,1.12,0),Vector3(.15,.86,.16),body_color,r)
	box("LegL",Vector3(-.18,.28,0),Vector3(.18,.82,.20),ASH_CLOTH,r)
	box("LegR",Vector3(.18,.28,0),Vector3(.18,.82,.20),ASH_CLOTH,r)
	box("Mantle",Vector3(0,1.05,.22),Vector3(.72,1.20,.09),accent,r)
	parent.add_child(r)
	return r

func _build_smith(p:Vector3,parent:Node3D)->void:
	var r:=Node3D.new()
	r.name="SmithStation"
	r.position=p
	parent.add_child(r)
	box("ServiceBackdrop",Vector3(-1.78,1.9,.2),Vector3(.24,3.8,3.8),STONE,r)
	box("ForgeSigil",Vector3(-1.62,2.55,.2),Vector3(.08,1.15,.55),EMBER,r)
	box("Anvil",Vector3(0,.7,0),Vector3(1.4,.45,.65),IRON,r)
	box("Forge",Vector3(-1.2,.8,.9),Vector3(1.3,1.6,1.2),STONE,r)
	box("Ember",Vector3(-1.2,1.15,.25),Vector3(.75,.25,.08),EMBER,r)
	var npc:=_build_npc_root("SmithNPC","smith",Vector3(-.92,0,.35),-90.0,LEATHER,IRON,r,.2)
	var tool:=Node3D.new()
	tool.name="Tool"
	tool.position=Vector3(.52,1.12,-.20)
	tool.rotation_degrees.z=-18.0
	box("HammerHandle",Vector3(0,.28,0),Vector3(.10,1.10,.10),WOOD,tool)
	box("HammerHead",Vector3(.10,.80,0),Vector3(.48,.20,.18),IRON,tool)
	npc.add_child(tool)
	box("Apron",Vector3(0,1.05,-.24),Vector3(.58,1.20,.08),Color(.15,.105,.07),npc)

func _build_merchant(p:Vector3,parent:Node3D)->void:
	var r:=Node3D.new()
	r.name="MerchantStation"
	r.position=p
	parent.add_child(r)
	box("ServiceBackdrop",Vector3(1.78,1.9,.2),Vector3(.24,3.8,3.8),STONE,r)
	box("TradeSigil",Vector3(1.62,2.55,.2),Vector3(.08,1.0,.68),WOOD,r)
	box("Counter",Vector3(0,.65,0),Vector3(3,1.3,.8),WOOD,r)
	box("Shelf",Vector3(.75,1.8,.8),Vector3(1.8,.18,.7),WOOD,r)
	for i in range(3):
		box("Goods%02d"%i,Vector3(-.72+i*.58,1.46,.74),Vector3(.34,.30,.34),Color(.24,.16,.09),r)
	var npc:=_build_npc_root("MerchantNPC","merchant",Vector3(.92,0,.52),90.0,CLOTH,WOOD,r,1.3)
	box("Hood",Vector3(0,2.16,.06),Vector3(.58,.42,.48),CLOTH,npc)

func _build_engraver(p:Vector3,parent:Node3D)->void:
	var r:=Node3D.new()
	r.name="EngraverStation"
	r.position=p
	parent.add_child(r)
	box("ServiceBackdrop",Vector3(-1.78,1.9,.2),Vector3(.24,3.8,3.8),STONE,r)
	box("RuneSigil",Vector3(-1.62,2.55,.2),Vector3(.08,1.05,.62),RUNE,r)
	box("RuneTable",Vector3(0,.7,0),Vector3(2.4,1.1,1.4),STONE,r)
	for i in range(3):
		box("RuneStone",Vector3(-.65+i*.65,1.4,0),Vector3(.32,.32,.32),RUNE,r)
	var npc:=_build_npc_root("EngraverNPC","engraver",Vector3(-.92,0,.34),-90.0,ASH_CLOTH,RUNE,r,2.1)
	var stylus:=box("Tool",Vector3(.48,1.12,-.18),Vector3(.06,.82,.06),RUNE,npc)
	stylus.rotation_degrees.z=-22.0
	box("RuneSatchel",Vector3(-.46,.90,.20),Vector3(.40,.52,.20),LEATHER,npc)

func _build_keeper(p:Vector3,parent:Node3D)->void:
	box("KeeperBackdrop",p+Vector3(0,2.25,-.72),Vector3(4.4,4.5,.35),STONE,parent)
	box("KeeperSigil",p+Vector3(0,2.65,-.48),Vector3(.16,1.55,.10),RUNE,parent)
	var r:=_build_npc_root("Keeper","keeper",p,180.0,CLOTH,RUNE,parent,.8)
	box("Hood",Vector3(0,2.17,.04),Vector3(.62,.48,.50),CLOTH,r)
	box("PrayerCord",Vector3(0,1.25,-.27),Vector3(.08,.75,.08),RUNE,r)

func _build_weapon_altar(p:Vector3,parent:Node3D)->void:
	var r:=Node3D.new()
	r.name="ForgottenCovenant"
	r.position=p
	parent.add_child(r)
	box("Altar",Vector3(0,.55,0),Vector3(5,1.1,2.2),STONE,r)
	var names=["SwordShield","Bow","TwoHandAxe","DualDaggers","MageStaff"]
	for i in range(names.size()):
		box(names[i],Vector3(-1.6+i*.8,1.35,0),Vector3(.12,1.0,.12),Color(.12,.13,.16),r)
