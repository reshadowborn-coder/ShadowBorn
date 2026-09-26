extends SceneTree

const AwakeningStageScript = preload("res://scripts/presentation/awakening_stage.gd")
const BattleStageScript = preload("res://scripts/presentation/battle_stage.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0

	var awakening := AwakeningStageScript.new()
	root.add_child(awakening)
	await process_frame
	failures += _check_sword_pickup_staging(awakening)
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
	await process_frame
	failures += _check_hound_visual_forward(battle)
	battle.queue_free()
	await process_frame

	if failures == 0:
		print("Shadowborn presentation orientation: PASS")
		quit(0)
	else:
		push_error("Shadowborn presentation orientation: %d failure(s)" % failures)
		quit(1)

func _check_sword_pickup_staging(stage: Node) -> int:
	var sword: Node3D = stage.sword_prop
	var shadow: Node3D = stage.shadow_root
	var camera: Camera3D = stage.camera
	if sword == null or shadow == null or camera == null:
		push_error("Sword pickup staging nodes missing")
		return 1

	# The imported sword is authored along local +Y from hilt toward blade tip.
	var blade_dir := sword.global_transform.basis.y.normalized()
	var camera_to_hilt := (sword.global_position-camera.global_position).normalized()
	var tip := sword.global_position+blade_dir*1.18
	var hilt_distance := sword.global_position.distance_to(shadow.global_position)
	var tip_distance := tip.distance_to(shadow.global_position)

	var failures := 0
	failures += _expect(blade_dir.dot(camera_to_hilt) > 0.25,"rusty sword blade points away from the camera")
	failures += _expect(hilt_distance < tip_distance,"rusty sword hilt is closer to Shadow than blade tip")
	failures += _expect(absf(blade_dir.y) < 0.08,"rusty sword lies flat before pickup")
	return failures

func _check_hound_visual_forward(stage: Node) -> int:
	var hound_root: Node3D = stage.actor_nodes.get("hound")
	if hound_root == null:
		push_error("Hound actor missing")
		return 1
	var visual := hound_root.get_node_or_null("Visual")
	if visual == null or visual.get_child_count() == 0:
		push_error("Hound visual missing")
		return 1
	var model := visual.get_child(0) as Node3D
	if model == null:
		push_error("Hound model missing")
		return 1
	# User-verified import correction: 0° showed the model's back in the battle shot.
	return _expect(absf(wrapf(model.rotation_degrees.y,0.0,360.0)-180.0) < 0.5,"Grave Hound dev mesh keeps camera-verified 180 degree facing correction")

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
