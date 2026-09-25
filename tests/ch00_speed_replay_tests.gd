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
	print("Chapter 0 equal-Speed replay tests complete. failures=%d"%failures)
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
