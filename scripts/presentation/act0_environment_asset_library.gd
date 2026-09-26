class_name Act0EnvironmentAssetLibrary
extends RefCounted

const GRAVE_MARKER_HERO := "res://assets/environments/checkpoint01/grave_marker_hero.obj"
const BROKEN_ARCH_HERO := "res://assets/environments/checkpoint01/broken_arch_hero.obj"
const AWAKENING_SLAB_HERO := "res://assets/environments/checkpoint01/awakening_slab_hero.obj"
const WALL_FRAGMENT_HERO := "res://assets/environments/checkpoint01/wall_fragment_hero.obj"
const RUBBLE_CLUSTER_HERO := "res://assets/environments/checkpoint01/rubble_cluster_hero.obj"

static var _grave_material: ShaderMaterial

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
	instance.material_override = _grave_stone_material()
	instance.set_instance_shader_parameter("grave_tint",Color(0.105,0.102,0.098,1.0))
	return instance

static func create_awakening_slab_hero() -> MeshInstance3D:
	if not ResourceLoader.exists(AWAKENING_SLAB_HERO):
		return null
	var mesh := load(AWAKENING_SLAB_HERO) as Mesh
	if mesh == null:
		push_error("Failed to load production-preview awakening slab: %s" % AWAKENING_SLAB_HERO)
		return null
	var instance := MeshInstance3D.new()
	instance.name = "AwakeningSlabHero"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.set_meta("shadowborn_visual_tier","production_preview")
	instance.set_meta("shadowborn_visual_source",AWAKENING_SLAB_HERO)
	instance.material_override = _grave_stone_material()
	instance.set_instance_shader_parameter("grave_tint",Color(0.135,0.137,0.142,1.0))
	return instance

static func create_broken_arch_hero() -> MeshInstance3D:
	if not ResourceLoader.exists(BROKEN_ARCH_HERO):
		return null
	var mesh := load(BROKEN_ARCH_HERO) as Mesh
	if mesh == null:
		push_error("Failed to load production-preview broken arch mesh: %s" % BROKEN_ARCH_HERO)
		return null
	var instance := MeshInstance3D.new()
	instance.name = "BrokenArchHero"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.set_meta("shadowborn_visual_tier","production_preview")
	instance.set_meta("shadowborn_visual_source",BROKEN_ARCH_HERO)
	instance.material_override = _grave_stone_material()
	instance.set_instance_shader_parameter("grave_tint",Color(0.082,0.083,0.086,1.0))
	return instance

static func has_wall_fragment_hero() -> bool:
	return ResourceLoader.exists(WALL_FRAGMENT_HERO)

static func has_rubble_cluster_hero() -> bool:
	return ResourceLoader.exists(RUBBLE_CLUSTER_HERO)

static func create_wall_fragment_hero() -> MeshInstance3D:
	return _create_stone_preview_mesh(WALL_FRAGMENT_HERO,"WallFragmentHero",Color(0.070,0.073,0.080,1.0))

static func create_rubble_cluster_hero() -> MeshInstance3D:
	return _create_stone_preview_mesh(RUBBLE_CLUSTER_HERO,"RubbleClusterHero",Color(0.082,0.080,0.076,1.0))

static func _create_stone_preview_mesh(path: String,node_name: String,tint: Color) -> MeshInstance3D:
	if not ResourceLoader.exists(path):
		return null
	var mesh := load(path) as Mesh
	if mesh == null:
		push_error("Failed to load production-preview stone mesh: %s" % path)
		return null
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.set_meta("shadowborn_visual_tier","production_preview")
	instance.set_meta("shadowborn_visual_source",path)
	instance.material_override = _grave_stone_material()
	instance.set_instance_shader_parameter("grave_tint",tint)
	return instance

static func _grave_stone_material() -> ShaderMaterial:
	if _grave_material != null:
		return _grave_material

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
instance uniform vec4 grave_tint : source_color = vec4(0.105,0.102,0.098,1.0);
varying vec3 local_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 p = local_pos;
	float broad = 0.5 + 0.5*sin(p.y*8.0 + p.x*5.0 + sin(p.z*11.0));
	float chips = hash31(floor(p*18.0));
	float damp = smoothstep(0.72,0.10,p.y) * (0.45 + 0.55*hash31(floor(p*7.0)));
	float moss = smoothstep(0.77,0.96,0.52*broad + 0.48*chips) * (0.25 + 0.75*damp);

	vec3 col = grave_tint.rgb * mix(0.72,1.08,broad);
	col *= mix(0.88,0.68,damp*0.55);
	col = mix(col,vec3(0.035,0.055,0.038),moss*0.25);

	ALBEDO = col;
	ROUGHNESS = clamp(0.91 + chips*0.06 - damp*0.13,0.73,0.99);
	SPECULAR = mix(0.28,0.48,damp);
	METALLIC = 0.0;
}
"""
	_grave_material = ShaderMaterial.new()
	_grave_material.shader = shader
	return _grave_material
