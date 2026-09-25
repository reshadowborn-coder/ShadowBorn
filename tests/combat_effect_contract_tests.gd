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
	_test_definition_runtime_isolation()
	_test_tag_contributors()
	_test_tag_snapshot_atomic_restore()
	_test_tag_property_sequence()
	print("Combat effect contract tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _poison_definition()->CombatEffectDefinition:
	var definition:=CombatEffectDefinition.new()
	definition.id=&"Status.Poison"
	definition.semantic_tags=[&"Status.Poison"]
	definition.duration_policy=CombatEffectDefinition.DurationPolicy.TURN_BASED
	definition.base_duration_turns=3
	definition.max_stacks=3
	definition.stacking_policy=CombatEffectDefinition.StackingPolicy.REFRESH
	definition.base_magnitudes={"damage_per_turn":2.0}
	definition.cue_ids=[&"Cue.Poison.Apply",&"Cue.Poison.Tick"]
	return definition

func _test_definition_runtime_isolation()->void:
	var definition:=_poison_definition()
	var context_a:=CombatEffectContext.new(&"enemy_a",&"shadow",4,101)
	context_a.source_skill_id=&"poison_bite"
	var context_b:=CombatEffectContext.new(&"enemy_b",&"shadow",5,102)
	context_b.source_skill_id=&"venom_spit"

	var spec_a:=definition.create_spec(context_a)
	var spec_b:=definition.create_spec(context_b)
	spec_a.runtime_magnitudes["damage_per_turn"]=7.0
	spec_a.advance_turn()
	spec_a.record_delta(&"Health",-7.0)
	spec_a.inject_tag(&"Event.Damage.Periodic")
	spec_a.created_tags.append(&"Status.Poison")

	_check(float(definition.base_magnitudes["damage_per_turn"])==2.0,"Runtime magnitude mutation never changes static effect definition")
	_check(float(spec_b.runtime_magnitudes["damage_per_turn"])==2.0,"Independent specs do not share runtime magnitude dictionaries")
	_check(spec_a.remaining_turns==2 and spec_b.remaining_turns==3,"Turn duration is per runtime spec")
	_check(spec_a.context.source_actor_id==&"enemy_a" and spec_b.context.source_actor_id==&"enemy_b","Effect context preserves independent source provenance")
	_check(spec_a.context.transaction_id==101 and spec_b.context.transaction_id==102,"Effect context preserves transaction provenance")
	_check(spec_a.has_tag(&"Status.Poison") and spec_a.has_tag(&"Event.Damage.Periodic"),"Spec resolves static and dynamic semantic tags")
	_check(float(spec_a.calculated_deltas.get(&"Health",0.0))==-7.0,"Spec records exact calculated delta receipt")
	var snap:=spec_a.snapshot()
	_check(str(snap.definition_id)=="Status.Poison" and int(snap.context.transaction_id)==101,"Spec snapshot retains definition and context identity")

func _test_tag_contributors()->void:
	var ledger:=CombatTagLedger.new()
	_check(ledger.add(&"Status.Marked",&"shadow_school"),"First tag contributor is accepted")
	_check(ledger.add(&"Status.Marked",&"hero_passive"),"Second tag contributor is accepted")
	_check(ledger.has(&"Status.Marked"),"Tag is present while contributors exist")
	_check(ledger.contributor_count(&"Status.Marked")==2,"Contributor count tracks independent sources")
	_check(ledger.total_contribution_count(&"Status.Marked")==2,"Contribution total starts at two")
	_check(ledger.add(&"Status.Marked",&"hero_passive",2),"Same source may contribute multiple semantic counts")
	_check(ledger.contributor_count(&"Status.Marked")==2 and ledger.total_contribution_count(&"Status.Marked")==4,"Contributor identity stays separate from contribution total")
	_check(ledger.remove(&"Status.Marked",&"shadow_school"),"One contributor can be removed")
	_check(ledger.has(&"Status.Marked") and ledger.contributor_count(&"Status.Marked")==1,"Removing one source cannot clear another source's tag")
	_check(ledger.remove(&"Status.Marked",&"hero_passive",3),"Remaining source can be fully removed")
	_check(not ledger.has(&"Status.Marked"),"Tag disappears only after the final contributor is removed")

func _test_tag_snapshot_atomic_restore()->void:
	var original:=CombatTagLedger.new()
	original.add(&"Status.Guarded",&"shield")
	original.add(&"Aura.Temple",&"keeper")
	var snapshot:=original.snapshot()

	var restored:=CombatTagLedger.new()
	_check(restored.restore(snapshot),"Valid semantic tag snapshot restores")
	_check(restored.has(&"Status.Guarded") and restored.has(&"Aura.Temple"),"Restored ledger reproduces semantic presence")

	var before:=restored.snapshot()
	_check(not restored.restore({"Status.Guarded":{"shield":0}}),"Invalid contribution counts are rejected")
	_check(restored.snapshot()==before,"Failed restore is atomic and leaves live ledger unchanged")

func _test_tag_property_sequence()->void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=0x5A17B0
	var ledger:=CombatTagLedger.new()
	var oracle:Dictionary={}
	var tags:=[&"Status.Marked",&"Status.Poison",&"State.Guarded",&"Aura.Field",&"Status.Broken"]
	var sources:=[&"shadow",&"hero_a",&"hero_b",&"weapon",&"school",&"enemy_a",&"enemy_b",&"relic"]

	for step in range(600):
		var tag:StringName=tags[rng.randi_range(0,tags.size()-1)]
		var source:StringName=sources[rng.randi_range(0,sources.size()-1)]
		var amount:=rng.randi_range(1,3)
		var do_add:=rng.randf()<0.58

		if do_add:
			ledger.add(tag,source,amount)
			var tag_key:=str(tag)
			var source_key:=str(source)
			if not oracle.has(tag_key):
				oracle[tag_key]={}
			var src:Dictionary=oracle[tag_key]
			src[source_key]=int(src.get(source_key,0))+amount
		else:
			var tag_key:=str(tag)
			var source_key:=str(source)
			var expected_success:=oracle.has(tag_key) and (oracle[tag_key] as Dictionary).has(source_key)
			var actual_success:=ledger.remove(tag,source,amount)
			_check(actual_success==expected_success,"Property sequence remove result matches oracle at step %d"%step)
			if expected_success:
				var src:Dictionary=oracle[tag_key]
				var next_count:=int(src[source_key])-amount
				if next_count>0:
					src[source_key]=next_count
				else:
					src.erase(source_key)
				if src.is_empty():
					oracle.erase(tag_key)

		_check(ledger.snapshot()==oracle,"Tag ledger matches independent oracle at step %d"%step)

		if step%75==0:
			var roundtrip:=CombatTagLedger.new()
			_check(roundtrip.restore(ledger.snapshot()),"Property sequence snapshot restores at step %d"%step)
			_check(roundtrip.snapshot()==oracle,"Property sequence roundtrip matches oracle at step %d"%step)
