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

func _run()->void:
	_test_fixed_contract()
	_test_director_route_contract()
	_test_temple_progression()
	_test_all_weapon_families()
	_test_catacomb_progression()
	_test_catacomb_reentry_contract()
	_test_combat_math()
	_test_save_recovery()
	_test_resume_transition_matrix()
	_test_room5_limit_contract()
	print("Act 0 state tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_fixed_contract()->void:
	_check(Act0Contract.STAGES.size()==8,"Act 0 exposes exactly eight canonical progression stages")
	_check(not Act0Contract.can_transition(Act0Contract.STAGE_EXTERIOR,Act0Contract.STAGE_FIRST_FORGE),"fixed contract rejects stage skipping")
	_check(Act0Contract.can_transition(Act0Contract.STAGE_EXTERIOR,Act0Contract.STAGE_TEMPLE_ENTRY),"fixed contract allows exterior -> Temple threshold")
	_check(not Act0Contract.can_start_exterior_encounter("armless",[]),"Armless cannot start before Hound")
	_check(Act0Contract.can_start_exterior_encounter("armless",["hound"]),"Armless unlocks after Hound")
	_check(not Act0Contract.can_start_exterior_encounter("shield_boss",["hound"],false),"Shield cannot start before Armless")
	_check(not Act0Contract.can_start_exterior_encounter("shield_boss",["hound","armless"],false),"Shield remains locked until Temple reveal is persisted")
	_check(Act0Contract.can_start_exterior_encounter("shield_boss",["hound","armless"],true),"Shield unlocks only after both exterior prerequisites and Temple reveal")
	var weapon_keys:Array=Act0Progression.WEAPONS.keys()
	_check(weapon_keys.size()==Act0Contract.WEAPON_FAMILIES.size(),"weapon data count matches fixed family contract")
	for family in Act0Contract.WEAPON_FAMILIES:
		_check(Act0Progression.WEAPONS.has(family),"fixed weapon family %s has progression data"%family)
	for room in range(1,6):
		var expected_ids:Array=Act0Contract.catacomb_encounter_ids(room)
		var profiles:=CatacombEncounterPlan.enemies(room)
		var actual_ids:Array=[]
		for profile in profiles:
			actual_ids.append(str(profile.get("id","")))
		_check(actual_ids==expected_ids,"Catacomb Room %d matches the fixed encounter membership contract"%room)
	_check(Act0Contract.catacomb_encounter_ids(5).size()==2,"fixed Room 5 contract remains the authored 1v2")
	_check(not Act0Contract.can_start_exterior_encounter("unknown_enemy",[],false),"unknown exterior encounter IDs are rejected by the fixed contract")

func _test_director_route_contract()->void:
	var d:=Chapter00Director.new()
	_check(d.current_route()=="awakening" and d.current_cell=="CEM_01","Chapter 0 Director starts at awakening/Cemetery cell")
	d.mark_exterior_encounter_cleared("hound")
	_check(d.current_route()=="ruins" and d.current_cell=="RUIN_01","Hound clear advances exactly to Ruins")
	d.mark_exterior_encounter_cleared("armless")
	_check(d.current_route()=="temple_reveal" and d.current_cell=="TEMPLE_EXT_01","Armless clear advances exactly to Temple reveal")
	d.mark_temple_reveal_seen()
	_check(d.current_route()=="shield_boss","Temple reveal advances exactly to Shield")
	d.mark_exterior_encounter_cleared("shield_boss")
	_check(d.current_route()=="temple_gate","Shield clear advances exactly to Temple gate")

func _test_temple_progression()->void:
	var state:=SaveManager.default_state()
	_check(int(state.silver)==0,"new game starts with zero Silver")
	_check(str(state.act0_stage)=="exterior","new game starts in exterior stage")
	_check(not bool(state.reduced_motion),"Reduced Motion defaults off without affecting gameplay")
	_check(not bool(state.hound_residual_absorbed) and not bool(state.temple_reveal_seen) and not bool(state.faded_sigil_activated),"new game starts before one-shot exterior threshold beats")

	var p:=Act0Progression.new()
	p.restore(state)
	_check(not p.join_covenant(),"Covenant cannot be joined before Temple entry")
	_check(p.mark_hound_residual_absorbed(),"Hound residual absorption is a one-shot exterior beat")
	_check(not p.mark_hound_residual_absorbed(),"Hound residual absorption cannot duplicate")
	_check(p.mark_temple_reveal_seen(),"Temple reveal is a one-shot exterior beat")
	_check(not p.mark_temple_reveal_seen(),"Temple reveal cannot duplicate")
	p.stage=Act0Contract.STAGE_TEMPLE_ENTRY
	_check(not p.join_covenant(),"Covenant remains locked until the Faded Sigil threshold")
	_check(p.activate_faded_sigil(),"Faded Sigil activates once after Shield/Temple threshold")
	_check(not p.activate_faded_sigil(),"Faded Sigil activation cannot duplicate")
	_check(p.join_covenant(),"Covenant joins after the threshold is satisfied")
	_check(p.stage==Act0Contract.STAGE_WEAPON_CHOICE,"Covenant advances to weapon choice")
	_check(p.choose_weapon("sword_shield"),"valid weapon family can be selected")
	_check(not p.choose_weapon("bow"),"weapon choice is irreversible after confirmation")
	_check(not p.can_first_forge(),"forge is blocked without Silver")
	p.silver=1
	var candidate:=p.first_forge_candidate()
	_check(not candidate.is_empty(),"forge candidate exists with one Silver")
	var tampered:=candidate.duplicate(true)
	tampered["level"]=1
	_check(not p.apply_first_forge(tampered),"first forge rejects non-canonical item payloads")
	var injected:=candidate.duplicate(true)
	injected["bonus_power"]=999
	_check(not p.apply_first_forge(injected),"first forge rejects extra injected item fields")
	_check(p.apply_first_forge(candidate),"first forge commits")
	_check(p.silver==0,"first forge debits exactly one Silver")
	_check(p.first_forge_done and p.stage=="catacombs","first forge advances to Catacombs")
	_check(int(p.forged_item.get("level",-1))==0 and not bool(p.forged_item.get("bonus_unlocked",true)),"+0 forge has no bonus")

func _test_all_weapon_families()->void:
	for family_value in Act0Progression.WEAPONS.keys():
		var family:=str(family_value)
		var state:=SaveManager.default_state()
		state.act0_stage=Act0Contract.STAGE_TEMPLE_ENTRY
		state.cleared_encounters=["hound","armless","shield_boss"]
		state.hound_residual_absorbed=true
		state.faded_sigil_activated=true
		state.silver=1
		var p:=Act0Progression.new()
		p.restore(state)
		_check(p.join_covenant(),"%s can join the Covenant path"%family)
		_check(p.choose_weapon(family),"%s can be selected as the irreversible family"%family)
		var candidate:=p.first_forge_candidate()
		_check(str(candidate.get("family",""))==family,"%s creates a matching first-forge candidate"%family)
		_check(p.apply_first_forge(candidate),"%s completes the scripted first forge"%family)
		_check(p.first_forge_done and p.stage=="catacombs","%s reaches Catacombs after forge"%family)
		_check(bool(p.forged_item.get("equipped",false)) and int(p.forged_item.get("level",-1))==0,"%s first item is equipped at +0"%family)

func _test_catacomb_progression()->void:
	var c:=CatacombProgression.new()
	c.restore(SaveManager.default_state())
	_check(c.start() and c.room==1,"Catacombs start at Room 1")
	_check(not c.clear_room(2),"rooms cannot be cleared out of order")
	for room in range(1,5):
		_check(c.clear_room(room),"Room %d clears in order"%room)
	_check(c.room==5,"Room 4 advances to Room 5")
	_check(c.trigger_room5_solo_limit(),"Room 5 first contact triggers solo limit")
	_check(not c.trigger_room5_solo_limit(),"solo limit is one-shot")
	_check(not c.clear_room(5),"Room 5 cannot complete before companion")
	_check(c.unlock_story_summon(),"story companion unlocks after solo limit")
	_check(not c.unlock_story_summon(),"story companion unlock is one-shot")
	_check(c.clear_room(5) and c.complete,"Room 5 rematch completes Act 0")

func _test_catacomb_reentry_contract()->void:
	var expected_ids:={
		0:"temple_entry",
		1:"catacombs_entry",
		2:"cat_r1_skeleton_cleared",
		3:"cat_r2_hound_cleared",
		4:"cat_r3_guard_cleared",
		5:"cat_r4_revenant_cleared"
	}
	for room in range(0,6):
		_check(Act0Contract.catacomb_checkpoint_id(room)==str(expected_ids[room]),"Catacomb Room %d has a fixed resume checkpoint ID"%room)
		if room>0:
			var resume:=Act0Layout.catacomb_room_resume_position(room)
			var trigger:=Act0Layout.catacomb_room_trigger_position(room)
			_check(absf(resume.x)<0.001 and resume.z>trigger.z,"Catacomb Room %d resume anchor remains before its encounter trigger"%room)

	var temple:=Act0Progression.new()
	var cat:=CatacombProgression.new()
	var flow:=Act0Orchestrator.new()
	var state:=SaveManager.default_state()
	state.covenant_joined=true
	state.weapon_family="bow"
	state.first_forge_done=true
	state.forged_item=Act0Progression.canonical_first_forge_item("bow")
	state.act0_stage=Act0Contract.STAGE_CATACOMBS
	state.catacomb_room=3
	temple.restore(state)
	cat.restore(state)
	flow.setup(temple,cat)
	_check(flow.enter_catacombs() and cat.room==3,"re-entering Catacombs preserves the current unfinished Room 3")

	state.act0_stage=Act0Contract.STAGE_ROOM5_REMATCH
	state.catacomb_room=5
	state.room5_solo_limit_seen=true
	state.story_summon_unlocked=true
	state.room5_rematch_ready=true
	flow.restore(state)
	_check(flow.enter_catacombs() and cat.room==5,"Room 5 rematch re-entry preserves Room 5 instead of restarting Catacombs")

func _test_combat_math()->void:
	var base:=CombatResolver.damage(8.0,1.30,4.0)
	var expected:=8.0*1.30*(100.0/104.0)
	_check(absf(base-expected)<0.0001,"damage formula remains deterministic")


func _test_save_recovery()->void:
	var lost_silver:=SaveManager.default_state()
	lost_silver.cleared_encounters=["shield_boss","shield_boss"]
	lost_silver.act0_stage="first_forge"
	lost_silver.covenant_joined=true
	lost_silver.weapon_family="bow"
	lost_silver.silver=0
	var repaired:=SaveManager._migrate(lost_silver)
	_check(repaired.cleared_encounters.count("shield_boss")==1,"save migration deduplicates reward ledger")
	_check(int(repaired.silver)>=1 and repaired.act0_stage=="first_forge","pre-forge Silver is repaired instead of soft-locking")

	var broken_forge:=SaveManager.default_state()
	broken_forge.cleared_encounters=["shield_boss"]
	broken_forge.covenant_joined=true
	broken_forge.weapon_family="two_hand_axe"
	broken_forge.first_forge_done=true
	broken_forge.forged_item={"family":"bow","equipped":true}
	broken_forge.silver=0
	broken_forge.catacomb_room=4
	var rollback:=SaveManager._migrate(broken_forge)
	_check(not rollback.first_forge_done and rollback.act0_stage=="first_forge","invalid committed forge rolls back to first_forge")
	_check(int(rollback.silver)>=1 and int(rollback.catacomb_room)==0,"invalid forge refunds progression currency and Catacomb state")

	var impossible_story:=SaveManager.default_state()
	impossible_story.story_summon_unlocked=true
	impossible_story.room5_rematch_ready=true
	var story_repair:=SaveManager._migrate(impossible_story)
	_check(not story_repair.story_summon_unlocked and int(story_repair.catacomb_room)==0,"story summon cannot survive without Covenant/forge chain")

	var future_clear:=SaveManager.default_state()
	future_clear.cleared_encounters=["cat_r4_revenant","unknown_injected_enemy"]
	var future_clear_repair:=SaveManager._migrate(future_clear)
	_check("cat_r4_revenant" not in future_clear_repair.cleared_encounters,"future Catacomb clear ID cannot survive without room progress")
	_check("unknown_injected_enemy" not in future_clear_repair.cleared_encounters,"unknown encounter IDs are removed from the Act 0 save ledger")

	var room3_future_clear:=SaveManager.default_state()
	room3_future_clear.cleared_encounters=["hound","armless","shield_boss","cat_r5_skeleton_a","cat_r4_revenant"]
	room3_future_clear.covenant_joined=true
	room3_future_clear.weapon_family="bow"
	room3_future_clear.first_forge_done=true
	room3_future_clear.forged_item=Act0Progression.canonical_first_forge_item("bow")
	room3_future_clear.catacomb_room=3
	room3_future_clear.act0_stage=Act0Contract.STAGE_CATACOMBS
	var room3_ledger:=SaveManager._migrate(room3_future_clear)
	_check("cat_r1_skeleton" in room3_ledger.cleared_encounters and "cat_r2_hound" in room3_ledger.cleared_encounters,"Room 3 reconstructs exactly the two completed Catacomb fights")
	_check("cat_r3_guard" not in room3_ledger.cleared_encounters and "cat_r4_revenant" not in room3_ledger.cleared_encounters and "cat_r5_skeleton_a" not in room3_ledger.cleared_encounters,"future Catacomb clear IDs cannot skip the current or later rooms")

	var late_room:=SaveManager.default_state()
	late_room.cleared_encounters=["shield_boss"]
	late_room.covenant_joined=true
	late_room.weapon_family="sword_shield"
	late_room.first_forge_done=true
	late_room.forged_item={"id":"shadow_sword_shield_01","family":"sword_shield","equipped":true,"level":0,"bonus_unlocked":false}
	late_room.catacomb_room=5
	var ledger:=SaveManager._migrate(late_room)
	_check("cat_r1_skeleton" in ledger.cleared_encounters and "cat_r4_revenant" in ledger.cleared_encounters,"room progress rebuilds missing encounter visual ledger")
	_check(int(ledger.route_index)==Chapter00Director.ROUTE.size()-1,"Temple/Catacomb progress repairs exterior route index")
	_check("hound" in ledger.cleared_encounters and "armless" in ledger.cleared_encounters and "shield_boss" in ledger.cleared_encounters,"later progress repairs the complete mandatory exterior encounter chain")
	_check(bool(ledger.hound_residual_absorbed) and bool(ledger.temple_reveal_seen) and bool(ledger.faded_sigil_activated),"later progress repairs one-shot exterior threshold invariants")

	var legacy:=SaveManager.default_state()
	legacy.version=4
	legacy.erase("hound_residual_absorbed")
	legacy.erase("temple_reveal_seen")
	legacy.erase("faded_sigil_activated")
	legacy.cleared_encounters=["shield_boss"]
	legacy.act0_stage=Act0Contract.STAGE_TEMPLE_ENTRY
	legacy.silver=1
	var legacy_resume:=SaveManager._migrate(legacy)
	_check(bool(legacy_resume.hound_residual_absorbed) and bool(legacy_resume.temple_reveal_seen) and bool(legacy_resume.faded_sigil_activated),"v4 saves migrate forward without replaying newly persisted one-shot beats")
	_check("hound" in legacy_resume.cleared_encounters and "armless" in legacy_resume.cleared_encounters,"v4 Shield progress reconstructs skipped exterior prerequisites")


	var malformed_flags:=SaveManager.default_state()
	malformed_flags.covenant_joined="false"
	malformed_flags.first_forge_done=1
	malformed_flags.story_summon_unlocked="true"
	malformed_flags.room5_rematch_ready=1
	malformed_flags.act0_complete="false"
	malformed_flags.reduced_motion="true"
	var malformed_recovery:=SaveManager._migrate(malformed_flags)
	_check(typeof(malformed_recovery.covenant_joined)==TYPE_BOOL and typeof(malformed_recovery.first_forge_done)==TYPE_BOOL,"migrated Covenant/forge flags are canonical booleans")
	_check(typeof(malformed_recovery.story_summon_unlocked)==TYPE_BOOL and typeof(malformed_recovery.room5_rematch_ready)==TYPE_BOOL and typeof(malformed_recovery.act0_complete)==TYPE_BOOL,"migrated late Act 0 flags are canonical booleans")
	_check(malformed_recovery.covenant_joined==false and malformed_recovery.first_forge_done==false,"non-boolean Covenant/forge flags cannot unlock progression")
	_check(malformed_recovery.story_summon_unlocked==false and malformed_recovery.room5_rematch_ready==false and malformed_recovery.act0_complete==false,"non-boolean late Act 0 flags are rejected")
	_check(typeof(malformed_recovery.reduced_motion)==TYPE_BOOL and malformed_recovery.reduced_motion==false,"non-boolean settings flags fall back to canonical false")

	var injected_forge:=SaveManager.default_state()
	injected_forge.cleared_encounters=["hound","armless","shield_boss"]
	injected_forge.covenant_joined=true
	injected_forge.weapon_family="bow"
	injected_forge.first_forge_done=true
	injected_forge.forged_item={"id":"shadow_bow_01","family":"bow","level":0,"bonus_unlocked":false,"equipped":true,"bonus_power":999}
	injected_forge.silver=0
	var injected_recovery:=SaveManager._migrate(injected_forge)
	_check(injected_recovery.first_forge_done==false and str(injected_recovery.act0_stage)==Act0Contract.STAGE_FIRST_FORGE,"save migration rolls back forged items with injected fields")
	_check(int(injected_recovery.silver)==1,"invalid injected forge restores the one scripted Silver")

	var bad_cat:=SaveManager.default_state()
	bad_cat.cleared_encounters=["hound","armless","shield_boss"]
	bad_cat.temple_reveal_seen=true
	bad_cat.faded_sigil_activated=true
	bad_cat.covenant_joined=true
	bad_cat.weapon_family="bow"
	bad_cat.first_forge_done=true
	bad_cat.forged_item={"id":"shadow_bow_01","family":"bow","level":0,"bonus_unlocked":false,"equipped":true}
	bad_cat.catacomb_room=3
	bad_cat.act0_stage=Act0Contract.STAGE_CATACOMBS
	bad_cat.checkpoint_position=[999.0,999.0,999.0]
	var cat_recovery:=SaveManager._migrate(bad_cat)
	var room3_resume:=Act0Layout.catacomb_room_resume_position(3)
	_check(cat_recovery.checkpoint_position==SaveManager._vector3_array(room3_resume) and str(cat_recovery.checkpoint)=="cat_r2_hound_cleared","corrupt Catacomb checkpoint recovers immediately before the current room")

	var bad_temple:=SaveManager.default_state()
	bad_temple.cleared_encounters=["hound","armless","shield_boss"]
	bad_temple.temple_reveal_seen=true
	bad_temple.act0_stage=Act0Contract.STAGE_TEMPLE_ENTRY
	bad_temple.silver=1
	bad_temple.checkpoint_position=[0.0,0.9,8.0]
	var temple_recovery:=SaveManager._migrate(bad_temple)
	var sigil_recovery:=Vector3(Act0Layout.FADED_SIGIL_TRIGGER.x,0.9,Act0Layout.FADED_SIGIL_TRIGGER.z)
	_check(temple_recovery.checkpoint_position==SaveManager._vector3_array(sigil_recovery),"pre-Sigil Temple state cannot resume outside the threshold zone")

	var valid_cat:=bad_cat.duplicate(true)
	valid_cat.checkpoint="cat_r2_hound_cleared"
	valid_cat.checkpoint_position=[0.0,0.9,-150.0]
	var valid_recovery:=SaveManager._migrate(valid_cat)
	_check(valid_recovery.checkpoint_position==[0.0,0.9,-150.0] and str(valid_recovery.checkpoint)=="cat_r2_hound_cleared","valid in-stage checkpoint coordinates and IDs are preserved")

	var wall_temple:=bad_temple.duplicate(true)
	wall_temple.faded_sigil_activated=true
	wall_temple.checkpoint="temple_entry"
	wall_temple.checkpoint_position=[14.0,0.9,-78.0]
	var wall_temple_recovery:=SaveManager._migrate(wall_temple)
	_check(wall_temple_recovery.checkpoint_position==SaveManager._vector3_array(Act0Layout.TEMPLE_ENTRY_CHECKPOINT),"Temple checkpoint outside walkable nave width is relocated to the safe entry anchor")

	var wall_cat:=bad_cat.duplicate(true)
	wall_cat.checkpoint="cat_r2_hound_cleared"
	wall_cat.checkpoint_position=[5.8,0.9,-150.0]
	var wall_cat_recovery:=SaveManager._migrate(wall_cat)
	_check(wall_cat_recovery.checkpoint_position==SaveManager._vector3_array(room3_resume),"Catacomb checkpoint inside side-wall geometry is relocated before the current room")

	var bad_checkpoint_id:=bad_cat.duplicate(true)
	bad_checkpoint_id.checkpoint="room5_return"
	bad_checkpoint_id.checkpoint_position=[0.0,0.9,-150.0]
	var id_recovery:=SaveManager._migrate(bad_checkpoint_id)
	_check(str(id_recovery.checkpoint)=="cat_r2_hound_cleared" and id_recovery.checkpoint_position==SaveManager._vector3_array(room3_resume),"checkpoint ID from another Act 0 stage cannot survive migration")


	var wrong_room_position:=bad_cat.duplicate(true)
	wrong_room_position.checkpoint="cat_r2_hound_cleared"
	wrong_room_position.checkpoint_position=[0.0,0.9,-171.0]
	var wrong_room_recovery:=SaveManager._migrate(wrong_room_position)
	_check(wrong_room_recovery.checkpoint_position==SaveManager._vector3_array(room3_resume),"Room 3 checkpoint cannot carry a physically valid Room 5 position")

func _test_resume_transition_matrix()->void:
	var exterior:=SaveManager._migrate(SaveManager.default_state())
	_check(str(exterior.act0_stage)=="exterior","resume preserves fresh exterior state")

	var temple:=SaveManager.default_state()
	temple.cleared_encounters=["shield_boss"]
	temple.act0_stage="temple_entry"
	temple.silver=1
	var temple_resume:=SaveManager._migrate(temple)
	_check(str(temple_resume.act0_stage)=="temple_entry" and int(temple_resume.silver)>=1,"resume preserves Temple entry and first Silver")

	var covenant:=temple.duplicate(true)
	covenant.faded_sigil_activated=true
	covenant.covenant_joined=true
	covenant.act0_stage="weapon_choice"
	var covenant_resume:=SaveManager._migrate(covenant)
	_check(str(covenant_resume.act0_stage)=="weapon_choice" and bool(covenant_resume.covenant_joined),"resume preserves Forgotten Covenant handoff")

	var weapon:=covenant.duplicate(true)
	weapon.weapon_family="bow"
	weapon.act0_stage="first_forge"
	var weapon_resume:=SaveManager._migrate(weapon)
	_check(str(weapon_resume.act0_stage)=="first_forge" and str(weapon_resume.weapon_family)=="bow","resume preserves irreversible weapon selection before forge")

	var post_forge:=weapon.duplicate(true)
	post_forge.first_forge_done=true
	post_forge.forged_item={"id":"shadow_bow_01","family":"bow","level":0,"bonus_unlocked":false,"equipped":true}
	post_forge.silver=0
	post_forge.catacomb_room=0
	post_forge.act0_stage=Act0Contract.STAGE_CATACOMBS
	post_forge.checkpoint="temple_entry"
	post_forge.checkpoint_position=SaveManager._vector3_array(Act0Layout.TEMPLE_ENTRY_CHECKPOINT)
	var post_forge_resume:=SaveManager._migrate(post_forge)
	_check(int(post_forge_resume.catacomb_room)==0 and str(post_forge_resume.checkpoint)=="temple_entry","committed forge does not auto-enter Catacomb Room 1")
	_check(post_forge_resume.checkpoint_position==SaveManager._vector3_array(Act0Layout.TEMPLE_ENTRY_CHECKPOINT),"post-forge resume remains safely inside the Temple until physical Catacomb entry")

	var forged:=post_forge.duplicate(true)
	forged.catacomb_room=1
	forged.checkpoint="catacombs_entry"
	forged.checkpoint_position=SaveManager._vector3_array(Act0Layout.CATACOMB_ENTRY_CHECKPOINT)
	var forged_resume:=SaveManager._migrate(forged)
	_check(str(forged_resume.act0_stage)=="catacombs" and bool(forged_resume.first_forge_done) and int(forged_resume.catacomb_room)==1,"physical Catacomb entry starts Room 1 and preserves committed forge/equip")

	for room in range(1,6):
		var room_state:=forged.duplicate(true)
		room_state.catacomb_room=room
		var room_resume:=SaveManager._migrate(room_state)
		_check(str(room_resume.act0_stage)=="catacombs" and int(room_resume.catacomb_room)==room,"resume preserves Catacomb Room %d progress"%room)

	var room5_return:=forged.duplicate(true)
	room5_return.catacomb_room=5
	room5_return.room5_solo_limit_seen=true
	room5_return.act0_stage="room5_return"
	var return_resume:=SaveManager._migrate(room5_return)
	_check(str(return_resume.act0_stage)=="room5_return" and not bool(return_resume.story_summon_unlocked),"resume preserves scripted solo-limit return before summon")

	var rematch:=room5_return.duplicate(true)
	rematch.story_summon_unlocked=true
	rematch.room5_rematch_ready=true
	rematch.act0_stage="room5_rematch"
	var rematch_resume:=SaveManager._migrate(rematch)
	_check(str(rematch_resume.act0_stage)=="room5_rematch" and bool(rematch_resume.room5_rematch_ready),"resume preserves first story summon and rematch readiness")
	var team:=TeamState.new()
	team.restore(rematch_resume)
	_check(StoryCompanion.ID in team.active_ids(),"resume restores the first story team slot")
	team.restore(SaveManager.default_state())
	_check(StoryCompanion.ID not in team.active_ids(),"team restore is idempotent and relocks slot 2 for an earlier state")

	var complete:=rematch.duplicate(true)
	complete.act0_complete=true
	complete.act0_stage="act0_complete"
	var complete_resume:=SaveManager._migrate(complete)
	_check(str(complete_resume.act0_stage)=="act0_complete" and bool(complete_resume.act0_complete),"resume preserves final Act 0 completion")
	_check("cat_r5_skeleton_a" in complete_resume.cleared_encounters and "cat_r5_skeleton_b" in complete_resume.cleared_encounters,"completed resume rebuilds Room 5 clear ledger")

func _test_room5_limit_contract()->void:
	var profiles:=CatacombEncounterPlan.enemies(5)
	_check(profiles.size()==2,"Room 5 remains a two-enemy encounter")

	var clean_a2:=MultiEnemyEncounter.new()
	clean_a2.set_loadout("sword_shield")
	clean_a2.start(profiles,false,false)
	var hp_before:=clean_a2.shadow_hp
	clean_a2.shadow_action("INVALID")
	_check(clean_a2.rounds==0 and clean_a2.shadow_hp==hp_before and not clean_a2.fray,"Room 5 rejects invalid combat commands without mutating state")
	clean_a2.shadow_action("A2")
	var expected_hp:=20.0-(2.6*(1.0-0.30))-2.6
	_check(absf(clean_a2.shadow_hp-expected_hp)<0.0001,"Room 5 clean A2 applies Veil to the first enemy response")
	_check(clean_a2.a2_cd==3,"Room 5 clean A2 enters configured cooldown without requiring prior Fray")
	var rounds_after_a2:=clean_a2.rounds
	clean_a2.shadow_action("A2")
	_check(clean_a2.rounds==rounds_after_a2,"Room 5 blocks A2 while cooldown is active")

	var empty:=MultiEnemyEncounter.new()
	empty.start([],false,false)
	_check(not empty.active,"Room 5 combat refuses an empty encounter plan")

	var multi:=MultiEnemyEncounter.new()
	multi.set_loadout("two_hand_axe")
	multi.start(profiles,false,true)
	multi.shadow_action("A2")
	_check(multi.active and not multi._all_dead(),"solo-limit attempt cannot be won on the first action")
	multi.shadow_action("A1")
	_check(multi.limit_reached and not multi.active,"solo-limit resolves deterministically after the authored round limit")

	var lethal_profiles:=CatacombEncounterPlan.enemies(5)
	for enemy in lethal_profiles:
		enemy["damage"]=999.0
	var damage_proof:=MultiEnemyEncounter.new()
	damage_proof.start(lethal_profiles,false,true)
	damage_proof.shadow_action("A1")
	_check(damage_proof.active and damage_proof.rounds==1 and damage_proof.shadow_hp>=1.0,"solo-limit cannot end one round early because of future damage tuning")
	damage_proof.shadow_action("A1")
	_check(damage_proof.limit_reached and damage_proof.rounds==2,"solo-limit timing remains the fixed two-round story contract under lethal tuning")
