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
