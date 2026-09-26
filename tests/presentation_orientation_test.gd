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
	failures += _check_shadow_sword_direction(battle)
	battle.queue_free()
	await process_frame

	if failures == 0:
		print("Shadowborn presentation orientation: PASS")
		quit(0)
	else:
		push_error("Shadowborn presentation orientation: %d failure(s)" % failures)
		quit(1)

func _check_sword_pickup_staging(stage: Node) -> int:
	var sword := stage.get("sword_prop") as Node3D
	var shadow := stage.get("shadow_root") as Node3D
	var camera := stage.get("camera") as Camera3D
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

func _check_shadow_sword_direction(stage: Node) -> int:
	var actors: Dictionary = stage.get("actor_nodes")
	var shadow_root := actors.get("shadow") as Node3D
	var hound_root := actors.get("hound") as Node3D
	if shadow_root == null or hound_root == null:
		push_error("Sword direction regression: battle actors missing")
		return 1
	var sword := shadow_root.find_child("ShadowbornWeapon",true,false) as Node3D
	if sword == null:
		push_error("Sword direction regression: ShadowbornWeapon missing")
		return 1
	var grip := sword.find_child("Grip",true,false) as Node3D
	var tip := sword.find_child("BladeTip",true,false) as Node3D
	if grip == null or tip == null:
		push_error("Sword direction regression: Grip/BladeTip markers missing")
		return 1
	var blade_length_world := grip.global_position.distance_to(tip.global_position)
	var camera := stage.get("battle_camera") as Camera3D
	var failures := 0
	failures += _expect(CharacterFactory.PRODUCTION_SWORD_WRIST_ROTATION.is_equal_approx(Vector3(0.0,0.0,-90.0)),"Production starter sword keeps camera-verified -90 degree Wrist.R mount")
	failures += _expect(blade_length_world > 0.70,"Production starter sword keeps its authored Grip-to-BladeTip reach")
	if camera == null:
		push_error("Sword direction regression: battle camera missing")
		failures += 1
	else:
		# This is a camera-readability regression, so test it in the shipping camera's
		# projected space. From the character's torso center to the sword hand, then
		# from the hand to BladeTip, the direction must keep moving outward instead
		# of folding back across the body silhouette as the old 180-degree mount did.
		var body_screen := camera.unproject_position(shadow_root.global_position+Vector3(0.0,1.05,0.0))
		var grip_screen := camera.unproject_position(grip.global_position)
		var tip_screen := camera.unproject_position(tip.global_position)
		var blade_out := tip_screen-grip_screen
		var grip_radius := grip_screen.distance_to(body_screen)
		var tip_radius := tip_screen.distance_to(body_screen)
		failures += _expect(blade_out.length() >= 24.0,"Production starter sword projects to a readable blade length in the battle camera")
		failures += _expect(tip_radius >= grip_radius+16.0,"Production starter sword BladeTip clears the projected Shadow body instead of folding back across the silhouette")
	return failures

func _check_hound_visual_forward(stage: Node) -> int:
	var actors: Dictionary = stage.get("actor_nodes")
	var hound_root := actors.get("hound") as Node3D
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
	var failures := _expect(absf(wrapf(model.rotation_degrees.y,0.0,360.0)-180.0) < 0.5,"Grave Hound dev mesh keeps camera-verified 180 degree facing correction")
	var labels: Dictionary = stage.get("actor_labels")
	var hound_label := labels.get("hound") as Label3D
	failures += _expect(hound_label != null,"Grave Hound world health label exists")
	if hound_label != null:
		failures += _expect(hound_label.position.y >= 1.45,"Grave Hound world health label keeps user-requested head clearance")
		failures += _expect(hound_label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,"Grave Hound world health label always faces the battle camera")
		failures += _expect(not hound_label.double_sided,"Grave Hound world health label cannot render mirrored from its back face")

	var shadow_label := labels.get("shadow") as Label3D
	failures += _expect(shadow_label != null,"Shadow world health label exists")
	if shadow_label != null:
		failures += _expect(shadow_label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,"Shadow world health label always faces the battle camera")
		failures += _expect(not shadow_label.double_sided,"Shadow world health label cannot render mirrored from its back face")
	return failures

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
