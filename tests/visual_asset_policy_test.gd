extends SceneTree

const Policy = preload("res://scripts/presentation/visual_asset_policy.gd")
const Factory = preload("res://scripts/presentation/character_factory.gd")

func _init() -> void:
	var failures := 0
	failures += _check_path_contract()
	failures += _check_shadow_preview_contract()
	failures += _check_factory_provenance("Shadow",Policy.SHADOW_SCENE,func(): return Factory.create_shadow(false))
	failures += _check_factory_provenance("Grave Hound",Policy.HOUND_SCENE,func(): return Factory.create_hound())
	failures += _check_factory_provenance("Shadow Sword",Policy.SWORD_SCENE,func(): return Factory.create_sword_prop())

	var missing := Policy.missing_required_assets()
	if missing.is_empty():
		print("INFO: production visual pack is complete")
	else:
		print("INFO: production visual pack incomplete by design (%d missing); debug fallback remains enabled outside acceptance mode" % missing.size())
		for path in missing:
			print("  MISSING PRODUCTION: %s" % path)

	if failures == 0:
		print("Shadowborn visual asset policy: PASS")
		quit(0)
	else:
		push_error("Shadowborn visual asset policy: %d failure(s)" % failures)
		quit(1)

func _check_path_contract() -> int:
	var failures := 0
	for path in Policy.required_production_paths():
		if "/vendor/" in path:
			push_error("Production visual path must never point at vendor content: %s" % path)
			failures += 1
	for path in [Policy.DEV_SHADOW_SCENE,Policy.DEV_HOUND_SCENE,Policy.DEV_SWORD_SCENE]:
		if not ("/vendor/" in path):
			push_error("Debug visual path must stay explicitly vendor-scoped: %s" % path)
			failures += 1
	if failures == 0:
		print("PASS: production/debug visual namespaces are separated")
	return failures

func _check_shadow_preview_contract() -> int:
	if ResourceLoader.exists(Policy.SHADOW_SCENE):
		return 0
	var shadow := Factory.create_shadow(false)
	if shadow == null:
		push_error("Shadow preview contract: factory returned null")
		return 1
	var failures := 0
	failures += _expect(str(shadow.get_meta("shadowborn_visible_tier","")) == "production_preview_original","Shadow fallback exposes original production-preview visible tier")
	failures += _expect(str(shadow.get_meta("shadowborn_preview_contract","")) == "vendor_rig_hidden_original_visible_shell","Shadow fallback keeps vendor rig as hidden carrier only")
	failures += _expect(shadow.find_child("ShadowPreviewMarker",true,false) != null,"Shadow production-preview marker exists on the rig")
	var vendor_body := shadow.find_child("Adventurer_Body",true,false) as MeshInstance3D
	if vendor_body != null:
		failures += _expect(not vendor_body.visible,"Vendor Shadow body mesh stays hidden in production-preview screenshots")
	var preview_count := _count_preview_meshes(shadow)
	failures += _expect(preview_count >= 14,"Shadow production-preview shell contains enough original rig-driven silhouette pieces")
	shadow.free()
	return failures

func _count_preview_meshes(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and str(node.get_meta("shadowborn_visual_tier","")) == "production_preview_original":
		count += 1
	for child in node.get_children():
		count += _count_preview_meshes(child)
	return count

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1

func _check_factory_provenance(label: String,production_path: String,builder: Callable) -> int:
	var node := builder.call() as Node3D
	if node == null:
		push_error("%s factory returned null" % label)
		return 1
	var tier := str(node.get_meta("shadowborn_visual_tier",""))
	var source := str(node.get_meta("shadowborn_visual_source",""))
	var production_exists := ResourceLoader.exists(production_path)
	var ok := true
	if production_exists:
		ok = tier == "production" and source == production_path
	else:
		ok = tier in ["debug_vendor","debug_emergency"] and source != production_path
	if not ok:
		push_error("%s provenance mismatch: production_exists=%s tier=%s source=%s" % [label,production_exists,tier,source])
	node.free()
	if ok:
		print("PASS: %s provenance=%s" % [label,tier])
		return 0
	return 1
