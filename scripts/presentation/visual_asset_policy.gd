class_name VisualAssetPolicy
extends RefCounted

const ACCEPTANCE_SETTING := "shadowborn/visual/acceptance_mode"
const ACCEPTANCE_ENV := "SHADOWBORN_VISUAL_ACCEPTANCE"

const SHADOW_SCENE := "res://assets/characters/shadow/shadow.glb"
const HOUND_SCENE := "res://assets/characters/grave_hound/grave_hound.glb"
const SWORD_SCENE := "res://assets/weapons/shadow_sword/shadow_sword.glb"
const AWAKENING_ENVIRONMENT := "res://assets/environments/checkpoint01/awakening_environment.tscn"
const BATTLE_ENVIRONMENT := "res://assets/environments/checkpoint01/grave_hound_arena.tscn"

const DEV_SHADOW_SCENE := "res://assets/vendor/quaternius/shadow_adventurer.gltf"
const DEV_HOUND_SCENE := "res://assets/vendor/quaternius/grave_wolf.gltf"
const DEV_SWORD_SCENE := "res://assets/vendor/quaternius/shadow_sword.gltf"

static func is_acceptance_mode() -> bool:
	if OS.has_environment(ACCEPTANCE_ENV):
		var env_value := OS.get_environment(ACCEPTANCE_ENV).strip_edges().to_lower()
		if env_value in ["1","true","yes","on"]:
			return true
	return bool(ProjectSettings.get_setting(ACCEPTANCE_SETTING,false))

static func production_character_paths() -> PackedStringArray:
	return PackedStringArray([SHADOW_SCENE,HOUND_SCENE,SWORD_SCENE])

static func production_environment_paths() -> PackedStringArray:
	return PackedStringArray([AWAKENING_ENVIRONMENT,BATTLE_ENVIRONMENT])

static func required_production_paths() -> PackedStringArray:
	var paths := production_character_paths()
	paths.append_array(production_environment_paths())
	return paths

static func missing_required_assets() -> PackedStringArray:
	var missing := PackedStringArray()
	for path in required_production_paths():
		if not ResourceLoader.exists(path):
			missing.append(path)
	return missing

static func production_ready() -> bool:
	return missing_required_assets().is_empty()

static func instantiate_scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("VisualAssetPolicy: failed to load PackedScene: %s" % path)
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_error("VisualAssetPolicy: production asset is not Node3D: %s" % path)
	return instance

static func tag_visual_tier(root: Node, tier: String, source_path: String) -> void:
	if root == null:
		return
	root.set_meta("shadowborn_visual_tier",tier)
	root.set_meta("shadowborn_visual_source",source_path)

static func report_debug_fallback(label: String, final_path: String, dev_path: String) -> void:
	var message := "Visual fallback for %s: missing %s; using debug source %s" % [label,final_path,dev_path]
	if is_acceptance_mode():
		push_error(message)
	else:
		push_warning(message)
