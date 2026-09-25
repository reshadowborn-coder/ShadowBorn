extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _approx_vec3(a: Vector3, b: Vector3, epsilon := 0.001) -> bool:
	return a.distance_to(b) <= epsilon

func _approx_float(a: float, b: float, epsilon := 0.001) -> bool:
	return absf(a - b) <= epsilon

func _run() -> void:
	await _test_camera_framing_parity()
	await _test_impact_pool_reuse()
	print("Perf/visual consistency tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _make_camera_director() -> CameraDirector:
	var director := CameraDirector.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	director.add_child(camera)
	var target := Node3D.new()
	target.name = "Target"
	root.add_child(target)
	director.target = target
	root.add_child(director)
	return director

func _test_camera_framing_parity() -> void:
	var director := _make_camera_director()
	await process_frame

	director.set_reduced_motion(false)
	director.enter_combat(Vector3(-1, 0, 0), Vector3(1, 0, 0))
	var normal_combat_offset := director.offset
	var normal_combat_rotation := director.target_rotation
	var normal_combat_fov := director.target_fov
	director.exit_combat()

	director.set_reduced_motion(true)
	director.enter_combat(Vector3(-1, 0, 0), Vector3(1, 0, 0))
	_check(_approx_vec3(director.offset, normal_combat_offset), "Reduced Motion preserves combat camera offset")
	_check(_approx_vec3(director.target_rotation, normal_combat_rotation), "Reduced Motion preserves combat camera rotation")
	_check(_approx_float(director.target_fov, normal_combat_fov), "Reduced Motion preserves combat camera FOV")
	_check(_approx_vec3(director.global_position, director.combat_focus + director.offset), "Reduced Motion removes combat travel by snapping to the same framing")
	director.exit_combat()

	director.set_reduced_motion(false)
	director.enter_reveal(Vector3(4, 0, -3))
	var normal_reveal_offset := director.offset
	var normal_reveal_rotation := director.target_rotation
	var normal_reveal_fov := director.target_fov
	director.exit_reveal()

	director.set_reduced_motion(true)
	director.enter_reveal(Vector3(4, 0, -3))
	_check(_approx_vec3(director.offset, normal_reveal_offset), "Reduced Motion preserves reveal camera offset")
	_check(_approx_vec3(director.target_rotation, normal_reveal_rotation), "Reduced Motion preserves reveal camera rotation")
	_check(_approx_float(director.target_fov, normal_reveal_fov), "Reduced Motion preserves reveal camera FOV")
	_check(_approx_vec3(director.global_position, director.reveal_focus + director.offset), "Reduced Motion removes reveal travel by snapping to the same framing")

	var target := director.target
	director.queue_free()
	if is_instance_valid(target):
		target.queue_free()
	await process_frame

func _test_impact_pool_reuse() -> void:
	var presenter := CombatPresenter.new()
	root.add_child(presenter)
	var shadow := Node3D.new()
	var enemy := Node3D.new()
	root.add_child(shadow)
	root.add_child(enemy)
	shadow.global_position = Vector3.ZERO
	enemy.global_position = Vector3(2, 0, 0)
	await process_frame

	presenter.bind_combatants(shadow, enemy)
	_check(presenter._impact_pool.size() == presenter.IMPACT_POOL_SIZE, "Combat impact VFX pool is preallocated")

	var child_count_before := presenter.get_child_count()
	for i in range(12):
		presenter._impact_flash(enemy if i % 2 == 0 else shadow, i % 3 == 0)
	_check(presenter.get_child_count() == child_count_before, "Repeated combat impacts reuse pooled nodes without scene-tree growth")
	_check(presenter._impact_pool.size() == presenter.IMPACT_POOL_SIZE, "Repeated combat impacts keep a bounded pool")

	await create_timer(0.20).timeout
	var hidden_count := 0
	for flash in presenter._impact_pool:
		if not flash.visible:
			hidden_count += 1
	_check(hidden_count == presenter.IMPACT_POOL_SIZE, "Impact VFX pool returns all nodes to hidden state")

	presenter.clear()
	_check(presenter.get_child_count() == child_count_before, "Clearing combat does not destroy and recreate pooled VFX")
	presenter.queue_free()
	shadow.queue_free()
	enemy.queue_free()
	await process_frame
