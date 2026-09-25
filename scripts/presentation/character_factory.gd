class_name CharacterFactory
extends RefCounted

const FINAL_SHADOW := "res://assets/characters/shadow/shadow.glb"
const FINAL_HOUND := "res://assets/characters/grave_hound/grave_hound.glb"

const DEV_SHADOW := "res://assets/vendor/quaternius/shadow_adventurer.gltf"
const DEV_HOUND := "res://assets/vendor/quaternius/grave_wolf.gltf"
const DEV_SWORD := "res://assets/vendor/quaternius/shadow_sword.gltf"

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

static func play_shadow_attack(root: Node3D,speed: float = 1.0) -> bool:
	return play_named_animation(root,["Sword_Slash","Attack","Attack_01","Basic_Attack"],speed,0.10)

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

static func animation_names(root: Node) -> Array[StringName]:
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

	if body:
		body.material_override = _mat(Color(0.035,0.042,0.052),0.88,0.02)
	if legs:
		legs.material_override = _mat(Color(0.055,0.058,0.065),0.90,0.0)
	if feet:
		feet.material_override = _mat(Color(0.070,0.050,0.038),0.82,0.02)

	_enable_shadows(root)

static func _prepare_dev_hound(root: Node3D) -> void:
	_enable_shadows(root)

static func _prepare_sword(root: Node3D) -> void:
	root.scale = Vector3(0.92,0.92,0.92)
	_enable_shadows(root)

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
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
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
