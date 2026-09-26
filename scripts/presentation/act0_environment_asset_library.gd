class_name Act0EnvironmentAssetLibrary
extends RefCounted

const GRAVE_MARKER_HERO := "res://assets/environments/checkpoint01/grave_marker_hero.obj"

static func has_grave_marker_hero() -> bool:
	return ResourceLoader.exists(GRAVE_MARKER_HERO)

static func create_grave_marker_hero() -> MeshInstance3D:
	if not has_grave_marker_hero():
		return null
	var mesh := load(GRAVE_MARKER_HERO) as Mesh
	if mesh == null:
		push_error("Failed to load production-preview grave marker mesh: %s" % GRAVE_MARKER_HERO)
		return null

	var instance := MeshInstance3D.new()
	instance.name = "GraveMarkerHero"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.set_meta("shadowborn_visual_tier","production_preview")
	instance.set_meta("shadowborn_visual_source",GRAVE_MARKER_HERO)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.105,0.102,0.098,1.0)
	material.roughness = 0.96
	material.metallic = 0.0
	instance.material_override = material
	return instance
