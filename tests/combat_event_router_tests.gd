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

func _passive(id:StringName,chance:int=10000)->CombatPassiveDefinition:
	var passive:=CombatPassiveDefinition.new()
	passive.id=id
	passive.display_name=str(id)
	passive.trigger_event=CombatEventTypes.ACTIVE_DAMAGE_TAKEN
	passive.owner_relation=CombatPassiveDefinition.OwnerRelation.SELF_TARGET
	passive.reaction_kind=CombatReactionQueue.KIND_COUNTER
	passive.once_per_turn=true
	passive.internal_cooldown_owner_turns=1
	passive.proc_chance_bp=chance
	return passive

func _event(serial:int,depth:int=0)->CombatTriggerEvent:
	var event:=CombatTriggerEvent.new(CombatEventTypes.ACTIVE_DAMAGE_TAKEN,&"rat",&"shadow",serial)
	event.source_team=&"enemy"
	event.target_team=&"ally"
	event.chain_depth=depth
	return event

func _run()->void:
	_test_failed_proc_does_not_consume_guard()
	_test_success_commits_once_per_turn()
	_test_once_per_action_and_reaction_origin()
	_test_chain_and_event_budgets()
	print("Combat event router tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_failed_proc_does_not_consume_guard()->void:
	var runtime:=CombatPassiveRuntime.new()
	runtime.register_actor(&"shadow",&"ally")
	var passive:=_passive(&"shadow.counter",5000)
	runtime.register_passive(&"shadow",passive)
	var router:=CombatEventRouter.new(runtime,CombatReactionQueue.new(),CombatDeterministicRng.new(1))
	router.begin_turn_window(7)
	var first:=router.dispatch(_event(7))
	var first_receipts:Array=first.receipts
	_check(first_receipts.size()==1 and str(first_receipts[0].reason)=="proc_miss","first deterministic 50% proc can miss")
	_check(router.reaction_queue.size()==0,"failed proc never enters reaction queue")
	var state_after_miss:Dictionary=runtime.state_snapshot()["shadow|shadow.counter"]
	_check(not bool(state_after_miss.used_battle) and int(state_after_miss.last_turn_serial)==-1,"failed proc does not consume once-per-turn/battle runtime state")
	var second:=router.dispatch(_event(7))
	var second_receipts:Array=second.receipts
	_check(second_receipts.size()==1 and bool(second_receipts[0].queued),"later eligible event in same turn may still proc after an earlier miss")
	_check(router.reaction_queue.size()==1,"successful passive proc queues exactly one reaction")

func _test_success_commits_once_per_turn()->void:
	var runtime:=CombatPassiveRuntime.new()
	runtime.register_actor(&"shadow",&"ally")
	runtime.register_passive(&"shadow",_passive(&"shadow.guaranteed",10000))
	var router:=CombatEventRouter.new(runtime,CombatReactionQueue.new(),CombatDeterministicRng.new(11))
	router.begin_turn_window(20)
	var first:=router.dispatch(_event(20))
	_check(int(first.pending_reactions)==1,"guaranteed passive queues on first eligible event")
	var second:=router.dispatch(_event(20))
	_check((second.receipts as Array).is_empty() and int(second.pending_reactions)==1,"once-per-turn passive is no longer a candidate after successful activation")
	runtime.advance_owner_turn(&"shadow")
	router.begin_turn_window(21)
	var third:=router.dispatch(_event(21))
	_check(int(third.pending_reactions)==1,"owner-turn cooldown expiry allows passive in a later turn window")

func _test_once_per_action_and_reaction_origin()->void:
	var runtime:=CombatPassiveRuntime.new()
	runtime.register_actor(&"shadow",&"ally")
	var passive:=_passive(&"shadow.action_once",10000)
	passive.once_per_turn=false
	passive.once_per_action=true
	passive.internal_cooldown_owner_turns=0
	runtime.register_passive(&"shadow",passive)
	var router:=CombatEventRouter.new(runtime,CombatReactionQueue.new(),CombatDeterministicRng.new(17))
	router.begin_turn_window(50)

	var hit_a:=_event(50)
	hit_a.transaction_id=9001
	hit_a.add_tag(CombatEventTags.ORIGIN_NATURAL_TURN)
	var first:=router.dispatch(hit_a)
	_check(int(first.pending_reactions)==1,"once-per-action passive can trigger on first hit of an action")

	var hit_b:=_event(50)
	hit_b.transaction_id=9001
	hit_b.add_tag(CombatEventTags.ORIGIN_NATURAL_TURN)
	var second:=router.dispatch(hit_b)
	_check((second.receipts as Array).is_empty(),"second hit with same transaction cannot retrigger once-per-action passive")

	router.pop_reaction()
	var hit_c:=_event(50)
	hit_c.transaction_id=9002
	hit_c.add_tag(CombatEventTags.ORIGIN_NATURAL_TURN)
	var third:=router.dispatch(hit_c)
	_check(int(third.pending_reactions)==1,"different action transaction may trigger again in the same turn when once-per-turn is disabled")

	var reaction_runtime:=CombatPassiveRuntime.new()
	reaction_runtime.register_actor(&"shadow",&"ally")
	var no_chain:=_passive(&"shadow.no_reaction_chain",10000)
	no_chain.once_per_turn=false
	no_chain.internal_cooldown_owner_turns=0
	reaction_runtime.register_passive(&"shadow",no_chain)
	var reaction_router:=CombatEventRouter.new(reaction_runtime,CombatReactionQueue.new(),CombatDeterministicRng.new(21))
	reaction_router.begin_turn_window(51)
	var reaction_event:=_event(51)
	reaction_event.transaction_id=9100
	reaction_event.add_tag(CombatEventTags.ORIGIN_REACTION)
	var blocked:=reaction_router.dispatch(reaction_event)
	_check((blocked.receipts as Array).is_empty(),"passives do not trigger from Reaction-origin events by default")

	var allowed_runtime:=CombatPassiveRuntime.new()
	allowed_runtime.register_actor(&"shadow",&"ally")
	var allowed:=_passive(&"shadow.explicit_reaction_chain",10000)
	allowed.once_per_turn=false
	allowed.internal_cooldown_owner_turns=0
	allowed.allow_reaction_trigger=true
	allowed_runtime.register_passive(&"shadow",allowed)
	var allowed_router:=CombatEventRouter.new(allowed_runtime,CombatReactionQueue.new(),CombatDeterministicRng.new(23))
	allowed_router.begin_turn_window(52)
	var allowed_event:=_event(52)
	allowed_event.transaction_id=9200
	allowed_event.add_tag(CombatEventTags.ORIGIN_REACTION)
	var allowed_result:=allowed_router.dispatch(allowed_event)
	_check(int(allowed_result.pending_reactions)==1,"reaction-triggered passive chains require explicit author opt-in")

func _test_chain_and_event_budgets()->void:
	var runtime:=CombatPassiveRuntime.new()
	runtime.register_actor(&"shadow",&"ally")
	var chained:=_passive(&"shadow.chain_guard",10000)
	chained.once_per_turn=false
	chained.internal_cooldown_owner_turns=0
	runtime.register_passive(&"shadow",chained)
	var router:=CombatEventRouter.new(runtime,CombatReactionQueue.new(),CombatDeterministicRng.new(3))
	router.begin_turn_window(30)
	var deep:=router.dispatch(_event(30,CombatReactionQueue.MAX_CHAIN_DEPTH))
	var deep_receipts:Array=deep.receipts
	_check(deep_receipts.size()==1 and str(deep_receipts[0].reason)=="chain_guard","passive-created reaction cannot exceed maximum reaction chain depth")
	_check(router.reaction_queue.size()==0,"chain-guarded reaction is never queued")

	var budget_runtime:=CombatPassiveRuntime.new()
	budget_runtime.register_actor(&"shadow",&"ally")
	var budget_router:=CombatEventRouter.new(budget_runtime,CombatReactionQueue.new(),CombatDeterministicRng.new(9))
	budget_router.begin_turn_window(40)
	for _i in range(CombatEventRouter.MAX_EVENTS_PER_WINDOW):
		var accepted:=budget_router.dispatch(_event(40))
		_check(bool(accepted.accepted),"event router accepts events inside the per-turn budget")
	var overflow:=budget_router.dispatch(_event(40))
	_check(not bool(overflow.accepted) and str(overflow.reason)=="event_budget","event router hard-stops pathological passive event storms")
