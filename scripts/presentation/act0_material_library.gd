class_name Act0MaterialLibrary
extends RefCounted

# Production material paths are intentionally fixed. The runtime falls back to
# the procedural graybox material until the approved CC0 files are present.
const COBBLE_ALBEDO := "res://assets/production/materials/cemetery_wet_cobble/cobblestone_01_diff_2k.png"
const COBBLE_NORMAL := "res://assets/production/materials/cemetery_wet_cobble/cobblestone_01_nor_gl_2k.png"
const COBBLE_ORM := "res://assets/production/materials/cemetery_wet_cobble/cobblestone_01_arm_2k.png"

static func has_cemetery_cobble() -> bool:
	return (
		ResourceLoader.exists(COBBLE_ALBEDO)
		and ResourceLoader.exists(COBBLE_NORMAL)
		and ResourceLoader.exists(COBBLE_ORM)
	)

static func create_cemetery_cobble(uv_scale: float = 2.35) -> Material:
	if not has_cemetery_cobble():
		return null

	var material := ORMMaterial3D.new()
	material.albedo_texture = load(COBBLE_ALBEDO) as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(COBBLE_NORMAL) as Texture2D
	material.orm_texture = load(COBBLE_ORM) as Texture2D
	material.uv1_scale = Vector3(uv_scale,uv_scale,uv_scale)
	# Preserve a cold, damp baseline without making the stone mirror-like.
	material.albedo_color = Color(0.78,0.80,0.82,1.0)
	material.roughness = 1.0
	material.metallic = 0.0
	return material
