extends SceneTree

# RR-956: stage-local/world-space contract under a translated + yawed parent.
# This is structural CI, not a side-on visual or physical iPhone acceptance test.
const Stage = preload("res://scripts/presentation/battle_stage.gd")
var failures := 0

class FallbackStage extends BattleStage:
	func _build_environment() -> void:
		_build_debug_environment()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var parent := Node3D.new()
	parent.position = Vector3(7.0,0.0,-3.0)
	parent.rotation_degrees.y = 31.0
	root.add_child(parent)

	var stage := Stage.new()
	parent.add_child(stage)
	await process_frame
	stage.apply_state({
		"speed":1.0,
		"units":[
			{"id":"shadow","name":"Shadow","hp":100,"max_hp":100},
			{"id":"hound","name":"Grave Hound","hp":80,"max_hp":80}
		]
	})
	await process_frame

	var arena := stage.get("production_environment") as Node3D
	var actors: Dictionary = stage.get("actor_nodes")
	var shadow := actors.get("shadow") as Node3D
	var hound := actors.get("hound") as Node3D
	var camera := stage.get("battle_camera") as Camera3D
	if arena == null or shadow == null or hound == null or camera == null:
		push_error("RR-956 fixture missing arena, actors or camera")
		quit(1)
		return

	var player_anchor := arena.find_child("PlayerHome",true,false) as Node3D
	var enemy_anchor := arena.find_child("EnemyHome",true,false) as Node3D
	var target_anchor := arena.find_child("CameraTarget",true,false) as Node3D
	if player_anchor == null or enemy_anchor == null or target_anchor == null:
		push_error("RR-956 fixture missing authored anchors")
		quit(1)
		return

	_check(shadow.global_position.distance_to(player_anchor.global_position)<0.01,"Shadow matches world PlayerHome under rotated parent")
	_check(hound.global_position.distance_to(enemy_anchor.global_position)<0.01,"Hound matches world EnemyHome under rotated parent")
	_check(stage.to_global(stage.get("camera_target")).distance_to(target_anchor.global_position)<0.01,"CameraTarget has explicit stage-local ownership")
	_check(camera.position.distance_to(stage.get("camera_home"))<0.01,"CameraHome is camera-parent local")
	_check(absf(camera.fov-float(stage.get("camera_home_fov")))<0.01,"Authored FOV is captured on initialization")

	var lane := (hound.global_position-shadow.global_position).normalized()
	_check((-shadow.global_transform.basis.z).normalized().dot(lane)>0.99,"Shadow faces opponent in world coordinates")
	_check((-hound.global_transform.basis.z).normalized().dot(-lane)>0.99,"Hound faces opponent in world coordinates")

	var vfx: Dictionary = stage.get("vfx_meshes")
	var a1_world := hound.global_position+Vector3(0.0,0.95,0.0)
	stage.play_impact("shadow","hound","basic_slash",9,"")
	_check_effects(stage,vfx["basic_slash"],3,a1_world,0.12,lane,"A1 slash")
	_check_damage_text(stage,hound.global_position+Vector3(0.0,2.05,0.0),"A1 damage")
	await create_timer(0.36).timeout

	# Recovery unit fixture: 41 degrees is injected into cached state after
	# initialization. This tests recovery behavior, not a 41-degree authored scene.
	stage.set("camera_home_fov",41.0)
	camera.fov = 41.0
	stage.play_windup("shadow","hound","shadow_lunge")
	_check_effects(stage,[vfx["shadow_charge"]],1,shadow.global_position+Vector3(0.0,0.85,0.0),0.02,Vector3.ZERO,"A2 charge")
	await create_timer(0.58).timeout

	var a2_world := hound.global_position+Vector3(0.0,0.95,0.0)
	stage.play_impact("shadow","hound","shadow_lunge",19,"")
	var heavy: Array = (vfx["heavy_shards"] as Array).duplicate()
	heavy.append(vfx["heavy_burst"])
	_check_effects(stage,heavy,6,a2_world,0.02,lane,"A2 burst and shards")
	_check_damage_text(stage,hound.global_position+Vector3(0.0,2.05,0.0),"A2 damage")
	await create_timer(0.68).timeout
	_check(camera.position.distance_to(stage.get("camera_home"))<0.03,"A2 camera returns to parent-local home")
	_check(absf(camera.fov-41.0)<0.05,"A2 camera restores nondefault cached FOV")
	_check(not (stage.get("last_recovery_probe") as Dictionary).is_empty(),"A2 emits recovery probe")

	stage.queue_free()
	await process_frame

	var fallback := FallbackStage.new()
	parent.add_child(fallback)
	await process_frame
	var fallback_camera := fallback.get("battle_camera") as Camera3D
	if fallback_camera == null:
		_check(false,"Fallback camera exists")
	else:
		var fallback_target := fallback.to_global(fallback.get("camera_target"))
		var forward := (-fallback_camera.global_transform.basis.z).normalized()
		var toward := (fallback_target-fallback_camera.global_position).normalized()
		_check(forward.dot(toward)>0.99,"Fallback camera looks at global target under rotated parent")
	parent.queue_free()
	await process_frame

	print("RR-956 transform-space regression: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
	quit(0 if failures==0 else 1)

func _check_effects(stage: Node3D,expected_meshes: Array,expected_count: int,world_pos: Vector3,tolerance: float,world_dir: Vector3,label: String) -> void:
	var count := 0
	for child in stage.get_children():
		if child is MeshInstance3D:
			var effect := child as MeshInstance3D
			if expected_meshes.has(effect.mesh):
				count += 1
				_check(effect.global_position.distance_to(world_pos)<=tolerance,"%s world position" % label)
				if world_dir.length_squared()>0.01:
					var forward := (-effect.global_transform.basis.z).normalized()
					# Heavy burst has no directional look_at; only streaks/shards do.
					if label!="A2 burst and shards" or effect.mesh!=stage.get("vfx_meshes")["heavy_burst"]:
						_check(forward.dot(world_dir)>0.94,"%s world-facing" % label)
	_check(count==expected_count,"%s count=%d expected=%d" % [label,count,expected_count])

func _check_damage_text(stage: Node3D,world_pos: Vector3,label: String) -> void:
	var count := 0
	for child in stage.get_children():
		if child is Label3D:
			var damage := child as Label3D
			if damage.text.begins_with("-"):
				count += 1
				_check(damage.global_position.distance_to(world_pos)<0.02,"%s world position" % label)
	_check(count==1,"%s single label" % label)

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
