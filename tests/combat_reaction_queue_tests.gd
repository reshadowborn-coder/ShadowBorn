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
	_test_reaction_is_not_a_turn()
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
