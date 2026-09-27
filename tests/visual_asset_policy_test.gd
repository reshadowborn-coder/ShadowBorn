extends SceneTree

const Policy = preload("res://scripts/presentation/visual_asset_policy.gd")
const Factory = preload("res://scripts/presentation/character_factory.gd")
const ShadowPreview = preload("res://assets/characters/shadow/shadow_preview.gd")
const HoundPreview = preload("res://assets/characters/grave_hound/grave_hound_preview.gd")

func _init() -> void:
	var failures := 0
	failures += _check_path_contract()
	failures += _check_shadow_preview_contract()
	failures += _check_hound_preview_contract()
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
	var failures := 0
	failures += _expect(ResourceLoader.exists(Policy.SHADOW_PREVIEW_SCENE),"Shadow production-preview scene exists outside the vendor namespace")
	failures += _expect(not ("/vendor/" in Policy.SHADOW_PREVIEW_SCENE),"Shadow production-preview path is project-owned")
	failures += _expect(ResourceLoader.exists(ShadowPreview.AUTHORED_HOOD_MESH),"Shadow preview authored hood mesh exists")
	failures += _expect(ResourceLoader.exists(ShadowPreview.AUTHORED_COWL_MESH),"Shadow preview authored cowl mesh exists")
	failures += _expect(not ("/vendor/" in ShadowPreview.AUTHORED_HOOD_MESH),"Shadow preview hood is project-owned, not vendor geometry")
	failures += _expect(not ("/vendor/" in ShadowPreview.AUTHORED_COWL_MESH),"Shadow preview cowl is project-owned, not vendor geometry")
	var shadow := Factory.create_shadow(false)
	if shadow == null:
		push_error("Shadow preview contract: factory returned null")
		return failures+1
	failures += _expect(str(shadow.get_meta("shadowborn_visual_tier","")) == "production_preview","Shadow factory exposes production-preview provenance while final GLB is missing")
	failures += _expect(str(shadow.get_meta("shadowborn_visual_source","")) == Policy.SHADOW_PREVIEW_SCENE,"Shadow production-preview source is explicit")
	failures += _expect(str(shadow.get_meta("shadowborn_visible_tier","")) == "production_preview_original","Shadow preview declares original visible geometry")
	failures += _expect(str(shadow.get_meta("shadowborn_preview_contract","")) == "vendor_rig_hidden_by_preview_scene","Shadow preview declares temporary hidden rig-carrier contract")
	failures += _expect(shadow.find_child("AnimationCarrier",true,false) != null,"Shadow preview retains temporary animation carrier")
	failures += _expect(shadow.find_child("HeadTop",true,false) != null,"Shadow preview exposes authored HeadTop UI anchor")
	shadow.free()
	return failures

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1

func _check_hound_preview_contract() -> int:
	if ResourceLoader.exists(Policy.HOUND_SCENE):
		return 0
	var failures := 0
	failures += _expect(ResourceLoader.exists(Policy.HOUND_PREVIEW_SCENE),"Grave Hound production-preview scene exists outside the vendor namespace")
	failures += _expect(not ("/vendor/" in Policy.HOUND_PREVIEW_SCENE),"Grave Hound production-preview path is project-owned")
	failures += _expect(ResourceLoader.exists(HoundPreview.AUTHORED_HEAD_MESH),"Grave Hound authored head mesh exists")
	failures += _expect(not ("/vendor/" in HoundPreview.AUTHORED_HEAD_MESH),"Grave Hound authored head is project-owned, not vendor geometry")
	var hound := Factory.create_hound()
	if hound == null:
		push_error("Grave Hound preview contract: factory returned null")
		return failures+1
	failures += _expect(str(hound.get_meta("shadowborn_visual_tier","")) == "production_preview","Grave Hound factory exposes production-preview provenance while final GLB is missing")
	failures += _expect(str(hound.get_meta("shadowborn_visual_source","")) == Policy.HOUND_PREVIEW_SCENE,"Grave Hound production-preview source is explicit")
	failures += _expect(str(hound.get_meta("shadowborn_visible_tier","")) == "production_preview_original","Grave Hound preview declares original visible geometry")
	failures += _expect(str(hound.get_meta("shadowborn_preview_contract","")) == "vendor_quadruped_rig_hidden_by_preview_scene","Grave Hound preview declares temporary hidden quadruped carrier")
	failures += _expect(hound.find_child("AnimationCarrier",true,false) != null,"Grave Hound preview retains temporary animation carrier")
	failures += _expect(hound.find_child("HeadTop",true,false) != null,"Grave Hound preview exposes authored HeadTop anchor")
	hound.free()
	return failures

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
	elif label == "Shadow" and ResourceLoader.exists(Policy.SHADOW_PREVIEW_SCENE):
		ok = tier == "production_preview" and source == Policy.SHADOW_PREVIEW_SCENE
	elif label == "Grave Hound" and ResourceLoader.exists(Policy.HOUND_PREVIEW_SCENE):
		ok = tier == "production_preview" and source == Policy.HOUND_PREVIEW_SCENE
	else:
		ok = tier in ["debug_vendor","debug_emergency"] and source != production_path
	if not ok:
		push_error("%s provenance mismatch: production_exists=%s tier=%s source=%s" % [label,production_exists,tier,source])
	node.free()
	if ok:
		print("PASS: %s provenance=%s" % [label,tier])
		return 0
	return 1
