extends SceneTree

var failures := 0
var rows: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	_test_single_event_frame_assignment()
	_test_state_projection_and_recovery()
	await _test_multi_enemy_trace()
	print("Combat frame trace tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _new_trace() -> CombatFrameTrace:
	var trace := CombatFrameTrace.new()
	trace.set_console_output(false)
	trace.row_completed.connect(func(row:Dictionary)->void:
		rows.append(row.duplicate(true))
	)
	return trace

func _flush(trace: CombatFrameTrace) -> void:
	trace._on_frame_pre_draw()
	trace._on_frame_post_draw()

func _test_single_event_frame_assignment() -> void:
	rows.clear()
	var trace := _new_trace()
	trace.set_context("battery30",true)
	trace._mark("probe",{"value":7})
	_flush(trace)

	_check(rows.size()==2,"context + probe rows are completed")
	if rows.size()<2:
		return
	var probe:Dictionary=rows[1]
	_check(str(probe.get("event",""))=="probe","probe event identity survives trace")
	_check(int(probe.get("requested_fps",0))==30,"trace records requested 30 FPS")
	_check(bool(probe.get("reduced_motion",false)),"trace records Reduced Motion")
	_check(int(probe.get("value",0))==7,"trace preserves event payload")
	_check(int(probe.get("eligible_engine_frame",0))==1,"first pending events bind to first eligible engine frame")
	_check(int(probe.get("frame_pre_draw_ts_us",0))>=int(probe.get("ts_us",0)),"frame pre timestamp does not precede event")
	_check(int(probe.get("frame_post_draw_ts_us",0))>=int(probe.get("frame_pre_draw_ts_us",0)),"frame post timestamp does not precede frame pre")
	_check(int(probe.get("event_to_frame_pre_us",-1))>=0,"event-to-frame latency is non-negative")

func _test_state_projection_and_recovery() -> void:
	rows.clear()
	var trace := _new_trace()
	trace.set_context("smooth60",false)
	var initial := {
		"encounter_id":"shield_boss",
		"action_locked":true,
		"shadow":{"hp":60.0,"a2_cd":0,"veil":0.0,"fray":false},
		"enemy":{"hp":87.0,"guard":true,"intent":"BRACE"}
	}
	var initial_copy:Dictionary=initial.duplicate(true)
	trace._on_combat_state_changed(initial)
	_flush(trace)
	_check(initial==initial_copy,"trace observation does not mutate source combat state")

	rows.clear()
	var contact := initial.duplicate(true)
	contact.enemy.hp=79.6666667
	contact.shadow.fray=true
	trace._on_semantic_contact("shadow","A1")
	trace._on_combat_state_changed(contact)
	_flush(trace)

	var names:Array[String]=[]
	for row in rows:
		names.append(str(row.get("event","")))
	_check("semantic_contact" in names,"semantic contact is captured")
	_check("combat_state_projection" in names,"contact state projection is captured")

	rows.clear()
	var unlocked:=contact.duplicate(true)
	unlocked.action_locked=false
	trace._on_combat_state_changed(unlocked)
	_flush(trace)
	names.clear()
	for row in rows:
		names.append(str(row.get("event","")))
	_check("recovery_unlock" in names,"locked-to-ready transition is captured")

func _test_multi_enemy_trace() -> void:
	rows.clear()
	var trace:=_new_trace()
	trace.set_context("smooth60",false)
	var combat:=MultiEnemyEncounter.new()
	root.add_child(combat)
	trace.attach_multi(combat)
	var profiles:Array=[
		{"id":"trace_rat_a","label":"Rat A","hp":30.0,"def":2.0,"damage":1.5},
		{"id":"trace_rat_b","label":"Rat B","hp":30.0,"def":2.0,"damage":1.5}
	]
	_check(combat.start(profiles,false,true),"multi trace fixture starts a two-enemy encounter")
	combat.shadow_action("A1")
	_flush(trace)

	var names:Array[String]=[]
	var enemy_rows:=0
	var target_index:=-1
	for row in rows:
		var event_name:=str(row.get("event",""))
		names.append(event_name)
		if event_name=="multi_enemy_presentation_start":
			enemy_rows+=1
		if event_name=="multi_shadow_presentation_start":
			target_index=int(row.get("target_index",-1))
	_check("multi_state_initial" in names,"multi trace records the initial pack projection")
	_check("multi_command_committed" in names,"multi trace records the accepted command")
	_check("multi_shadow_presentation_start" in names and target_index==0,"multi trace records the selected target for Shadow presentation")
	_check(enemy_rows==2,"multi trace records one presentation event for each living enemy response")
	_check("multi_state_projection" in names,"multi trace records resulting HP/round/action-lock projection")

	combat.queue_free()
	await process_frame
