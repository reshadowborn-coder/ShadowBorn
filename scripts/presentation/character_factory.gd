class_name CharacterFactory
extends RefCounted

const FINAL_SHADOW := "res://assets/characters/shadow/shadow.glb"
const FINAL_HOUND := "res://assets/characters/grave_hound/grave_hound.glb"

const DEV_SHADOW := "res://assets/vendor/quaternius/shadow_adventurer.gltf"
const DEV_HOUND := "res://assets/vendor/quaternius/grave_wolf.gltf"
const DEV_SWORD := "res://assets/vendor/quaternius/shadow_sword.gltf"

const META_ANIMATION_PLAYER_PATH := &"_shadowborn_animation_player_path"
const META_SKELETON_PATH := &"_shadowborn_skeleton_path"

static func create_shadow(with_sword: bool = true) -> Node3D:
	var final_model := _load_scene(FINAL_SHADOW)
	if final_model != null:
		final_model.name = "ShadowModel"
		_set_named_weapon_visible(final_model,with_sword)
		return final_model

	var dev_model := _load_scene(DEV_SHADOW)
	if dev_model != null:
		dev_model.name = "ShadowDevModel"
		_prepare_dev_shadow(dev_model)
		if with_sword:
			attach_sword(dev_model)
		return dev_model

	return _build_emergency_shadow(with_sword)

static func create_hound() -> Node3D:
	var final_model := _load_scene(FINAL_HOUND)
	if final_model != null:
		final_model.name = "GraveHoundModel"
		return final_model

	var dev_model := _load_scene(DEV_HOUND)
	if dev_model != null:
		dev_model.name = "GraveHoundDevModel"
		_prepare_dev_hound(dev_model)
		return dev_model

	return _build_emergency_hound()

static func create_sword_prop() -> Node3D:
	var model := _load_scene(DEV_SWORD)
	if model != null:
		model.name = "SwordProp"
		_prepare_sword(model)
		return model
	return _build_emergency_sword()

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
		sword.position = Vector3(0.0,0.08,0.0)
		sword.rotation_degrees = Vector3(0.0,0.0,180.0)
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

static func pose_seated_corpse(root: Node3D) -> void:
	# Production model can ship a dedicated seated-death clip later.
	if set_animation_end_pose(root,["Dead_Seated","dead_seated","Corpse_Seated","corpse_seated"]):
		return

	# The CC0 development character has a real skeletal Death clip. Its final frame
	# gives us a physically collapsed body instead of a rigid primitive mannequin.
	if set_animation_end_pose(root,["Death"]):
		root.position = Vector3(0.0,-0.06,0.04)
		root.rotation_degrees = Vector3(-7.0,0.0,-13.0)
		return

	# Last-resort emergency stand-in.
	root.position = Vector3(0.0,-0.08,0.0)
	root.rotation_degrees = Vector3(8.0,0.0,-16.0)

static func play_resurrection(root: Node3D) -> bool:
	root.position = Vector3(0.0,-0.06,0.04)
	return play_backwards_named(root,["Death"],0.52,0.20)

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
	return play_named_animation(root,["Idle","Idle_2","Idle_2_HeadLow"],speed,0.16)

static func play_hound_attack(root: Node3D,speed: float = 1.0) -> bool:
	return play_named_animation(root,["Attack"],speed,0.08)

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
			player.play(candidate,blend,speed,false)
			return true
	return false

static func play_backwards_named(root: Node,candidates: Array[String],speed: float = 1.0,blend: float = 0.12) -> bool:
	var player := _find_animation_player(root)
	if player == null:
		return false
	for candidate in candidates:
		if player.has_animation(candidate):
			player.play(candidate,blend,-absf(speed),true)
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
		# No human face: the imported head becomes a light-absorbing void.
		head.material_override = _mat(Color(0.002,0.003,0.006),1.0,0.0)

	_add_shadow_hood_and_eyes(root)
	_add_shadow_mist(root)
	_enable_shadows(root)

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
			mesh.material = _mat(Color(0.72,0.10,0.025),0.42,0.0,true)
			eye.mesh = mesh
			eye.position = Vector3(0.075*side,0.055,-0.225)
			head_socket.add_child(eye)

	if skeleton.find_bone("Torso2") >= 0:
		var torso_socket := BoneAttachment3D.new()
		torso_socket.name = "UndeadWound"
		torso_socket.bone_name = "Torso2"
		skeleton.add_child(torso_socket)
		var wound := MeshInstance3D.new()
		var wound_mesh := SphereMesh.new()
		wound_mesh.radius = 0.12
		wound_mesh.height = 0.24
		wound_mesh.radial_segments = 12
		wound_mesh.rings = 6
		wound_mesh.material = _mat(Color(0.16,0.025,0.018),0.86,0.0)
		wound.mesh = wound_mesh
		wound.position = Vector3(0.18,0.02,-0.15)
		wound.scale = Vector3(1.5,0.28,0.8)
		torso_socket.add_child(wound)

static func _prepare_sword(root: Node3D) -> void:
	root.scale = Vector3(0.92,0.92,0.92)
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
