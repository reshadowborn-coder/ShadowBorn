extends SceneTree

const CANDIDATE_GLTF := "res://build/dcc_shadow/shadow_mesh_candidate.glb"
const ARENA_SCENE := "res://assets/environments/checkpoint01/grave_hound_arena.tscn"
const SWORD_SCENE := "res://assets/weapons/shadow_sword/shadow_sword.tscn"
const OUT_DIR := "res://build/dcc_shadow/captures"

const ROTATIONS := [-180.0,-90.0,0.0,90.0]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	root.size = Vector2i(1280,720)
	for angle in ROTATIONS:
		await _capture_angle(angle)
	print("SHADOWBORN_SHADOW_SWORD_SWEEP_PASS")
	quit(0)

func _capture_angle(angle: float) -> void:
	var arena_packed := load(ARENA_SCENE) as PackedScene
	var arena := arena_packed.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await process_frame

	var player_anchor := arena.find_child("PlayerHome",true,false) as Node3D
	var enemy_anchor := arena.find_child("EnemyHome",true,false) as Node3D
	var camera := arena.find_child("BattleCamera",true,false) as Camera3D
	camera.current = true

	var root_actor := Node3D.new()
	arena.add_child(root_actor)
	root_actor.global_position = player_anchor.global_position

	var packed := load(CANDIDATE_GLTF) as PackedScene
	var shadow := packed.instantiate() as Node3D
	root_actor.add_child(shadow)

	var skeleton := _find_skeleton(shadow)
	if skeleton == null or skeleton.find_bone("DEF-hand.R") < 0:
		push_error("Missing DEF-hand.R")
		arena.queue_free()
		await process_frame
		return

	var sword_packed := load(SWORD_SCENE) as PackedScene
	var sword := sword_packed.instantiate() as Node3D
	var grip := sword.find_child("Grip",true,false) as Node3D
	var tip := sword.find_child("BladeTip",true,false) as Node3D
	if grip == null or tip == null:
		push_error("Sword markers missing")
		arena.queue_free()
		await process_frame
		return

	var socket := BoneAttachment3D.new()
	socket.bone_name = "DEF-hand.R"
	skeleton.add_child(socket)
	var mount := Node3D.new()
	mount.rotation_degrees = Vector3(0,0,angle)
	socket.add_child(mount)
	sword.transform = grip.transform.affine_inverse()
	mount.add_child(sword)

	root_actor.look_at(enemy_anchor.global_position,Vector3.UP)
	root_actor.rotation_degrees.x = 0.0
	root_actor.rotation_degrees.z = 0.0
	shadow.rotation_degrees.y = 180.0

	var anim := _find_animation_player(shadow)
	if anim != null and anim.has_animation("SHD_IDLE_COMBAT_01"):
		anim.play("SHD_IDLE_COMBAT_01")
		anim.seek(anim.get_animation("SHD_IDLE_COMBAT_01").length*0.5,true)

	await process_frame
	await process_frame
	await process_frame

	var grip_world := grip.global_position
	var tip_world := tip.global_position
	var direction := (tip_world-grip_world).normalized()
	var enemy_dir := (enemy_anchor.global_position-grip_world).normalized()
	print("SHADOW_SWORD_SWEEP angle=%.1f grip=%s tip=%s dir=%s enemy_dot=%.4f" % [
		angle,str(grip_world),str(tip_world),str(direction),direction.dot(enemy_dir)
	])

	var suffix := str(int(angle)).replace("-","m")
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT_DIR+"/shadow_sword_sweep_"+suffix+".png"))

	arena.queue_free()
	await process_frame
	await process_frame

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
