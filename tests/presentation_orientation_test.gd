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
	failures += _check_world_healthplates(battle)
	failures += _check_shadow_sword_direction(battle)
	failures += _check_side_on_battle_composition(battle)
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
	return _expect(absf(wrapf(model.rotation_degrees.y,0.0,360.0)-180.0) < 0.5,"Grave Hound dev mesh keeps camera-verified 180 degree facing correction")

func _check_world_healthplates(stage: Node) -> int:
	var actors: Dictionary = stage.get("actor_nodes")
	var roots: Dictionary = stage.get("actor_health_roots")
	var fills: Dictionary = stage.get("actor_health_fills")
	var camera := stage.get("battle_camera") as Camera3D
	var hound_actor := actors.get("hound") as Node3D
	var hound_tracker := roots.get("hound") as Node3D
	var shadow_tracker := roots.get("shadow") as Node3D
	var hound_fill := fills.get("hound") as MeshInstance3D
	var shadow_fill := fills.get("shadow") as MeshInstance3D
	if camera == null or hound_actor == null or hound_tracker == null or shadow_tracker == null or hound_fill == null or shadow_fill == null:
		push_error("World healthplate regression: required nodes missing")
		return 1

	var failures := 0
	var hound_anchor := hound_tracker.get_node_or_null("HealthPlateAnchor") as Node3D
	var shadow_anchor := shadow_tracker.get_node_or_null("HealthPlateAnchor") as Node3D
	failures += _expect(hound_anchor != null and hound_anchor.position.y >= 1.60,"Grave Hound healthplate clears the head in the side camera")
	failures += _expect(shadow_anchor != null and shadow_anchor.position.y >= 2.45,"Shadow healthplate clears the hood and sword silhouette")

	var follow := hound_actor.get_node_or_null("HealthPlateFollow") as RemoteTransform3D
	failures += _expect(follow != null,"Grave Hound healthplate has a transform follower")
	if follow != null:
		failures += _expect(follow.update_position,"healthplate follows actor translation")
		failures += _expect(not follow.update_rotation,"healthplate does not inherit actor-facing yaw")
		failures += _expect(not follow.update_scale,"healthplate does not inherit character scale")

	if hound_anchor != null:
		var hound_actor_screen := camera.unproject_position(hound_actor.global_position)
		var hound_bar_screen := camera.unproject_position(hound_tracker.global_position+hound_anchor.position)
		failures += _expect(hound_bar_screen.y < hound_actor_screen.y-45.0,"Grave Hound healthplate projects visibly above the body")

	stage.apply_state({
		"speed":1.0,
		"units":[
			{"id":"shadow","name":"Shadow","hp":100,"max_hp":100},
			{"id":"hound","name":"Grave Hound","hp":40,"max_hp":80}
		]
	})
	failures += _expect(absf(hound_fill.scale.x-0.5) < 0.01,"world healthplate fill tracks HP ratio")
	failures += _expect(hound_fill.position.x < -0.20,"world healthplate depletes from right to left instead of center")
	failures += _expect(absf(shadow_fill.scale.x-1.0) < 0.01,"full-health Shadow plate remains full width")
	return failures

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1


func _check_side_on_battle_composition(stage: Node) -> int:
	var camera := stage.get("battle_camera") as Camera3D
	var actors: Dictionary = stage.get("actor_nodes")
	var shadow := actors.get("shadow") as Node3D
	var hound := actors.get("hound") as Node3D
	if camera == null or shadow == null or hound == null:
		push_error("Side-on composition regression: camera/actors missing")
		return 1

	var viewport_size := camera.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		push_error("Side-on composition regression: invalid viewport size")
		return 1

	var shadow_screen := camera.unproject_position(shadow.global_position)
	var hound_screen := camera.unproject_position(hound.global_position)
	var horizontal_gap := hound_screen.x-shadow_screen.x
	var baseline_gap := absf(hound_screen.y-shadow_screen.y)
	var shadow_distance := camera.global_position.distance_to(shadow.global_position)
	var hound_distance := camera.global_position.distance_to(hound.global_position)
	var depth_ratio := maxf(shadow_distance,hound_distance)/maxf(0.001,minf(shadow_distance,hound_distance))

	var failures := 0
	failures += _expect(shadow_screen.x < hound_screen.x,"side-on battle keeps Shadow left of the enemy")
	failures += _expect(horizontal_gap >= viewport_size.x*0.35,"side-on battle reserves a readable attack lane between actors")
	failures += _expect(baseline_gap <= viewport_size.y*0.08,"side-on battle keeps actor foot baselines nearly horizontal")
	failures += _expect(shadow_screen.y >= viewport_size.y*0.52 and shadow_screen.y <= viewport_size.y*0.82,"Shadow feet stay in the lower battle band")
	failures += _expect(hound_screen.y >= viewport_size.y*0.52 and hound_screen.y <= viewport_size.y*0.82,"Grave Hound feet stay in the lower battle band")
	failures += _expect(depth_ratio <= 1.15,"side-on battle keeps combatants at comparable camera depth and apparent scale")
	return failures
