extends SceneTree

const AwakeningStageScript = preload("res://scripts/presentation/awakening_stage.gd")
const BattleStageScript = preload("res://scripts/presentation/battle_stage.gd")
const CharacterFactory = preload("res://scripts/presentation/character_factory.gd")
const OUT_DIR := "/tmp/shadowborn-visual"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var requested := OS.get_environment("SHADOWBORN_CAPTURE_SIZE").split("x")
	if requested.size() != 2:
		push_error("Missing SHADOWBORN_CAPTURE_SIZE=WIDTHxHEIGHT")
		quit(1)
		return
	var target := Vector2i(int(requested[0]),int(requested[1]))
	root.content_scale_size = target
	root.size = target
	await process_frame
	if Vector2i(root.get_visible_rect().size) != target:
		push_error("Visual viewport mismatch: %s != %s" % [root.get_visible_rect().size,target])
		quit(1)
		return

	var awakening := AwakeningStageScript.new()
	root.add_child(awakening)
	await create_timer(1.15).timeout
	await _capture(OUT_DIR+"/awakening_corpse.png")
	await create_timer(1.10).timeout
	await _capture(OUT_DIR+"/awakening_rise.png")
	await create_timer(1.58).timeout
	await _capture(OUT_DIR+"/awakening_pickup.png")
	awakening.queue_free()
	await process_frame

	await _capture_corpse_pose_sheet()
	await _capture_shadow_idle_sheet()

	var battle := BattleStageScript.new()
	root.add_child(battle)
	await process_frame
	battle.apply_state({
		"speed":1.0,
		"units":[
			{"id":"shadow","name":"Shadow","hp":100,"max_hp":100},
			{"id":"hound","name":"Grave Hound","hp":80,"max_hp":80}
		]
	})
	await create_timer(0.20).timeout
	await _capture(OUT_DIR+"/grave_hound_battle.png")
	battle.play_windup("hound","shadow","hound_bite")
	await create_timer(0.08).timeout
	await _capture(OUT_DIR+"/grave_hound_attack_coil.png")
	await create_timer(0.18).timeout
	await _capture(OUT_DIR+"/grave_hound_attack_launch.png")
	await create_timer(0.26).timeout
	# Capture CONTACT_T0 before play_impact starts the recovery tween.
	await _capture(OUT_DIR+"/grave_hound_attack_contact.png")
	battle.queue_free()
	await process_frame

	# Pose-fraction captures are diagnostic, not semantic timing. They let us compare
	# silhouette evolution independent of tween timing and expose generic/reused clips
	# that a single "hero frame" can hide. Production contact still comes from the
	# authored semantic contract, never from assuming 50% of the clip is the hit.
	await _capture_hound_bite_pose(0.15,OUT_DIR+"/hound_bite_pose_15.png")
	await _capture_hound_bite_pose(0.50,OUT_DIR+"/hound_bite_pose_50.png")
	await _capture_hound_bite_pose(0.85,OUT_DIR+"/hound_bite_pose_85.png")

	await _capture_shadow_skill("basic_slash",OUT_DIR+"/shadow_a1.png",0.40)
	await _capture_shadow_skill("shadow_lunge",OUT_DIR+"/shadow_a2.png",0.74)
	# Highlighted weapon and rotation-sweep captures are intentionally no longer
	# part of every push. The -90° mount is now locked by presentation orientation
	# regression tests; keep the helpers below for manual diagnosis only.
	print("Shadowborn visual capture: PASS")
	quit(0)


func _capture_hound_bite_pose(fraction: float,path: String) -> void:
	var battle := BattleStageScript.new()
	root.add_child(battle)
	await process_frame
	battle.apply_state({
		"speed":1.0,
		"units":[
			{"id":"shadow","name":"Shadow","hp":100,"max_hp":100},
			{"id":"hound","name":"Grave Hound","hp":80,"max_hp":80}
		]
	})
	await create_timer(0.20).timeout
	var actors: Dictionary = battle.get("actor_nodes")
	var hound_root := actors.get("hound") as Node3D
	if hound_root == null:
		push_error("Hound pose capture: actor missing")
		quit(1)
		return
	var sampled := CharacterFactory.set_animation_pose_fraction(hound_root,["HND_BITE_01","Attack"],fraction)
	if not sampled:
		push_error("Hound pose capture: no Bite/Attack clip available")
		quit(1)
		return
	await create_timer(0.05).timeout
	await _capture(path)
	battle.queue_free()
	await process_frame

func _capture_shadow_skill(skill_id: String,path: String,delay: float) -> void:
	var battle := BattleStageScript.new()
	root.add_child(battle)
	await process_frame
	battle.apply_state({
		"speed":1.0,
		"units":[
			{"id":"shadow","name":"Shadow","hp":100,"max_hp":100},
			{"id":"hound","name":"Grave Hound","hp":80,"max_hp":80}
		]
	})
	await create_timer(0.20).timeout
	battle.play_windup("shadow","hound",skill_id)
	await create_timer(delay).timeout
	# Contact frame is captured before impact/recovery mutates presentation state.
	await _capture(path)
	battle.queue_free()
	await process_frame

func _capture_shadow_weapon_debug(skill_id: String,path: String,delay: float) -> void:
	var battle := BattleStageScript.new()
	root.add_child(battle)
	await process_frame
	battle.apply_state({
		"speed":1.0,
		"units":[
			{"id":"shadow","name":"Shadow","hp":100,"max_hp":100},
			{"id":"hound","name":"Grave Hound","hp":80,"max_hp":80}
		]
	})
	await create_timer(0.20).timeout
	var actors: Dictionary = battle.get("actor_nodes")
	var shadow_root := actors.get("shadow") as Node3D
	if shadow_root != null:
		_highlight_attached_sword(shadow_root)
	battle.play_windup("shadow","hound",skill_id)
	await create_timer(delay).timeout
	await _capture(path)
	battle.queue_free()
	await process_frame

func _capture_weapon_rotation_sweep() -> void:
	var candidates := [
		["z0",Vector3(0,0,0)],
		["z90",Vector3(0,0,90)],
		["zneg90",Vector3(0,0,-90)],
		["x90_z180",Vector3(90,0,180)],
		["xneg90_z180",Vector3(-90,0,180)],
		["y90_z180",Vector3(0,90,180)],
		["yneg90_z180",Vector3(0,-90,180)]
	]
	for candidate in candidates:
		var battle := BattleStageScript.new()
		root.add_child(battle)
		await process_frame
		battle.apply_state({
			"speed":1.0,
			"units":[
				{"id":"shadow","name":"Shadow","hp":100,"max_hp":100},
				{"id":"hound","name":"Grave Hound","hp":80,"max_hp":80}
			]
		})
		await create_timer(0.20).timeout
		var actors: Dictionary = battle.get("actor_nodes")
		var shadow_root := actors.get("shadow") as Node3D
		if shadow_root != null:
			_highlight_attached_sword(shadow_root)
			var mount := shadow_root.find_child("WeaponGripMount",true,false) as Node3D
			if mount != null:
				mount.rotation_degrees = candidate[1]
		battle.play_windup("shadow","hound","shadow_basic")
		await create_timer(0.18).timeout
		await _capture(OUT_DIR+"/weapon_rot_"+str(candidate[0])+".png")
		battle.queue_free()
		await process_frame

func _highlight_attached_sword(root_node: Node) -> void:
	var sword := root_node.find_child("ShadowbornWeapon",true,false)
	if sword == null:
		push_error("Weapon debug capture: ShadowbornWeapon missing")
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0,0.03,0.72)
	mat.emission_enabled = true
	mat.emission = Color(1.0,0.03,0.72)
	mat.emission_energy_multiplier = 4.0
	mat.roughness = 0.35
	_override_mesh_material_recursive(sword,mat)

func _override_mesh_material_recursive(node: Node,material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_override_mesh_material_recursive(child,material)

func _capture_shadow_idle_sheet() -> void:
	var stage := Node3D.new()
	stage.name = "ShadowIdleStudy"
	root.add_child(stage)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.022,0.027,0.038)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35,0.40,0.54)
	env.ambient_light_energy = 1.25
	world.environment = env
	stage.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42,-28,0)
	light.light_color = Color(0.72,0.80,1.0)
	light.light_energy = 1.45
	stage.add_child(light)

	var clips := ["Idle_Neutral","Idle","Idle_Sword"]
	for i in range(clips.size()):
		var model := CharacterFactory.create_shadow(true)
		model.position = Vector3(-2.25+2.25*i,0.0,0.0)
		model.scale = Vector3.ONE*0.92
		stage.add_child(model)
		CharacterFactory.play_named_animation(model,[clips[i]],1.0,0.0)
		var label := Label3D.new()
		label.text = clips[i]
		label.position = model.position+Vector3(0,2.42,0)
		label.font_size = 28
		label.outline_size = 7
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		stage.add_child(label)

	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 40.0
	camera.position = Vector3(0.0,2.55,8.0)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0,1.05,0.0),Vector3.UP)
	await create_timer(0.28).timeout
	await _capture(OUT_DIR+"/shadow_idle_sheet.png")
	stage.queue_free()
	await process_frame

func _capture_corpse_pose_sheet() -> void:
	var stage := Node3D.new()
	stage.name = "CorpsePoseStudy"
	root.add_child(stage)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025,0.030,0.040)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24,0.28,0.38)
	env.ambient_light_energy = 1.05
	world.environment = env
	stage.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42,-28,0)
	light.light_color = Color(0.70,0.78,1.0)
	light.light_energy = 1.35
	stage.add_child(light)

	var fractions := [0.22,0.32,0.42,0.52,0.62]
	for i in range(fractions.size()):
		var model := CharacterFactory.create_shadow(false)
		model.position = Vector3(-4.0+2.0*i,0.0,0.0)
		model.scale = Vector3.ONE*0.88
		stage.add_child(model)
		CharacterFactory.set_animation_pose_fraction(model,["Death"],float(fractions[i]))
		var label := Label3D.new()
		label.text = "%.2f" % float(fractions[i])
		label.position = Vector3(-4.0+2.0*i,2.35,0.0)
		label.font_size = 32
		stage.add_child(label)

	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 42.0
	camera.position = Vector3(0.0,2.6,8.7)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0,1.05,0.0),Vector3.UP)
	await create_timer(0.20).timeout
	await _capture(OUT_DIR+"/corpse_pose_sheet.png")
	stage.queue_free()
	await process_frame

func _capture(path: String) -> void:
	await process_frame
	RenderingServer.force_draw(false,0.0)
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Visual capture image is empty: "+path)
		quit(1)
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to save visual capture %s: %s" % [path,error])
		quit(1)
