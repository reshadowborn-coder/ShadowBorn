class_name Ch00GrayboxBuilder
extends Node3D

const STONE := Color(0.22,0.23,0.24)
const GROUND := Color(0.14,0.15,0.14)
const TEMPLE := Color(0.18,0.19,0.20)
const BONE := Color(0.48,0.46,0.40)
const RUST := Color(0.27,0.14,0.09)
const WOOD := Color(0.20,0.14,0.09)
const MOSS := Color(0.10,0.16,0.11)
const ROOF := Color(0.24,0.09,0.065)
const DEADWOOD := Color(0.12,0.095,0.075)
var _materials: Dictionary = {}
var _visual_root: Node3D
var _collision_root: Node3D
const TRIGGER_SCRIPT = preload("res://scripts/combat/encounter_trigger.gd")
const REVEAL_SCRIPT = preload("res://scripts/world/reveal_zone.gd")

func _ready() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualGeometry"
	add_child(_visual_root)
	_collision_root = Node3D.new()
	_collision_root.name = "GameplayCollision"
	add_child(_collision_root)
	_build_route()

func _material(color:Color) -> StandardMaterial3D:
	var key := str(color)
	if _materials.has(key): return _materials[key]
	var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=0.95
	_materials[key]=mat; return mat

func _box(name:String,pos:Vector3,size:Vector3,color:Color=STONE,parent:Node3D=null) -> MeshInstance3D:
	var target := parent if parent != null else _visual_root
	var m:=MeshInstance3D.new(); m.name=name
	var mesh:=BoxMesh.new(); mesh.size=size; mesh.material=_material(color)
	m.mesh=mesh; m.position=pos; target.add_child(m); return m

func _blocker(name:String,pos:Vector3,size:Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new(); body.name=name; body.position=pos
	var shape_node:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; shape_node.shape=shape
	body.add_child(shape_node); _collision_root.add_child(body); return body

func _grave(name:String,pos:Vector3,rot_y:float=0.0) -> Node3D:
	var root:=Node3D.new(); root.name=name; root.position=pos; root.rotation_degrees.y=rot_y; _visual_root.add_child(root)
	_box("Base",Vector3(0,0.10,0),Vector3(1.25,0.20,0.62),STONE,root)
	_box("Marker",Vector3(0,0.72,0.08),Vector3(0.78,1.18,0.24),STONE,root)
	_box("Cap",Vector3(0,1.30,0.08),Vector3(0.95,0.18,0.28),STONE,root).rotation_degrees.z=4.0
	return root

func _broken_column(name:String,pos:Vector3,height:float,rot_z:float=0.0) -> Node3D:
	var root:=Node3D.new(); root.name=name; root.position=pos; root.rotation_degrees.z=rot_z; _visual_root.add_child(root)
	_box("Base",Vector3(0,0.16,0),Vector3(1.25,0.32,1.25),STONE,root)
	_box("Shaft",Vector3(0,height*0.5+0.28,0),Vector3(0.72,height,0.72),STONE,root)
	_box("BrokenCap",Vector3(0,height+0.28,0),Vector3(0.92,0.20,0.92),STONE,root).rotation_degrees.y=17.0
	return root

func _capsule(name:String,pos:Vector3,radius:float,height:float,color:Color,parent:Node3D) -> MeshInstance3D:
	var m:=MeshInstance3D.new(); m.name=name
	var mesh:=CapsuleMesh.new(); mesh.radius=radius; mesh.height=height
	mesh.material=_material(color); m.mesh=mesh; m.position=pos; parent.add_child(m); return m

func _build_route() -> void:
	_build_awaken_pocket()
	_box("CEM_01_Ground",Vector3(0,-0.25,0),Vector3(18,0.5,30),GROUND)
	_box("RUIN_01_Ground",Vector3(2,-0.25,-29),Vector3(15,0.5,28),GROUND)
	_box("TEMPLE_EXT_01_Ground",Vector3(0,-0.25,-58),Vector3(22,0.5,30),GROUND)
	var grave_i:=0
	for z in [-3.0,-8.0,-13.0,-18.0]:
		_grave("GraveL%02d"%grave_i,Vector3(-5.2,0.0,z),-8.0+grave_i*5.0)
		_grave("GraveR%02d"%grave_i,Vector3(4.8,0.0,z-1.3),7.0-grave_i*4.0)
		grave_i+=1
	_box("BrokenWallL",Vector3(-7,1.4,-10),Vector3(0.8,2.8,14)); _box("BrokenWallR",Vector3(7,1.0,-13),Vector3(0.8,2.0,10))
	_blocker("BoundaryL",Vector3(-7,1.4,-10),Vector3(0.8,2.8,14)); _blocker("BoundaryR",Vector3(7,1.0,-13),Vector3(0.8,2.0,10))
	for i in range(6): _box("Step%02d"%i,Vector3(1,0.15+i*0.16,-22-i*1.05),Vector3(7,0.3,1.1))
	_box("RuinArchL",Vector3(-4,2.2,-35),Vector3(1.2,4.4,1.2)); _box("RuinArchR",Vector3(5,2.2,-35),Vector3(1.2,4.4,1.2)); _box("RuinArchTop",Vector3(0.5,4.1,-35),Vector3(10.2,1.0,1.2))
	_box("TempleFacade",Vector3(0,5,-72),Vector3(18,10,3),TEMPLE); _box("TempleTowerL",Vector3(-7,10,-73),Vector3(4,20,4),TEMPLE); _box("TempleTowerR",Vector3(7,9,-73),Vector3(4,18,4),TEMPLE); _box("TempleDoor",Vector3(0,3,-70.4),Vector3(4.2,6,0.4),Color(0.07,0.07,0.065))
	var roof_l:=_box("TempleRoofL",Vector3(-4.6,11.2,-72.5),Vector3(9.5,0.55,5.0),ROOF); roof_l.rotation_degrees.z=-18
	var roof_r:=_box("TempleRoofR",Vector3(4.6,11.2,-72.5),Vector3(9.5,0.55,5.0),ROOF); roof_r.rotation_degrees.z=18
	_box("DoorLintel",Vector3(0,6.3,-70.15),Vector3(6.2,0.7,0.7),STONE)
	_box("EntryColumnL",Vector3(-3.1,3.0,-69.9),Vector3(0.75,6.0,0.75),STONE)
	_box("EntryColumnR",Vector3(3.1,3.0,-69.9),Vector3(0.75,6.0,0.75),STONE)
	_build_environment_props()
	_build_route_occlusion()
	_add_reveal_zone("temple", Vector3(0,0.8,-50.5), Vector3(10,2,4))
	_add_encounter("hound",Vector3(0,0.8,-12),12,2,2)
	_add_encounter("armless",Vector3(1,0.8,-38),15,3,2.4)
	_add_encounter("shield_boss",Vector3(0,0.8,-60),23,8,3.0)
	_build_hound(Vector3(0,0.75,-14.0))
	_build_armless(Vector3(1,0.95,-40.0))
	_build_shield_boss(Vector3(0,1.0,-62.0))

func _build_awaken_pocket() -> void:
	_box("AwakenSlab",Vector3(0,0.12,7.0),Vector3(2.1,0.24,4.0),STONE)
	_box("AwakenWallL",Vector3(-4.8,1.25,5.5),Vector3(0.65,2.5,8.0),STONE)
	_box("AwakenWallR",Vector3(4.5,0.85,4.2),Vector3(0.65,1.7,5.2),STONE)
	var fallen:=_box("AwakenFallenArch",Vector3(2.8,0.65,1.8),Vector3(5.2,0.55,0.8),STONE); fallen.rotation_degrees.z=17
	_box("AwakenGraveMarker",Vector3(-2.2,0.7,6.0),Vector3(0.8,1.4,0.32),STONE)

func _build_route_occlusion() -> void:
	_box("CemeteryTurnMass",Vector3(3.9,1.8,-19.0),Vector3(5.4,3.6,1.2),STONE)
	_box("RuinScreenL",Vector3(-3.8,2.0,-45.5),Vector3(4.5,4.0,1.0),STONE)
	var screen:=_box("RuinScreenR",Vector3(4.8,1.45,-48.0),Vector3(4.0,2.9,1.0),STONE); screen.rotation_degrees.y=-12
	_box("RevealArchL",Vector3(-5.3,2.6,-51.5),Vector3(1.0,5.2,1.0),STONE)
	_box("RevealArchR",Vector3(5.3,1.9,-51.5),Vector3(1.0,3.8,1.0),STONE)
	var top:=_box("RevealArchBrokenTop",Vector3(-1.0,4.8,-51.5),Vector3(7.5,0.8,1.0),STONE); top.rotation_degrees.z=-6

func _add_reveal_zone(id:String,pos:Vector3,size:Vector3) -> void:
	var a:=Area3D.new(); a.name="REVEAL_"+id.to_upper(); a.position=pos; a.script=REVEAL_SCRIPT; a.reveal_id=id
	var c:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; c.shape=shape; a.add_child(c); add_child(a)

func _build_environment_props() -> void:
	var rocks := [Vector3(-6.2,0.25,4),Vector3(5.8,0.18,1),Vector3(-4.8,0.22,-16),Vector3(5.4,0.3,-25),Vector3(-5.5,0.28,-43),Vector3(6.1,0.22,-53)]
	for i in range(rocks.size()):
		var r:=_box("Rock%02d"%i,rocks[i],Vector3(1.4+0.2*(i%2),0.5,1.0),STONE); r.rotation_degrees.y=float(i*31)
	for i in range(5):
		var z:=-5.0-float(i)*9.0
		var side:=-1.0 if i%2==0 else 1.0
		_box("MossPatch%02d"%i,Vector3(side*5.7,0.025,z),Vector3(2.4,0.05,1.5),MOSS)
	for spec in [[Vector3(-7.0,1.9,-2),-8.0],[Vector3(6.7,2.1,-20),11.0],[Vector3(-6.5,2.3,-47),-14.0]]:
		var trunk:=_box("DeadTree",spec[0],Vector3(0.38,4.2,0.38),DEADWOOD); trunk.rotation_degrees.z=spec[1]
		var branch:=_box("Branch",spec[0]+Vector3(0,1.1,0),Vector3(2.2,0.22,0.22),DEADWOOD); branch.rotation_degrees.z=25.0*sign(spec[1])
	_broken_column("ForecourtColumnL",Vector3(-6.2,0,-55),2.9,-3.0)
	_broken_column("ForecourtColumnR",Vector3(6.2,0,-55),2.2,6.0)
	_broken_column("FallenColumn",Vector3(-5.0,0.15,-58.5),2.6,82.0)

func _enemy_root(id:String,pos:Vector3) -> Node3D:
	var root:=Node3D.new(); root.name="VIS_"+id.to_upper(); root.position=pos; root.add_to_group("encounter_visual"); root.set_meta("encounter_id",id); _visual_root.add_child(root); return root

func _build_hound(pos:Vector3) -> void:
	var r:=_enemy_root("hound",pos)
	_capsule("Body",Vector3(0,0.45,0),0.38,1.25,BONE,r).rotation_degrees.z=90
	_capsule("Head",Vector3(0.65,0.58,-0.05),0.28,0.58,BONE,r).rotation_degrees.z=72
	for p in [Vector3(-0.42,0.0,-0.28),Vector3(-0.42,0.0,0.28),Vector3(0.38,0.0,-0.28),Vector3(0.38,0.0,0.28)]: _box("Leg",p,Vector3(0.14,0.7,0.14),BONE,r)

func _build_armless(pos:Vector3) -> void:
	var r:=_enemy_root("armless",pos)
	_capsule("Torso",Vector3(0,0.85,0),0.34,1.45,BONE,r)
	_capsule("Skull",Vector3(0,1.78,0),0.28,0.58,BONE,r)
	_box("LegL",Vector3(-0.18,0.05,0),Vector3(0.18,0.9,0.18),BONE,r); _box("LegR",Vector3(0.18,0.05,0),Vector3(0.18,0.9,0.18),BONE,r)

func _build_shield_boss(pos:Vector3) -> void:
	var r:=_enemy_root("shield_boss",pos)
	_capsule("Torso",Vector3(0,1.0,0),0.48,1.75,Color(0.29,0.29,0.27),r)
	_capsule("Helmet",Vector3(0,2.05,0),0.38,0.72,RUST,r)
	_box("LegL",Vector3(-0.24,0.1,0),Vector3(0.25,1.05,0.25),Color(0.25,0.25,0.23),r); _box("LegR",Vector3(0.24,0.1,0),Vector3(0.25,1.05,0.25),Color(0.25,0.25,0.23),r)
	_box("Arm",Vector3(-0.55,1.15,0),Vector3(0.22,1.1,0.22),Color(0.27,0.27,0.25),r)
	var shield:=_box("Shield",Vector3(-0.62,1.15,-0.42),Vector3(1.25,1.85,0.18),WOOD,r); shield.rotation_degrees.x=-18
	_box("ShieldBand",Vector3(-0.62,1.15,-0.53),Vector3(1.32,0.14,0.08),RUST,r)

func _add_encounter(id:String,pos:Vector3,hp:float,defense:float,dmg:float) -> void:
	var a:=Area3D.new(); a.name="ENC_"+id.to_upper(); a.position=pos; a.script=TRIGGER_SCRIPT
	a.encounter_id=id; a.enemy_hp=hp; a.enemy_def=defense; a.enemy_damage=dmg
	var c:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=Vector3(8,2,4); c.shape=shape; a.add_child(c); add_child(a)
