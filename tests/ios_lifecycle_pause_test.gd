extends SceneTree

const GameRootScript = preload("res://scripts/app/game_root.gd")
const Battle = preload("res://scripts/combat/battle_controller.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_lifecycle_blocker_order()
	await _test_battle_windup_freezes_while_inactive()
	paused = false
	print("iOS lifecycle pause tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _test_lifecycle_blocker_order() -> void:
	var app := GameRootScript.new()
	root.add_child(app)
	await process_frame

	app.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(paused,"focus-out pauses the SceneTree immediately")

	app.notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	_check(paused,"OS paused notification keeps SceneTree paused")

	app.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(paused,"focus-in alone cannot resume while OS-paused blocker remains")

	app.notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	_check(not paused,"game resumes only after both lifecycle blockers clear")

	app.queue_free()
	await process_frame

func _test_battle_windup_freezes_while_inactive() -> void:
	var app := GameRootScript.new()
	root.add_child(app)
	var battle := Battle.new()
	root.add_child(battle)
	await process_frame

	battle.set_speed(2.0)
	battle.set_auto(true)
	var windups: Array[String] = []
	var impacts: Array[String] = []
	battle.action_windup.connect(func(attacker_id: String,_target_id: String,skill_id: String):
		windups.append("%s:%s" % [attacker_id,skill_id])
	)
	battle.action_impact.connect(func(attacker_id: String,_target_id: String,skill_id: String,_damage: int,_effect: String):
		impacts.append("%s:%s" % [attacker_id,skill_id])
	)

	battle.start_battle()
	var windup_deadline := Time.get_ticks_usec()+4000000
	while windups.is_empty() and Time.get_ticks_usec() < windup_deadline:
		await create_timer(0.02,true).timeout

	_check(not windups.is_empty(),"live battle reaches first windup before lifecycle interruption")
	if windups.is_empty():
		battle.running = false
		app.queue_free()
		battle.queue_free()
		await process_frame
		return

	app.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(paused,"battle lifecycle interruption pauses SceneTree")
	var impact_count_before := impacts.size()

	# Longer than the first A2 windup at x2. A process_always test timer advances
	# wall-clock while the battle's process_always=false timer must remain frozen.
	await create_timer(0.55,true).timeout
	_check(impacts.size() == impact_count_before,"no combat impact occurs while app is inactive")

	app.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(not paused,"focus return resumes the frozen battle clock")

	var impact_deadline := Time.get_ticks_usec()+1800000
	while impacts.size() == impact_count_before and Time.get_ticks_usec() < impact_deadline:
		await create_timer(0.02,true).timeout

	_check(impacts.size() == impact_count_before+1,"paused windup continues to exactly one impact after resume")
	if impacts.size() > impact_count_before:
		_check(impacts[impact_count_before] == "shadow:shadow_lunge","resume preserves the already-authoritative Shadow A2 action")

	battle.running = false
	battle.turn_loop_generation += 1
	app.queue_free()
	battle.queue_free()
	await process_frame

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
