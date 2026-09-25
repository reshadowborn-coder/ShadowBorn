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
	_test_valid_step_vocabulary()
	_test_condition_vocabulary()
	_test_target_resolution_and_planning()
	_test_invalid_steps_fail_closed()
	_test_definitions_use_step_validator()
	print("Combat ability operation tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_valid_step_vocabulary()->void:
	var steps:Array=[
		{"op":"damage","target":"primary_target","coeff":1.25},
		{"op":"apply_status","target":"primary_target","status_id":"Status.Poison","chance_bp":7500,"turns":2},
		{"op":"turn_meter","target":"self","value_bp":1500},
		{"op":"speed_modifier","target":"all_allies","value_bp":3000,"turns":2},
		{"op":"cooldown_delta","target":"self","value":-1},
		{"op":"resource_delta","target":"self","resource_id":"shadow_essence","value":10},
		{"op":"grant_tag","target":"self","tag":"State.Empowered"}
	]
	_check(CombatAbilityOps.validate_steps(steps).is_empty(),"supported data-driven combat operations validate as a sequence")

func _test_condition_vocabulary()->void:
	var context:Dictionary={
		"self_id":"shadow",
		"primary_target_id":"rat",
		"event_source_id":"rat",
		"event_target_id":"shadow",
		"event_tags":["Result.Critical"],
		"actors":{
			"shadow":{"team":"ally","alive":true,"hp":8.0,"max_hp":20.0,"turn_meter_bp":8500,"tags":["State.Veil"],"resources":{"shadow_essence":60}},
			"ally":{"team":"ally","alive":true,"hp":10.0,"max_hp":10.0,"turn_meter_bp":2000,"tags":[],"resources":{}},
			"rat":{"team":"enemy","alive":true,"hp":4.0,"max_hp":12.0,"turn_meter_bp":3000,"tags":["Status.Poison"],"resources":{}}
		}
	}
	var conditions:Array=[
		{"op":"has_tag","subject":"primary_target","tag":"Status.Poison"},
		{"op":"hp_pct_lte","subject":"self","value_bp":5000},
		{"op":"turn_meter_gte","subject":"self","value_bp":8000},
		{"op":"resource_gte","subject":"self","resource_id":"shadow_essence","value":50},
		{"op":"alive_enemies_lte","value":1},
		{"op":"event_has_tag","tag":"Result.Critical"}
	]
	_check(CombatConditionEvaluator.validate(conditions).is_empty(),"reusable conditional skill rules validate")
	_check(CombatConditionEvaluator.evaluate_all(conditions,context),"conditional evaluator combines status, HP, TM, resource, enemy-count and event state")
	var nested:Dictionary={"op":"all","conditions":[
		{"op":"has_tag","subject":"primary_target","tag":"Status.Poison"},
		{"op":"not","condition":{"op":"has_tag","subject":"primary_target","tag":"Status.Stun"}}
	]}
	_check(CombatConditionEvaluator.evaluate(nested,context),"nested ALL/NOT conditions evaluate deterministically")
	_check(not CombatConditionEvaluator.validate([{"op":"mystery_rule","subject":"self"}]).is_empty(),"unknown condition op fails closed")
	var deep:Dictionary={"op":"has_tag","subject":"self","tag":"State.Veil"}
	for _i in range(CombatConditionEvaluator.MAX_DEPTH+2):
		deep={"op":"not","condition":deep}
	_check(not CombatConditionEvaluator.validate([deep]).is_empty(),"condition nesting is hard-bounded")
	var conditional_step:Dictionary={"op":"damage","target":"primary_target","coeff":1.4,"conditions":[nested]}
	_check(CombatAbilityOps.validate_step(conditional_step).is_empty(),"ability effect step accepts validated reusable conditions")

func _test_target_resolution_and_planning()->void:
	var context:Dictionary={
		"self_id":"shadow",
		"actors":{
			"shadow":{"team":"ally","alive":true,"hp":20.0,"max_hp":20.0,"turn_meter_bp":2500,"tags":[],"resources":{}},
			"keeper":{"team":"ally","alive":true,"hp":4.0,"max_hp":20.0,"turn_meter_bp":9000,"tags":[],"resources":{}},
			"rat_a":{"team":"enemy","alive":true,"hp":8.0,"max_hp":10.0,"turn_meter_bp":7000,"tags":["Status.Poison"],"resources":{}},
			"rat_b":{"team":"enemy","alive":true,"hp":10.0,"max_hp":10.0,"turn_meter_bp":9500,"tags":[],"resources":{}},
			"dead_rat":{"team":"enemy","alive":false,"hp":0.0,"max_hp":10.0,"turn_meter_bp":10000,"tags":[],"resources":{}}
		}
	}
	_check(CombatTargetResolver.resolve("lowest_hp_ally",context)==[&"keeper"],"target resolver chooses lowest-HP living ally deterministically")
	_check(CombatTargetResolver.resolve("highest_turn_meter_enemy",context)==[&"rat_b"],"target resolver ignores dead actors and chooses highest-TM enemy")
	_check(CombatTargetResolver.resolve("all_enemies",context)==[&"rat_a",&"rat_b"],"all-enemy target order is stable and excludes dead actors")
	var steps:Array=[
		{"op":"damage","target":"all_enemies","coeff":1.0},
		{"op":"turn_meter","target":"highest_turn_meter_enemy","value_bp":-1500},
		{"op":"damage","target":"all_enemies","coeff":0.5,"conditions":[{"op":"has_tag","subject":"primary_target","tag":"Status.Poison"}]}
	]
	var plan:=CombatAbilityPlanner.build(steps,context)
	_check(bool(plan.ok),"validated ability steps build a deterministic execution plan")
	_check(CombatAbilityPlanner.operation_count(plan,"damage")==4,"planner retains conditional operations for execution-time evaluation")
	_check(CombatAbilityPlanner.preview_operation_count(plan,"damage")==3,"current-state preview still counts only presently eligible damage operations")
	var operations:Array=plan.operations
	_check(str(operations[0].target_actor_id)=="rat_a" and str(operations[1].target_actor_id)=="rat_b","multi-target operation ordering is deterministic")
	_check(str(operations[2].target_actor_id)=="rat_b" and str(operations[2].op)=="turn_meter","highest-TM selector resolves into one explicit operation")
	_check(bool(operations[3].preview_condition_passed) and not bool(operations[4].preview_condition_passed),"per-target condition previews do not delete later operations")
	var future_context:=context.duplicate(true)
	var future_actors:Dictionary=future_context["actors"]
	var future_rat_b:Dictionary=future_actors["rat_b"]
	future_rat_b["tags"]=["Status.Poison"]
	future_actors["rat_b"]=future_rat_b
	future_context["actors"]=future_actors
	_check(CombatAbilityPlanner.operation_conditions_pass(operations[4],future_context),"execution-time condition can become true after an earlier step changes state")
	var invalid:=CombatAbilityPlanner.build([{"op":"mystery","target":"self"}],context)
	_check(not bool(invalid.ok) and not (invalid.errors as Array).is_empty(),"planner fails closed before executing invalid combat data")

func _test_invalid_steps_fail_closed()->void:
	_check(not CombatAbilityOps.validate_step({"op":"turnmeter","target":"self","value_bp":1000}).is_empty(),"unknown operation typo is rejected")
	_check(not CombatAbilityOps.validate_step({"op":"apply_status","target":"primary_target","status_id":"Status.Stun","chance_bp":12000,"turns":1}).is_empty(),"status chance cannot exceed 100%")
	_check(not CombatAbilityOps.validate_step({"op":"apply_status","target":"primary_target","status_id":"Status.Poison","chance_bp":5000,"turns":2,"roll_scope":"per_sneeze"}).is_empty(),"status roll scope must explicitly be per-action or per-hit")
	_check(not CombatAbilityOps.validate_step({"op":"extra_turn","target":"self","count":99}).is_empty(),"ability data cannot bypass the global extra-turn chain cap")
	_check(not CombatAbilityOps.validate_step({"op":"speed_modifier","target":"mystery_target","value_bp":3000,"turns":2}).is_empty(),"unknown target selector is rejected")
	_check(not CombatAbilityOps.validate_step({"op":"damage","target":"primary_target"}).is_empty(),"damage operation requires explicit scaling")

func _test_definitions_use_step_validator()->void:
	var skill:=CombatSkillDefinition.new()
	skill.id=&"test.invalid_skill"
	skill.display_name="Invalid Skill"
	skill.kind=CombatSkillDefinition.SkillKind.ACTIVE
	skill.base_cooldown=3
	skill.effect_steps=[{"op":"not_real","target":"self"}]
	_check(not skill.validate().is_empty(),"skill definition rejects invalid effect operations")

	var passive:=CombatPassiveDefinition.new()
	passive.id=&"test.invalid_passive"
	passive.display_name="Invalid Passive"
	passive.trigger_event=CombatEventTypes.AFTER_HIT
	passive.effect_steps=[{"op":"extra_turn","target":"self","count":3}]
	_check(not passive.validate().is_empty(),"passive definition cannot author an illegal extra-turn count")
