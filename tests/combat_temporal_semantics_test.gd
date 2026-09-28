extends SceneTree

const Rules = preload("res://scripts/combat/battle_rules.gd")
const Battle = preload("res://scripts/combat/battle_controller.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_cd3_blocks_three_future_actionable_opportunities()
	await _test_hard_control_skip_does_not_refresh_cooldown()
	await _test_poison_ticks_before_hard_control()
	print("Combat temporal semantics tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)

func _test_cd3_blocks_three_future_actionable_opportunities() -> void:
	var cooldowns: Array = [0,0]
	cooldowns = Rules.resolve_action_cooldowns(cooldowns,1,3)
	_check(int(cooldowns[1]) == 3,"A2 CD3 is committed as three blocked future owner opportunities")
	_check(not Rules.cooldown_ready(cooldowns,1),"A2 is unavailable immediately after commit")

	cooldowns = Rules.resolve_action_cooldowns(cooldowns,0,0)
	_check(int(cooldowns[1]) == 2,"first later actionable owner turn consumes one cooldown opportunity")
	_check(not Rules.cooldown_ready(cooldowns,1),"A2 remains blocked after first later action")

	cooldowns = Rules.resolve_action_cooldowns(cooldowns,0,0)
	_check(int(cooldowns[1]) == 1,"second later actionable owner turn consumes one cooldown opportunity")
	_check(not Rules.cooldown_ready(cooldowns,1),"A2 remains blocked after second later action")

	cooldowns = Rules.resolve_action_cooldowns(cooldowns,0,0)
	_check(int(cooldowns[1]) == 0,"third later actionable owner turn consumes the final blocked opportunity")
	_check(Rules.cooldown_ready(cooldowns,1),"A2 becomes ready only for the fourth later owner opportunity")

func _test_hard_control_skip_does_not_refresh_cooldown() -> void:
	var battle := Battle.new()
	root.add_child(battle)
	battle.units = [battle._make_shadow(),battle._make_hound()]
	battle.running = true
	battle.turn_loop_generation = 1
	battle.battle_speed = 2.0
	battle._initialize_turn_scheduler()

	var shadow: Dictionary = battle.units[0]
	shadow["cooldowns"] = [0,3]
	var statuses: Dictionary = shadow.get("statuses",{})
	statuses["stun"] = 1
	shadow["statuses"] = statuses

	await battle._begin_turn(0)
	battle.running = false
	battle.turn_loop_generation += 1

	_check(int((shadow.get("cooldowns",[]) as Array)[1]) == 3,"Stun-skipped owner opportunity does not refresh A2 cooldown")
	_check(int((shadow.get("statuses",{}) as Dictionary).get("stun",0)) == 0,"one-turn Stun is consumed by the skipped owner opportunity")
	_check(not battle.waiting_for_player,"hard control never opens manual input")

	battle.queue_free()
	await process_frame

func _test_poison_ticks_before_hard_control() -> void:
	var battle := Battle.new()
	root.add_child(battle)
	battle.units = [battle._make_shadow(),battle._make_hound()]
	battle.running = true
	battle.turn_loop_generation = 1
	battle.battle_speed = 2.0
	battle._initialize_turn_scheduler()

	var shadow: Dictionary = battle.units[0]
	shadow["max_hp"] = 100
	shadow["hp"] = 100
	shadow["cooldowns"] = [0,3]
	var statuses: Dictionary = shadow.get("statuses",{})
	statuses["poison"] = 1
	statuses["stun"] = 1
	shadow["statuses"] = statuses

	await battle._begin_turn(0)
	battle.running = false
	battle.turn_loop_generation += 1

	_check(int(shadow.get("hp",0)) == 94,"Poison ticks at owner-turn start before hard-control legality")
	_check(int((shadow.get("statuses",{}) as Dictionary).get("poison",0)) == 0,"Poison duration advances on the controlled owner opportunity")
	_check(int((shadow.get("statuses",{}) as Dictionary).get("stun",0)) == 0,"Stun still consumes the same owner opportunity after Poison")
	_check(int((shadow.get("cooldowns",[]) as Array)[1]) == 3,"Poison plus Stun still does not refresh A2 cooldown")

	battle.queue_free()
	await process_frame

func _check(condition: bool,message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
