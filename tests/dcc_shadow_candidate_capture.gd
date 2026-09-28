extends SceneTree

const CANDIDATE_GLTF := "res://build/dcc_shadow/shadow_mesh_candidate.glb"
const ARENA_SCENE := "res://assets/environments/checkpoint01/grave_hound_arena.tscn"
const SWORD_SCENE := "res://assets/weapons/shadow_sword/shadow_sword.tscn"
const CharacterFactory = preload("res://scripts/presentation/character_factory.gd")
const OUT_DIR := "res://build/dcc_shadow/captures"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(CANDIDATE_GLTF):
		push_error("Missing generated Shadow candidate")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	root.size = Vector2i(1280,720)

	await _capture_side()
	await _capture_gameplay()
	print("SHADOWBORN_SHADOW_CANDIDATE_CAPTURE_PASS")
	quit(0)

func _capture_side() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var packed := load(CANDIDATE_GLTF) as PackedScene
	var shadow := packed.instantiate() as Node3D
	stage.add_child(shadow)

	var body := _find_mesh(shadow,"SHD_BODY_CANDIDATE")
	if body == null:
		push_error("Shadow body candidate missing in side capture")
		return
	var aabb := body.mesh.get_aabb()
	var target := body.to_global(aabb.get_center())

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.010,0.013,0.020)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34,0.40,0.55)
	env.ambient_light_energy = 0.72
	world.environment = env
	stage.add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38,-32,0)
	key.light_color = Color(0.65,0.74,1.0)
	key.light_energy = 1.45
	key.shadow_enabled = true
	stage.add_child(key)

	var rim := OmniLight3D.new()
	rim.position = target+Vector3(-1.1,0.5,0.8)
	rim.light_color = Color(0.15,0.24,0.65)
	rim.light_energy = 1.5
	rim.omni_range = 4.0
	stage.add_child(rim)

	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 34.0
	camera.position = target+Vector3(3.5,0.08,0.0)
	stage.add_child(camera)
	camera.look_at(target+Vector3(0,0.05,0),Vector3.UP)

	var player := _find_animation_player(shadow)
	if player != null and player.has_animation("SHD_IDLE_COMBAT_01"):
		player.play("SHD_IDLE_COMBAT_01")
		player.seek(player.get_animation("SHD_IDLE_COMBAT_01").length*0.5,true)
	await _settle()
	_save(OUT_DIR+"/shadow_candidate_idle_side.png")

	if player != null and player.has_animation("SHD_A1_SWORD_01"):
		var a1 := player.get_animation("SHD_A1_SWORD_01")
		player.play("SHD_A1_SWORD_01")
		player.seek(a1.length*0.35,true)
		await _settle()
		_save(OUT_DIR+"/shadow_candidate_a1_windup_side.png")
		player.seek(a1.length*0.68,true)
		await _settle()
		_save(OUT_DIR+"/shadow_candidate_a1_contact_side.png")

	stage.queue_free()
	await process_frame

func _capture_gameplay() -> void:
	var arena_packed := load(ARENA_SCENE) as PackedScene
	if arena_packed == null:
		push_error("Missing production battle arena")
		return
	var arena := arena_packed.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await process_frame

	var player_anchor := arena.find_child("PlayerHome",true,false) as Node3D
	var enemy_anchor := arena.find_child("EnemyHome",true,false) as Node3D
	var camera := arena.find_child("BattleCamera",true,false) as Camera3D
	if player_anchor == null or enemy_anchor == null or camera == null:
		push_error("Battle arena camera contract missing")
		return
	camera.current = true

	var player_root := Node3D.new()
	player_root.name = "shadow_candidate"
	arena.add_child(player_root)
	player_root.global_position = player_anchor.global_position

	var packed := load(CANDIDATE_GLTF) as PackedScene
	var shadow := packed.instantiate() as Node3D
	player_root.add_child(shadow)
	_attach_production_sword(shadow)

	var enemy_root := Node3D.new()
	enemy_root.name = "grave_hound_reference"
	arena.add_child(enemy_root)
	enemy_root.global_position = enemy_anchor.global_position
	var hound := CharacterFactory.create_hound()
	enemy_root.add_child(hound)
	CharacterFactory.play_hound_idle(hound,1.0)

	player_root.look_at(enemy_root.global_position,Vector3.UP)
	player_root.rotation_degrees.x = 0.0
	player_root.rotation_degrees.z = 0.0
	shadow.rotation_degrees.y = 180.0

	enemy_root.look_at(player_root.global_position,Vector3.UP)
	enemy_root.rotation_degrees.x = 0.0
	enemy_root.rotation_degrees.z = 0.0
	hound.rotation_degrees.y = 180.0

	var anim := _find_animation_player(shadow)
	if anim != null and anim.has_animation("SHD_IDLE_COMBAT_01"):
		anim.play("SHD_IDLE_COMBAT_01")
		anim.seek(anim.get_animation("SHD_IDLE_COMBAT_01").length*0.5,true)

	await _settle()
	_save(OUT_DIR+"/shadow_candidate_gameplay_idle.png")

	if anim != null and anim.has_animation("SHD_A1_SWORD_01"):
		var a1 := anim.get_animation("SHD_A1_SWORD_01")
		anim.play("SHD_A1_SWORD_01")
		anim.seek(a1.length*0.68,true)
		await _settle()
		_save(OUT_DIR+"/shadow_candidate_gameplay_a1.png")

	arena.queue_free()
	await process_frame

func _attach_production_sword(shadow: Node3D) -> void:
	var skeleton := _find_skeleton(shadow)
	if skeleton == null or skeleton.find_bone("DEF-hand.R") < 0:
		push_error("Shadow candidate missing DEF-hand.R for sword socket")
		return
	var sword_packed := load(SWORD_SCENE) as PackedScene
	if sword_packed == null:
		push_error("Production sword scene missing")
		return
	var sword := sword_packed.instantiate() as Node3D
	var grip := sword.find_child("Grip",true,false) as Node3D
	if grip == null:
		push_error("Production sword missing Grip marker")
		return

	var socket := BoneAttachment3D.new()
	socket.name = "CandidateWeaponSocket"
	socket.bone_name = "DEF-hand.R"
	skeleton.add_child(socket)

	var mount := Node3D.new()
	mount.name = "CandidateWeaponGripMount"
	mount.rotation_degrees = Vector3(0,0,-90)
	socket.add_child(mount)
	sword.transform = grip.transform.affine_inverse()
	mount.add_child(sword)

func _find_mesh(node: Node,prefix: String) -> MeshInstance3D:
	if node is MeshInstance3D and node.name.begins_with(prefix):
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child,prefix)
		if found != null:
			return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save Shadow candidate capture %s: %s" % [path,err])
