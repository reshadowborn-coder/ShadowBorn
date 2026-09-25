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
	_test_speed_ratio_and_ties()
	_test_speed_buffs_and_meter_manipulation()
	_test_hard_control_and_resolve()
	_test_sleep_break_and_freeze_rules()
	_test_extra_turn_and_owner_duration()
	_test_mid_turn_application_duration()
	_test_provoke_and_silence_contracts()
	_test_adversarial_turn_edges()
	print("Combat turn timeline tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _take(timeline:CombatTurnTimeline)->Dictionary:
	var ticket:=timeline.next_turn()
	if not ticket.is_empty():
		timeline.end_turn(StringName(ticket.actor_id))
	return ticket

func _test_speed_ratio_and_ties()->void:
	var timeline:=CombatTurnTimeline.new()
	_check(timeline.add_actor(&"fast",&"ally",200),"fast actor registers")
	_check(timeline.add_actor(&"slow",&"enemy",100),"slow actor registers")
	var first:=_take(timeline)
	var second:=_take(timeline)
	var third:=_take(timeline)
	_check(StringName(first.actor_id)==&"fast","200 SPD actor wins the first race")
	_check(StringName(second.actor_id)==&"fast","200 SPD actor can lap a 100 SPD actor")
	_check(StringName(third.actor_id)==&"slow","slower actor still receives its accumulated turn")
	
	var ties:=CombatTurnTimeline.new()
	ties.add_actor(&"first",&"ally",100)
	ties.add_actor(&"second",&"enemy",100)
	_check(StringName(_take(ties).actor_id)==&"first","exact speed/gauge ties resolve by stable registration order")

func _test_speed_buffs_and_meter_manipulation()->void:
	var timeline:=CombatTurnTimeline.new()
	timeline.add_actor(&"shadow",&"ally",100)
	timeline.add_actor(&"rat",&"enemy",100)
	_check(timeline.apply_speed_modifier(&"shadow",&"haste",3000,2),"30% speed buff applies")
	_check(timeline.effective_speed(&"shadow")==130,"speed buff changes effective SPD rather than instant meter")
	_check(StringName(_take(timeline).actor_id)==&"shadow","speed buff advances future turn frequency")
	
	var cut:=CombatTurnTimeline.new()
	cut.add_actor(&"shadow",&"ally",100)
	cut.add_actor(&"rat",&"enemy",120)
	_check(cut.adjust_turn_meter(&"shadow",6000),"direct +60% turn meter applies independently from SPD")
	_check(StringName(_take(cut).actor_id)==&"shadow","direct meter fill can overtake a faster opponent")
	_check(cut.adjust_turn_meter(&"rat",-3000),"turn meter reduction supports negative push")

func _test_hard_control_and_resolve()->void:
	var timeline:=CombatTurnTimeline.new()
	timeline.add_actor(&"shadow",&"ally",100,CombatTurnTimeline.GAUGE_MAX)
	_check(timeline.apply_control(&"shadow",CombatTurnTimeline.TAG_STUN,1,&"rat"),"Stun applies")
	var stunned:=timeline.next_turn()
	_check(bool(stunned.skipped),"Stun consumes the ready turn")
	_check(not bool(stunned.cooldowns_advance),"hard control blocks cooldown refresh")
	_check(StringName(stunned.control_reason)==CombatTurnTimeline.TAG_STUN,"turn ticket exposes Stun reason")
	timeline.end_turn(&"shadow")
	_check(not timeline.has_tag(&"shadow",CombatTurnTimeline.TAG_STUN),"one-turn Stun expires after owner turn")
	_check(int(timeline.actor_snapshot(&"shadow").resolve_stacks)==1,"first stolen turn grants one Resolve stack")
	_check(timeline.gauge(&"shadow")==CombatTurnTimeline.RESOLVE_GAUGE_PER_STACK,"Resolve refunds a small amount of next-turn progress")
	
	timeline.set_turn_meter(&"shadow",10000)
	timeline.apply_control(&"shadow",CombatTurnTimeline.TAG_FREEZE,1,&"rat")
	var frozen:=timeline.next_turn()
	_check(bool(frozen.skipped),"Freeze also consumes a turn")
	timeline.end_turn(&"shadow")
	_check(int(timeline.actor_snapshot(&"shadow").resolve_stacks)==2,"consecutive hard control builds Resolve")
	_check(timeline.gauge(&"shadow")==CombatTurnTimeline.RESOLVE_GAUGE_PER_STACK*2,"second control skip gets stronger but bounded recovery")

func _test_sleep_break_and_freeze_rules()->void:
	var timeline:=CombatTurnTimeline.new()
	timeline.add_actor(&"shadow",&"ally",100)
	_check(timeline.apply_control(&"shadow",CombatTurnTimeline.TAG_SLEEP,2,&"caster"),"Sleep applies")
	_check(timeline.has_tag(&"shadow",CombatTurnTimeline.TAG_SLEEP),"Sleep tag is active")
	_check(timeline.notify_active_damage(&"shadow")==1,"active damage wakes Sleep")
	_check(not timeline.has_tag(&"shadow",CombatTurnTimeline.TAG_SLEEP),"Sleep is removed by active damage")
	
	timeline.apply_control(&"shadow",CombatTurnTimeline.TAG_FREEZE,1,&"caster")
	_check(is_equal_approx(timeline.incoming_damage_multiplier(&"shadow"),0.75),"Freeze preserves RAID-style 25% incoming-damage protection")
	_check(timeline.notify_active_damage(&"shadow")==0,"active damage does not automatically break Freeze")

func _test_extra_turn_and_owner_duration()->void:
	var timeline:=CombatTurnTimeline.new()
	timeline.add_actor(&"shadow",&"ally",100)
	timeline.add_actor(&"rat",&"enemy",100)
	timeline.apply_speed_modifier(&"shadow",&"haste",3000,2)
	var first:=timeline.next_turn()
	_check(StringName(first.actor_id)==&"shadow","buffed Shadow takes the first natural turn")
	timeline.grant_extra_turn(&"shadow")
	timeline.end_turn(&"shadow")
	_check(timeline.has_tag(&"shadow",CombatTurnTimeline.TAG_SPEED),"two-turn speed buff survives first owner turn")
	var extra:=timeline.next_turn()
	_check(StringName(extra.actor_id)==&"shadow" and bool(extra.extra_turn),"granted extra turn executes before natural timeline")
	timeline.end_turn(&"shadow")
	_check(not timeline.has_tag(&"shadow",CombatTurnTimeline.TAG_SPEED),"owner-turn duration also counts an actual extra turn")
	
	var bounded:=CombatTurnTimeline.new()
	bounded.add_actor(&"shadow",&"ally",100)
	_check(bounded.grant_extra_turn(&"shadow",99),"extra-turn request is accepted")
	_check((bounded.snapshot().extra_turn_queue as Array).size()==CombatTurnTimeline.MAX_EXTRA_TURNS_PER_ACTOR,"extra-turn queue is hard-bounded against loops")

func _test_mid_turn_application_duration()->void:
	var timeline:=CombatTurnTimeline.new()
	timeline.add_actor(&"shadow",&"ally",100,CombatTurnTimeline.GAUGE_MAX)
	var ticket:=timeline.next_turn()
	_check(StringName(ticket.actor_id)==&"shadow","mid-turn duration fixture opens Shadow's turn")
	_check(timeline.apply_speed_modifier(&"shadow",&"self_haste",3000,2),"self speed buff can be applied during an open turn")
	timeline.end_turn(&"shadow")
	var after_self_buff:=timeline.actor_snapshot(&"shadow")
	var effects:Array=after_self_buff.get("effects",[])
	_check(effects.size()==1 and int((effects[0] as Dictionary).get("turns",0))==2,"self-buff applied mid-turn does not immediately lose one duration")

	var control:=CombatTurnTimeline.new()
	control.add_actor(&"shadow",&"ally",100,CombatTurnTimeline.GAUGE_MAX)
	var active:=control.next_turn()
	_check(StringName(active.actor_id)==&"shadow","mid-turn control fixture opens Shadow's current action")
	_check(control.apply_control(&"shadow",CombatTurnTimeline.TAG_STUN,1,&"reaction_source"),"Stun can be queued during an already-open turn")
	_check(not bool(control.active_ticket().get("skipped",false)),"mid-turn Stun does not retroactively cancel the action already granted")
	control.end_turn(&"shadow")
	control.set_turn_meter(&"shadow",10000)
	var next_ticket:=control.next_turn()
	_check(bool(next_ticket.get("skipped",false)) and StringName(next_ticket.get("control_reason",&""))==CombatTurnTimeline.TAG_STUN,"mid-turn Stun survives to cancel the next owner turn")
	control.end_turn(&"shadow")

func _test_provoke_and_silence_contracts()->void:
	var timeline:=CombatTurnTimeline.new()
	timeline.add_actor(&"shadow",&"ally",100)
	timeline.add_actor(&"guard",&"enemy",90)
	_check(timeline.apply_provoke(&"shadow",&"guard",1),"Provoke applies a forced target")
	_check(timeline.forced_target_id(&"shadow")==&"guard","Provoke exposes the required target without owning targeting UI")
	_check(timeline.apply_silence(&"shadow",&"guard",2),"Silence applies")
	_check(timeline.active_skills_blocked(&"shadow"),"Silence blocks active skills while leaving the default attack available")

func _test_adversarial_turn_edges()->void:
	var controlled_extra:=CombatTurnTimeline.new()
	controlled_extra.add_actor(&"shadow",&"ally",100,CombatTurnTimeline.GAUGE_MAX)
	controlled_extra.add_actor(&"rat",&"enemy",100)
	var natural:=controlled_extra.next_turn()
	_check(StringName(natural.actor_id)==&"shadow","adversarial fixture opens Shadow natural turn")
	_check(controlled_extra.grant_extra_turn(&"shadow"),"extra turn can be queued during active turn")
	controlled_extra.end_turn(&"shadow")
	_check(controlled_extra.apply_control(&"shadow",CombatTurnTimeline.TAG_STUN,1,&"rat"),"Stun can land before queued extra turn")
	var stolen_extra:=controlled_extra.next_turn()
	_check(bool(stolen_extra.extra_turn) and bool(stolen_extra.skipped),"hard control consumes queued extra turn instead of bypassing CC")
	controlled_extra.end_turn(&"shadow")
	_check(not controlled_extra.has_tag(&"shadow",CombatTurnTimeline.TAG_STUN),"one-turn control expires after consuming extra owner turn")

	var overflow:=CombatTurnTimeline.new()
	overflow.add_actor(&"shadow",&"ally",100)
	overflow.add_actor(&"rat",&"enemy",100)
	overflow.set_turn_meter(&"shadow",30000)
	var o1:=_take(overflow)
	var o2:=_take(overflow)
	var o3:=_take(overflow)
	_check(StringName(o1.actor_id)==&"shadow" and StringName(o2.actor_id)==&"shadow" and StringName(o3.actor_id)==&"shadow","300% stored meter grants exactly three immediately available natural turns")
	_check(overflow.gauge(&"shadow")==0,"three stored turns fully consume the 300% overflow before natural time advances")
	var o4:=_take(overflow)
	var o5:=_take(overflow)
	_check(StringName(o4.actor_id)==&"shadow","after overflow is exhausted an equal-speed natural tie still uses stable registration order")
	_check(StringName(o5.actor_id)==&"rat","opponent receives its accumulated ready turn immediately after the post-overflow tie winner")

	var death_queue:=CombatTurnTimeline.new()
	death_queue.add_actor(&"shadow",&"ally",100,CombatTurnTimeline.GAUGE_MAX)
	death_queue.add_actor(&"rat",&"enemy",90)
	var open:=death_queue.next_turn()
	_check(StringName(open.actor_id)==&"shadow","death fixture opens Shadow ticket")
	death_queue.grant_extra_turn(&"shadow",2)
	_check(death_queue.set_alive(&"shadow",false),"actor can die while ticket and extra turns exist")
	_check(death_queue.active_ticket().is_empty() and (death_queue.snapshot().extra_turn_queue as Array).is_empty(),"death clears active ticket and queued extra turns")
	_check(StringName(death_queue.next_turn().actor_id)==&"rat","timeline continues with survivor after queued actor death")

	var sleep_dot:=CombatTurnTimeline.new()
	sleep_dot.add_actor(&"shadow",&"ally",100,CombatTurnTimeline.GAUGE_MAX)
	sleep_dot.apply_control(&"shadow",CombatTurnTimeline.TAG_SLEEP,2,&"caster")
	_check(sleep_dot.has_tag(&"shadow",CombatTurnTimeline.TAG_SLEEP),"Sleep begins active for periodic-damage fixture")
	var slept:=sleep_dot.next_turn()
	_check(bool(slept.skipped),"periodic damage contract does not implicitly wake Sleep")
	sleep_dot.end_turn(&"shadow")
	_check(sleep_dot.has_tag(&"shadow",CombatTurnTimeline.TAG_SLEEP),"Sleep remains after one skipped owner turn without active-damage wake")
