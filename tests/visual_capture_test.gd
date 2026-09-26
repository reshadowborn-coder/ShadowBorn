extends SceneTree

const AwakeningStageScript = preload("res://scripts/presentation/awakening_stage.gd")
const BattleStageScript = preload("res://scripts/presentation/battle_stage.gd")
const CharacterFactory = preload("res://scripts/presentation/character_factory.gd")
const OUT_DIR := "/tmp/shadowborn-visual"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	root.size = Vector2i(1280,720)

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
	battle.queue_free()
	await process_frame

	print("Shadowborn visual capture: PASS")
	quit(0)

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
