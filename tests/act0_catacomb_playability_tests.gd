extends SceneTree

const ACTION_WAIT:=0.28
const MAX_TURNS:=12
var failures:=0

func _init()->void:
	call_deferred("_run")

func _check(condition:bool,message:String)->void:
	if not condition:
		failures+=1
		push_error("FAIL: "+message)

func _run()->void:
	for family_value in Act0Contract.WEAPON_FAMILIES:
		var family:=str(family_value)
		for room in range(1,5):
			await _probe_single_room(family,room)
		await _probe_room5_rematch(family)
	print("Act 0 Catacomb playability probe complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _probe_single_room(family:String,room:int)->void:
	var profiles:=CatacombEncounterPlan.enemies(room)
	_check(profiles.size()==1,"%s Room %d has exactly one authored 1v1 enemy"%[family,room])
	if profiles.size()!=1:
		return
	var controller:=EncounterController.new()
	root.add_child(controller)
	controller.set_reduced_motion(true)
	controller.set_loadout(family)
	controller.start_encounter(str(profiles[0].id),profiles[0])
	var turns:=0
	while controller.active and turns<MAX_TURNS:
		var skill:="A2" if int(controller.shadow.get("a2_cd",0))==0 else "A1"
		controller.shadow_action(skill)
		await create_timer(ACTION_WAIT).timeout
		turns+=1
	_check(not controller.active and float(controller.enemy.get("hp",1.0))<=0.0,
		"%s can clear Catacomb Room %d with the baseline deterministic strategy"%[family,room])
	_check(float(controller.shadow.get("hp",0.0))>0.0,
		"%s survives Catacomb Room %d baseline clear"%[family,room])
	controller.queue_free()
	await process_frame

func _probe_room5_rematch(family:String)->void:
	var profiles:=CatacombEncounterPlan.enemies(5)
	var combat:=MultiEnemyEncounter.new()
	root.add_child(combat)
	combat.set_loadout(family)
	combat.start(profiles,true,false)
	var turns:=0
	while combat.active and turns<MAX_TURNS:
		var skill:="A2" if combat.a2_cd==0 else "A1"
		combat.shadow_action(skill)
		turns+=1
		if combat.active and combat.action_locked:
			await create_timer(MultiEnemyEncounter.ACTION_LOCK_SECONDS+.03).timeout
	_check(not combat.active and combat._all_dead(),
		"%s can resolve the Room 5 story-companion rematch"%family)
	_check(combat.shadow_hp>0.0,
		"%s survives the Room 5 story-companion rematch"%family)
	combat.queue_free()
	await process_frame
