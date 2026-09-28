extends SceneTree

const CANDIDATE_GLTF := "res://build/dcc_hound/grave_hound_mesh_candidate.glb"
const BODY_PREFIX := "HND_BODY_CANDIDATE"
const IDLE_ACTION := "HND_IDLE_LOW_01"
const BITE_ACTION := "HND_BITE_01"
const OUT_DIR := "res://build/dcc_hound/captures"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(CANDIDATE_GLTF):
		push_error("Missing generated Hound candidate: %s" % CANDIDATE_GLTF)
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	root.size = Vector2i(1280,720)

	var stage := Node3D.new()
	stage.name = "HoundCandidateCaptureStage"
	root.add_child(stage)

	var packed := load(CANDIDATE_GLTF) as PackedScene
	if packed == null:
		push_error("Hound candidate failed to load as PackedScene")
		quit(1)
		return

	var actor := packed.instantiate() as Node3D
	stage.add_child(actor)

	var body := _find_body(actor)
	if body == null or body.mesh == null:
		push_error("Could not find %s in candidate GLB" % BODY_PREFIX)
		quit(1)
		return

	_hide_non_candidate_meshes(actor,body)
	body.material_override = _clay_material()

	var aabb := body.mesh.get_aabb()
	var target := body.to_global(aabb.get_center())
	var span := maxf(aabb.size.y,aabb.size.z)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018,0.022,0.030)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42,0.48,0.62)
	env.ambient_light_energy = 0.72
	world.environment = env
	stage.add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42,-28,0)
	key.light_color = Color(0.78,0.84,1.0)
	key.light_energy = 1.35
	key.shadow_enabled = true
	stage.add_child(key)

	var fill := OmniLight3D.new()
	fill.position = target + Vector3(1.8,1.0,-1.2)
	fill.light_color = Color(0.38,0.50,0.92)
	fill.light_energy = 1.8
	fill.omni_range = 5.0
	fill.shadow_enabled = false
	stage.add_child(fill)

	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(5.0,5.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.055,0.060,0.068)
	ground_mat.roughness = 0.95
	ground_mesh.material = ground_mat
	ground.mesh = ground_mesh
	ground.position.y = maxf(0.0,target.y-aabb.size.y*0.52)
	stage.add_child(ground)

	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 32.0
	camera.position = target + Vector3(span*1.85,span*0.10,0.0)
	stage.add_child(camera)
	camera.look_at(target+Vector3(0,0.04,0),Vector3.UP)

	var player := _find_animation_player(actor)
	if player == null:
		push_error("Candidate GLB has no AnimationPlayer")
		quit(1)
		return

	await process_frame
	await process_frame

	if not player.has_animation(IDLE_ACTION):
		push_error("Candidate missing %s" % IDLE_ACTION)
		quit(1)
		return
	var idle := player.get_animation(IDLE_ACTION)
	player.play(IDLE_ACTION)
	player.seek(idle.length*0.50,true)
	await _settle_and_capture(OUT_DIR+"/hound_candidate_idle_side.png")

	if not player.has_animation(BITE_ACTION):
		push_error("Candidate missing %s" % BITE_ACTION)
		quit(1)
		return
	var bite := player.get_animation(BITE_ACTION)
	player.play(BITE_ACTION)
	# Sample authored semantic phases rather than arbitrary thirds:
	# frame 4/13 ~= coil, frame 9/13 ~= jaw contact, near-end ~= recovery.
	player.seek(bite.length*0.25,true)
	await _settle_and_capture(OUT_DIR+"/hound_candidate_bite_windup.png")
	player.seek(bite.length*0.67,true)
	await _settle_and_capture(OUT_DIR+"/hound_candidate_bite_contact.png")
	player.seek(bite.length*0.92,true)
	await _settle_and_capture(OUT_DIR+"/hound_candidate_bite_recovery.png")

	print("SHADOWBORN_HOUND_CANDIDATE_CAPTURE_PASS")
	quit(0)

func _find_body(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.name.begins_with(BODY_PREFIX):
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_body(child)
		if found != null:
			return found
	return null

func _hide_non_candidate_meshes(node: Node,body: MeshInstance3D) -> void:
	if node is MeshInstance3D and node != body:
		(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_hide_non_candidate_meshes(child,body)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _clay_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24,0.255,0.23)
	mat.roughness = 0.82
	mat.metallic = 0.0
	return mat

func _settle_and_capture(path: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Failed to save Hound candidate capture %s: %s" % [path,error])
