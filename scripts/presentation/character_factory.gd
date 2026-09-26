class_name CharacterFactory
extends RefCounted

const VisualPolicy = preload("res://scripts/presentation/visual_asset_policy.gd")

const FINAL_SHADOW := VisualPolicy.SHADOW_SCENE
const FINAL_HOUND := VisualPolicy.HOUND_SCENE
const FINAL_SWORD := VisualPolicy.SWORD_SCENE

const DEV_SHADOW := VisualPolicy.DEV_SHADOW_SCENE
const DEV_HOUND := VisualPolicy.DEV_HOUND_SCENE
const DEV_SWORD := VisualPolicy.DEV_SWORD_SCENE
# User-tested debug correction. The vendor sword raw long axis is ~1.369 units
# against ~2.053 units of Shadow height. 0.75 brings the visible starter weapon
# to ~50% of body height instead of the previous ~61% after the 0.92 scale.
# Production sword must replace this with an authored Grip marker + socket contract.
const DEV_SWORD_PRESENTATION_SCALE := 0.75
const DEV_SWORD_WRIST_OFFSET := Vector3.ZERO
const DEV_SWORD_WRIST_ROTATION := Vector3(0.0,0.0,180.0)
# The authored sword's BladeTip is +Y from Grip. Camera-side rotation sweep
# showed the old 180° correction (inherited from the vendor sword) sent the
# blade back into the forearm/torso. -90° makes the production blade leave the
# right hand toward the opponent in the fixed battle camera.
const PRODUCTION_SWORD_WRIST_ROTATION := Vector3(0.0,0.0,-90.0)

const META_ANIMATION_PLAYER_PATH := &"_shadowborn_animation_player_path"
const META_SKELETON_PATH := &"_shadowborn_skeleton_path"

static func create_shadow(with_sword: bool = true) -> Node3D:
	var final_model := _load_scene(FINAL_SHADOW)
	if final_model != null:
		final_model.name = "ShadowModel"
		VisualPolicy.tag_visual_tier(final_model,"production",FINAL_SHADOW)
		_set_named_weapon_visible(final_model,with_sword)
		return final_model

	if VisualPolicy.is_acceptance_mode():
		return _build_missing_production_asset("Shadow",FINAL_SHADOW)

	var preview_model := _load_scene(VisualPolicy.SHADOW_PREVIEW_SCENE)
	if preview_model != null:
		preview_model.name = "ShadowProductionPreview"
		VisualPolicy.tag_visual_tier(preview_model,"production_preview",VisualPolicy.SHADOW_PREVIEW_SCENE)
		preview_model.set_meta("shadowborn_visible_tier","production_preview_original")
		preview_model.set_meta("shadowborn_preview_contract","vendor_rig_hidden_by_preview_scene")
		if with_sword:
			attach_sword(preview_model)
		return preview_model

	VisualPolicy.report_debug_fallback("Shadow",FINAL_SHADOW,DEV_SHADOW)
	var dev_model := _load_scene(DEV_SHADOW)
	if dev_model != null:
		dev_model.name = "ShadowDevModel"
		VisualPolicy.tag_visual_tier(dev_model,"debug_vendor",DEV_SHADOW)
		_prepare_dev_shadow(dev_model)
		if with_sword:
			attach_sword(dev_model)
		return dev_model

	var emergency := _build_emergency_shadow(with_sword)
	VisualPolicy.tag_visual_tier(emergency,"debug_emergency","generated://shadow")
	return emergency

static func create_hound() -> Node3D:
	var final_model := _load_scene(FINAL_HOUND)
	if final_model != null:
		final_model.name = "GraveHoundModel"
		VisualPolicy.tag_visual_tier(final_model,"production",FINAL_HOUND)
		return final_model

	if VisualPolicy.is_acceptance_mode():
		return _build_missing_production_asset("Grave Hound",FINAL_HOUND)

	VisualPolicy.report_debug_fallback("Grave Hound",FINAL_HOUND,DEV_HOUND)
	var dev_model := _load_scene(DEV_HOUND)
	if dev_model != null:
		dev_model.name = "GraveHoundDevModel"
		VisualPolicy.tag_visual_tier(dev_model,"debug_vendor",DEV_HOUND)
		_prepare_dev_hound(dev_model)
		return dev_model

	var emergency := _build_emergency_hound()
	VisualPolicy.tag_visual_tier(emergency,"debug_emergency","generated://grave_hound")
	return emergency

static func create_sword_prop() -> Node3D:
	var final_model := _load_scene(FINAL_SWORD)
	if final_model != null:
		final_model.name = "ShadowSword"
		VisualPolicy.tag_visual_tier(final_model,"production",FINAL_SWORD)
		return final_model

	if VisualPolicy.is_acceptance_mode():
		return _build_missing_production_asset("Shadow Sword",FINAL_SWORD)

	VisualPolicy.report_debug_fallback("Shadow Sword",FINAL_SWORD,DEV_SWORD)
	var model := _load_scene(DEV_SWORD)
	if model != null:
		model.name = "SwordDevProp"
		VisualPolicy.tag_visual_tier(model,"debug_vendor",DEV_SWORD)
		_prepare_sword(model)
		return model
	var emergency := _build_emergency_sword()
	VisualPolicy.tag_visual_tier(emergency,"debug_emergency","generated://shadow_sword")
	return emergency

static func attach_sword(root: Node3D) -> void:
	_set_named_weapon_visible(root,true)
	if root.find_child("ShadowbornWeapon",true,false) != null:
		return

	var skeleton := _find_skeleton(root)
	if skeleton != null and skeleton.find_bone("Wrist.R") >= 0:
		var socket := BoneAttachment3D.new()
		socket.name = "WeaponSocket"
		socket.bone_name = "Wrist.R"
		skeleton.add_child(socket)

		var sword := create_sword_prop()
		sword.name = "ShadowbornWeapon"
		var tier := str(sword.get_meta("shadowborn_visual_tier",""))
		if tier == "production":
			var grip := sword.find_child("Grip",true,false) as Node3D
			if grip == null: