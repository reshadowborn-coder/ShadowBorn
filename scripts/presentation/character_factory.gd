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
# The restored diagonal shipping camera exposed that the previous -90 degree
# mount projected the blade behind Shadow, away from the opponent at CONTACT_T0.
# +90 degrees flips the authored +Y Grip->BladeTip axis toward the enemy while
# keeping the hilt seated on Wrist.R.
const PRODUCTION_SWORD_WRIST_ROTATION := Vector3(0.0,0.0,90.0)
# Measured on the Blender 5.2 Rigify Basic Human production candidate:
# DEF-hand.R uses a different rest basis from legacy Wrist.R. Rotating the
# authored BladeTip (+Y from Grip) +90 degrees around local X points the blade
# almost directly toward the opponent in BattleCamera (~0.94 direction dot).
const PRODUCTION_RIGIFY_SWORD_HAND_ROTATION := Vector3(90.0,0.0,0.0)

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

	var preview_model := _load_scene(VisualPolicy.HOUND_PREVIEW_SCENE)
	if preview_model != null:
		preview_model.name = "GraveHoundProductionPreview"
		VisualPolicy.tag_visual_tier(preview_model,"production_preview",VisualPolicy.HOUND_PREVIEW_SCENE)
		preview_model.set_meta("shadowborn_visible_tier","production_preview_original")
		preview_model.set_meta("shadowborn_preview_contract","vendor_quadruped_rig_hidden_by_preview_scene")
		return preview_model

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
	if skeleton != null:
		# Legacy/vendor rigs use Wrist.R. The Blender 5.2 Rigify Basic Human
		# production path exports DEF-hand.R. Prefer the production deform bone
		# when present so the authored Grip contract survives the handoff.
		var weapon_bone := ""
		if skeleton.find_bone("DEF-hand.R") >= 0:
			weapon_bone = "DEF-hand.R"
		elif skeleton.find_bone("Wrist.R") >= 0:
			weapon_bone = "Wrist.R"

		if not weapon_bone.is_empty():
			var socket := BoneAttachment3D.new()
			socket.name = "WeaponSocket"
			socket.bone_name = weapon_bone
			skeleton.add_child(socket)

			var sword := create_sword_prop()
			sword.name = "ShadowbornWeapon"
			var tier := str(sword.get_meta("shadowborn_visual_tier",""))
			if tier == "production":
				var grip := sword.find_child("Grip",true,false) as Node3D
				if grip == null:
					push_error("Production Shadow Sword must provide authored Grip marker")
				else:
					var mount := Node3D.new()
					mount.name = "WeaponGripMount"
					mount.rotation_degrees = PRODUCTION_RIGIFY_SWORD_HAND_ROTATION if weapon_bone == "DEF-hand.R" else PRODUCTION_SWORD_WRIST_ROTATION
					socket.add_child(mount)
					sword.transform = grip.transform.affine_inverse()
					mount.add_child(sword)
					return
			elif tier == "debug_vendor":
				sword.position = DEV_SWORD_WRIST_OFFSET
				sword.rotation_degrees = DEV_SWORD_WRIST_ROTATION
				socket.add_child(sword)
				return

	var fallback_socket := Node3D.new()
	fallback_socket.name = "WeaponSocket"
	fallback_socket.position = Vector3(0.52,1.03,0.04)
	fallback_socket.rotation_degrees.z = -15.0
	root.add_child(fallback_socket)
	var fallback_sword := create_sword_prop()
	fallback_sword.name = "ShadowbornWeapon"
	fallback_socket.add_child(fallback_sword)

const DEV_CORPSE_DEATH_FRACTION := 0.48
const DEV_CORPSE_LOCAL_OFFSET := Vector3(0.0,0.13,0.04)

static func pose_seated_corpse(root: Node3D) -> void:
	# Production Shadow will ship a dedicated seated/slumped corpse clip.
	if set_animation_end_pose(root,["Dead_Seated","dead_seated","Corpse_Seated","corpse_seated"]):
		return

	# The final frame of the temporary Quaternius Death clip lies almost flat and
	# disappeared inside the burial slab in camera captures. Freeze an earlier
	# collapse phase instead: head/torso stay above the slab and read as a slumped
	# body rather than a dark patch on the floor.
	if set_animation_pose_fraction(root,["Death"],DEV_CORPSE_DEATH_FRACTION):
		root.position = DEV_CORPSE_LOCAL_OFFSET
		root.rotation_degrees = Vector3(-10.0,0.0,-12.0)
		return

	# Last-resort emergency stand-in.
	root.position = Vector3(0.0,0.10,0.0)
	root.rotation_degrees = Vector3(8.0,0.0,-16.0)

static func play_resurrection(root: Node3D) -> bool:
	root.position = DEV_CORPSE_LOCAL_OFFSET
	return play_backwards_from_fraction(root,["Death"],DEV_CORPSE_DEATH_FRACTION,0.44,0.20)

static func pose_standing(root: Node3D) -> void:
	root.position = Vector3.ZERO
	root.rotation_degrees = Vector3.ZERO
	play_named_animation(root,["Idle_Neutral","Idle","Idle_Sword"],1.0,0.18)

static func play_shadow_idle(root: Node3D,speed: float = 1.0) -> bool:
	return play_named_animation(root,["Idle_Sword","Idle","Idle_Neutral"],speed,0.16)

static func play_shadow_basic(root: Node3D,speed: float = 1.0) -> bool:
	# A1: compact, readable single sword cut.
	return play_named_animation(root,["Sword_Slash","Attack","Attack_01","Basic_Attack"],speed,0.08)

static func play_shadow_heavy_prep(root: Node3D,speed: float = 1.0) -> bool:
	# A2 starts from a completely different body motion before the sword strike.
	return play_named_animation(root,["Roll","Run"],speed,0.08)

static func play_shadow_heavy_strike(root: Node3D,speed: float = 1.0) -> bool:
	# The second phase is deliberately slower/heavier than A1.
	return play_named_animation(root,["Sword_Slash","Attack","Attack_01"],speed*0.78,0.06)

static func play_shadow_hit(root: Node3D,speed: float = 1.0) -> bool:
	return play_named_animation(root,["HitRecieve","HitRecieve_2","Hit","Damage"],speed,0.08)

static func play_hound_idle(root: Node3D,speed: float = 1.0) -> bool:
	# Prefer the low-head dev idle when available: it produces a clearer threat
	# silhouette in the fixed battle camera. This remains a debug-only improvement;
	# the production Grave Hound still requires a bespoke HND_IDLE_LOW clip.
	return play_named_animation(root,["Idle_2_HeadLow","Idle_2","Idle"],speed,0.16)

static func play_hound_attack(root: Node3D,speed: float = 1.0) -> bool:
	# Production always prefers the dedicated HND_BITE_01 clip. Until that lands,
	# preserve a stable low-head canine silhouette during the authored root-lunge.
	# The vendor Attack remains diagnostic-only because its mid/late frames visibly
	# over-extend the forelimbs in the shipping side camera.
	return play_named_animation(root,["HND_BITE_01","Idle_2_HeadLow","Idle_2","Attack"],speed,0.08)

static func play_hound_hit(root: Node3D,speed: float = 1.0) -> bool:
	return play_named_animation(root,["Idle_HitReact1","Idle_HitReact2"],speed,0.06)

static func play_pickup(root: Node3D,speed: float = 1.0) -> bool:
	return play_named_animation(root,["Interact"],speed,0.14)

static func play_death(root: Node3D,speed: float = 1.0) -> bool:
	return play_named_animation(root,["Death","Die"],speed,0.08)

static func play_named_animation(root: Node,candidates: Array[String],speed: float = 1.0,blend: float = 0.12) -> bool:
	var player := _find_animation_player(root)
	if player == null:
		return false
	for candidate in candidates:
		if player.has_animation(candidate):
			player.play(candidate,_presentation_blend_time(blend,speed),speed,false)
			return true
	return false

static func play_backwards_named(root: Node,candidates: Array[String],speed: float = 1.0,blend: float = 0.12) -> bool:
	var player := _find_animation_player(root)
	if player == null:
		return false
	for candidate in candidates:
		if player.has_animation(candidate):
			player.play(candidate,_presentation_blend_time(blend,-absf(speed)),-absf(speed),true)
			return true
	return false

static func _presentation_blend_time(authored_blend: float,playback_speed: float) -> float:
	# AnimationPlayer custom_speed changes clip playback but not custom_blend decay.
	# Keep the transition at the same fraction of authored motion at 1x/2x.
	var effective_speed := maxf(absf(playback_speed),0.001)
	return authored_blend/effective_speed

static func set_animation_pose_fraction(root: Node,candidates: Array[String],fraction: float) -> bool:
	var player := _find_animation_player(root)
	if player == null:
		return false
	for candidate in candidates:
		if player.has_animation(candidate):
			player.play(candidate,0.0,1.0,false)
			player.seek(player.current_animation_length*clampf(fraction,0.0,1.0),true)
			player.pause()
			return true
	return false

static func play_backwards_from_fraction(root: Node,candidates: Array[String],fraction: float,speed: float = 1.0,blend: float = 0.12) -> bool:
	var player := _find_animation_player(root)
	if player == null:
		return false
	for candidate in candidates:
		if player.has_animation(candidate):
			player.play(candidate,_presentation_blend_time(blend,-absf(speed)),-absf(speed),true)
			player.seek(player.current_animation_length*clampf(fraction,0.0,1.0),true)
			return true
	return false

static func set_animation_end_pose(root: Node,candidates: Array[String]) -> bool:
	var player := _find_animation_player(root)
	if player == null:
		return false
	for candidate in candidates:
		if player.has_animation(candidate):
			player.play(candidate,0.0,1.0,false)
			player.seek(player.current_animation_length,true)
			player.pause()
			return true
	return false

static func has_animation(root: Node,name_: String) -> bool:
	var player := _find_animation_player(root)
	return player != null and player.has_animation(name_)

static func animation_names(root: Node) -> PackedStringArray:
	var player := _find_animation_player(root)
	if player == null:
		return []
	return player.get_animation_list()

static func _prepare_dev_shadow(root: Node3D) -> void:
	# Emergency debug fallback only. The normal non-acceptance path now uses
	# shadow_preview.tscn, where vendor geometry is hidden and only the rig/animations
	# remain as temporary carriers.
	var backpack := root.find_child("Backpack",true,false)
	if backpack is Node3D:
		(backpack as Node3D).visible = false

	var body := root.find_child("Adventurer_Body",true,false) as MeshInstance3D
	var legs := root.find_child("Adventurer_Legs",true,false) as MeshInstance3D
	var feet := root.find_child("Adventurer_Feet",true,false) as MeshInstance3D
	var head := root.find_child("Adventurer_Head",true,false) as MeshInstance3D
	var shadow_mat := _shadow_material()
	if body:
		body.material_override = shadow_mat
	if legs:
		legs.material_override = shadow_mat
	if feet:
		feet.material_override = _mat(Color(0.008,0.010,0.016),0.94,0.0)
	if head:
		head.material_override = _mat(Color(0.002,0.003,0.006),1.0,0.0)
	_add_shadow_hood_and_eyes(root)
	_add_shadow_mist(root)
	_enable_shadows(root)

static func _hide_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_hide_meshes(child)

static func _add_shadow_production_preview(root: Node3D) -> void:
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		return
	if skeleton.find_child("ShadowPreviewMarker",false,false) != null:
		return

	var marker := Node3D.new()
	marker.name = "ShadowPreviewMarker"
	marker.set_meta("shadowborn_visual_tier","production_preview_original")
	marker.set_meta("shadowborn_role","visible_shell_on_temporary_rig")
	skeleton.add_child(marker)

	var body_mat := _shadow_material()
	var cloth_mat := _mat(Color(0.007,0.009,0.014),0.97,0.0)
	var edge_mat := _mat(Color(0.018,0.022,0.032),0.90,0.0)
	var void_mat := _mat(Color(0.0,0.0,0.002),1.0,0.0)
	var core_mat := _mat(Color(0.055,0.16,0.42),0.48,0.0,true)
	core_mat.emission_energy_multiplier = 0.62

	# Body mass follows the existing semantic bone chain. Each piece is original
	# runtime geometry and intentionally low-detail: the goal of this pass is to
	# lock Shadow's readable silhouette before expensive final topology/materials.
	_add_shadow_segment(skeleton,"Hips","Abdomen",0.205,0.74,body_mat,"PreviewPelvis")
	_add_shadow_segment(skeleton,"Abdomen","Torso",0.225,0.72,body_mat,"PreviewAbdomen")
	_add_shadow_segment(skeleton,"Torso","Chest",0.255,0.70,body_mat,"PreviewTorso")
	_add_shadow_segment(skeleton,"Chest","Neck",0.285,0.68,body_mat,"PreviewChest")

	for side in ["L","R"]:
		_add_shadow_segment(skeleton,"Shoulder."+side,"UpperArm."+side,0.135,0.82,edge_mat,"PreviewShoulder"+side)
		_add_shadow_segment(skeleton,"UpperArm."+side,"LowerArm."+side,0.105,0.78,body_mat,"PreviewUpperArm"+side)
		_add_shadow_segment(skeleton,"LowerArm."+side,"Wrist."+side,0.085,0.74,body_mat,"PreviewLowerArm"+side)
		_add_shadow_segment(skeleton,"UpperLeg."+side,"LowerLeg."+side,0.145,0.78,cloth_mat,"PreviewUpperLeg"+side)
		_add_shadow_segment(skeleton,"LowerLeg."+side,"Foot."+side,0.112,0.72,cloth_mat,"PreviewLowerLeg"+side)
		_add_shadow_hand(skeleton,"Wrist."+side,side,body_mat)
		_add_shadow_foot(skeleton,"Foot."+side,side,cloth_mat)

	# A short layered cowl gives the protagonist a deliberate shoulder/head break
	# without turning him into a caped knight or inflating the silhouette.
	var chest_socket := _bone_socket(skeleton,"Chest","PreviewCowlSocket")
	if chest_socket != null:
		var cowl := MeshInstance3D.new()
		cowl.name = "PreviewCowl"
		var cowl_mesh := CylinderMesh.new()
		cowl_mesh.top_radius = 0.22
		cowl_mesh.bottom_radius = 0.37
		cowl_mesh.height = 0.20
		cowl_mesh.radial_segments = 10
		cowl_mesh.rings = 1
		cowl_mesh.material = cloth_mat
		cowl.mesh = cowl_mesh
		cowl.position = Vector3(0.0,0.035,0.0)
		cowl.scale = Vector3(1.0,1.0,0.68)
		_tag_preview_mesh(cowl)
		chest_socket.add_child(cowl)

		var core := MeshInstance3D.new()
		core.name = "PreviewChestCore"
		var core_mesh := SphereMesh.new()
		core_mesh.radius = 0.050
		core_mesh.height = 0.100
		core_mesh.radial_segments = 12
		core_mesh.rings = 6
		core_mesh.material = core_mat
		core.mesh = core_mesh
		core.position = Vector3(0.0,0.015,0.235)
		core.scale = Vector3(1.18,1.0,0.34)
		_tag_preview_mesh(core)
		chest_socket.add_child(core)

	var head_socket := _bone_socket(skeleton,"Head","PreviewHeadSocket")
	if head_socket != null:
		var hood := MeshInstance3D.new()
		hood.name = "PreviewHood"
		var hood_mesh := CapsuleMesh.new()
		hood_mesh.radius = 0.215
		hood_mesh.height = 0.445
		hood_mesh.radial_segments = 14
		hood_mesh.rings = 7
		hood_mesh.material = cloth_mat
		hood.mesh = hood_mesh
		hood.position = Vector3(0.0,0.025,-0.018)
		hood.scale = Vector3(0.92,1.03,0.88)
		_tag_preview_mesh(hood)
		head_socket.add_child(hood)

		var face_void := MeshInstance3D.new()
		face_void.name = "PreviewFaceVoid"
		var void_mesh := SphereMesh.new()
		void_mesh.radius = 0.148
		void_mesh.height = 0.296
		void_mesh.radial_segments = 12
		void_mesh.rings = 6
		void_mesh.material = void_mat
		face_void.mesh = void_mesh
		face_void.position = Vector3(0.0,-0.015,0.158)
		face_void.scale = Vector3(0.76,0.94,0.28)
		_tag_preview_mesh(face_void)
		head_socket.add_child(face_void)

		for side in [-1.0,1.0]:
			var eye := MeshInstance3D.new()
			eye.name = "PreviewEyeL" if side < 0.0 else "PreviewEyeR"
			var eye_mesh := SphereMesh.new()
			eye_mesh.radius = 0.014
			eye_mesh.height = 0.028
			eye_mesh.radial_segments = 8
			eye_mesh.rings = 4
			eye_mesh.material = core_mat
			eye.mesh = eye_mesh
			eye.position = Vector3(0.050*side,0.003,0.196)
			eye.scale = Vector3(1.35,0.48,0.42)
			_tag_preview_mesh(eye)
			head_socket.add_child(eye)

static func _add_shadow_segment(skeleton: Skeleton3D,bone_name: String,child_bone_name: String,radius: float,z_scale: float,material: Material,node_name: String) -> void:
	var bone_idx := skeleton.find_bone(bone_name)
	var child_idx := skeleton.find_bone(child_bone_name)
	if bone_idx < 0 or child_idx < 0 or skeleton.get_bone_parent(child_idx) != bone_idx:
		return
	var end_local := skeleton.get_bone_rest(child_idx).origin
	var length := end_local.length()
	if length < 0.025:
		return
	var socket := _bone_socket(skeleton,bone_name,node_name+"Socket")
	if socket == null:
		return
	var segment := MeshInstance3D.new()
	segment.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius*0.88
	mesh.bottom_radius = radius
	mesh.height = length*0.96
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = material
	segment.mesh = mesh
	segment.position = end_local*0.48
	segment.quaternion = Quaternion(Vector3.UP,end_local.normalized())
	segment.scale = Vector3(1.0,1.0,z_scale)
	_tag_preview_mesh(segment)
	socket.add_child(segment)

static func _add_shadow_hand(skeleton: Skeleton3D,bone_name: String,side: String,material: Material) -> void:
	var socket := _bone_socket(skeleton,bone_name,"PreviewHandSocket"+side)
	if socket == null:
		return
	var hand := MeshInstance3D.new()
	hand.name = "PreviewHand"+side
	var mesh := SphereMesh.new()
	mesh.radius = 0.078
	mesh.height = 0.156
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = material
	hand.mesh = mesh
	hand.scale = Vector3(0.78,1.05,0.62)
	_tag_preview_mesh(hand)
	socket.add_child(hand)

static func _add_shadow_foot(skeleton: Skeleton3D,bone_name: String,side: String,material: Material) -> void:
	var socket := _bone_socket(skeleton,bone_name,"PreviewFootSocket"+side)
	if socket == null:
		return
	var foot := MeshInstance3D.new()
	foot.name = "PreviewFoot"+side
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.17,0.12,0.33)
	mesh.material = material
	foot.mesh = mesh
	foot.position = Vector3(0.0,-0.015,0.105)
	foot.rotation_degrees.x = -4.0
	_tag_preview_mesh(foot)
	socket.add_child(foot)

static func _bone_socket(skeleton: Skeleton3D,bone_name: String,node_name: String) -> BoneAttachment3D:
	if skeleton.find_bone(bone_name) < 0:
		return null
	var socket := BoneAttachment3D.new()
	socket.name = node_name
	socket.bone_name = bone_name
	skeleton.add_child(socket)
	return socket

static func _tag_preview_mesh(mesh: MeshInstance3D) -> void:
	mesh.set_meta("shadowborn_visual_tier","production_preview_original")
	mesh.set_meta("shadowborn_visual_source","generated://shadow_preview_v1")
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

static func _prepare_dev_hound(root: Node3D) -> void:
	var wolf := root.find_child("Wolf",true,false) as MeshInstance3D
	if wolf:
		_tint_imported_materials(wolf,Color(0.46,0.56,0.42,1.0),0.18)
	_add_hound_undead_details(root)
	_enable_shadows(root)

static func _shadow_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
void fragment() {
	float ripple = 0.5 + 0.5 * sin(UV.y * 34.0 + TIME * 0.9 + sin(UV.x * 19.0));
	float edge = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.5);
	ALBEDO = mix(vec3(0.002,0.003,0.006), vec3(0.014,0.019,0.032), ripple * 0.32);
	ROUGHNESS = 0.93;
	METALLIC = 0.0;
	EMISSION = vec3(0.015,0.025,0.055) * edge * 0.48;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

static func _add_shadow_hood_and_eyes(root: Node3D) -> void:
	var skeleton := _find_skeleton(root)
	if skeleton == null or skeleton.find_bone("Head") < 0:
		return
	if skeleton.find_child("ShadowIdentity",false,false) != null:
		return

	var socket := BoneAttachment3D.new()
	socket.name = "ShadowIdentity"
	socket.bone_name = "Head"
	skeleton.add_child(socket)

	# Keep the temporary hood close to believable adult-human head proportions.
	# The previous oversized sphere read as a ball from the actual combat camera.
	var hood := MeshInstance3D.new()
	var hood_mesh := CapsuleMesh.new()
	hood_mesh.radius = 0.205
	hood_mesh.height = 0.455
	hood_mesh.radial_segments = 20
	hood_mesh.rings = 8
	hood_mesh.material = _mat(Color(0.006,0.008,0.013),0.97,0.0)
	hood.mesh = hood_mesh
	hood.position = Vector3(0.0,0.035,-0.018)
	hood.scale = Vector3(0.92,1.02,0.88)
	socket.add_child(hood)

	# A narrow recessed void hides the imported face without swelling the silhouette.
	var face_void := MeshInstance3D.new()
	var void_mesh := SphereMesh.new()
	void_mesh.radius = 0.145
	void_mesh.height = 0.29
	void_mesh.radial_segments = 16
	void_mesh.rings = 8
	void_mesh.material = _mat(Color(0.0,0.0,0.002),1.0,0.0)
	face_void.mesh = void_mesh
	face_void.position = Vector3(0.0,-0.015,0.155)
	face_void.scale = Vector3(0.78,0.96,0.30)
	socket.add_child(face_void)

	for side in [-1.0,1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.016
		eye_mesh.height = 0.032
		eye_mesh.radial_segments = 10
		eye_mesh.rings = 5
		var eye_mat := _mat(Color(0.10,0.27,0.62),0.42,0.0,true)
		eye_mat.emission_energy_multiplier = 0.75
		eye_mesh.material = eye_mat
		eye.mesh = eye_mesh
		eye.position = Vector3(0.050*side,0.005,0.198)
		eye.scale = Vector3(1.18,0.58,0.48)
		socket.add_child(eye)

static func _add_shadow_mist(root: Node3D) -> void:
	if root.find_child("ShadowMist",false,false) != null:
		return
	var particles := GPUParticles3D.new()
	particles.name = "ShadowMist"
	particles.amount = 18
	particles.lifetime = 1.7
	particles.randomness = 0.48
	particles.position = Vector3(0,0.85,0)
	particles.visibility_aabb = AABB(Vector3(-0.8,-0.4,-0.8),Vector3(1.6,2.8,1.6))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.32,0.72,0.22)
	process.direction = Vector3(0,1,0)
	process.spread = 42.0
	process.gravity = Vector3(0,0.08,0)
	process.initial_velocity_min = 0.03
	process.initial_velocity_max = 0.16
	process.scale_min = 0.07
	process.scale_max = 0.19
	process.color = Color(0.006,0.010,0.020,0.20)
	particles.process_material = process

	var quad := QuadMesh.new()
	quad.size = Vector2(0.34,0.34)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_mat.albedo_color = Color(0.008,0.012,0.025,0.20)
	quad.material = smoke_mat
	particles.draw_pass_1 = quad
	root.add_child(particles)

static func _tint_imported_materials(mesh_instance: MeshInstance3D,tint: Color,roughness_add: float) -> void:
	if mesh_instance.mesh == null:
		return
	for surface in range(mesh_instance.mesh.get_surface_count()):
		var source := mesh_instance.mesh.surface_get_material(surface)
		if source is BaseMaterial3D:
			var copy := source.duplicate() as BaseMaterial3D
			copy.albedo_color *= tint
			copy.roughness = clampf(copy.roughness + roughness_add,0.0,1.0)
			mesh_instance.set_surface_override_material(surface,copy)

static func _add_hound_undead_details(root: Node3D) -> void:
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		return

	if skeleton.find_bone("Head") >= 0:
		var head_socket := BoneAttachment3D.new()
		head_socket.name = "UndeadHeadFX"
		head_socket.bone_name = "Head"
		skeleton.add_child(head_socket)
		for side in [-1.0,1.0]:
			var eye := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.030
			mesh.height = 0.060
			mesh.radial_segments = 10
			mesh.rings = 5
			var eye_mat := _mat(Color(0.64,0.085,0.018),0.46,0.0,true)
			# The eyes must read as undead from the combat camera without becoming
			# neon beacons that overpower the Hound silhouette.
			eye_mat.emission_energy_multiplier = 0.72
			mesh.material = eye_mat
			eye.mesh = mesh
			eye.position = Vector3(0.075*side,0.055,-0.225)
			head_socket.add_child(eye)

	if skeleton.find_bone("Torso2") >= 0:
		var torso_socket := BoneAttachment3D.new()
		torso_socket.name = "UndeadTorsoIdentity"
		torso_socket.bone_name = "Torso2"
		skeleton.add_child(torso_socket)

		# Two recessed dark flesh wounds break the healthy-wolf read. They stay
		# opaque and low-poly so the silhouette remains clean on mobile.
		for wound_data in [
			[Vector3(0.17,0.015,-0.15),Vector3(1.45,0.22,0.78),-9.0],
			[Vector3(-0.14,-0.055,0.11),Vector3(1.10,0.18,0.62),12.0]
		]:
			var wound := MeshInstance3D.new()
			var wound_mesh := SphereMesh.new()
			wound_mesh.radius = 0.105
			wound_mesh.height = 0.21
			wound_mesh.radial_segments = 10
			wound_mesh.rings = 5
			wound_mesh.material = _mat(Color(0.115,0.020,0.014),0.93,0.0)
			wound.mesh = wound_mesh
			wound.position = wound_data[0]
			wound.scale = wound_data[1]
			wound.rotation_degrees.z = wound_data[2]
			torso_socket.add_child(wound)

		# A few exposed ribs are enough to communicate emaciation from the authored
		# 3/4 camera. Do not build a full skeleton cage: six tiny opaque pieces are
		# cheaper and read better than dense geometry at phone size.
		var rib_material := _mat(Color(0.34,0.31,0.235),0.91,0.0)
		for side in [-1.0,1.0]:
			for index in range(3):
				var rib := MeshInstance3D.new()
				var rib_mesh := CylinderMesh.new()
				rib_mesh.top_radius = 0.014
				rib_mesh.bottom_radius = 0.018
				rib_mesh.height = 0.24 - 0.022*index
				rib_mesh.radial_segments = 7
				rib_mesh.material = rib_material
				rib.mesh = rib_mesh
				rib.position = Vector3(0.13*side,-0.035+0.055*index,-0.075+0.038*index)
				rib.rotation_degrees = Vector3(82.0,12.0*side,side*(24.0-5.0*index))
				rib.scale = Vector3(1.0,1.0,0.84)
				torso_socket.add_child(rib)

static func _prepare_sword(root: Node3D) -> void:
	root.scale = Vector3.ONE*DEV_SWORD_PRESENTATION_SCALE
	_apply_rust_to_meshes(root)
	_enable_shadows(root)

static func _apply_rust_to_meshes(root: Node) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_override = _rust_material()
	for child in root.get_children():
		_apply_rust_to_meshes(child)

static func _rust_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
void fragment() {
	float n1 = 0.5 + 0.5 * sin(UV.x * 71.0 + sin(UV.y * 39.0) * 2.0);
	float n2 = 0.5 + 0.5 * sin(UV.y * 113.0 + UV.x * 17.0);
	float rust = smoothstep(0.44,0.78,n1*0.65+n2*0.35);
	vec3 steel = vec3(0.16,0.17,0.18);
	vec3 oxide = vec3(0.34,0.085,0.018);
	vec3 deep = vec3(0.085,0.027,0.012);
	vec3 col = mix(steel,oxide,rust);
	col = mix(col,deep,smoothstep(0.72,0.95,n2)*rust);
	ALBEDO = col;
	METALLIC = mix(0.62,0.08,rust);
	ROUGHNESS = mix(0.48,0.96,rust);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

static func _enable_shadows(root: Node) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in root.get_children():
		_enable_shadows(child)

static func _set_named_weapon_visible(root: Node,visible_: bool) -> void:
	for candidate in ["Weapon","Sword","weapon","sword","ShadowbornWeapon"]:
		var found := root.find_child(candidate,true,false)
		if found is Node3D:
			(found as Node3D).visible = visible_

static func _load_scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D

static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	if root is AnimationPlayer:
		return root as AnimationPlayer

	# Imported character hierarchies do not change at runtime. Cache the relative
	# NodePath on the queried root so repeated attacks/idle/hit reactions avoid
	# recursively traversing the full glTF tree every time an animation starts.
	if root.has_meta(META_ANIMATION_PLAYER_PATH):
		var cached_path: NodePath = root.get_meta(META_ANIMATION_PLAYER_PATH)
		var cached_node := root.get_node_or_null(cached_path)
		if cached_node is AnimationPlayer:
			return cached_node as AnimationPlayer
		root.remove_meta(META_ANIMATION_PLAYER_PATH)

	var found := _find_animation_player_uncached(root)
	if found != null:
		root.set_meta(META_ANIMATION_PLAYER_PATH,root.get_path_to(found))
	return found

static func _find_animation_player_uncached(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player_uncached(child)
		if found != null:
			return found
	return null

static func _find_skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null
	if root is Skeleton3D:
		return root as Skeleton3D

	if root.has_meta(META_SKELETON_PATH):
		var cached_path: NodePath = root.get_meta(META_SKELETON_PATH)
		var cached_node := root.get_node_or_null(cached_path)
		if cached_node is Skeleton3D:
			return cached_node as Skeleton3D
		root.remove_meta(META_SKELETON_PATH)

	var found := _find_skeleton_uncached(root)
	if found != null:
		root.set_meta(META_SKELETON_PATH,root.get_path_to(found))
	return found

static func _find_skeleton_uncached(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton_uncached(child)
		if found != null:
			return found
	return null

static func _mat(color: Color,roughness: float=0.8,metallic: float=0.0,emission: bool=false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.2
	return mat

static func _box(size: Vector3,color: Color,metallic: float=0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color,0.70,metallic)
	node.mesh = mesh
	return node

static func _sphere(radius: float,color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _mat(color)
	node.mesh = mesh
	return node

static func _capsule(radius: float,height: float,color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _mat(color)
	node.mesh = mesh
	return node

static func _build_missing_production_asset(label: String,path: String) -> Node3D:
	push_error("VISUAL ACCEPTANCE BLOCKED: missing production asset for %s: %s" % [label,path])
	var root := Node3D.new()
	root.name = "MISSING_PRODUCTION_%s" % label.to_upper().replace(" ","_")
	VisualPolicy.tag_visual_tier(root,"missing_production",path)
	root.set_meta("visual_acceptance_error",true)

	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.75,1.75,0.75)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92,0.0,0.72)
	material.emission_enabled = true
	material.emission = Color(0.92,0.0,0.72)
	material.emission_energy_multiplier = 1.8
	material.roughness = 0.55
	mesh.material = material
	marker.mesh = mesh
	marker.position.y = 0.875
	root.add_child(marker)
	return root

static func _build_emergency_sword() -> Node3D:
	var root := Node3D.new()
	root.name = "EmergencySword"
	var blade := _box(Vector3(0.055,1.25,0.035),Color(0.38,0.42,0.49),0.7)
	blade.position.y = 0.42
	root.add_child(blade)
	var guard := _box(Vector3(0.34,0.065,0.065),Color(0.18,0.19,0.21),0.6)
	guard.position.y = -0.20
	root.add_child(guard)
	return root

static func _build_emergency_shadow(with_sword: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "ShadowEmergencyFallback"
	var torso := _capsule(0.34,1.05,Color(0.035,0.040,0.052))
	torso.position = Vector3(0,1.35,0)
	root.add_child(torso)
	var head := _sphere(0.26,Color(0.35,0.28,0.25))
	head.position = Vector3(0,2.05,0)
	root.add_child(head)
	for side in [-1.0,1.0]:
		var leg := _capsule(0.13,0.82,Color(0.045,0.047,0.052))
		leg.position = Vector3(0.17*side,0.55,0)
		root.add_child(leg)
		var arm := _capsule(0.10,0.70,Color(0.030,0.033,0.042))
		arm.position = Vector3(0.43*side,1.28,0)
		root.add_child(arm)
	if with_sword:
		attach_sword(root)
	return root

static func _build_emergency_hound() -> Node3D:
	var root := Node3D.new()
	root.name = "HoundEmergencyFallback"
	var body := _capsule(0.36,1.10,Color(0.075,0.08,0.09))
	body.position = Vector3(0,0.65,0)
	body.rotation_degrees.z = 90
	root.add_child(body)
	var head := _sphere(0.30,Color(0.065,0.07,0.08))
	head.position = Vector3(-0.72,0.78,0)
	root.add_child(head)
	return root
