class_name SewerBuilder
extends Node3D

const STONE:=Color(.105,.11,.105)
const BRICK:=Color(.16,.135,.115)
const FLOOR:=Color(.075,.085,.08)
const WATER:=Color(.07,.16,.105)
const IRON:=Color(.12,.13,.125)
const RAT:=Color(.20,.17,.15)
const RAT_DARK:=Color(.11,.095,.085)
const POISON:=Color(.18,.48,.20)
const TOXIC_WET:=Color(.10,.30,.12)
const WET_STONE:=Color(.055,.070,.062)
const TRACK:=Color(.13,.105,.085)
const RAT_SCRIPT:=preload("res://scripts/world/sewer_rat_visual.gd")
var mats:Dictionary={}
var glow_mats:Dictionary={}
var box_meshes:Dictionary={}

func _ready()->void:
	_build()

func _mat(c:Color)->StandardMaterial3D:
	var key:=str(c)
	if mats.has(key): return mats[key]
	var m:=StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=.93
	mats[key]=m
	return m

func _glow(c:Color)->StandardMaterial3D:
	var key:=str(c)
	if glow_mats.has(key): return glow_mats[key]
	var m:=StandardMaterial3D.new()
	m.albedo_color=c
	m.emission_enabled=true
	m.emission=c
	m.emission_energy_multiplier=1.3
	m.roughness=.82
	glow_mats[key]=m
	return m

func _box_mesh(size:Vector3,c:Color)->BoxMesh:
	var key:=str(size)+"|"+str(c)
	if box_meshes.has(key): return box_meshes[key]
	var mesh:=BoxMesh.new()
	mesh.size=size
	mesh.material=_mat(c)
	box_meshes[key]=mesh
	return mesh

func box(name_:String,pos:Vector3,size:Vector3,c:Color,parent:Node3D)->MeshInstance3D:
	var n:=MeshInstance3D.new()
	n.name=name_
	n.position=pos
	n.mesh=_box_mesh(size,c)
	parent.add_child(n)
	return n

func solid_box(name_:String,pos:Vector3,size:Vector3,c:Color,visual:Node3D,collision:StaticBody3D)->void:
	box(name_,pos,size,c,visual)
	var shape_node:=CollisionShape3D.new()
	shape_node.name=name_+"Shape"
	shape_node.position=pos
	var shape:=BoxShape3D.new()
	shape.size=size
	shape_node.shape=shape
	collision.add_child(shape_node)

func _build()->void:
	var visual:=Node3D.new()
	visual.name="SewerVisual"
	add_child(visual)
	var collision:=StaticBody3D.new()
	collision.name="SewerCollision"
	add_child(collision)

	# One compact authored descent with three readable chambers.
	solid_box("SewerFloor",Vector3(30,-.20,-100),Vector3(11,.4,52),FLOOR,visual,collision)
	for x in [24.5,35.5]:
		solid_box("SewerWall",Vector3(x,2.5,-100),Vector3(.7,5,52),BRICK,visual,collision)
	# Raised side walks frame a wet central gutter without adding water physics.
	box("WalkL",Vector3(27.2,.02,-100),Vector3(3.8,.18,52),STONE,visual)
	box("WalkR",Vector3(32.8,.02,-100),Vector3(3.8,.18,52),STONE,visual)
	var water:=box("SewerWater",Vector3(30,.01,-100),Vector3(1.8,.08,52),WATER,visual)
	water.material_override=_glow(Color(.055,.20,.10))

	for z in [-78.0,-86.0,-94.0,-102.0,-110.0,-118.0,-124.0]:
		box("CeilingRib",Vector3(30,4.25,z),Vector3(10.4,.32,.46),STONE,visual)
		box("PipeL",Vector3(25.2,3.0,z+.6),Vector3(.28,.28,4.8),IRON,visual)
	for room in range(1,4):
		var p:=Act1Layout.room_trigger(room)
		box("Room%02dArchL"%room,p+Vector3(-4.2,2.0,-1.0),Vector3(.55,4.0,.7),STONE,visual)
		box("Room%02dArchR"%room,p+Vector3(4.2,2.0,-1.0),Vector3(.55,4.0,.7),STONE,visual)
		box("Room%02dArchTop"%room,p+Vector3(0,3.75,-1.0),Vector3(8.9,.55,.7),STONE,visual)

	# Give each chamber one strong silhouette/readability cue instead of filling
	# the whole corridor with detail. These are static meshes: no extra lights,
	# particles or water physics are introduced.
	box("Room1DryThreshold",Vector3(30,.10,-88.6),Vector3(1.9,.05,2.4),WET_STONE,visual)
	box("Room1CollapsedPipe",Vector3(34.7,1.15,-88.2),Vector3(.28,2.3,.28),IRON,visual).rotation_degrees.z=14.0
	for i in range(3):
		var scratch:=box("Room1Scratch%02d"%i,Vector3(24.86,1.35+float(i)*.22,-87.4-float(i)*.30),Vector3(.05,.07,.90),TRACK,visual)
		scratch.rotation_degrees.x=8.0+float(i)*4.0

	var toxic_gutter:=box("Room2ToxicRunoff",Vector3(30,.075,-102.5),Vector3(2.10,.07,8.0),TOXIC_WET,visual)
	toxic_gutter.material_override=_glow(Color(.10,.32,.11))
	box("Room2Overflow",Vector3(27.55,.085,-102.6),Vector3(2.5,.05,2.7),TOXIC_WET,visual)
	box("Room2LeakPipe",Vector3(25.05,2.7,-101.0),Vector3(.30,2.4,.30),IRON,visual)
	box("Room2LeakStain",Vector3(25.38,1.25,-101.0),Vector3(.08,2.35,.70),TOXIC_WET,visual)
	for i in range(4):
		box("Room2DrainBar%02d"%i,Vector3(24.90,1.15+float(i)*.42,-104.2),Vector3(.12,.12,1.65),IRON,visual)

	# Room 3 is visually more dangerous: the gutter has overflowed onto both
	# walks and an old barred outflow closes the far end behind the pack.
	box("Room3FloodL",Vector3(27.65,.085,-118.4),Vector3(2.55,.05,7.2),WATER,visual)
	box("Room3FloodR",Vector3(32.35,.085,-118.4),Vector3(2.55,.05,7.2),WATER,visual)
	box("Room3UpperPipe",Vector3(30,3.05,-119.4),Vector3(9.4,.30,.30),IRON,visual)
	for i in range(5):
		box("Room3OutflowBar%02d"%i,Vector3(28.0+float(i),1.45,-123.0),Vector3(.16,2.7,.16),IRON,visual)
	box("Room3OutflowCross",Vector3(30,1.45,-123.0),Vector3(5.0,.16,.16),IRON,visual)

	# Sparse paired tracks lead forward without turning the floor into noise.
	for i in range(6):
		var track_z:=-80.5-float(i)*6.1
		var track_x:=28.15 if i%2==0 else 31.85
		var track:=box("RatTrack%02d"%i,Vector3(track_x,.125,track_z),Vector3(.18,.025,.42),TRACK,visual)
		track.rotation_degrees.y=18.0 if i%2==0 else -16.0

	# Sparse props: readable at phone scale, no clutter in the centre lane.
	for i in range(5):
		var side:=-1.0 if i%2==0 else 1.0
		box("Debris%02d"%i,Vector3(30+side*4.15,.18,-82.0-float(i)*8.2),Vector3(.70,.34,.55),STONE,visual).rotation_degrees.y=float(17+i*31)
	box("DrainGrate",Vector3(30,.18,-121.5),Vector3(3.0,.18,.35),IRON,visual)

	_build_rat("a1_r1_rat",Act1Layout.ROOM1_TRIGGER+Vector3(0,0,-1.8),"normal",visual,0.2)
	_build_rat("a1_r2_poison_rat",Act1Layout.ROOM2_TRIGGER+Vector3(0,0,-1.8),"poison",visual,1.1)
	_build_rat("a1_r3_rat_a",Act1Layout.ROOM3_TRIGGER+Vector3(-1.25,0,-2.0),"normal",visual,2.0)
	_build_rat("a1_r3_rat_b",Act1Layout.ROOM3_TRIGGER+Vector3(1.25,0,-2.3),"normal",visual,2.7)

func _build_rat(id:String,pos:Vector3,variant:String,parent:Node3D,phase:float)->void:
	var root:=Node3D.new()
	root.name="VIS_"+id.to_upper()
	root.position=Vector3(pos.x,.35,pos.z)
	root.set_script(RAT_SCRIPT)
	root.variant=variant
	root.phase=phase
	root.add_to_group("encounter_visual")
	root.set_meta("encounter_id",id)
	parent.add_child(root)

	var body:=MeshInstance3D.new()
	body.name="Body"
	var body_mesh:=CapsuleMesh.new()
	body_mesh.radius=.38
	body_mesh.height=1.10
	body_mesh.radial_segments=8
	body_mesh.rings=4
	body_mesh.material=_mat(POISON if variant=="poison" else RAT)
	body.mesh=body_mesh
	body.rotation_degrees.x=90
	root.add_child(body)

	var head:=MeshInstance3D.new()
	head.name="Head"
	var head_mesh:=SphereMesh.new()
	head_mesh.radius=.28
	head_mesh.height=.50
	head_mesh.radial_segments=8
	head_mesh.rings=4
	head_mesh.material=_glow(POISON) if variant=="poison" else _mat(RAT_DARK)
	head.mesh=head_mesh
	head.position=Vector3(0,.05,-.58)
	root.add_child(head)

	var tail:=MeshInstance3D.new()
	tail.name="Tail"
	var tail_mesh:=CylinderMesh.new()
	tail_mesh.top_radius=.04
	tail_mesh.bottom_radius=.07
	tail_mesh.height=1.0
	tail_mesh.radial_segments=6
	tail_mesh.material=_mat(RAT_DARK)
	tail.mesh=tail_mesh
	tail.position=Vector3(0,.02,.88)
	tail.rotation_degrees.x=72
	root.add_child(tail)