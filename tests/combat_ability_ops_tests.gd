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
