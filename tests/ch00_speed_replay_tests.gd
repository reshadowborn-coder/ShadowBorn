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
	_run_case(
		"ENC_HOUND_A1A2_V01",
		0.15,
		["A2","A1","A1","A1","A2"],
		"WIN",
		6.0847457627,
		"Hound observable Veil15"
	)
	_run_case(
		"ENC_ARMLESS_A1A2_V01",
		0.15,
		["A2","A1","A1","A1"],
		"WIN",
		11.1152542373,
		"Armless consolidation Veil15"
	)
	_run_case(
		"ENC_SHIELD_BRACE_V02_HP87_ATK20",
		0.15,
		["A1","A2","A1","A1","A1"],
		"WIN",
		9.1525423729,
		"Shield HOLD Veil15"
	)
	_run_case(
		"ENC_SHIELD_BRACE_V02_HP87_ATK20",
		0.20,
		["A1","A2","A1","A1","A1"],
		"WIN",
		10.0,
		"Shield HOLD Veil20"
	)
	_test_unequal_speed_opportunity_order()
	_test_shield_first_opportunity_gate()
	print("Chapter 0 Speed replay tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _run_case(
	script_id:String,
	veil:float,
	actions:Array,
	expected_terminal:String,
	expected_shadow_hp:float,
	label:String
)->void:
	var model:=Ch00CombatModel.new()
	_check(model.setup(script_id,veil),label+" model initializes")
	var timeline:=CombatTurnTimeline.new()
	_check(timeline.add_actor(&"shadow",&"ally",100),label+" Shadow scheduler actor registers")
	_check(timeline.add_actor(&"enemy",&"enemy",100),label+" enemy scheduler actor registers")
	var pair_index:=0
	for raw_action in actions:
		if str(model.snapshot().get("terminal","CONTINUE"))!="CONTINUE":
			break
		var shadow_ticket:=timeline.next_turn()
		_check(
			StringName(shadow_ticket.get("actor_id",&""))==&"shadow",
			label+" pair %d opens Shadow opportunity under equal Speed"%pair_index
		)
		var result:Dictionary=model.step(str(raw_action))
		_check(not result.has("error"),label+" pair %d action resolves"%pair_index)
		_check(timeline.end_turn(&"shadow"),label+" pair %d closes Shadow opportunity"%pair_index)
		if str(result.get("terminal","CONTINUE"))=="CONTINUE":
			var enemy_ticket:=timeline.next_turn()
			_check(
				StringName(enemy_ticket.get("actor_id",&""))==&"enemy",
				label+" pair %d exposes exactly one enemy opportunity before next Shadow decision"%pair_index
			)
			_check(timeline.end_turn(&"enemy"),label+" pair %d closes enemy opportunity"%pair_index)
		pair_index+=1

	var final_state:Dictionary=model.snapshot()
	_check(str(final_state.get("terminal",""))==expected_terminal,label+" terminal remains fixture-compatible")
	var shadow:Dictionary=final_state.get("shadow",{})
	_check(
		is_equal_approx(float(shadow.get("hp",0.0)),expected_shadow_hp),
		label+" ending HP remains fixture-compatible"
	)
	var next_ticket:=timeline.next_turn()
	if expected_terminal=="WIN":
		# Scheduler is diagnostic only here: it has no combat-life authority yet.
		# Its next ticket is intentionally ignored after the model reaches terminal.
		_check(not next_ticket.is_empty(),label+" scheduler remains deterministic after diagnostic replay")

func _test_unequal_speed_opportunity_order()->void:
	var fast_shadow:=CombatTurnTimeline.new()
	fast_shadow.add_actor(&"shadow",&"ally",200)
	fast_shadow.add_actor(&"enemy",&"enemy",100)
	var order:Array[StringName]=[]
	for _i in range(3):
		var ticket:=fast_shadow.next_turn()
		order.append(StringName(ticket.get("actor_id",&"")))
		fast_shadow.end_turn(StringName(ticket.get("actor_id",&"")))
	_check(order==[&"shadow",&"shadow",&"enemy"],"200:100 scheduler exposes two Shadow opportunities before the first enemy opportunity")

	var model:=Ch00CombatModel.new()
	_check(model.setup("ENC_HOUND_A1A2_V01",0.15),"fast-Shadow Hound model setup")
	var s1:Dictionary=model.begin_shadow_action("A1")
	var s2:Dictionary=model.begin_shadow_action("A1")
	_check(not s1.has("error") and not s2.has("error"),"split model accepts consecutive Shadow opportunities")
	_check(int(model.snapshot().get("decision",-1))==2 and int(model.snapshot().get("enemy_phase",-1))==0,"consecutive Shadow actions do not advance enemy phase")
	var e1:Dictionary=model.resolve_enemy_opportunity()
	_check(str(e1.get("enemy_action",""))=="BITE","first delayed enemy opportunity still resolves phase-zero Bite")

func _test_shield_first_opportunity_gate()->void:
	var enemy_first:=CombatTurnTimeline.new()
	enemy_first.add_actor(&"shadow",&"ally",100)
	enemy_first.add_actor(&"enemy",&"enemy",200)
	var first:=enemy_first.next_turn()
	_check(StringName(first.get("actor_id",&""))==&"enemy","diagnostic faster enemy can earn the first scheduler opportunity")

	var shield:=Ch00CombatModel.new()
	_check(shield.setup("ENC_SHIELD_BRACE_V02_HP87_ATK20",0.15),"Shield first-opportunity gate setup")
	_check(bool((shield.snapshot().get("enemy",{}) as Dictionary).get("guard",false)),"Shield starts with visible Guard")
	var exit:=shield.resolve_enemy_opportunity()
	_check(str(exit.get("enemy_action",""))=="BRACE_EXIT","an enemy-first opportunity consumes BRACE_EXIT")
	_check(not bool((shield.snapshot().get("enemy",{}) as Dictionary).get("guard",false)),"enemy-first cadence removes Guard before any Shadow command")
	_check(int(shield.snapshot().get("decision",-1))==0,"Guard can disappear with zero player decisions when enemy acts first")
