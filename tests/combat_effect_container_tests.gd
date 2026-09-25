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

func _definition(id:StringName,policy:CombatEffectDefinition.StackingPolicy,max_stacks:int=1,turns:int=2)->CombatEffectDefinition:
	var d:=CombatEffectDefinition.new()
	d.id=id
	d.semantic_tags=[id]
	d.duration_policy=CombatEffectDefinition.DurationPolicy.TURN_BASED
	d.base_duration_turns=turns
	d.max_stacks=max_stacks
	d.stacking_policy=policy
	d.base_magnitudes={"power":1.0}
	return d

func _context(source:StringName)->CombatEffectContext:
	return CombatEffectContext.new(source,&"shadow",1,1)

func _run()->void:
	_test_refresh()
	_test_refresh_provenance()
	_test_stacks()
	_test_independent()
	_test_tags()
	print("Combat effect container tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_refresh()->void:
	var c:=CombatEffectContainer.new()
	var d:=_definition(&"Status.Poison",CombatEffectDefinition.StackingPolicy.REFRESH,1,2)
	d.magnitude_merge_policy=CombatEffectDefinition.MagnitudeMergePolicy.MAX_NUMERIC
	var a:=c.apply(d,_context(&"rat_a"),1.0,{"power":2.0})
	var b:=c.apply(d,_context(&"rat_b"),1.0,{"power":3.5})
	var spec:=c.first_spec(d.id)
	_check(bool(a.applied) and str(b.reason)=="refreshed" and c.count(d.id)==1,"refresh keeps one runtime effect")
	_check(spec!=null and is_equal_approx(float(spec.runtime_magnitudes.power),3.5) and spec.context.source_actor_id==&"rat_b","refresh preserves stronger magnitude and latest provenance")

func _test_refresh_provenance()->void:
	var c:=CombatEffectContainer.new()
	var d:=_definition(&"Status.StrongPoison",CombatEffectDefinition.StackingPolicy.REFRESH,1,2)
	d.magnitude_merge_policy=CombatEffectDefinition.MagnitudeMergePolicy.MAX_NUMERIC
	c.apply(d,_context(&"rat_strong"),1.0,{"power":5.0})
	c.apply(d,_context(&"rat_weak"),1.0,{"power":3.0})
	var spec:=c.first_spec(d.id)
	_check(spec!=null and is_equal_approx(float(spec.runtime_magnitudes.power),5.0),"weaker refresh cannot overwrite retained stronger magnitude")
	_check(spec!=null and spec.magnitude_source("power").source_actor_id==&"rat_strong","retained stronger magnitude keeps original source attribution")
	_check(spec!=null and spec.context.source_actor_id==&"rat_weak","effect context still records the latest duration refresher separately")
	c.apply(d,_context(&"rat_stronger"),1.0,{"power":7.0})
	spec=c.first_spec(d.id)
	_check(spec!=null and spec.magnitude_source("power").source_actor_id==&"rat_stronger","stronger replacement transfers magnitude ownership to the winning source")

func _test_stacks()->void:
	var c:=CombatEffectContainer.new()
	var d:=_definition(&"Status.Bleed",CombatEffectDefinition.StackingPolicy.ADD_STACKS,3,2)
	c.apply(d,_context(&"rat_a"))
	c.apply(d,_context(&"rat_b"))
	c.apply(d,_context(&"rat_c"))
	var capped:=c.apply(d,_context(&"rat_d"))
	var spec:=c.first_spec(d.id)
	_check(c.count(d.id)==1 and c.stack_count(d.id)==3 and str(capped.reason)=="stack_cap_refreshed","stacking caps and refreshes deterministically")
	_check(spec!=null and spec.stack_source_actor_ids()==["rat_a","rat_b","rat_c"],"stacked effect preserves per-stack source attribution and cap refresh adds no phantom stack owner")

func _test_independent()->void:
	var c:=CombatEffectContainer.new()
	var d:=_definition(&"Status.Burn",CombatEffectDefinition.StackingPolicy.INDEPENDENT,2,1)
	var a:=c.apply(d,_context(&"mage_a"))
	var b:=c.apply(d,_context(&"mage_b"))
	var blocked:=c.apply(d,_context(&"mage_c"))
	_check(bool(a.applied) and bool(b.applied) and not bool(blocked.applied) and c.count(d.id)==2,"independent effects enforce instance cap")
	_check(c.advance_owner_turn().size()==2 and c.count(d.id)==0,"independent effects expire separately")

func _test_tags()->void:
	var c:=CombatEffectContainer.new()
	var d:=_definition(&"Status.Poison",CombatEffectDefinition.StackingPolicy.INDEPENDENT,2,3)
	c.apply(d,_context(&"rat_a"))
	c.apply(d,_context(&"rat_b"))
	_check(c.has_tag(d.id),"tag is present while contributors remain")
	c.remove_by_id(d.id,1)
	_check(c.has_tag(d.id),"one removal preserves remaining contributor")
	c.remove_by_tag(d.id,99)
	_check(not c.has_tag(d.id),"tag disappears after final contributor")
