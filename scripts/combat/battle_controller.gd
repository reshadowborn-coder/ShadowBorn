class_name BattleController
extends Node

signal state_changed(snapshot: Dictionary)
signal actor_ready(actor_id: String)
signal action_windup(attacker_id: String, target_id: String, skill_id: String)
signal action_impact(attacker_id: String, target_id: String, skill_id: String, damage: int, effect: String)
signal actor_died(actor_id: String)
signal battle_message(text: String)
signal battle_finished(victory: bool)

const PLAYER_TEAM := "player"
const ENEMY_TEAM := "enemy"
const PLAYER_ID := "shadow"
const TurnScheduler = preload("res://scripts/combat/battle_turn_scheduler.gd")

var units: Array[Dictionary] = []
var auto_enabled := false
var battle_speed := 1.0
var waiting_for_player := false
var action_busy := false
var active_actor_index := -1
var running := false
var turn_scheduler := TurnScheduler.new()
var turn_loop_generation := 0

func start_battle() -> void:
	units = [_make_shadow(), _make_hound()]
	turn_loop_generation += 1
	_initialize_turn_scheduler()
	running = true
	action_busy = true
	waiting_for_player = false
	active_actor_index = -1
	battle_message.emit("FIRST ENCOUNTER")
	_emit_state()
	var generation := turn_loop_generation
	await _wait_presentation_time(0.9,generation,false)
	if not running or generation != turn_loop_generation:
		return
	action_busy = false
	call_deferred("_schedule_next_turn")

func set_auto(value: bool) -> void:
	auto_enabled = value
	if waiting_for_player and auto_enabled and active_actor_index >= 0:
		waiting_for_player = false
		action_busy = true
		_execute_action(active_actor_index,_choose_auto_skill(active_actor_index))

func set_speed(multiplier: float) -> void:
	battle_speed = clampf(multiplier,1.0,2.0)

func request_player_skill(skill_index: int) -> void:
	if not running or not waiting_for_player or active_actor_index < 0:
		return
	var actor: Dictionary = units[active_actor_index]
	if str(actor.get("id","")) != PLAYER_ID:
		return
	var cooldowns: Array = actor.get("cooldowns",[0,0])
	if not BattleRules.cooldown_ready(cooldowns,skill_index):
		return
	waiting_for_player = false
	action_busy = true
	_execute_action(active_actor_index,skill_index)

func _schedule_next_turn() -> void:
	if not running or action_busy or waiting_for_player:
		return
	if BattleRules.living_count(units,ENEMY_TEAM) == 0:
		_finish_battle(true)
		return
	if BattleRules.living_count(units,PLAYER_TEAM) == 0:
		_finish_battle(false)
		return

	var event: Dictionary = turn_scheduler.next_event()
	if event.is_empty():
		return
	_sync_units_from_scheduler()
	_emit_state()

	# The semantic winner is already fixed by the scheduler. This wait is presentation
	# pacing only, so render cadence and x1/x2 cannot change who owns the next turn.
	action_busy = true
	var generation := turn_loop_generation
	var wait_seconds := float(event.get("wait_seconds_1x",0.0))
	await _wait_presentation_time(wait_seconds,generation)
	if not running or generation != turn_loop_generation:
		return

	var actor_id := str(event.get("actor_id",""))
	var index := _unit_index_for_id(actor_id)
	if index < 0 or int(units[index].get("hp",0)) <= 0:
		action_busy = false
		call_deferred("_schedule_next_turn")
		return

	action_busy = false
	_begin_turn(index)

func _wait_presentation_time(seconds_1x: float,generation: int,scale_with_battle_speed: bool = true) -> void:
	var remaining := maxf(0.0,seconds_1x)
	while remaining > 0.0001 and running and generation == turn_loop_generation:
		var speed_scale := maxf(1.0,battle_speed) if scale_with_battle_speed else 1.0
		var wall_slice := minf(0.05,remaining/speed_scale)
		# process_always=false is deliberate: SceneTree pause must freeze battle time.
		# Never subtract Time.get_ticks_usec() here; suspended/background wall time
		# is not gameplay time and would otherwise skip the remaining action phase.
		await get_tree().create_timer(wall_slice,false).timeout
		remaining = maxf(0.0,remaining-wall_slice*speed_scale)

func _initialize_turn_scheduler() -> void:
	turn_scheduler.reset()
	for unit in units:
		var id := StringName(str(unit.get("id","")))
		var speed_value := maxi(1,int(round(float(unit.get("speed",1.0)))))
		var initial_meter_bp := clampi(int(round(float(unit.get("meter",0.0))*100.0)),0,TurnScheduler.MAX_GAUGE)
		turn_scheduler.add_actor(id,speed_value,initial_meter_bp)
	_sync_units_from_scheduler()

func _sync_units_from_scheduler() -> void:
	for unit in units:
		var id := StringName(str(unit.get("id","")))
		if turn_scheduler.has_actor(id):
			unit["meter"] = float(turn_scheduler.gauge_bp(id))/100.0

func _unit_index_for_id(actor_id: String) -> int:
	for i in range(units.size()):
		if str(units[i].get("id","")) == actor_id:
			return i
	return -1

func _begin_turn(index: int) -> void:
	if action_busy:
		return
	action_busy = true
	active_actor_index = index
	var actor: Dictionary = units[index]

	var skipped := BattleRules.consume_control(actor.get("statuses",{}))
	if not skipped.is_empty():
		battle_message.emit("%s loses the turn: %s" % [actor["name"],skipped.to_upper()])
		var generation := turn_loop_generation
		await _wait_presentation_time(0.32,generation)
		if not running or generation != turn_loop_generation:
			return
		_finish_turn()
		return

	if str(actor.get("team","")) == PLAYER_TEAM and not auto_enabled:
		waiting_for_player = true
		action_busy = false
		actor_ready.emit(str(actor["id"]))
		battle_message.emit("YOUR TURN")
		_emit_state()
		return

	_execute_action(index,_choose_auto_skill(index))

func _execute_action(attacker_index: int, skill_index: int) -> void:
	action_busy = true
	waiting_for_player = false
	var attacker: Dictionary = units[attacker_index]
	var enemy_team := ENEMY_TEAM if str(attacker["team"]) == PLAYER_TEAM else PLAYER_TEAM
	var target_index := BattleRules.choose_first_alive(units,enemy_team)
	if target_index < 0:
		_finish_turn()
		return
	var target: Dictionary = units[target_index]
	var skill := _skill_for(attacker,skill_index)
	var skill_id := str(skill["id"])

	action_windup.emit(str(attacker["id"]),str(target["id"]),skill_id)
	var generation := turn_loop_generation
	await _wait_presentation_time(float(skill["windup"]),generation)
	if not running or generation != turn_loop_generation:
		return

	var damage := BattleRules.compute_damage(float(attacker["power"]),float(skill["multiplier"]),float(target["defense"]))
	var actual := BattleRules.apply_damage(target,damage)
	var effect := ""
	if str(skill.get("effect","")) == "turn_cut" and int(target["hp"]) > 0:
		turn_scheduler.adjust_gauge_bp(StringName(str(target["id"])),-3000)
		_sync_units_from_scheduler()
		effect = "TURN METER -30"

	attacker["cooldowns"] = BattleRules.resolve_action_cooldowns(
		attacker.get("cooldowns",[0,0]),
		skill_index,
		int(skill.get("cooldown",0))
	)

	action_impact.emit(str(attacker["id"]),str(target["id"]),skill_id,actual,effect)
	_emit_state()
	await _wait_presentation_time(float(skill["recover"]),generation)
	if not running or generation != turn_loop_generation:
		return

	if int(target["hp"]) <= 0:
		turn_scheduler.set_alive(StringName(str(target["id"])),false)
		_sync_units_from_scheduler()
		actor_died.emit(str(target["id"]))
		await _wait_presentation_time(0.55,generation)
		if not running or generation != turn_loop_generation:
			return
	_finish_turn()

func _finish_turn() -> void:
	active_actor_index = -1
	waiting_for_player = false
	action_busy = false
	_sync_units_from_scheduler()
	_emit_state()
	call_deferred("_schedule_next_turn")

func _finish_battle(victory: bool) -> void:
	if not running:
		return
	running = false
	turn_loop_generation += 1
	action_busy = true
	waiting_for_player = false
	_emit_state()
	battle_finished.emit(victory)

func _choose_auto_skill(index: int) -> int:
	var actor: Dictionary = units[index]
	var cooldowns: Array = actor.get("cooldowns",[0,0])
	if str(actor["team"]) == PLAYER_TEAM and cooldowns.size() > 1 and BattleRules.cooldown_ready(cooldowns,1):
		return 1
	return 0

func _skill_for(actor: Dictionary, skill_index: int) -> Dictionary:
	if str(actor["team"]) == PLAYER_TEAM:
		if skill_index == 1:
			return {"id":"shadow_lunge","multiplier":1.72,"cooldown":3,"windup":0.72,"recover":0.72,"effect":"turn_cut"}
		return {"id":"basic_slash","multiplier":1.0,"cooldown":0,"windup":0.38,"recover":0.48,"effect":""}
	if skill_index == 1:
		return {"id":"hound_rend","multiplier":1.28,"cooldown":2,"windup":0.52,"recover":0.62,"effect":""}
	return {"id":"hound_bite","multiplier":1.0,"cooldown":0,"windup":0.52,"recover":0.62,"effect":""}

func _make_shadow() -> Dictionary:
	return {
		"id":"shadow","name":"Shadow","team":"player","kind":"shadow",
		"max_hp":210,"hp":210,"speed":53.0,"power":31.0,"defense":15.0,
		"meter":18.0,"cooldowns":[0,0],"statuses":{"poison":0,"stun":0,"freeze":0,"sleep":0}
	}

func _make_hound() -> Dictionary:
	return {
		"id":"grave_hound","name":"Grave Hound","team":"enemy","kind":"hound",
		"max_hp":118,"hp":118,"speed":45.0,"power":22.0,"defense":8.0,
		"meter":0.0,"cooldowns":[0,0],"statuses":{"poison":0,"stun":0,"freeze":0,"sleep":0}
	}

func _emit_state() -> void:
	state_changed.emit({
		"wave":1,
		"wave_count":1,
		"units":units.duplicate(true),
		"auto":auto_enabled,
		"speed":battle_speed,
		"player_ready":waiting_for_player,
		"running":running
	})
