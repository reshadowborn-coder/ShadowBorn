class_name CharacterFactory
extends RefCounted

const SHADOW_SCENE := "res://assets/characters/shadow/shadow.glb"
const HOUND_SCENE := "res://assets/characters/grave_hound/grave_hound.glb"

static func create_shadow() -> Node3D:
	var loaded := _load_scene(SHADOW_SCENE)
	if loaded != null:
		loaded.name = "ShadowModel"
		return loaded
	return _build_shadow_fallback()

static func create_hound() -> Node3D:
	var loaded := _load_scene(HOUND_SCENE)
	if loaded != null:
		loaded.name = "GraveHoundModel"
		return loaded
	return _build_hound_fallback()

static func play_named_animation(root: Node, candidates: Array[String]) -> bool:
	var player := _find_animation_player(root)
	if player == null:
		return false
	for name in candidates:
		if player.has_animation(name):
			player.play(name)
			return true
	return false

static func _load_scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate()
	return node as Node3D

static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

static func _mat(color: Color, roughness: float=0.8, metallic: float=0.0, emission: bool=false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.6
	return mat

static func _sphere(radius: float, color: Color, emission: bool=false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	mesh.material = _mat(color,0.72,0.0,emission)
	n.mesh = mesh
	return n

static func _capsule(radius: float, height: float, color: Color, metallic: float=0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 12
	mesh.material = _mat(color,0.66,metallic)
	n.mesh = mesh
	return n

static func _cylinder(radius: float, height: float, color: Color, metallic: float=0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.material = _mat(color,0.62,metallic)
	n.mesh = mesh
	return n

static func _box(size: Vector3, color: Color, metallic: float=0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color,0.62,metallic)
	n.mesh = mesh
	return n

static func _build_shadow_fallback() -> Node3D:
	var root := Node3D.new()
	root.name = "ShadowFallback"
	var armor := Color(0.030,0.038,0.058)
	var armor_mid := Color(0.075,0.090,0.130)
	var steel := Color(0.32,0.37,0.46)
	var skin := Color(0.39,0.31,0.28)

	var pelvis := _capsule(0.27,0.62,armor)
	pelvis.position = Vector3(0,0.87,0)
	root.add_child(pelvis)

	for side in [-1.0,1.0]:
		var thigh := _capsule(0.14,0.70,armor)
		thigh.position = Vector3(0.17*side,0.53,0)
		thigh.rotation_degrees.z = 2.5*side
		root.add_child(thigh)
		var boot := _capsule(0.13,0.50,Color(0.025,0.029,0.040))
		boot.position = Vector3(0.17*side,0.19,0.02)
		root.add_child(boot)

	var torso := _capsule(0.39,1.16,armor_mid,0.10)
	torso.position = Vector3(0,1.43,0)
	torso.scale = Vector3(1.05,1.0,0.78)
	root.add_child(torso)

	var chest_plate := _sphere(0.36,Color(0.09,0.105,0.15))
	chest_plate.position = Vector3(0,1.48,0.24)
	chest_plate.scale = Vector3(1.03,1.10,0.28)
	root.add_child(chest_plate)

	for side in [-1.0,1.0]:
		var shoulder := _sphere(0.245,steel)
		shoulder.position = Vector3(0.43*side,1.64,0.01)
		shoulder.scale = Vector3(1.0,0.78,1.0)
		root.add_child(shoulder)
		var upper := _capsule(0.105,0.56,armor)
		upper.position = Vector3(0.48*side,1.31,0)
		upper.rotation_degrees.z = 8.0*side
		root.add_child(upper)
		var fore := _capsule(0.095,0.48,Color(0.055,0.065,0.09),0.18)
		fore.position = Vector3(0.53*side,1.00,0.03)
		fore.rotation_degrees.z = 4.0*side
		root.add_child(fore)

	var neck := _cylinder(0.13,0.18,skin)
	neck.position = Vector3(0,1.98,0)
	root.add_child(neck)
	var face := _sphere(0.285,skin)
	face.position = Vector3(0,2.18,0.015)
	face.scale = Vector3(0.90,1.07,0.84)
	root.add_child(face)
	var hood := _sphere(0.33,armor)
	hood.position = Vector3(0,2.28,-0.035)
	hood.scale = Vector3(1.02,0.80,1.06)
	root.add_child(hood)
	var mask := _box(Vector3(0.47,0.17,0.035),Color(0.010,0.014,0.024))
	mask.position = Vector3(0,2.18,0.255)
	root.add_child(mask)

	for side in [-1.0,1.0]:
		var eye := _sphere(0.031,Color(0.44,0.62,1.0),true)
		eye.name = "GlowEye"
		eye.position = Vector3(0.09*side,2.205,0.278)
		root.add_child(eye)

	var cloak := _box(Vector3(0.73,1.18,0.055),Color(0.028,0.034,0.050))
	cloak.position = Vector3(0,1.36,-0.31)
	cloak.rotation_degrees.x = 8
	root.add_child(cloak)

	var sword := Node3D.new()
	sword.name = "Weapon"
	sword.position = Vector3(0.57,1.02,0.07)
	sword.rotation_degrees.z = -15
	var blade := _box(Vector3(0.065,1.28,0.04),Color(0.48,0.53,0.62),0.72)
	blade.position.y = 0.42
	sword.add_child(blade)
	var guard := _box(Vector3(0.38,0.07,0.07),steel,0.65)
	guard.position.y = -0.19
	sword.add_child(guard)
	var grip := _cylinder(0.043,0.38,Color(0.12,0.075,0.045),0.05)
	grip.position.y = -0.38
	sword.add_child(grip)
	root.add_child(sword)

	return root

static func _build_hound_fallback() -> Node3D:
	var root := Node3D.new()
	root.name = "GraveHoundFallback"
	var fur := Color(0.095,0.105,0.115)
	var bone := Color(0.38,0.36,0.32)
	var wound := Color(0.24,0.055,0.045)

	var body := _capsule(0.38,1.15,fur)
	body.position = Vector3(0,0.72,0)
	body.rotation_degrees.z = 90
	body.scale = Vector3(1.0,1.14,0.76)
	root.add_child(body)

	var chest := _sphere(0.42,fur)
	chest.position = Vector3(-0.38,0.80,0)
	chest.scale = Vector3(1.0,1.08,0.78)
	root.add_child(chest)

	var head := _sphere(0.31,fur)
	head.position = Vector3(-0.86,0.91,0.02)
	head.scale = Vector3(1.12,0.87,0.86)
	root.add_child(head)
	var muzzle := _capsule(0.17,0.43,Color(0.075,0.080,0.087))
	muzzle.position = Vector3(-1.12,0.84,0.02)
	muzzle.rotation_degrees.z = 90
	root.add_child(muzzle)

	for side in [-1.0,1.0]:
		var ear := _box(Vector3(0.11,0.42,0.20),fur)
		ear.position = Vector3(-0.79,1.22,0.20*side)
		ear.rotation_degrees.z = 18*side
		root.add_child(ear)
		var eye := _sphere(0.040,Color(0.95,0.16,0.05),true)
		eye.position = Vector3(-1.045,0.99,0.14*side)
		root.add_child(eye)

	for x in [-0.46,0.40]:
		for z in [-0.25,0.25]:
			var leg := _capsule(0.095,0.67,fur)
			leg.position = Vector3(x,0.34,z)
			leg.rotation_degrees.z = -8 if x < 0 else 8
			root.add_child(leg)
			var paw := _sphere(0.13,Color(0.065,0.070,0.075))
			paw.position = Vector3(x,0.07,z)
			paw.scale = Vector3(1.3,0.55,1.0)
			root.add_child(paw)

	var spine := _box(Vector3(0.95,0.08,0.10),bone)
	spine.position = Vector3(0.10,1.04,-0.30)
	spine.rotation_degrees.z = -6
	root.add_child(spine)

	for i in range(4):
		var rib := _cylinder(0.025,0.46,bone)
		rib.position = Vector3(-0.15+0.20*i,0.88,-0.32)
		rib.rotation_degrees.x = 90
		root.add_child(rib)

	var wound_mark := _sphere(0.11,wound,true)
	wound_mark.position = Vector3(0.20,0.81,0.33)
	wound_mark.scale = Vector3(1.6,0.45,0.75)
	root.add_child(wound_mark)

	var tail_root := Node3D.new()
	tail_root.position = Vector3(0.67,0.80,0)
	root.add_child(tail_root)
	for i in range(5):
		var seg := _cylinder(0.055-float(i)*0.006,0.30,fur)
		seg.position = Vector3(0.14+0.25*i,0.04+0.05*i,0)
		seg.rotation_degrees.z = 84
		tail_root.add_child(seg)

	return root
