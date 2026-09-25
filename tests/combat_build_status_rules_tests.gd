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
	_test_deterministic_rng_roundtrip()
	_test_status_application_pipeline()
	_test_aura_scope_and_lifetime()
	_test_talent_build_compilation()
	print("Combat build and status rules tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_deterministic_rng_roundtrip()->void:
	var rng:=CombatDeterministicRng.new(123456)
	var first:Array[int]=[]
	for _i in range(4):
		first.append(rng.next_bp())
	var snap:=rng.snapshot()
	var tail_a:Array[int]=[]
	for _i in range(5):
		tail_a.append(rng.next_bp())
	var restored:=CombatDeterministicRng.new(1)
	_check(restored.restore(snap),"deterministic combat RNG restores a valid state")
	var tail_b:Array[int]=[]
	for _i in range(5):
		tail_b.append(restored.next_bp())
	_check(tail_a==tail_b,"restored combat RNG reproduces the exact future roll stream")
	_check(first.size()==4 and first[0]!=first[1],"combat RNG produces a non-constant deterministic stream")

func _test_status_application_pipeline()->void:
	var miss:=CombatStatusResolver.resolve(6000,100.0,100.0,7000,9999)
	_check(not bool(miss.applied) and str(miss.reason)=="proc_miss","status proc chance is checked before resistance")
	var equal_resist:=CombatStatusResolver.resistance_chance_bp(100.0,100.0)
	_check(equal_resist==CombatStatusResolver.BASE_RESIST_BP,"equal ACC/RES uses the authored baseline resistance")
	_check(CombatStatusResolver.resistance_chance_bp(160.0,100.0)==0,"sufficient Accuracy can reach true guaranteed application instead of hidden failure floor")
	var resisted:=CombatStatusResolver.resolve(10000,100.0,140.0,0,0)
	_check(bool(resisted.proc_passed) and bool(resisted.resisted) and not bool(resisted.applied),"successful proc may still be resisted")
	var unresistable:=CombatStatusResolver.resolve(10000,0.0,9999.0,0,0,true)
	_check(bool(unresistable.applied) and str(unresistable.reason)=="applied_unresistable","explicit unresistable effects bypass ACC/RES")
	var blocked:=CombatStatusResolver.resolve(10000,9999.0,0.0,0,9999,false,true)
	_check(not bool(blocked.applied) and str(blocked.reason)=="blocked","immunity/blocking resolves before proc and resistance")

func _aura()->CombatSkillDefinition:
	var aura:=CombatSkillDefinition.new()
	aura.id=&"test.aura"
	aura.display_name="Test Aura"
	aura.kind=CombatSkillDefinition.SkillKind.AURA
	aura.target_rule=CombatSkillDefinition.TargetRule.ALL_ALLIES
	aura.unlock_level=40
	aura.aura_stat_modifiers={"speed_bp":1000,"resistance":25.0}
	aura.aura_required_battle_tags=[&"Mode.PVE"]
	aura.aura_blocked_battle_tags=[&"Rule.NoAuras"]
	aura.aura_persists_after_owner_death=false
	return aura

func _test_aura_scope_and_lifetime()->void:
	var runtime:=CombatAuraRuntime.new()
	runtime.register_actor(&"leader",&"ally")
	runtime.register_actor(&"shadow",&"ally")
	runtime.register_actor(&"rat",&"enemy")
	var aura:=_aura()
	_check(aura.validate().is_empty(),"team aura definition validates")
	_check(runtime.activate_team_aura(&"ally",&"leader",aura),"team aura activates from a registered owner")
	_check(runtime.modifiers_for(&"shadow",[&"Mode.PVE"]).get("speed_bp",0)==1000,"active aura applies modifiers to same-team ally in required battle mode")
	_check(runtime.modifiers_for(&"rat",[&"Mode.PVE"]).is_empty(),"team aura never leaks to enemy team")
	_check(runtime.modifiers_for(&"shadow",[]).is_empty(),"mode-gated aura stays inactive without its required battle tag")
	_check(runtime.modifiers_for(&"shadow",[&"Mode.PVE",&"Rule.NoAuras"]).is_empty(),"battle rule can explicitly suppress aura")
	runtime.set_alive(&"leader",false)
	_check(runtime.modifiers_for(&"shadow",[&"Mode.PVE"]).is_empty(),"non-persistent aura ends when its owner dies")

func _test_talent_build_compilation()->void:
	var kit:=ShadowAbilityCatalog.kit_for_weapon("sword_shield")
	var graph:=CombatTalentGraph.new()
	var offense:=CombatTalentDefinition.new()
	offense.id=&"test.edge"
	offense.display_name="Edge"
	offense.branch=&"offense"
	offense.tier=1
	offense.max_rank=2
	offense.stat_modifiers={"attack_bp":300}
	offense.skill_patches=[
		{"skill_id":"shadow.sword_shield.a2","key":"coeff","op":"multiply_bp","value":10500}
	]
	offense.granted_passive_ids=[&"passive.test.edge"]
	_check(graph.add_definition(offense),"talent compiler fixture registers")
	var compiled:=CombatBuildCompiler.compile(kit,graph,{"test.edge":2})
	_check(bool(compiled.ok),"valid kit + talent graph compiles")
	var specs:Dictionary=compiled.skill_specs
	var a2:CombatSkillSpec=specs["shadow.sword_shield.a2"]
	var expected:=float(ShadowLoadout.PROFILES["sword_shield"].a2_coeff)*1.05*1.05
	_check(is_equal_approx(float(a2.runtime_values.coeff),expected),"multi-rank talent patch modifies only the runtime A2 spec")
	_check(is_equal_approx(float(compiled.stat_modifiers.attack_bp),600.0),"ranked talent stat modifier scales by purchased rank")
	_check((&"passive.test.edge") in (compiled.granted_passive_ids as Array),"talent compilation exposes granted passive IDs")
	_check(is_equal_approx(float(ShadowLoadout.PROFILES["sword_shield"].a2_coeff),1.20),"talent compilation never mutates source loadout data")
