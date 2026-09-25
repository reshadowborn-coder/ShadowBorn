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

func _completed_act0_state()->Dictionary:
	var s:=SaveManager.default_state()
	s.shadow_identity="male"
	s.covenant_joined=true
	s.weapon_family="sword_shield"
	s.forged_item=Act0Progression.canonical_first_forge_item("sword_shield")
	s.first_forge_done=true
	s.silver=0
	s.hound_residual_absorbed=true
	s.temple_reveal_seen=true
	s.faded_sigil_activated=true
	s.catacomb_room=5
	s.room5_solo_limit_seen=true
	s.story_summon_unlocked=true
	s.room5_rematch_ready=true
	s.act0_complete=true
	s.act0_stage=Act0Contract.STAGE_COMPLETE
	s.cleared_encounters=Act0Contract.all_encounter_ids()
	s.checkpoint="act0_complete"
	s.checkpoint_position=[Act0Layout.ROOM5_SHADOW_POSITION.x,Act0Layout.ROOM5_SHADOW_POSITION.y,Act0Layout.ROOM5_SHADOW_POSITION.z]
	return s

func _run()->void:
	var migrated:=SaveManager._migrate(_completed_act0_state())
	_check(int(migrated.version)==SaveManager.SAVE_VERSION,"completed Act 0 save migrates to current schema")
	_check(str(migrated.act1_stage)==Act1Contract.STAGE_SEWER_ROOM1,"completed Act 0 enters Act 1.1 room 1")
	_check(int(migrated.act1_sewer_room)==1,"Act 1 migration selects first sewer room")
	_check(str(migrated.checkpoint)=="act1_sewer_entry","Act 1 migration repairs checkpoint to sewer entry")
	_check(Vector3(float(migrated.checkpoint_position[0]),float(migrated.checkpoint_position[1]),float(migrated.checkpoint_position[2])).is_equal_approx(Act1Layout.SEWER_ENTRY),"Act 1 migration uses canonical sewer entry position")

	var p:=Act1Progression.new()
	root.add_child(p)
	p.restore(migrated)
	_check(not p.keeper_briefing(),"Keeper briefing cannot be skipped before sewer defeat")
	_check(not p.smith_handoff(),"Smith handoff cannot be skipped before Keeper")
	_check(not p.join_temple_watch(),"Temple Watch cannot be joined before the handoff chain")
	_check(p.room_cleared(1),"room 1 Sewer Rat clear advances Act 1.1")
	_check(p.stage==Act1Contract.STAGE_SEWER_ROOM2 and p.sewer_room==2,"room 1 advances exactly to Poison Rat room")
	_check(p.room_cleared(2),"room 2 Poison Rat clear advances Act 1.1")
	_check(p.stage==Act1Contract.STAGE_SEWER_ROOM3 and p.sewer_room==3,"room 2 advances exactly to pack room")
	_check(not p.room_cleared(3),"pack room cannot be cleared through the single-room API")
	_check(p.commit_pack_defeat(),"pack room commits the authored defeat")
	_check(p.stage==Act1Contract.STAGE_TEMPLE_RETURN and p.sewer_defeat_seen,"pack defeat returns progression to Temple")
	_check(p.keeper_briefing(),"Keeper briefing unlocks after sewer defeat")
	_check(p.smith_handoff(),"Smith handoff unlocks after Keeper briefing")
	_check(p.guard_offer_ready(),"Temple Guard covenant offer unlocks only after Smith")
	_check(p.join_temple_watch(),"Temple Watch covenant can be joined after the authored chain")
	_check(p.complete_act1_1(),"Temple Watch oath completes Act 1.1 onboarding")
	_check(p.act1_1_complete and p.stage==Act1Contract.STAGE_ACT1_1_COMPLETE,"Act 1.1 completion state is stable")

	_check(Act1Contract.encounter_ids(1)==["a1_r1_rat"],"room 1 has exactly one normal rat")
	_check(Act1Contract.encounter_ids(2)==["a1_r2_poison_rat"],"room 2 has exactly one poison rat")
	_check(Act1Contract.encounter_ids(3)==["a1_r3_rat_a","a1_r3_rat_b"],"room 3 has exactly two rats")
	var poison:=SewerEncounterPlan.PROFILES["a1_r2_poison_rat"]
	_check(float(poison.poison_damage)>0.0 and int(poison.poison_turns)==2,"Poison Rat carries a bounded poison status")
	_check(EncounterController._valid_legacy_profile(poison),"Poison Rat profile passes generic combat validation")

	var pack:=MultiEnemyEncounter.new()
	root.add_child(pack)
	pack.set_loadout("sword_shield")
	var pack_shadow_presentations:Array=[]
	var pack_enemy_presentations:Array=[]
	pack.shadow_attack_presented.connect(func(target_index:int,skill:String,damage:float): pack_shadow_presentations.append([target_index,skill,damage]))
	pack.enemy_attack_presented.connect(func(enemy_index:int,damage:float): pack_enemy_presentations.append([enemy_index,damage]))
	_check(pack.start(SewerEncounterPlan.enemies(3),false,true),"Act 1 pack encounter starts as an authored solo limit")
	pack.shadow_action("A1")
	_check(pack_shadow_presentations.size()==1 and int(pack_shadow_presentations[0][0])==0 and str(pack_shadow_presentations[0][1])=="A1","pack combat emits a target-specific Shadow presentation event")
	_check(pack_enemy_presentations.size()==2 and int(pack_enemy_presentations[0][0])==0 and int(pack_enemy_presentations[1][0])==1,"both living pack enemies emit presentation events each enemy phase")
	_check(pack.active and pack.action_locked,"Act 1 pack survives first solo round and locks rapid follow-up input")
	var round_after_first:=pack.rounds
	var presentations_after_first:=pack_shadow_presentations.size()
	pack.shadow_action("A1")
	_check(pack.rounds==round_after_first and pack_shadow_presentations.size()==presentations_after_first and not pack.limit_reached,"rapid double-tap cannot consume the second scripted pack round")
	await create_timer(MultiEnemyEncounter.ACTION_LOCK_SECONDS+.05).timeout
	_check(not pack.action_locked,"Act 1 pack unlocks after the presentation window")
	pack.shadow_action("A1")
	_check(not pack.active and pack.limit_reached,"Act 1 pack forces the authored defeat after the second accepted round")
	for enemy in pack.enemies:
		_check(float(enemy.current_hp)>=1.0,"Act 1 pack rats cannot be killed during first-contact story limit")

	# Save/resume matrix: every committed Act 1.1 stage must converge to a
	# canonical checkpoint even if the raw checkpoint payload is stale/corrupt.
	var resume_cases:Array=[
		{"name":"room1","stage":Act1Contract.STAGE_SEWER_ROOM1,"room":1,"flags":[],"checkpoint":"act1_sewer_entry","position":Act1Layout.SEWER_ENTRY},
		{"name":"room2","stage":Act1Contract.STAGE_SEWER_ROOM2,"room":2,"flags":[],"checkpoint":"act1_room1_cleared","position":Act1Layout.room_checkpoint(2)},
		{"name":"room3","stage":Act1Contract.STAGE_SEWER_ROOM3,"room":3,"flags":[],"checkpoint":"act1_room2_cleared","position":Act1Layout.room_checkpoint(3)},
		{"name":"temple_return","stage":Act1Contract.STAGE_TEMPLE_RETURN,"room":0,"flags":["defeat"],"checkpoint":"act1_temple_return","position":Act1Layout.TEMPLE_RETURN},
		{"name":"keeper","stage":Act1Contract.STAGE_KEEPER_BRIEFING,"room":0,"flags":["keeper"],"checkpoint":"act1_keeper_briefed","position":Act1Layout.TEMPLE_RETURN},
		{"name":"smith","stage":Act1Contract.STAGE_SMITH_HANDOFF,"room":0,"flags":["smith"],"checkpoint":"act1_smith_handoff","position":Vector3(Act1Layout.SMITH_HANDOFF.x,.9,Act1Layout.SMITH_HANDOFF.z)},
		{"name":"guard","stage":Act1Contract.STAGE_GUARD_COVENANT,"room":0,"flags":["watch"],"checkpoint":"act1_guard_covenant","position":Vector3(Act1Layout.GUARD_POSITION.x,.9,Act1Layout.GUARD_POSITION.z)},
		{"name":"complete","stage":Act1Contract.STAGE_ACT1_1_COMPLETE,"room":0,"flags":["complete"],"checkpoint":"act1_guard_covenant","position":Vector3(Act1Layout.GUARD_POSITION.x,.9,Act1Layout.GUARD_POSITION.z)}
	]
	for resume_case in resume_cases:
		var raw:=_completed_act0_state()
		raw.act1_stage=resume_case["stage"]
		raw.act1_sewer_room=resume_case["room"]
		raw.checkpoint="stale_checkpoint"
		raw.checkpoint_position=[999.0,999.0,999.0]
		var flags:Array=resume_case["flags"]
		if "defeat" in flags: raw.act1_sewer_defeat_seen=true
		if "keeper" in flags: raw.act1_keeper_briefed=true
		if "smith" in flags: raw.act1_smith_handoff_done=true
		if "watch" in flags: raw.temple_watch_covenant_joined=true
		if "complete" in flags: raw.act1_1_complete=true
		var resumed:=SaveManager._migrate(raw)
		var expected_position:Vector3=resume_case["position"]
		var actual_position:=Vector3(float(resumed.checkpoint_position[0]),float(resumed.checkpoint_position[1]),float(resumed.checkpoint_position[2]))
		_check(str(resumed.act1_stage)==str(resume_case["stage"]),"resume stage is canonical: "+str(resume_case["name"]))
		_check(str(resumed.checkpoint)==str(resume_case["checkpoint"]),"resume checkpoint id is repaired: "+str(resume_case["name"]))
		_check(actual_position.is_equal_approx(expected_position),"resume checkpoint position is repaired: "+str(resume_case["name"]))

	var corrupt_handoff:=_completed_act0_state()
	corrupt_handoff.act1_stage=Act1Contract.STAGE_SEWER_ROOM1
	corrupt_handoff.act1_smith_handoff_done=true
	var repaired_handoff:=SaveManager._migrate(corrupt_handoff)
	_check(str(repaired_handoff.act1_stage)==Act1Contract.STAGE_SMITH_HANDOFF,"downstream Smith evidence repairs Act 1 stage forward")
	_check(bool(repaired_handoff.act1_sewer_defeat_seen) and bool(repaired_handoff.act1_keeper_briefed),"downstream Smith evidence restores prerequisite handoffs")
	_check(bool(repaired_handoff.covenant_joined) and not bool(repaired_handoff.temple_watch_covenant_joined),"Act 0 Forgotten Covenant remains separate from Temple Watch")

	p.queue_free()
	pack.queue_free()
	await process_frame
	print("Act 1.1 state tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)