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

var units: Array[Dictionary] = []
var auto_enabled := false
var battle_speed := 1.0
var waiting_for_player := false
var action_busy := false
var active_actor_index := -1
var running := false

func start_battle() -> void:
	units = [_make_shadow(), _make_hound()]
	running = true
	action_busy = true
	waiting_for_player = false
	active_actor_index = -1
	battle_message.emit("FIRST ENCOUNTER")
	_emit_state()
	await get_tree().create_timer(0.9).timeout
	action_busy = false

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
	if skill_index < 0 or skill_index >= cooldowns.size() or int(cooldowns[skill_index]) > 0:
		return
	waiting_for_player = false
	action_busy = true
	_execute_action(active_actor_index,skill_index)

func _process(delta: float) -> void:
	if not running or action_busy or waiting_for_player:
		return
	if BattleRules.living_count(units,ENEMY_TEAM) == 0:
		_finish_battle(true)
		return
	if BattleRules.living_count(units,PLAYER_TEAM) == 0:
		_finish_battle(false)
		return

	for unit in units:
		if int(unit.get("hp",0)) <= 0:
			continue
		unit["meter"] = minf(160.0,float(unit.get("meter",0.0))+float(unit.get("speed",0.0))*delta*1.10*battle_speed)

	var ready := _find_ready_actor()
	if ready >= 0:
		_begin_turn(ready)
	elif Engine.get_process_frames() % 6 == 0:
		_emit_state()

func _find_ready_actor() -> int:
	var chosen := -1
	var best := 99.999
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		if int(unit.get("hp",0)) <= 0:
			continue
		var meter := float(unit.get("meter",0.0))
		if meter >= 100.0 and meter > best:
			best = meter
			chosen = i
	return chosen

func _begin_turn(index: int) -> void:
	if action_busy:
		return
	action_busy = true
	active_actor_index = index
	var actor: Dictionary = units[index]
	actor["meter"] = maxf(0.0,float(actor.get("meter",100.0))-100.0)
	_tick_cooldowns(actor)

	var skipped := BattleRules.consume_control(actor.get("statuses",{}))
	if not skipped.is_empty():
		battle_message.emit("%s loses the turn: %s" % [actor["name"],skipped.to_upper()])
		await get_tree().create_timer(0.32/battle_speed).timeout
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
	await get_tree().create_timer(float(skill["windup"])/battle_speed).timeout

	var damage := BattleRules.compute_damage(float(attacker["power"]),float(skill["multiplier"]),float(target["defense"]))
	var actual := BattleRules.apply_damage(target,damage)
	var effect := ""
	if str(skill.get("effect","")) == "turn_cut" and int(target["hp"]) > 0:
		target["meter"] = maxf(0.0,float(target.get("meter",0.0))-30.0)
		effect = "TURN METER -30"

	if skill_index > 0:
		var cooldowns: Array = attacker.get("cooldowns",[0,0])
		cooldowns[skill_index] = int(skill.get("cooldown",0))
		attacker["cooldowns"] = cooldowns

	action_impact.emit(str(attacker["id"]),str(target["id"]),skill_id,actual,effect)
	_emit_state()
	await get_tree().create_timer(float(skill["recover"])/battle_speed).timeout

	if int(target["hp"]) <= 0:
		actor_died.emit(str(target["id"]))
		await get_tree().create_timer(0.55/battle_speed).timeout
	_finish_turn()

func _finish_turn() -> void:
	active_actor_index = -1
	waiting_for_player = false
	action_busy = false
	_emit_state()

func _finish_battle(victory: bool) -> void:
	if not running:
		return
	running = false
	action_busy = true
	waiting_for_player = false
	_emit_state()
	battle_finished.emit(victory)

func _choose_auto_skill(index: int) -> int:
	var actor: Dictionary = units[index]
	var cooldowns: Array = actor.get("cooldowns",[0,0])
	if str(actor["team"]) == PLAYER_TEAM and cooldowns.size() > 1 and int(cooldowns[1]) == 0:
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

func _tick_cooldowns(actor: Dictionary) -> void:
	var cooldowns: Array = actor.get("cooldowns",[0,0])
	for i in range(cooldowns.size()):
		cooldowns[i] = maxi(0,int(cooldowns[i])-1)
	actor["cooldowns"] = cooldowns

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
