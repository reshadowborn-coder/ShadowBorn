extends SceneTree

const Battle = preload("res://scripts/combat/battle_controller.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var auto_trace := await _run_first_three(true)
	var manual_trace := await _run_first_three(false)

	_check(auto_trace.size() == 3,"AUTO reaches three live semantic actions")
	_check(manual_trace.size() == 3,"MANUAL reaches three live semantic actions")
	if auto_trace.size() == 3:
		_check(auto_trace[0] == "shadow:shadow_lunge","AUTO first live action is Shadow A2")
		_check(auto_trace[1] == "grave_hound:hound_bite","AUTO second live action is Grave Hound")
		_check(auto_trace[2] == "shadow:basic_slash","AUTO third live action returns to Shadow A1 while A2 cools down")
	if manual_trace.size() == 3:
		_check(manual_trace[0] == "shadow:shadow_lunge","MANUAL first requested action is Shadow A2")
		_check(manual_trace[1] == "grave_hound:hound_bite","MANUAL uses the same enemy turn authority")
		_check(manual_trace[2] == "shadow:basic_slash","MANUAL returns to Shadow on the same third opportunity")
	_check(auto_trace == manual_trace,"MANUAL and AUTO share one live scheduler/action-order path")

	print("Battle controller scheduler integration tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _run_first_three(auto_mode: bool) -> Array[String]:
	var battle := Battle.new()
	root.add_child(battle)
	battle.set_speed(2.0)
	battle.set_auto(auto_mode)

	var trace: Array[String] = []
	var manual_shadow_turn := 0
	battle.action_windup.connect(func(attacker_id: String,_target_id: String,skill_id: String):
		if trace.size() < 3:
			trace.append("%s:%s" % [attacker_id,skill_id])
	)
	if not auto_mode:
		battle.actor_ready.connect(func(_actor_id: String):
			var skill_index := 1 if manual_shadow_turn == 0 else 0
			manual_shadow_turn += 1
			battle.call_deferred("request_player_skill",skill_index)
		)

	battle.start_battle()
	var deadline_usec := Time.get_ticks_usec()+8000000
	while trace.size() < 3 and Time.get_ticks_usec() < deadline_usec:
		await create_timer(0.025).timeout

	battle.running = false
	battle.turn_loop_generation += 1
	battle.queue_free()
	await process_frame
	return trace

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
