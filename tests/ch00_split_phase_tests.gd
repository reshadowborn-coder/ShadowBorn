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

func _close(a:float,b:float)->bool:
	return absf(a-b)<=0.00001

func _run()->void:
	_test_case(
		"ENC_HOUND_A1A2_V01",
		0.15,
		["A2","A1","A1","A1","A2"],
		"Hound observable"
	)
	_test_case(
		"ENC_ARMLESS_A1A2_V01",
		0.15,
		["A2","A1","A1","A1"],
		"Armless consolidation"
	)
	_test_case(
		"ENC_SHIELD_BRACE_V02_HP87_ATK20",
		0.15,
		["A1","A2","A1","A1","A1"],
		"Shield HOLD V15"
	)
	_test_case(
		"ENC_SHIELD_BRACE_V02_HP87_ATK20",
		0.20,
		["A1","A2","A1","A1","A1"],
		"Shield HOLD V20"
	)
	_test_independent_opportunities()
	_test_enemy_phase_visibility_boundary()
	print("Chapter 0 split-phase tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_case(script_id:String,veil:float,actions:Array,label:String)->void:
	var atomic:=Ch00CombatModel.new()
	var phased:=Ch00CombatModel.new()
	_check(atomic.setup(script_id,veil),label+" atomic setup")
	_check(phased.setup(script_id,veil),label+" phased setup")

	for raw_action in actions:
		if str(atomic.snapshot().get("terminal","CONTINUE"))!="CONTINUE":
			break
		var action:=str(raw_action)
		var atomic_result:Dictionary=atomic.step(action)
		var phase_one:Dictionary=phased.begin_shadow_action(action)
		_check(not phase_one.has("error"),label+" begin "+action+" succeeds")
		if phase_one.has("error"):
			return

		var phased_result:Dictionary
		if str(phase_one.get("terminal","CONTINUE"))=="WIN":
			phased_result=phase_one.duplicate(true)
		else:
			var second:Dictionary=phased.resolve_enemy_opportunity()
			_check(not second.has("error"),label+" enemy opportunity resolves")
			phased_result=_merge_phases_for_atomic_compare(phase_one,second)

		_compare_result(atomic_result,phased_result,label+" "+action)
		_compare_snapshot(atomic.snapshot(),phased.snapshot(),label+" snapshot")

func _compare_result(a:Dictionary,b:Dictionary,label:String)->void:
	for key in [
		"encounter_script_id","decision","visible_state","action","enemy_action","terminal",
		"a2_cd_before","a2_cd_after","fray_before","fray_after","veil_before","veil_after"
	]:
		_check(a.get(key)==b.get(key),label+" result field "+key+" matches")
	for key in [
		"shadow_hp_before","enemy_hp_before","outgoing_damage","incoming_damage",
		"veil_prevented","shadow_hp_after","enemy_hp_after"
	]:
		_check(_close(float(a.get(key,0.0)),float(b.get(key,0.0))),label+" result float "+key+" matches")
	_check(a.get("post_action_shadow",{})==b.get("post_action_shadow",{}),label+" post-action Shadow projection matches")
	_check(a.get("post_action_enemy",{})==b.get("post_action_enemy",{}),label+" post-action enemy projection matches")

func _compare_snapshot(a:Dictionary,b:Dictionary,label:String)->void:
	_check(str(a.get("terminal",""))==str(b.get("terminal","")),label+" terminal matches")
	_check(int(a.get("decision",-1))==int(b.get("decision",-2)),label+" decision matches")
	_check(int(a.get("enemy_phase",-1))==int(b.get("enemy_phase",-2)),label+" enemy phase matches")
	var ashadow:Dictionary=a.get("shadow",{})
	var bshadow:Dictionary=b.get("shadow",{})
	var aenemy:Dictionary=a.get("enemy",{})
	var benemy:Dictionary=b.get("enemy",{})
	_check(_close(float(ashadow.get("hp",0.0)),float(bshadow.get("hp",0.0))),label+" Shadow HP matches")
	_check(_close(float(aenemy.get("hp",0.0)),float(benemy.get("hp",0.0))),label+" enemy HP matches")
	_check(int(ashadow.get("a2_cd",0))==int(bshadow.get("a2_cd",0)),label+" cooldown matches")
	_check(bool(ashadow.get("fray",false))==bool(bshadow.get("fray",false)),label+" Fray matches")
	_check(_close(float(ashadow.get("veil",0.0)),float(bshadow.get("veil",0.0))),label+" Veil matches")


func _merge_phases_for_atomic_compare(shadow_phase:Dictionary,enemy_phase_result:Dictionary)->Dictionary:
	var out:=shadow_phase.duplicate(true)
	out.erase("phase")
	out.erase("enemy_phase")
	for key in [
		"enemy_action","incoming_damage","veil_prevented","shadow_hp_after",
		"enemy_hp_after","a2_cd_after","fray_after","veil_after","terminal"
	]:
		out[key]=enemy_phase_result.get(key)
	return out

func _test_independent_opportunities()->void:
	var hound:=Ch00CombatModel.new()
	_check(hound.setup("ENC_HOUND_A1A2_V01",0.15),"independent Hound setup")
	var first:Dictionary=hound.begin_shadow_action("A1")
	_check(not first.has("error"),"first Shadow opportunity resolves without forcing enemy response")
	var second:Dictionary=hound.begin_shadow_action("A1")
	_check(not second.has("error"),"second Shadow opportunity can resolve before enemy when Speed grants it")
	var before_enemy:=hound.snapshot()
	_check(int(before_enemy.get("decision",-1))==2,"two Shadow decisions are counted independently")
	_check(int(before_enemy.get("enemy_phase",-1))==0,"enemy phase does not advance from Shadow actions")
	var enemy:Dictionary=hound.resolve_enemy_opportunity()
	_check(not enemy.has("error"),"enemy can resolve its first opportunity after two Shadow opportunities")
	_check(str(enemy.get("enemy_action",""))=="BITE","enemy still executes phase-zero Bite")
	_check(int(hound.snapshot().get("enemy_phase",-1))==1,"enemy phase advances only on enemy opportunity")

	var shield:=Ch00CombatModel.new()
	_check(shield.setup("ENC_SHIELD_BRACE_V02_HP87_ATK20",0.15),"independent Shield setup")
	var shield_one:Dictionary=shield.begin_shadow_action("A1")
	_check(not shield_one.has("error"),"Shield first Shadow opportunity resolves")
	_check(bool((shield.snapshot().get("enemy",{}) as Dictionary).get("guard",false)),"Guard stays authoritative after first Shadow action")
	var shield_two:Dictionary=shield.begin_shadow_action("A1")
	_check(not shield_two.has("error"),"faster Shadow can receive a second action into the same Guard phase")
	_check(bool((shield.snapshot().get("enemy",{}) as Dictionary).get("guard",false)),"Guard remains until enemy BRACE_EXIT opportunity")
	var brace_exit:Dictionary=shield.resolve_enemy_opportunity()
	_check(str(brace_exit.get("enemy_action",""))=="BRACE_EXIT","enemy opportunity resolves BRACE_EXIT")
	_check(not bool((shield.snapshot().get("enemy",{}) as Dictionary).get("guard",false)),"Guard clears only after BRACE_EXIT")

	var veil:=Ch00CombatModel.new()
	_check(veil.setup("ENC_HOUND_A1A2_V01",0.15),"independent Veil setup")
	var a2:Dictionary=veil.begin_shadow_action("A2")
	_check(not a2.has("error") and bool((veil.snapshot().get("shadow",{}) as Dictionary).get("veil",0.0)>0.0),"A2 grants Veil")
	var lap:Dictionary=veil.begin_shadow_action("A1")
	_check(not lap.has("error"),"Shadow can lap before enemy after A2")
	_check(not bool((veil.snapshot().get("shadow",{}) as Dictionary).get("veil",0.0)>0.0),"unconsumed Veil expires at the next Shadow opportunity")
	var bite:Dictionary=veil.resolve_enemy_opportunity()
	_check(_close(float(bite.get("veil_prevented",0.0)),0.0),"expired Veil does not mitigate the delayed enemy hit")

func _test_enemy_phase_visibility_boundary()->void:
	var hound:=Ch00CombatModel.new()
	_check(hound.setup("ENC_HOUND_A1A2_V01",0.15),"visibility Hound setup")
	var d1:Dictionary=hound.step("A1")
	_check(not d1.has("error"),"visibility Hound D1 resolves")
	var d2:Dictionary=hound.begin_shadow_action("A1")
	_check(not d2.has("error"),"visibility Hound D2 Shadow phase resolves")
	var before_prep:Dictionary=hound.snapshot()
	var before_enemy:Dictionary=before_prep.get("enemy",{})
	_check(str(before_enemy.get("intent","")).is_empty(),"next Rush intent is not leaked before RUSH_PREP enemy opportunity resolves")
	var prep:Dictionary=hound.resolve_enemy_opportunity()
	_check(not prep.has("error"),"visibility Hound RUSH_PREP opportunity resolves")
	var after_prep:Dictionary=hound.snapshot()
	var after_enemy:Dictionary=after_prep.get("enemy",{})
	_check(str(after_enemy.get("intent",""))=="RUSH PREP","Rush intent appears only after the prep opportunity resolves")

	var shield:=Ch00CombatModel.new()
	_check(shield.setup("ENC_SHIELD_BRACE_V02_HP87_ATK20",0.15),"visibility Shield setup")
	var hold:Dictionary=shield.begin_shadow_action("A1")
	_check(not hold.has("error"),"visibility Shield D1 Shadow phase resolves")
	_check(bool((shield.snapshot().get("enemy",{}) as Dictionary).get("guard",false)),"Guard remains visible before BRACE_EXIT enemy opportunity")
	var exit:Dictionary=shield.resolve_enemy_opportunity()
	_check(not exit.has("error"),"visibility Shield BRACE_EXIT resolves")
	_check(not bool((shield.snapshot().get("enemy",{}) as Dictionary).get("guard",false)),"Guard clears only after BRACE_EXIT resolves")
