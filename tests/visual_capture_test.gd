extends SceneTree

const AwakeningStageScript = preload("res://scripts/presentation/awakening_stage.gd")
const BattleStageScript = preload("res://scripts/presentation/battle_stage.gd")
const OUT_DIR := "/tmp/shadowborn-visual"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	root.size = Vector2i(1280,720)

	var awakening := AwakeningStageScript.new()
	root.add_child(awakening)
	await create_timer(1.15).timeout
	await _capture(OUT_DIR+"/awakening.png")
	awakening.queue_free()
	await process_frame

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
