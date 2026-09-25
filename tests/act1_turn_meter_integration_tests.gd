extends SceneTree

var failures:=0

func _init()->void:
	call_deferred("_run")

func _check(condition:bool,message:String)->void:
	if condition:
		print("PASS: "+message)
	else:
		failures+=1
		push_error("FAIL: "+message)

func _wait_for_shadow(controller:EncounterController,timeout_seconds:float=2.0)->bool:
	var elapsed:=0.0
	while controller.active and controller.action_locked and elapsed<timeout_seconds:
		await create_timer(.02).timeout
		elapsed+=.02
	return (
		controller.active
		and not controller.action_locked
		and StringName(controller.current_turn.get("actor_id",&""))==&"shadow"
	)

func _wait_for_next_shadow_or_end(controller:EncounterController,timeout_seconds:float=2.0)->bool:
	var elapsed:=0.0
	while controller.active and controller.action_locked and elapsed<timeout_seconds:
		await create_timer(.02).timeout
		elapsed+=.02
	return not controller.active or (
		not controller.action_locked
		and StringName(controller.current_turn.get("actor_id",&""))==&"shadow"
	)

func _new_controller()->EncounterController:
	var controller:=EncounterController.new()
	root.add_child(controller)
	controller.set_loadout("sword_shield")
	controller.set_reduced_motion(true)
	controller.set_turn_meter_mode_enabled(true)
	return controller

func _run()->void:
	await _test_single_rat_turn_order()
	await _test_poison_ticks_on_shadow_turn()
	await _test_control_skip_blocks_cooldown()
	await _test_silence_blocks_active_skill()
	print("Act 1 turn-meter integration tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_single_rat_turn_order()->void:
	var controller:=_new_controller()
	var enemy_attacks:Array[float]=[]
	controller.enemy_attack_presented.connect(func(damage:float): enemy_attacks.append(damage))
	var profile:=Dictionary(SewerEncounterPlan.PROFILES["a1_r1_rat"]).duplicate(true)
	_check(controller.start_encounter("a1_r1_rat",profile),"Room 1 starts in turn-meter mode")
	_check(await _wait_for_shadow(controller),"100 SPD Shadow reaches the first command window before 92 SPD Sewer Rat")
	_check(int(controller.turn_timeline.actor_snapshot(&"shadow").effective_speed)==EncounterController.SHADOW_BASE_SPEED,"single combat exposes Shadow effective SPD")
	controller.shadow_action("A1")
	_check(await _wait_for_next_shadow_or_end(controller),"turn loop returns to Shadow or a valid terminal state")
	if controller.active:
		_check(enemy_attacks.size()==1,"slower Sewer Rat receives exactly one natural turn before Shadow's second turn")
		_check(controller.shadow_completed_turns==1,"one accepted Shadow action consumes exactly one Shadow turn")
	controller.queue_free()
	await process_frame

func _test_poison_ticks_on_shadow_turn()->void:
	var controller:=_new_controller()
	var profile:=Dictionary(SewerEncounterPlan.PROFILES["a1_r2_poison_rat"]).duplicate(true)
	_check(controller.start_encounter("a1_r2_poison_rat",profile),"Poison Rat starts in turn-meter mode")
	_check(await _wait_for_shadow(controller),"Shadow receives the first Poison Rat command window")
	controller.shadow_action("A1")
	_check(await _wait_for_next_shadow_or_end(controller),"Poison Rat response resolves into the next Shadow turn")
	if controller.active:
		_check(int(controller.shadow.get("poison_turns",0))==1,"Poison ticks and decrements at the beginning of Shadow's next turn")
		_check(float(controller.shadow.get("hp",20.0))<18.0,"enemy hit plus start-of-turn Poison both affect Shadow before input unlocks")
	controller.queue_free()
	await process_frame

func _test_control_skip_blocks_cooldown()->void:
	var controller:=_new_controller()
	var profile:=Dictionary(SewerEncounterPlan.PROFILES["a1_r1_rat"]).duplicate(true)
	_check(controller.start_encounter("a1_r1_rat",profile),"control fixture starts")
	_check(await _wait_for_shadow(controller),"control fixture reaches Shadow")
	controller.shadow.a2_cd=2
	# Close the current ready ticket first, then apply Stun so its one owner-turn
	# duration belongs to the NEXT Shadow turn rather than expiring on this one.
	controller.turn_timeline.end_turn(&"shadow")
	controller.current_turn.clear()
	controller.shadow_completed_turns=1
	_check(controller.apply_turn_control(&"shadow",CombatTurnTimeline.TAG_STUN,1,&"test_rat"),"controller exposes hard-control application")
	controller.action_locked=true
	controller.call_deferred("_advance_turn_meter",controller.encounter_generation)
	var elapsed:=0.0
	while controller.active and controller.action_locked and elapsed<2.0:
		await create_timer(.02).timeout
		elapsed+=.02
	_check(controller.active and not controller.action_locked,"automatic loop consumes the stunned Shadow turn and eventually returns control")
	_check(int(controller.shadow.a2_cd)==1,"cooldown advances only on the later actionable Shadow turn, not on the stunned skipped turn")
	_check(int(controller.turn_timeline.actor_snapshot(&"shadow").resolve_stacks)==1,"stunned skipped turn grants Resolve in live single combat")
	controller.queue_free()
	await process_frame


func _test_silence_blocks_active_skill()->void:
	var controller:=_new_controller()
	var profile:=Dictionary(SewerEncounterPlan.PROFILES["a1_r1_rat"]).duplicate(true)
	_check(controller.start_encounter("a1_r1_rat",profile),"Silence fixture starts")
	_check(await _wait_for_shadow(controller),"Silence fixture reaches Shadow")
	var committed:Array[String]=[]
	controller.command_committed.connect(func(skill:String):committed.append(skill))
	_check(controller.apply_turn_silence(&"shadow",&"test_mage",1),"Silence can be applied through the live controller API")
	controller.shadow_action("A2")
	_check(committed.is_empty() and not controller.action_locked,"Silence rejects active A2 without consuming the turn")
	controller.shadow_action("A1")
	_check(committed.size()==1 and committed[0]=="A1","Silence preserves the default A1 action")
	controller.queue_free()
	await process_frame
