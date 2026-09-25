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
var wave_index := -1
var auto_enabled := false
var battle_speed := 1.0
var waiting_for_player := false
var action_busy := false
var active_actor_index := -1
var running := false

var waves := [
	[
		{"id":"rat_01","name":"Sewer Rat","max_hp":72,"speed":44.0,"power":19.0,"defense":7.0,"kind":"rat"}
	],
	[
		{"id":"venom_01","name":"Venom Rat","max_hp":94,"speed":50.0,"power":18.0,"defense":8.0,"kind":"venom"}
	],
	[
		{"id":"rat_02","name":"Frenzied Rat","max_hp":138,"speed":55.0,"power":31.0,"defense":10.0,"kind":"rat"},
		{"id":"venom_02","name":"Plague Rat","max_hp":126,"speed":58.0,"power":27.0,"defense":9.0,"kind":"venom"}
	]
]

func start_battle() -> void:
	units.clear()
	units.append(_make_shadow())
	wave_index = -1
	running = true
	action_busy = false
	waiting_for_player = false
	_advance_wave()

func set_auto(value: bool) -> void:
	auto_enabled = value
	if waiting_for_player and auto_enabled and active_actor_index >= 0:
		waiting_for_player = false
		action_busy = true
		_execute_action(active_actor_index, _choose_auto_skill(active_actor_index))

func set_speed(multiplier: float) -> void:
	battle_speed = clampf(multiplier, 1.0, 2.0)

func request_player_skill(skill_index: int) -> void:
	if not running or not waiting_for_player or active_actor_index < 0:
		return
	var actor: Dictionary = units[active_actor_index]
	if str(actor.get("id", "")) != PLAYER_ID:
		return
	var cooldowns: Array = actor.get("cooldowns", [0,0])
	if skill_index < 0 or skill_index >= cooldowns.size():
		return
	if int(cooldowns[skill_index]) > 0:
		return
	waiting_for_player = false
	action_busy = true
	_execute_action(active_actor_index, skill_index)

func _process(delta: float) -> void:
	if not running or action_busy or waiting_for_player:
		return
	if BattleRules.living_count(units, ENEMY_TEAM) == 0:
		_advance_wave()
		return
	if BattleRules.living_count(units, PLAYER_TEAM) == 0:
		_finish_battle(false)
		return
	for unit in units:
		if int(unit.get("hp",0)) <= 0:
			continue
		unit["meter"] = minf(160.0, float(unit.get("meter",0.0)) + float(unit.get("speed",0.0)) * delta * 1.14 * battle_speed)
	var ready := _find_ready_actor()
	if ready >= 0:
		_begin_turn(ready)
	elif Engine.get_process_frames() % 8 == 0:
		_emit_state()

func _find_ready_actor() -> int:
	var chosen := -1
	var best_meter := 99.999
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		if int(unit.get("hp",0)) <= 0:
			continue
		var meter := float(unit.get("meter",0.0))
		if meter >= 100.0 and meter > best_meter:
			best_meter = meter
			chosen = i
	return chosen

func _begin_turn(index: int) -> void:
	if index < 0 or index >= units.size() or action_busy:
		return
	action_busy = true
	active_actor_index = index
	var actor: Dictionary = units[index]
	actor["meter"] = maxf(0.0, float(actor.get("meter",100.0)) - 100.0)
	_tick_cooldowns(actor)

	var poison_damage := BattleRules.poison_tick(actor)
	if poison_damage > 0:
		battle_message.emit("%s suffers %d poison damage" % [actor["name"], poison_damage])
		if int(actor["hp"]) <= 0:
			actor_died.emit(str(actor["id"]))
			_finish_turn()
			return

	var skipped := BattleRules.consume_control(actor.get("statuses",{}))
	if not skipped.is_empty():
		battle_message.emit("%s loses the turn: %s" % [actor["name"], skipped.to_upper()])
		await get_tree().create_timer(0.34 / battle_speed).timeout
		_finish_turn()
		return

	if str(actor.get("team","")) == PLAYER_TEAM and not auto_enabled:
		waiting_for_player = true
		action_busy = false
		actor_ready.emit(str(actor["id"]))
		_emit_state()
		return

	_execute_action(index, _choose_auto_skill(index))

func _execute_action(attacker_index: int, skill_index: int) -> void:
	action_busy = true
	waiting_for_player = false
	if attacker_index < 0 or attacker_index >= units.size():
		_finish_turn()
		return
	var attacker: Dictionary = units[attacker_index]
	var enemy_team := ENEMY_TEAM if str(attacker["team"]) == PLAYER_TEAM else PLAYER_TEAM
	var target_index := BattleRules.choose_first_alive(units, enemy_team)
	if target_index < 0:
		_finish_turn()
		return
	var target: Dictionary = units[target_index]
	var skill := _skill_for(attacker, skill_index)
	var skill_id := str(skill["id"])
	action_windup.emit(str(attacker["id"]), str(target["id"]), skill_id)
	await get_tree().create_timer(float(skill["windup"]) / battle_speed).timeout

	var damage := BattleRules.compute_damage(float(attacker["power"]), float(skill["multiplier"]), float(target["defense"]))
	var actual := BattleRules.apply_damage(target, damage)
	var effect := ""
	if str(skill.get("effect","")) == "poison" and int(target["hp"]) > 0:
		var statuses: Dictionary = target.get("statuses",{})
		statuses["poison"] = maxi(int(statuses.get("poison",0)), 2)
		target["statuses"] = statuses
		effect = "POISON"
	if str(skill.get("effect","")) == "turn_cut" and int(target["hp"]) > 0:
		target["meter"] = maxf(0.0, float(target.get("meter",0.0)) - 28.0)
		effect = "TURN METER -28"

	if skill_index > 0:
		var cooldowns: Array = attacker.get("cooldowns",[0,0])
		cooldowns[skill_index] = int(skill.get("cooldown",0))
		attacker["cooldowns"] = cooldowns

	action_impact.emit(str(attacker["id"]), str(target["id"]), skill_id, actual, effect)
	_emit_state()
	await get_tree().create_timer(float(skill["recover"]) / battle_speed).timeout
	if int(target["hp"]) <= 0:
		actor_died.emit(str(target["id"]))
	_finish_turn()

func _finish_turn() -> void:
	active_actor_index = -1
	waiting_for_player = false
	action_busy = false
	_emit_state()

func _advance_wave() -> void:
	if action_busy:
		return
	wave_index += 1
	if wave_index >= waves.size():
		_finish_battle(true)
		return
	action_busy = true
	var player: Dictionary = units[0] if not units.is_empty() else _make_shadow()
	units = [player]
	var specs: Array = waves[wave_index]
	for spec_variant in specs:
		var spec: Dictionary = spec_variant
		units.append(_make_enemy(spec))
	for unit in units:
		unit["meter"] = 0.0
	battle_message.emit("WAVE %d / %d" % [wave_index + 1, waves.size()])
	_emit_state()
	await get_tree().create_timer(0.72 / battle_speed).timeout
	action_busy = false

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
	if str(actor.get("kind","")) == "venom" and cooldowns.size() > 1 and int(cooldowns[1]) == 0:
		return 1
	return 0

func _skill_for(actor: Dictionary, skill_index: int) -> Dictionary:
	if str(actor["team"]) == PLAYER_TEAM:
		if skill_index == 1:
			return {"id":"shadow_lunge","multiplier":1.72,"cooldown":3,"windup":0.27,"recover":0.34,"effect":"turn_cut"}
		return {"id":"basic_slash","multiplier":1.00,"cooldown":0,"windup":0.20,"recover":0.25,"effect":""}
	if str(actor.get("kind","")) == "venom" and skill_index == 1:
		return {"id":"venom_bite","multiplier":0.82,"cooldown":2,"windup":0.22,"recover":0.26,"effect":"poison"}
	return {"id":"rat_bite","multiplier":1.00,"cooldown":0,"windup":0.18,"recover":0.23,"effect":""}

func _tick_cooldowns(actor: Dictionary) -> void:
	var cooldowns: Array = actor.get("cooldowns",[0,0])
	for i in range(cooldowns.size()):
		cooldowns[i] = maxi(0, int(cooldowns[i]) - 1)
	actor["cooldowns"] = cooldowns

func _make_shadow() -> Dictionary:
	return {
		"id":PLAYER_ID,"name":"Shadow","team":PLAYER_TEAM,"kind":"shadow",
		"max_hp":220,"hp":220,"speed":52.0,"power":34.0,"defense":15.0,
		"meter":0.0,"cooldowns":[0,0],"statuses":{"poison":0,"stun":0,"freeze":0,"sleep":0}
	}

func _make_enemy(spec: Dictionary) -> Dictionary:
	return {
		"id":str(spec["id"]),"name":str(spec["name"]),"team":ENEMY_TEAM,"kind":str(spec["kind"]),
		"max_hp":int(spec["max_hp"]),"hp":int(spec["max_hp"]),"speed":float(spec["speed"]),
		"power":float(spec["power"]),"defense":float(spec["defense"]),
		"meter":0.0,"cooldowns":[0,0],"statuses":{"poison":0,"stun":0,"freeze":0,"sleep":0}
	}

func _emit_state() -> void:
	state_changed.emit({
		"wave":wave_index + 1,
		"wave_count":waves.size(),
		"units":units.duplicate(true),
		"auto":auto_enabled,
		"speed":battle_speed,
		"player_ready":waiting_for_player,
		"running":running
	})
