extends SceneTree

const CANDIDATE_GLTF := "res://build/dcc_hound/grave_hound_mesh_candidate.glb"
const CharacterFactory = preload("res://scripts/presentation/character_factory.gd")
const PLAYER_HOME := Vector3(-2.8,0.0,0.3)
const ENEMY_HOME := Vector3(2.8,0.0,-0.3)
const CAMERA_HOME := Vector3(0.0,2.4,9.0)
const CAMERA_TARGET := Vector3(0.0,1.0,0.0)
const OUT_PATH := "res://build/dcc_hound/captures/hound_candidate_gameplay_camera.png"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(CANDIDATE_GLTF):
		push_error("Missing generated Hound candidate: %s" % CANDIDATE_GLTF)
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/dcc_hound/captures"))
	root.size = Vector2i(1280,720)

	var stage := Node3D.new()
	stage.name = "GameplayCameraCandidateStage"
	root.add_child(stage)
	_build_world(stage)

	var player_root := Node3D.new()
	player_root.name = "shadow"
	player_root.position = PLAYER_HOME
	stage.add_child(player_root)
	var player_visual := Node3D.new()
	player_root.add_child(player_visual)
	var shadow := CharacterFactory.create_shadow(true)
	shadow.scale = Vector3(1.05,1.05,1.05)
	player_visual.add_child(shadow)
	CharacterFactory.play_shadow_idle(shadow,1.0)

	var enemy_root := Node3D.new()
	enemy_root.name = "grave_hound_candidate"
	enemy_root.position = ENEMY_HOME
	stage.add_child(enemy_root)
	var enemy_visual := Node3D.new()
	enemy_root.add_child(enemy_visual)

	var packed := load(CANDIDATE_GLTF) as PackedScene
	if packed == null:
		push_error("Candidate failed to load")
		quit(1)
		return
	var hound := packed.instantiate() as Node3D
	# The generated candidate is authored in meter scale and represents the
	# production path, not the oversized vendor preview carrier.
	hound.scale = Vector3.ONE
	enemy_visual.add_child(hound)
	_set_candidate_materials(hound)
	_play_animation(hound,"HND_IDLE_LOW_01")

	# Mirror the exact BattleStage facing contract.
	player_root.look_at(ENEMY_HOME,Vector3.UP)
	player_root.rotation_degrees.x = 0.0
	player_root.rotation_degrees.z = 0.0
	shadow.rotation_degrees.y = 180.0

	enemy_root.look_at(PLAYER_HOME,Vector3.UP)
	enemy_root.rotation_degrees.x = 0.0
	enemy_root.rotation_degrees.z = 0.0
	hound.rotation_degrees.y = 180.0

	var camera := Camera3D.new()
	camera.name = "BattleCamera"
	camera.current = true
	camera.fov = 38.0
	camera.position = CAMERA_HOME
	stage.add_child(camera)
	camera.look_at(CAMERA_TARGET,Vector3.UP)

	await process_frame
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	var err := image.save_png(ProjectSettings.globalize_path(OUT_PATH))
	if err != OK:
		push_error("Failed gameplay candidate capture: %s" % err)
		quit(1)
		return
	print("SHADOWBORN_HOUND_GAMEPLAY_CAMERA_CAPTURE_PASS")
	quit(0)

func _build_world(stage: Node3D) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008,0.011,0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.135,0.160,0.215)
	env.ambient_light_energy = 0.68
	world.environment = env
	stage.add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48,-34,0)
	moon.light_color = Color(0.54,0.66,0.96)
	moon.light_energy = 1.02
	moon.shadow_enabled = true
	stage.add_child(moon)

	var enemy_fire := OmniLight3D.new()
	enemy_fire.position = Vector3(4.3,1.65,-2.7)
	enemy_fire.light_color = Color(1.0,0.23,0.05)
	enemy_fire.light_energy = 3.4
	enemy_fire.omni_range = 4.8
	stage.add_child(enemy_fire)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.5,11.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.075,0.080,0.092)
	mat.roughness = 0.94
	plane.material = mat
	floor.mesh = plane
	stage.add_child(floor)

func _play_animation(node: Node,animation_name: String) -> void:
	var player := _find_animation_player(node)
	if player != null and player.has_animation(animation_name):
		player.play(animation_name)
		var animation := player.get_animation(animation_name)
		if animation != null:
			player.seek(animation.length*0.5,true)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _set_candidate_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.name.begins_with("HND_BODY_CANDIDATE"):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.17,0.19,0.16)
			mat.roughness = 0.86
			mesh_node.material_override = mat
		elif mesh_node.name.begins_with("HND_EXPOSED_RIBS_CANDIDATE"):
			var bone := StandardMaterial3D.new()
			bone.albedo_color = Color(0.50,0.44,0.31)
			bone.roughness = 0.94
			mesh_node.material_override = bone
		elif mesh_node.name.begins_with("HND_THORAX_WOUND_CANDIDATE"):
			var wound := StandardMaterial3D.new()
			wound.albedo_color = Color(0.10,0.014,0.012)
			wound.roughness = 0.88
			wound.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_node.material_override = wound
		else:
			mesh_node.visible = false
	for child in node.get_children():
		_set_candidate_materials(child)
