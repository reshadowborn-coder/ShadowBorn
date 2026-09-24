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
	_test_temple_progression()
	_test_catacomb_progression()
	_test_combat_math()
	_test_save_recovery()
	_test_room5_limit_contract()
	print("Act 0 state tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_temple_progression()->void:
	var state:=SaveManager.default_state()
	_check(int(state.silver)==0,"new game starts with zero Silver")
	_check(str(state.act0_stage)=="exterior","new game starts in exterior stage")
	_check(not bool(state.reduced_motion),"Reduced Motion defaults off without affecting gameplay")

	var p:=Act0Progression.new()
	p.restore(state)
	_check(not p.join_covenant(),"Covenant cannot be joined before Temple entry")
	p.stage="temple_entry"
	_check(p.join_covenant(),"Covenant joins at Temple entry")
	_check(p.stage=="weapon_choice","Covenant advances to weapon choice")
	_check(p.choose_weapon("sword_shield"),"valid weapon family can be selected")
	_check(not p.choose_weapon("bow"),"weapon choice is irreversible after confirmation")
	_check(not p.can_first_forge(),"forge is blocked without Silver")
	p.silver=1
	var candidate:=p.first_forge_candidate()
	_check(not candidate.is_empty(),"forge candidate exists with one Silver")
	_check(p.apply_first_forge(candidate),"first forge commits")
	_check(p.silver==0,"first forge debits exactly one Silver")
	_check(p.first_forge_done and p.stage=="catacombs","first forge advances to Catacombs")
	_check(int(p.forged_item.get("level",-1))==0 and not bool(p.forged_item.get("bonus_unlocked",true)),"+0 forge has no bonus")

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

	var late_room:=SaveManager.default_state()
	late_room.cleared_encounters=["shield_boss"]
	late_room.covenant_joined=true
	late_room.weapon_family="sword_shield"
	late_room.first_forge_done=true
	late_room.forged_item={"family":"sword_shield","equipped":true,"level":0,"bonus_unlocked":false}
	late_room.catacomb_room=5
	var ledger:=SaveManager._migrate(late_room)
	_check("cat_r1_skeleton" in ledger.cleared_encounters and "cat_r4_revenant" in ledger.cleared_encounters,"room progress rebuilds missing encounter visual ledger")
	_check(int(ledger.route_index)==Chapter00Director.ROUTE.size()-1,"Temple/Catacomb progress repairs exterior route index")

func _test_room5_limit_contract()->void:
	var profiles:=CatacombEncounterPlan.enemies(5)
	_check(profiles.size()==2,"Room 5 remains a two-enemy encounter")
	var multi:=MultiEnemyEncounter.new()
	multi.set_loadout("two_hand_axe")
	multi.start(profiles,false,true)
	multi.shadow_action("A2")
	_check(multi.active and not multi._all_dead(),"solo-limit attempt cannot be won on the first action")
