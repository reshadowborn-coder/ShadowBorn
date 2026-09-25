class_name TempleInteriorBuilder
extends Node3D

const STONE:=Color(0.17,0.18,0.19)
const FLOOR:=Color(0.10,0.105,0.11)
const WOOD:=Color(0.18,0.115,0.07)
const IRON:=Color(0.15,0.15,0.15)
const EMBER:=Color(0.52,0.20,0.07)
const CLOTH:=Color(0.16,0.09,0.08)
const SKIN:=Color(0.34,0.30,0.27)
const LEATHER:=Color(0.21,0.13,0.08)
const MERCHANT_CLOTH:=Color(0.12,0.13,0.16)
const ENGRAVER_CLOTH:=Color(0.12,0.09,0.17)
const NPC_AMBIENT:=preload("res://scripts/world/temple_npc_ambient.gd")
var mats:={}
var meshes:={}

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
	_build_smith(Act0Layout.floor_anchor(Act0Layout.SMITH_TRIGGER),visual)
	_build_merchant(Act0Layout.floor_anchor(Act0Layout.MERCHANT_TRIGGER),visual)
	_build_engraver(Act0Layout.floor_anchor(Act0Layout.ENGRAVER_TRIGGER),visual)
	_build_keeper(Act0Layout.floor_anchor(Act0Layout.KEEPER_TRIGGER),visual)
	_build_weapon_altar(Act0Layout.floor_anchor(Act0Layout.COVENANT_TRIGGER),visual)

func _ambient_root(name:String,role:String,p:Vector3,parent:Node3D,style:int,phase:float=0.0)->Node3D:
	var r:=Node3D.new()
	r.name=name
	r.position=p
	r.set_script(NPC_AMBIENT)
	r.set("style",style)
	r.set("phase_offset",phase)
	r.set_meta("role",role)
	r.add_to_group("temple_ambient_npc")
	parent.add_child(r)
	return r

func _add_humanoid_core(r:Node3D,body_color:Color,body_size:Vector3=Vector3(.78,1.55,.52),head_y:float=1.95)->void:
	box("Body",Vector3(0,1.0,0),body_size,body_color,r)
	box("Head",Vector3(0,head_y,0),Vector3(.48,.55,.45),SKIN,r)

func _add_work_arm(r:Node3D,name:String,local_pos:Vector3,color:Color)->Node3D:
	var arm:=Node3D.new()
	arm.name=name
	arm.position=local_pos
	r.add_child(arm)
	box("ArmMesh",Vector3(0,-.34,0),Vector3(.18,.72,.18),color,arm)
	return arm

func _build_smith(p:Vector3,parent:Node3D)->void:
	var station:=Node3D.new()
	station.name="SmithStation"
	station.position=p
	parent.add_child(station)
	box("Anvil",Vector3(0,.7,0),Vector3(1.4,.45,.65),IRON,station)
	box("Forge",Vector3(-1.2,.8,.4),Vector3(1.3,1.6,1.2),STONE,station)
	box("Ember",Vector3(-1.2,1.15,-.25),Vector3(.75,.25,.08),EMBER,station)

	var smith:=_ambient_root("Smith","smith",Vector3(1.15,0,.55),station,TempleNPCAmbient.Style.SMITH,0.15)
	smith.rotation_degrees.y=-18.0
	_add_humanoid_core(smith,LEATHER,Vector3(.95,1.55,.6),1.98)
	var work_arm:=_add_work_arm(smith,"WorkArm",Vector3(-.42,1.55,-.05),LEATHER)
	var hammer:=Node3D.new()
	hammer.name="WorkProp"
	hammer.position=Vector3(0,-.72,0)
	work_arm.add_child(hammer)
	box("HammerHandle",Vector3(0,-.18,0),Vector3(.12,.75,.12),WOOD,hammer)
	box("HammerHead",Vector3(0,-.55,0),Vector3(.55,.22,.26),IRON,hammer)
	_add_work_arm(smith,"OffArm",Vector3(.42,1.48,-.02),LEATHER)

func _build_merchant(p:Vector3,parent:Node3D)->void:
	var station:=Node3D.new()
	station.name="MerchantStation"
	station.position=p
	parent.add_child(station)
	box("Counter",Vector3(0,.65,0),Vector3(3,1.3,.8),WOOD,station)
	box("Shelf",Vector3(0,1.8,.8),Vector3(3.4,.18,.7),WOOD,station)
	# Large cloth/gear silhouettes behind the counter make the merchant read
	# as a trader even before final authored assets replace the graybox.
	box("HangingClothL",Vector3(-1.05,2.25,1.0),Vector3(.8,1.0,.08),Color(.18,.10,.09),station)
	box("HangingClothR",Vector3(.85,2.18,1.0),Vector3(.75,.9,.08),Color(.10,.13,.16),station)

	var merchant:=_ambient_root("Merchant","merchant",Vector3(0,0,.72),station,TempleNPCAmbient.Style.MERCHANT,1.1)
	_add_humanoid_core(merchant,MERCHANT_CLOTH)
	_add_work_arm(merchant,"WorkArm",Vector3(-.38,1.48,-.12),MERCHANT_CLOTH)
	var focus:=Node3D.new()
	focus.name="FocusProp"
	focus.position=Vector3(.42,1.18,-.42)
	merchant.add_child(focus)
	box("SmallGoods",Vector3.ZERO,Vector3(.34,.18,.28),Color(.22,.17,.10),focus)

func _build_engraver(p:Vector3,parent:Node3D)->void:
	var station:=Node3D.new()
	station.name="EngraverStation"
	station.position=p
	parent.add_child(station)
	box("RuneTable",Vector3(0,.7,0),Vector3(2.4,1.1,1.4),STONE,station)
	for i in range(3):
		box("RuneStone",Vector3(-.65+i*.65,1.4,0),Vector3(.32,.32,.32),Color(.19,.15,.23),station)

	var engraver:=_ambient_root("Engraver","engraver",Vector3(0,0,.72),station,TempleNPCAmbient.Style.ENGRAVER,2.0)
	engraver.rotation_degrees.y=180.0
	_add_humanoid_core(engraver,ENGRAVER_CLOTH)
	_add_work_arm(engraver,"WorkArm",Vector3(-.36,1.52,-.05),ENGRAVER_CLOTH)
	_add_work_arm(engraver,"OffArm",Vector3(.36,1.48,-.02),ENGRAVER_CLOTH)
	var focus:=Node3D.new()
	focus.name="FocusProp"
	focus.position=Vector3(0,1.36,-.52)
	engraver.add_child(focus)
	box("RuneFocus",Vector3.ZERO,Vector3(.30,.08,.30),Color(.24,.16,.31),focus)

func _build_keeper(p:Vector3,parent:Node3D)->void:
	var keeper:=_ambient_root("Keeper","keeper",p,parent,TempleNPCAmbient.Style.KEEPER,2.8)
	_add_humanoid_core(keeper,CLOTH,Vector3(.75,1.7,.5),2.05)
	_add_work_arm(keeper,"WorkArm",Vector3(-.34,1.42,-.08),CLOTH)
	_add_work_arm(keeper,"OffArm",Vector3(.34,1.42,-.08),CLOTH)

func _build_weapon_altar(p:Vector3,parent:Node3D)->void:
	var r:=Node3D.new()
	r.name="ForgottenCovenant"
	r.position=p
	parent.add_child(r)
	box("Altar",Vector3(0,.55,0),Vector3(5,1.1,2.2),STONE,r)
	var names=["SwordShield","Bow","TwoHandAxe","DualDaggers","MageStaff"]
	for i in range(names.size()):
		box(names[i],Vector3(-1.6+i*.8,1.35,0),Vector3(.12,1.0,.12),Color(.12,.13,.16),r)
