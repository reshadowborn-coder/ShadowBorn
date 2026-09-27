extends SceneTree

const Audit = preload("res://scripts/presentation/character_asset_audit.gd")
const Policy = preload("res://scripts/presentation/visual_asset_policy.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	failures += _check_imported_character(Policy.DEV_SHADOW_SCENE,"Shadow dev",true)
	failures += _check_imported_character(Policy.DEV_HOUND_SCENE,"Grave Hound dev",true)
	failures += _check_optional_production(Policy.SHADOW_SCENE,"Shadow production")
	failures += _check_optional_production(Policy.HOUND_SCENE,"Grave Hound production")

	if failures == 0:
		print("Shadowborn character import audit: PASS")
		quit(0)
	else:
		push_error("Shadowborn character import audit: %d failure(s)" % failures)
		quit(1)

func _check_imported_character(path: String,label: String,require_animation: bool) -> int:
	var report := Audit.audit_scene(path,root)
	print("CHARACTER_IMPORT_AUDIT ",label,": ",Audit.concise(report))
	var failures := 0
	failures += _expect(str(report.get("status","")) == "ok","%s imports as an auditable Godot PackedScene" % label)
	failures += _expect(int(report.get("mesh_instance_count",0)) > 0,"%s contains renderable mesh instances" % label)
	failures += _expect(int(report.get("surface_count",0)) > 0,"%s exposes imported mesh surfaces" % label)
	failures += _expect(int(report.get("vertex_count",0)) > 0,"%s exposes imported vertex count" % label)
	failures += _expect(int(report.get("triangle_count",0)) > 0,"%s exposes imported triangle count" % label)
	failures += _expect(int(report.get("skeleton_count",0)) > 0,"%s contains a Skeleton3D" % label)
	failures += _expect(int(report.get("bone_count_max",0)) >= 4,"%s exposes non-trivial bone count" % label)
	failures += _expect(int(report.get("skinned_mesh_count",0)) > 0,"%s has a mesh bound to a skeleton" % label)
	failures += _expect(float(report.get("visual_height_m",0.0)) > 0.2,"%s exposes non-zero visible height" % label)
	if require_animation:
		failures += _expect((report.get("animation_names",[]) as Array).size() > 0,"%s exposes imported animations" % label)
	return failures

func _check_optional_production(path: String,label: String) -> int:
	var report := Audit.audit_scene(path,root)
	if str(report.get("status","")) == "missing":
		print("INFO: %s not present yet; import audit will activate automatically when %s lands" % [label,path])
		return 0
	return _check_imported_character(path,label,true)

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
