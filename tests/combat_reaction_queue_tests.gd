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
	_test_priority_and_stability()
	_test_duplicate_and_chain_guards()
	_test_transaction_scoped_identity()
	_test_reaction_is_not_a_turn()
	_test_actor_invalidation_contract()
	print("Combat reaction queue tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_priority_and_stability()->void:
	var queue:=CombatReactionQueue.new()
	queue.begin_window(7)
	_check(queue.queue_reaction(&"rat_a",&"counter_a",CombatReactionQueue.KIND_COUNTER,10),"counter reaction queues")
	_check(queue.queue_reaction(&"shadow",&"interrupt",CombatReactionQueue.KIND_INTERRUPT,30),"higher-priority interrupt queues")
	_check(queue.queue_reaction(&"ally",&"assist",CombatReactionQueue.KIND_ASSIST,10),"same-priority assist queues")
	var first:=queue.pop_next()
	var second:=queue.pop_next()
	var third:=queue.pop_next()
	_check(StringName(first.reaction_id)==&"interrupt","higher-priority reaction resolves first")
	_check(StringName(second.reaction_id)==&"counter_a","equal-priority reactions preserve deterministic insertion order")
	_check(StringName(third.reaction_id)==&"assist","stable ordering survives multiple pops")

func _test_duplicate_and_chain_guards()->void:
	var queue:=CombatReactionQueue.new()
	queue.begin_window(11)
	_check(queue.queue_reaction(&"shadow",&"riposte",CombatReactionQueue.KIND_COUNTER,0,0),"first reaction identity is accepted")
	_check(not queue.queue_reaction(&"shadow",&"riposte",CombatReactionQueue.KIND_COUNTER,0,0),"same actor/reaction cannot recursively enqueue twice in one source window")
	_check(not queue.queue_reaction(&"shadow",&"deep_loop",CombatReactionQueue.KIND_FOLLOW_UP,0,CombatReactionQueue.MAX_CHAIN_DEPTH+1),"reaction depth is bounded against passive loops")
	for i in range(CombatReactionQueue.MAX_PENDING-1):
		_check(queue.queue_reaction(StringName("actor_%d"%i),StringName("reaction_%d"%i),CombatReactionQueue.KIND_ASSIST),"bounded reaction slot accepts valid entry %d"%i)
	_check(not queue.queue_reaction(&"overflow",&"overflow",CombatReactionQueue.KIND_ASSIST),"reaction queue has a hard per-window cap")

func _test_transaction_scoped_identity()->void:
	var queue:=CombatReactionQueue.new()
	queue.begin_window(77)
	var payload_a:Dictionary={"event":{"transaction_id":1001}}
	var payload_b:Dictionary={"event":{"transaction_id":1002}}
	_check(queue.queue_reaction(&"shadow",&"same_passive",CombatReactionQueue.KIND_FOLLOW_UP,0,0,payload_a),"reaction identity accepts first source action")
	_check(not queue.queue_reaction(&"shadow",&"same_passive",CombatReactionQueue.KIND_FOLLOW_UP,0,0,payload_a),"same passive cannot duplicate inside one source action")
	_check(queue.queue_reaction(&"shadow",&"same_passive",CombatReactionQueue.KIND_FOLLOW_UP,0,0,payload_b),"same passive may react to a distinct source action in the same natural turn")
	var first:=queue.pop_next()
	var second:=queue.pop_next()
	_check(int(first.get("source_transaction_id",0))==1001 and int(second.get("source_transaction_id",0))==1002,"queued reactions preserve source action provenance")

func _test_reaction_is_not_a_turn()->void:
	var timeline:=CombatTurnTimeline.new()
	timeline.add_actor(&"shadow",&"ally",100,CombatTurnTimeline.GAUGE_MAX)
	timeline.apply_speed_modifier(&"shadow",&"haste",3000,2)
	var ticket:=timeline.next_turn()
	var before:=timeline.actor_snapshot(&"shadow")
	var queue:=CombatReactionQueue.new()
	queue.begin_window(int(ticket.serial))
	queue.queue_reaction(&"shadow",&"riposte",CombatReactionQueue.KIND_COUNTER)
	var reaction:=queue.pop_next()
	var after:=timeline.actor_snapshot(&"shadow")
	_check(StringName(reaction.actor_id)==&"shadow","reaction can belong to the actor whose natural turn is open")
	_check(int(after.gauge)==int(before.gauge),"popping a reaction never consumes or fills Turn Meter")
	_check((after.effects as Array)==(before.effects as Array),"reaction resolution does not tick owner-turn effect durations")
	_check(timeline.active_ticket()==ticket,"reaction queue cannot replace or finish the natural turn ticket")
	timeline.end_turn(&"shadow")

func _test_actor_invalidation_contract()->void:
	var queue:=CombatReactionQueue.new()
	queue.begin_window(91)
	_check(queue.queue_reaction(&"rat_a",&"death_counter",CombatReactionQueue.KIND_COUNTER,20),"reaction can queue before actor invalidation")
	_check(queue.queue_reaction(&"rat_a",&"death_assist",CombatReactionQueue.KIND_ASSIST,10),"same actor can own a distinct pending reaction")
	_check(queue.queue_reaction(&"shadow",&"survivor_follow",CombatReactionQueue.KIND_FOLLOW_UP,0),"unrelated actor reaction queues")
	queue.clear_actor(&"rat_a")
	_check(queue.size()==1,"actor invalidation removes every pending reaction owned by that actor")
	var survivor:=queue.pop_next()
	_check(StringName(survivor.actor_id)==&"shadow","actor invalidation preserves unrelated pending reactions")
	_check(not queue.has_pending(),"queue drains deterministically after invalidation")
