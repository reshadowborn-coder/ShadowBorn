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
	var controller:=EncounterController.new()
	root.add_child(controller)
	controller.set_loadout("sword_shield")
	controller.set_reduced_motion(true)
	var poison:=Dictionary(SewerEncounterPlan.PROFILES["a1_r2_poison_rat"]).duplicate(true)
	_check(controller.start_encounter("a1_r2_poison_rat",poison),"Poison Rat starts in generic encounter controller")
	controller.shadow_action("A1")
	await create_timer(.24).timeout
	_check(int(controller.shadow.get("poison_turns",0))==2,"Poison Rat attack applies two poison turns")
	_check(absf(float(controller.shadow.get("poison_damage",0.0))-.75)<.001,"Poison Rat applies the authored poison strength")
	var hp_after_application:=float(controller.shadow.get("hp",0.0))
	controller.shadow_action("A2")
	await create_timer(.18).timeout
	_check(float(controller.shadow.get("hp",0.0))<=hp_after_application-.74,"poison ticks before the next Shadow action")
	_check(int(controller.shadow.get("poison_turns",0))==1,"poison duration decrements after a tick")
	controller.queue_free()
	await process_frame
	print("Act 1 poison behavior tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)