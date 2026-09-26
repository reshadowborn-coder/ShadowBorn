class_name Act0EnvironmentMeshLibrary
extends RefCounted

const GRAVE_STELE_BROKEN_A := preload("res://assets/production/environment/graves/grave_stele_broken_a.obj")

static func create_broken_grave(material: Material, tint: Color = Color(0.078,0.083,0.092)) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "BrokenGraveSteleA"
	instance.mesh = GRAVE_STELE_BROKEN_A
	instance.material_override = material
	if material is ShaderMaterial:
		instance.set_instance_shader_parameter("base_color",tint)
	return instance
