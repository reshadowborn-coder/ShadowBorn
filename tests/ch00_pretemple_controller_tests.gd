extends SceneTree

const TOL := 0.00002
const STEP_WAIT := 0.90
const WATCHDOG_SECONDS := 8.0

var failures := 0
var finished := false

func _init() -> void:
	var watchdog := create_timer(WATCHDOG_SECONDS)
	watchdog.timeout.connect(_watchdog_timeout)
	call_deferred("_run")

func _watchdog_timeout() -> void:
	if finished:
		return
	push_error("FAIL: pre-Temple controller integration watchdog expired")
	quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _close(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= TOL

func _controller() -> EncounterController:
	var controller := EncounterController.new()
	root.add_child(controller)
	return controller

func _destroy(controller: EncounterController) -> void:
	controller.active = false
	controller.queue_free()
	await process_frame

func _index(order: Array[String], event_name: String) -> int:
	return order.find(event_name)

func _run() -> void:
	_test_presentation_contract()
	await _test_hound_adapter()
	await _test_reduced_motion_order()
	await _test_armless_adapter()
	await _test_shield_adapter()
	_test_post_forge_separation()
	finished = true
	print("Chapter 0 pre-Temple controller integration complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _test_presentation_contract() -> void:
	var a1: Dictionary = CombatPresentationContract.shadow_timing("A1",false)
	var a2: Dictionary = CombatPresentationContract.shadow_timing("A2",false)
	var enemy_hit: Dictionary = CombatPresentationContract.enemy_timing("BITE",false)
	var reduced: Dictionary = CombatPresentationContract.shadow_timing("A2",true)
	_check(_close(float(a1.contact),0.19) and _close(float(a1.recovery_end),0.34),"A1 contact/recovery contract is explicit")
	_check(_close(float(a2.contact),0.17) and _close(float(a2.recovery_end),0.32),"A2 contact/recovery contract is explicit")
	_check(_close(float(enemy_hit.contact),0.18) and _close(float(enemy_hit.recovery_end),0.30),"enemy contact/recovery contract is explicit")
	_check(_close(float(reduced.contact),0.0) and _close(float(reduced.recovery_end),0.08),"reduced-motion contract preserves immediate contact with bounded recovery")

func _test_hound_adapter() -> void:
	var controller := _controller()
	var order: Array[String] = []
	var enemy_contact_seen := false
	var shadow_contact_seen := false
	var unlock_seen := false
	controller.shadow_attack_presented.connect(func(_skill:String,_damage:float,_guarded:bool)->void:
		order.append("shadow_present")
	)
	controller.enemy_beat_presented.connect(func(_action:String,_damage:float)->void:
		order.append("enemy_present")
	)
	controller.combat_state_changed.connect(func(state:Dictionary)->void:
		var s: Dictionary = state.get("shadow",{})
		var e: Dictionary = state.get("enemy",{})
		var locked := bool(state.get("action_locked",false))
		if locked and not enemy_contact_seen and float(e.get("hp",105.0)) < 105.0:
			enemy_contact_seen = true
			order.append("enemy_hp_contact")
		if locked and not shadow_contact_seen and float(s.get("hp",80.0)) < 80.0:
			shadow_contact_seen = true
			order.append("shadow_hp_contact")
		if not locked and shadow_contact_seen and not unlock_seen:
			unlock_seen = true
			order.append("unlock")
	)

	controller.start_encounter("hound",{"hp":1.0,"def":0.0,"damage":999.0})
	_check(controller.pre_temple_mode,"Hound routes through pre-Temple deterministic model")
	_check(_close(float(controller.shadow.hp),80.0),"Hound starts Shadow at 80 HP")
	_check(_close(float(controller.enemy.hp),105.0),"Hound ignores obsolete placeholder HP")
	_check(not bool(controller.enemy.get("guard",false)),"Hound D1 is not guarded")

	controller.shadow_action("A2")
	await create_timer(STEP_WAIT).timeout
	_check(_close(float(controller.shadow.hp),61.8474576),"Hound A2->Bite Shadow HP matches fixture")
	_check(_close(float(controller.enemy.hp),78.5185185),"Hound A2 damage matches fixture")
	_check(int(controller.shadow.a2_cd)==3,"Hound A2 cooldown is 3 blocked opportunities")

	print("Hound presentation order: "+str(order))
	var p0 := _index(order,"shadow_present")
	var p1 := _index(order,"enemy_hp_contact")
	var p2 := _index(order,"enemy_present")
	var p3 := _index(order,"shadow_hp_contact")
	var p4 := _index(order,"unlock")
	_check(p0 >= 0 and p0 < p1 and p1 < p2 and p2 < p3 and p3 < p4,
		"Hound presentation order is shadow-present -> enemy-HP contact -> enemy-present -> Shadow-HP contact -> unlock")

	controller.shadow_action("A1")
	await create_timer(STEP_WAIT).timeout
	_check(str(controller.enemy.get("intent",""))=="RUSH PREP","Hound exposes Rush Prep before D3 command")
	_check(int(controller.shadow.a2_cd)==2,"Hound cooldown decrements after blocked A1 opportunity")
	await _destroy(controller)

func _test_reduced_motion_order() -> void:
	var controller := _controller()
	controller.set_reduced_motion(true)
	var order: Array[String] = []
	var enemy_contact_seen := false
	var shadow_contact_seen := false
	var unlock_seen := false
	controller.shadow_attack_presented.connect(func(_skill:String,_damage:float,_guarded:bool)->void:
		order.append("shadow_present")
	)
	controller.enemy_beat_presented.connect(func(_action:String,_damage:float)->void:
		order.append("enemy_present")
	)
	controller.combat_state_changed.connect(func(state:Dictionary)->void:
		var s: Dictionary = state.get("shadow",{})
		var e: Dictionary = state.get("enemy",{})
		var locked := bool(state.get("action_locked",false))
		if locked and not enemy_contact_seen and float(e.get("hp",105.0)) < 105.0:
			enemy_contact_seen = true
			order.append("enemy_hp_contact")
		if locked and not shadow_contact_seen and float(s.get("hp",80.0)) < 80.0:
			shadow_contact_seen = true
			order.append("shadow_hp_contact")
		if not locked and shadow_contact_seen and not unlock_seen:
			unlock_seen = true
			order.append("unlock")
	)

	controller.start_encounter("hound",{})
	controller.shadow_action("A2")
	await create_timer(0.25).timeout
	_check(_close(float(controller.shadow.hp),61.8474576),"Reduced motion preserves Hound semantic result")
	_check(not controller.action_locked,"Reduced motion reaches same unlocked decision state")

	print("Reduced presentation order: "+str(order))
	var p0 := _index(order,"shadow_present")
	var p1 := _index(order,"enemy_hp_contact")
	var p2 := _index(order,"enemy_present")
	var p3 := _index(order,"shadow_hp_contact")
	var p4 := _index(order,"unlock")
	_check(p0 >= 0 and p0 < p1 and p1 < p2 and p2 < p3 and p3 < p4,
		"Reduced motion preserves semantic presentation ordering")
	await _destroy(controller)

func _test_armless_adapter() -> void:
	var controller := _controller()
	controller.start_encounter("armless",{"hp":1.0,"def":0.0,"damage":999.0})
	_check(controller.pre_temple_mode,"Armless routes through pre-Temple deterministic model")
	_check(_close(float(controller.shadow.hp),60.0),"Armless starts Shadow at scripted 60 HP")
	_check(_close(float(controller.enemy.hp),82.0),"Armless uses authoritative 82 HP")

	controller.shadow_action("A2")
	await create_timer(STEP_WAIT).timeout
	_check(_close(float(controller.shadow.hp),45.420339),"Armless A2->Lunge Shadow HP matches fixture")
	_check(_close(float(controller.enemy.hp),56.912281),"Armless A2 damage matches fixture")
	await _destroy(controller)

func _test_shield_adapter() -> void:
	var controller := _controller()
	controller.start_encounter("shield_boss",{"hp":1.0,"def":0.0,"damage":999.0})
	_check(controller.pre_temple_mode,"Shield Boss routes through pre-Temple deterministic model")
	_check(bool(controller.enemy.get("guard",false)),"Shield Guard is authoritative and visible at D1")
	_check(_close(float(controller.enemy.hp),87.0),"Shield diagnostic profile uses 87 HP")

	controller.shadow_action("A1")
	await create_timer(STEP_WAIT).timeout
	_check(_close(float(controller.shadow.hp),60.0),"Shield D1 brace beat deals no damage")
	_check(_close(float(controller.enemy.hp),79.6666667),"Shield guarded A1 damage matches fixture")
	_check(not bool(controller.enemy.get("guard",false)),"Shield Guard exits before D2 command")
	_check(bool(controller.shadow.get("fray",false)),"Shield A1 leaves Fray setup active")
	await _destroy(controller)

func _test_post_forge_separation() -> void:
	var controller := _controller()
	controller.set_loadout("bow")
	controller.start_encounter("cat_r1_skeleton",{"hp":10.0,"def":2.0,"damage":1.0})
	_check(not controller.pre_temple_mode,"post-forge Catacomb encounter stays on weapon-loadout path")
	_check(_close(float(controller.shadow.hp),20.0),"post-forge test profile remains isolated from pre-Temple 80/60 HP contract")
	controller.active = false
	controller.queue_free()
