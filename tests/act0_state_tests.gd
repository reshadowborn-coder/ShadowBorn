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
	print("Act 0 state tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_temple_progression()->void:
	var state:=SaveManager.default_state()
	_check(int(state.silver)==0,"new game starts with zero Silver")
	_check(str(state.act0_stage)=="exterior","new game starts in exterior stage")

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
