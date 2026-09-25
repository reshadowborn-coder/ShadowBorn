class_name CharacterFactory
extends RefCounted

const SHADOW_SCENE := "res://assets/characters/shadow/shadow.glb"
const HOUND_SCENE := "res://assets/characters/grave_hound/grave_hound.glb"

static func create_shadow(with_sword: bool = true) -> Node3D:
	var loaded := _load_scene(SHADOW_SCENE)
	if loaded != null:
		loaded.name = "ShadowModel"
		if not with_sword:
			_set_named_weapon_visible(loaded,false)
		return loaded
	return _build_shadow_fallback(with_sword)

static func create_hound() -> Node3D:
	var loaded := _load_scene(HOUND_SCENE)
	if loaded != null:
		loaded.name = "GraveHoundModel"
		return loaded
	return _build_hound_fallback()

static func create_sword_prop() -> Node3D:
	var sword := Node3D.new()
	sword.name = "SwordProp"
	var steel := Color(0.31,0.34,0.39)
	var blade := _box(Vector3(0.055,1.34,0.035),Color(0.43,0.47,0.52),0.72)
	blade.position.y = 0.44
	sword.add_child(blade)
	var guard := _box(Vector3(0.36,0.065,0.065),steel,0.68)
	guard.position.y = -0.22
	sword.add_child(guard)
	var grip := _cylinder(0.040,0.34,Color(0.10,0.065,0.040),0.05)
	grip.position.y = -0.39
	sword.add_child(grip)
	var pommel := _sphere(0.07,steel)
	pommel.position.y = -0.59
	sword.add_child(pommel)
	return sword

static func attach_sword(root: Node3D) -> void:
	_set_named_weapon_visible(root,true)
	if root.find_child("Weapon",true,false) != null:
		return
	var socket := root.find_child("WeaponSocket",true,false) as Node3D
	if socket == null:
		socket = Node3D.new()
		socket.name = "WeaponSocket"
		socket.position = Vector3(0.57,1.03,0.07)
		socket.rotation_degrees.z = -15.0
		root.add_child(socket)
	var sword := create_sword_prop()
	sword.name = "Weapon"
	socket.add_child(sword)

static func pose_seated_corpse(root: Node3D) -> void:
	if play_named_animation(root,["dead_seated","Dead_Seated","corpse_seated","Corpse_Seated"]):
		return
	var fallback := root.find_child("ShadowFallback",true,false)
	if fallback == null and root.name == "ShadowFallback":
		fallback = root
	if fallback == null:
		root.rotation_degrees = Vector3(6.0,0.0,-8.0)
		return
	var pelvis := fallback.get_node_or_null("Pelvis") as Node3D
	var torso := fallback.get_node_or_null("Torso") as Node3D
	var head := fallback.get_node_or_null("HeadRig") as Node3D
	var leg_l := fallback.get_node_or_null("LegL") as Node3D
	var leg_r := fallback.get_node_or_null("LegR") as Node3D
	var arm_l := fallback.get_node_or_null("ArmL") as Node3D
	var arm_r := fallback.get_node_or_null("ArmR") as Node3D
	if pelvis:
		pelvis.position = Vector3(0,0.46,0)
		pelvis.rotation_degrees.z = -7
	if torso:
		torso.position = Vector3(-0.05,1.02,-0.06)
		torso.rotation_degrees = Vector3(0,0,-13)
	if head:
		head.position = Vector3(-0.16,1.70,-0.02)
		head.rotation_degrees = Vector3(18,0,-19)
	if leg_l:
		leg_l.position = Vector3(-0.22,0.23,0.24)
		leg_l.rotation_degrees = Vector3(72,0,-18)
	if leg_r:
		leg_r.position = Vector3(0.20,0.20,0.18)
		leg_r.rotation_degrees = Vector3(62,0,12)
	if arm_l:
		arm_l.position = Vector3(-0.46,0.88,0.08)
		arm_l.rotation_degrees = Vector3(20,0,-42)
	if arm_r:
		arm_r.position = Vector3(0.34,0.74,0.18)
		arm_r.rotation_degrees = Vector3(58,0,26)

static func pose_standing(root: Node3D) -> void:
	var fallback := root.find_child("ShadowFallback",true,false)
	if fallback == null and root.name == "ShadowFallback":
		fallback = root
	if fallback == null:
		play_named_animation(root,["stand_up","Stand_Up","get_up","Get_Up","idle","Idle"])
		return
	var pelvis := fallback.get_node_or_null("Pelvis") as Node3D
	var torso := fallback.get_node_or_null("Torso") as Node3D
	var head := fallback.get_node_or_null("HeadRig") as Node3D
	var leg_l := fallback.get_node_or_null("LegL") as Node3D
	var leg_r := fallback.get_node_or_null("LegR") as Node3D
	var arm_l := fallback.get_node_or_null("ArmL") as Node3D
	var arm_r := fallback.get_node_or_null("ArmR") as Node3D
	if pelvis:
		pelvis.position = Vector3(0,0.87,0); pelvis.rotation_degrees = Vector3.ZERO
	if torso:
		torso.position = Vector3(0,1.43,0); torso.rotation_degrees = Vector3.ZERO
	if head:
		head.position = Vector3(0,2.15,0); head.rotation_degrees = Vector3.ZERO
	if leg_l:
		leg_l.position = Vector3(-0.17,0.53,0); leg_l.rotation_degrees = Vector3(0,0,-2.5)
	if leg_r:
		leg_r.position = Vector3(0.17,0.53,0); leg_r.rotation_degrees = Vector3(0,0,2.5)
	if arm_l:
		arm_l.position = Vector3(-0.47,1.25,0); arm_l.rotation_degrees = Vector3(0,0,-8)
	if arm_r:
		arm_r.position = Vector3(0.47,1.25,0); arm_r.rotation_degrees = Vector3(0,0,8)

static func play_named_animation(root: Node, candidates: Array[String]) -> bool:
	var player := _find_animation_player(root)
	if player == null:
		return false
	for name in candidates:
		if player.has_animation(name):
			player.play(name)
			return true
	return false

static func _set_named_weapon_visible(root: Node, visible_: bool) -> void:
	for candidate in ["Weapon","Sword","weapon","sword"]:
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

static func _mat(color: Color, roughness: float=0.8, metallic: float=0.0, emission: bool=false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.4
	return mat

static func _sphere(radius: float, color: Color, emission: bool=false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	mesh.material = _mat(color,0.74,0.0,emission)
	n.mesh = mesh
	return n

static func _capsule(radius: float, height: float, color: Color, metallic: float=0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 12
	mesh.material = _mat(color,0.70,metallic)
	n.mesh = mesh
	return n

static func _cylinder(radius: float, height: float, color: Color, metallic: float=0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.material = _mat(color,0.66,metallic)
	n.mesh = mesh
	return n

static func _box(size: Vector3, color: Color, metallic: float=0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color,0.68,metallic)
	n.mesh = mesh
	return n

static func _build_shadow_fallback(with_sword: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "ShadowFallback"
	var cloth := Color(0.027,0.030,0.038)
	var cloth_2 := Color(0.047,0.050,0.061)
	var leather := Color(0.095,0.070,0.052)
	var old_steel := Color(0.18,0.19,0.21)
	var skin := Color(0.36,0.29,0.26)

	var pelvis := Node3D.new(); pelvis.name = "Pelvis"; pelvis.position = Vector3(0,0.87,0); root.add_child(pelvis)
	var waist := _capsule(0.255,0.54,cloth); pelvis.add_child(waist)

	var leg_l := Node3D.new(); leg_l.name = "LegL"; leg_l.position = Vector3(-0.17,0.53,0); leg_l.rotation_degrees.z=-2.5; root.add_child(leg_l)
	var ll := _capsule(0.13,0.78,cloth_2); leg_l.add_child(ll)
	var boot_l := _capsule(0.125,0.42,Color(0.025,0.024,0.025)); boot_l.position=Vector3(0,-0.30,0.035); leg_l.add_child(boot_l)

	var leg_r := Node3D.new(); leg_r.name = "LegR"; leg_r.position = Vector3(0.17,0.53,0); leg_r.rotation_degrees.z=2.5; root.add_child(leg_r)
	var lr := _capsule(0.13,0.78,cloth_2); leg_r.add_child(lr)
	var boot_r := _capsule(0.125,0.42,Color(0.025,0.024,0.025)); boot_r.position=Vector3(0,-0.30,0.035); leg_r.add_child(boot_r)

	var torso := Node3D.new(); torso.name="Torso"; torso.position=Vector3(0,1.43,0); root.add_child(torso)
	var body := _capsule(0.35,1.05,cloth_2); body.scale=Vector3(1.0,1.0,0.72); torso.add_child(body)
	var rag_front := _box(Vector3(0.58,0.72,0.035),Color(0.038,0.041,0.051)); rag_front.position=Vector3(0,-0.04,0.25); rag_front.rotation_degrees.z=-4; torso.add_child(rag_front)
	var strap := _box(Vector3(0.09,0.95,0.045),leather); strap.position=Vector3(-0.10,0.02,0.27); strap.rotation_degrees.z=-18; torso.add_child(strap)
	var old_plate := _box(Vector3(0.34,0.18,0.045),old_steel,0.42); old_plate.position=Vector3(0.19,0.18,0.27); old_plate.rotation_degrees.z=8; torso.add_child(old_plate)

	var arm_l := Node3D.new(); arm_l.name="ArmL"; arm_l.position=Vector3(-0.47,1.25,0); arm_l.rotation_degrees.z=-8; root.add_child(arm_l)
	var al := _capsule(0.10,0.72,cloth); arm_l.add_child(al)
	var arm_r := Node3D.new(); arm_r.name="ArmR"; arm_r.position=Vector3(0.47,1.25,0); arm_r.rotation_degrees.z=8; root.add_child(arm_r)
	var ar := _capsule(0.10,0.72,cloth); arm_r.add_child(ar)

	var head_rig := Node3D.new(); head_rig.name="HeadRig"; head_rig.position=Vector3(0,2.15,0); root.add_child(head_rig)
	var neck := _cylinder(0.12,0.18,skin); neck.position=Vector3(0,-0.24,0); head_rig.add_child(neck)
	var face := _sphere(0.275,skin); face.scale=Vector3(0.90,1.06,0.84); head_rig.add_child(face)
	var hair := _sphere(0.288,Color(0.035,0.030,0.029)); hair.position=Vector3(0,0.10,-0.035); hair.scale=Vector3(1.0,0.72,1.02); head_rig.add_child(hair)
	var cloth_wrap := _box(Vector3(0.46,0.12,0.03),Color(0.018,0.020,0.026)); cloth_wrap.position=Vector3(0,-0.03,0.252); head_rig.add_child(cloth_wrap)
	for side in [-1.0,1.0]:
		var eye := _sphere(0.030,Color(0.38,0.56,0.95),true)
		eye.name = "GlowEye"
		eye.position = Vector3(0.087*side,0.005,0.274)
		head_rig.add_child(eye)

	var cloak := _box(Vector3(0.66,1.10,0.045),Color(0.020,0.022,0.029))
	cloak.position=Vector3(0,1.33,-0.26); cloak.rotation_degrees.x=8; root.add_child(cloak)

	var socket := Node3D.new(); socket.name="WeaponSocket"; socket.position=Vector3(0.57,1.03,0.07); socket.rotation_degrees.z=-15; root.add_child(socket)
	if with_sword:
		var weapon := create_sword_prop(); weapon.name="Weapon"; socket.add_child(weapon)

	return root

static func _build_hound_fallback() -> Node3D:
	var root := Node3D.new()
	root.name = "GraveHoundFallback"
	var fur := Color(0.075,0.080,0.086)
	var bone := Color(0.33,0.31,0.28)
	var wound := Color(0.24,0.045,0.035)

	var body := _capsule(0.38,1.15,fur); body.position=Vector3(0,0.72,0); body.rotation_degrees.z=90; body.scale=Vector3(1.0,1.14,0.76); root.add_child(body)
	var chest := _sphere(0.42,fur); chest.position=Vector3(-0.38,0.80,0); chest.scale=Vector3(1.0,1.08,0.78); root.add_child(chest)
	var head := _sphere(0.31,fur); head.position=Vector3(-0.86,0.91,0.02); head.scale=Vector3(1.12,0.87,0.86); root.add_child(head)
	var muzzle := _capsule(0.17,0.43,Color(0.055,0.058,0.062)); muzzle.position=Vector3(-1.12,0.84,0.02); muzzle.rotation_degrees.z=90; root.add_child(muzzle)
	for side in [-1.0,1.0]:
		var ear := _box(Vector3(0.11,0.42,0.20),fur); ear.position=Vector3(-0.79,1.22,0.20*side); ear.rotation_degrees.z=18*side; root.add_child(ear)
		var eye := _sphere(0.040,Color(0.95,0.14,0.04),true); eye.position=Vector3(-1.045,0.99,0.14*side); root.add_child(eye)
	for x in [-0.46,0.40]:
		for z in [-0.25,0.25]:
			var leg := _capsule(0.095,0.67,fur); leg.position=Vector3(x,0.34,z); leg.rotation_degrees.z=-8 if x<0 else 8; root.add_child(leg)
			var paw := _sphere(0.13,Color(0.050,0.052,0.056)); paw.position=Vector3(x,0.07,z); paw.scale=Vector3(1.3,0.55,1.0); root.add_child(paw)
	var spine := _box(Vector3(0.95,0.08,0.10),bone); spine.position=Vector3(0.10,1.04,-0.30); spine.rotation_degrees.z=-6; root.add_child(spine)
	for i in range(4):
		var rib := _cylinder(0.025,0.46,bone); rib.position=Vector3(-0.15+0.20*i,0.88,-0.32); rib.rotation_degrees.x=90; root.add_child(rib)
	var wound_mark := _sphere(0.11,wound,true); wound_mark.position=Vector3(0.20,0.81,0.33); wound_mark.scale=Vector3(1.6,0.45,0.75); root.add_child(wound_mark)
	var tail_root := Node3D.new(); tail_root.position=Vector3(0.67,0.80,0); root.add_child(tail_root)
	for i in range(5):
		var seg := _cylinder(0.055-float(i)*0.006,0.30,fur); seg.position=Vector3(0.14+0.25*i,0.04+0.05*i,0); seg.rotation_degrees.z=84; tail_root.add_child(seg)
	return root
