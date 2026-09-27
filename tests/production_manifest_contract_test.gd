extends SceneTree

const Policy = preload("res://scripts/presentation/visual_asset_policy.gd")
const MANIFEST_PATH := "res://assets/production_manifest.json"

func _init() -> void:
	var failures := 0
	var manifest := _load_manifest()
	if manifest.is_empty():
		push_error("Production manifest failed to load")
		quit(1)
		return

	failures += _expect(str(manifest.get("scope","")) == "CHECKPOINT_01_AWAKENING_GRAVE_HOUND","manifest scope matches current checkpoint")
	var handoff: Dictionary = manifest.get("character_asset_handoff",{})
	failures += _expect(str(handoff.get("engine_baseline","")) == "Godot 4.7.2","character handoff pins current Godot baseline")
	failures += _expect(str(handoff.get("format","")) == "glTF 2.0 / GLB","character handoff uses glTF/GLB")
	failures += _expect("OpenGL" in str(handoff.get("normal_map_contract","")),"character handoff locks OpenGL tangent-space normals")
	failures += _expect((handoff.get("validation",[]) as Array).size() >= 5,"character handoff has executable import validation gates")
	var import_audit: Dictionary = manifest.get("character_import_audit",{})
	failures += _expect(str(import_audit.get("runtime_truth_source","")) == "Godot 4.7.2 imported resources","character audit uses imported Godot runtime truth")
	failures += _expect(str(import_audit.get("implementation","")) == "res://scripts/presentation/character_asset_audit.gd","character audit implementation path is locked")
	var audit_metrics: Array = import_audit.get("required_metrics",[])
	for metric in ["vertex_count","surface_count","unique_material_count","bone_count_max","animation_names"]:
		failures += _expect(metric in audit_metrics,"character audit includes required metric %s" % metric)
	var candidate_routes: Array = import_audit.get("candidate_basemesh_routes",[])
	failures += _expect(candidate_routes.size() >= 2,"character audit keeps original and neutral-substrate routes comparable")

	var animation_import: Dictionary = manifest.get("animation_import_contract",{})
	failures += _expect(str(animation_import.get("engine_baseline","")) == "Godot 4.7.2","animation import contract pins current Godot baseline")
	failures += _expect(int(animation_import.get("bake_fps_candidate",0)) == 30,"animation import starts from 30 FPS bake candidate")
	failures += _expect(bool(animation_import.get("trim_static_ends",false)),"animation import trims static animation ends")
	failures += _expect(bool(animation_import.get("remove_immutable_tracks",false)),"animation import removes immutable tracks")
	var semantic_capture: Dictionary = animation_import.get("semantic_capture",{})
	failures += _expect(bool(semantic_capture.get("diagnostic_only",false)),"pose-fraction captures are explicitly diagnostic only")
	failures += _expect((semantic_capture.get("diagnostic_pose_fractions",[]) as Array).size() == 3,"semantic diagnostic capture has three pose fractions")
	failures += _expect("HND_BITE_01" in (semantic_capture.get("required_hound_clips",[]) as Array),"Hound production contract requires dedicated Bite clip")
	failures += _expect("SHD_A2_LUNGE_01" in (semantic_capture.get("required_shadow_clips",[]) as Array),"Shadow production contract requires dedicated A2 clip")

	var required: Dictionary = manifest.get("checkpoint_01_required_assets",{})

	failures += _expect(_asset_path(required,"shadow") == Policy.SHADOW_SCENE,"Shadow path matches VisualAssetPolicy")
	failures += _expect(_asset_path(required,"grave_hound") == Policy.HOUND_SCENE,"Grave Hound path matches VisualAssetPolicy")
	failures += _expect(_asset_path(required,"shadow_sword") == Policy.SWORD_SCENE,"Sword path matches VisualAssetPolicy")
	failures += _expect(_asset_path(required,"awakening_environment") == Policy.AWAKENING_ENVIRONMENT,"Awakening environment path matches VisualAssetPolicy")
	failures += _expect(_asset_path(required,"grave_hound_arena") == Policy.BATTLE_ENVIRONMENT,"Battle environment path matches VisualAssetPolicy")

	failures += _expect(
		_required_nodes(required,"awakening_environment") == PackedStringArray(["AwakeningCamera","ShadowSpawn","SwordSpawn"]),
		"Awakening anchor contract matches runtime"
	)
	failures += _expect(
		_required_nodes(required,"grave_hound_arena") == PackedStringArray(["BattleCamera","PlayerHome","EnemyHome","CameraTarget"]),
		"Battle anchor contract matches runtime"
	)

	var temple_deferred := false
	for entry_variant in manifest.get("production_mesh_families",[]):
		var entry: Dictionary = entry_variant
		if str(entry.get("id","")) == "TEMPLE_EXTERIOR_KIT":
			temple_deferred = not bool(entry.get("needed",true)) and bool(entry.get("deferred",false))
			break
	failures += _expect(temple_deferred,"Temple production remains deferred until Checkpoint 01 acceptance")

	if failures == 0:
		print("Shadowborn production manifest contract: PASS")
		quit(0)
	else:
		push_error("Shadowborn production manifest contract: %d failure(s)" % failures)
		quit(1)

func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH,FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

func _asset_path(required: Dictionary,key: String) -> String:
	var entry: Dictionary = required.get(key,{})
	return str(entry.get("path",""))

func _required_nodes(required: Dictionary,key: String) -> PackedStringArray:
	var result := PackedStringArray()
	var entry: Dictionary = required.get(key,{})
	for value in entry.get("required_nodes",[]):
		result.append(str(value))
	return result

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
