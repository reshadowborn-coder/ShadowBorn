class_name CatacombsBuilder
extends Node3D

const STONE:=Color(.135,.14,.145)
const FLOOR:=Color(.085,.09,.095)
const BONE:=Color(.43,.41,.36)
var mats:={}

func _ready()->void:_build()

func mat(c:Color)->StandardMaterial3D:
	var k:=str(c)
	if mats.has(k):return mats[k]
	var m:=StandardMaterial3D.new();m.albedo_color=c;m.roughness=.95;mats[k]=m;return m

func box(n:String,p:Vector3,s:Vector3,c:Color=STONE,parent:Node3D=self)->MeshInstance3D:
	var x:=MeshInstance3D.new();x.name=n;var mesh:=BoxMesh.new();mesh.size=s;mesh.material=mat(c);x.mesh=mesh;x.position=p;parent.add_child(x);return x

func _build()->void:
	var root:=Node3D.new();root.name="CatacombVisual";add_child(root)
	for i in range(5):
		var z:=-122.0-float(i)*13.0
		box("Room%02dFloor"%(i+1),Vector3(0,-.2,z),Vector3(12,.4,11),FLOOR,root)
		box("Room%02dWallL"%(i+1),Vector3(-6,2.2,z),Vector3(.7,4.4,11),STONE,root)
		box("Room%02dWallR"%(i+1),Vector3(6,2.2,z),Vector3(.7,4.4,11),STONE,root)
		box("Room%02dArchL"%(i+1),Vector3(-2.8,2.2,z-5.4),Vector3(.8,4.4,.8),STONE,root)
		box("Room%02dArchR"%(i+1),Vector3(2.8,2.2,z-5.4),Vector3(.8,4.4,.8),STONE,root)
		box("Room%02dArchTop"%(i+1),Vector3(0,4.1,z-5.4),Vector3(6.4,.7,.8),STONE,root)
		for j in range(3):
			box("Room%02dBones%02d"%(i+1,j),Vector3(-4.0+j*4.0,.08,z+2.5-(j%2)*4.0),Vector3(1.0,.16,.35),BONE,root)
	box("Room5Seal",Vector3(0,2.2,-179.0),Vector3(7,4.4,.65),Color(.10,.08,.09),root)
