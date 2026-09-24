class_name ShadowProxy
extends Node3D

const SHADOW_BODY := Color(0.055,0.06,0.075,1.0)
const SHADOW_EDGE := Color(0.13,0.14,0.18,1.0)
var _materials: Dictionary = {}

func _ready() -> void:
	_build_proxy()

func _material(color: Color) -> StandardMaterial3D:
	var key:=str(color)
	if _materials.has(key): return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	mat.metallic = 0.05
	_materials[key]=mat
	return mat

func _capsule(name_: String, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.material = _material(color)
	node.mesh = mesh
	node.position = pos
	add_child(node)
	return node

func _box(name_: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	node.mesh = mesh
	node.position = pos
	add_child(node)
	return node

func _build_proxy() -> void:
	_capsule("Torso", Vector3(0,0.10,0), 0.31, 1.10, SHADOW_BODY)
	_capsule("Head", Vector3(0,0.91,0), 0.235, 0.47, SHADOW_BODY)
	_box("Neck", Vector3(0,0.62,0), Vector3(0.20,0.20,0.18), SHADOW_BODY)
	var shoulder := _box("ShoulderMantle", Vector3(0,0.43,0), Vector3(1.02,0.17,0.36), SHADOW_EDGE)
	shoulder.rotation_degrees.z = -4.0
	_box("LegL", Vector3(-0.16,-0.64,0), Vector3(0.17,0.88,0.19), SHADOW_BODY)
	_box("LegR", Vector3(0.16,-0.64,0), Vector3(0.17,0.88,0.19), SHADOW_BODY)
	_box("ArmL", Vector3(-0.43,0.05,0), Vector3(0.14,0.88,0.16), SHADOW_BODY).rotation_degrees.z = -8.0
	_box("ArmR", Vector3(0.43,0.05,0), Vector3(0.14,0.88,0.16), SHADOW_BODY).rotation_degrees.z = 8.0
	var mantle := _box("Mantle", Vector3(0,0.02,0.16), Vector3(0.72,1.05,0.08), SHADOW_EDGE)
	mantle.rotation_degrees.x = 8.0
