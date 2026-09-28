extends SceneTree

const CANDIDATE_GLTF := "res://build/dcc_hound/grave_hound_mesh_candidate.glb"
const ARENA_SCENE := "res://assets/environments/checkpoint01/grave_hound_arena.tscn"
const CharacterFactory = preload("res://scripts/presentation/character_factory.gd")
const OUT_DIR := "res://build/dcc_hound/captures"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(CANDIDATE_GLTF):
		push_error("Missing generated Hound candidate: %s" % CANDIDATE_GLTF)
		quit(1)
		return
	if not ResourceLoader.exists(ARENA_SCENE):
		push_error("Missing production arena: %s" % ARENA_SCENE)
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/dcc_hound/captures"))
	root.size = Vector2i(1280,720)

	var arena_packed := load(ARENA_SCENE) as PackedScene
	if arena_packed == null:
		push_error("Production arena failed to load")
		quit(1)
		return
	var arena := arena_packed.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await process_frame

	var player_anchor := arena.find_child("PlayerHome",true,false) as Node3D
	var enemy_anchor := arena.find_child("EnemyHome",true,false) as Node3D
	var camera := arena.find_child("BattleCamera",true,false) as Camera3D
	if player_anchor == null or enemy_anchor == null or camera == null:
		push_error("Production arena is missing PlayerHome / EnemyHome / BattleCamera")
		quit(1)
		return
	camera.current = true

	var player_root := Node3D.new()
	player_root.name = "shadow"
	arena.add_child(player_root)
	player_root.global_position = player_anchor.global_position

	var player_visual := Node3D.new()
	player_visual.name = "Visual"
	player_root.add_child(player_visual)

	var shadow := CharacterFactory.create_shadow(true)
	shadow.scale = Vector3(1.05,1.05,1.05)
	player_visual.add_child(shadow)
	CharacterFactory.play_shadow_idle(shadow,1.0)

	var enemy_root := Node3D.new()
	enemy_root.name = "grave_hound_candidate"
	arena.add_child(enemy_root)
	enemy_root.global_position = enemy_anchor.global_position

	var enemy_visual := Node3D.new()
	enemy_visual.name = "Visual"
	enemy_root.add_child(enemy_visual)

	var packed := load(CANDIDATE_GLTF) as PackedScene
	if packed == null:
		push_error("Candidate failed to load")
		quit(1)
		return
	var hound := packed.instantiate() as Node3D
	# Candidate represents the production meter-scale path, not vendor preview scale.
	hound.scale = Vector3.ONE
	enemy_visual.add_child(hound)
	_set_candidate_materials(hound)
	_disable_candidate_fx(hound)
	_play_animation(hound,"HND_IDLE_LOW_01")

	# Exact BattleStage facing contract.
	player_root.look_at(enemy_root.global_position,Vector3.UP)
	player_root.rotation_degrees.x = 0.0
	player_root.rotation_degrees.z = 0.0
	shadow.rotation_degrees.y = 180.0

	enemy_root.look_at(player_root.global_position,Vector3.UP)
	enemy_root.rotation_degrees.x = 0.0
	enemy_root.rotation_degrees.z = 0.0
	hound.rotation_degrees.y = 180.0

	await process_frame
	await process_frame
	await process_frame

	await _capture(OUT_DIR+"/hound_candidate_battle_neutral_pbr_idle.png")
	_apply_review_override(hound,Color(0.46,0.47,0.48),false)
	await _capture(OUT_DIR+"/hound_candidate_battle_flat_gray_idle.png")
	_apply_review_override(hound,Color(0.006,0.006,0.007),true)
	await _capture(OUT_DIR+"/hound_candidate_battle_silhouette_idle.png")

	_seek_animation(hound,"HND_BITE_01",9.0/30.0)
	_set_candidate_materials(hound)
	await _capture(OUT_DIR+"/hound_candidate_battle_neutral_pbr_contact.png")
	_apply_review_override(hound,Color(0.46,0.47,0.48),false)
	await _capture(OUT_DIR+"/hound_candidate_battle_flat_gray_contact.png")
	_apply_review_override(hound,Color(0.006,0.006,0.007),true)
	await _capture(OUT_DIR+"/hound_candidate_battle_silhouette_contact.png")

	print("SHADOWBORN_HOUND_GAMEPLAY_CAMERA_CAPTURE_PASS")
	quit(0)

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
			# Restore the imported dry/wet opaque material split from the GLB.
			mesh_node.material_override = null
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
		elif mesh_node.name.begins_with("HND_MISSING_EYE_SOCKET_CANDIDATE"):
			var socket := StandardMaterial3D.new()
			socket.albedo_color = Color(0.018,0.022,0.019)
			socket.roughness = 0.92
			mesh_node.material_override = socket
		elif mesh_node.name.begins_with("HND_EXPOSED_JAW_BONE_CANDIDATE"):
			var jaw_bone := StandardMaterial3D.new()
			jaw_bone.albedo_color = Color(0.48,0.42,0.30)
			jaw_bone.roughness = 0.95
			mesh_node.material_override = jaw_bone
		else:
			mesh_node.visible = false

	for child in node.get_children():
		_set_candidate_materials(child)


func _disable_candidate_fx(node: Node) -> void:
	if node is GPUParticles3D:
		(node as GPUParticles3D).emitting = false
		(node as GPUParticles3D).visible = false
	elif node is CPUParticles3D:
		(node as CPUParticles3D).emitting = false
		(node as CPUParticles3D).visible = false
	elif node is Light3D:
		(node as Light3D).visible = false
	for child in node.get_children():
		_disable_candidate_fx(child)

func _apply_review_override(node: Node,color: Color,unshaded: bool) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.visible:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 1.0
			mat.metallic = 0.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.emission_enabled = false
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mesh_node.material_override = mat
	for child in node.get_children():
		_apply_review_override(child,color,unshaded)

func _capture(path: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed gameplay candidate capture %s: %s" % [path,err])


func _seek_animation(node: Node,animation_name: String,time_seconds: float) -> void:
	var player := _find_animation_player(node)
	if player == null or not player.has_animation(animation_name):
		push_error("Candidate missing animation for review capture: %s" % animation_name)
		return
	player.play(animation_name)
	player.seek(time_seconds,true)
