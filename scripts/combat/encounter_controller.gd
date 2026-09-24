class_name EncounterController
extends Node

signal encounter_started(id: String)
signal encounter_finished(id: String)
signal encounter_failed(id: String)
signal combat_state_changed(state: Dictionary)
signal shadow_attack_presented(skill: String, damage: float, target_guarded: bool)
signal enemy_attack_presented(damage: float)

const FRAY_BONUS := 1.15

var active := false
var action_locked := false
var encounter_id := ""
var shadow := {}
var enemy := {}
var loadout:Dictionary=ShadowLoadout.profile("")

func set_loadout(family:String)->void:
	loadout=ShadowLoadout.profile(family)

func reset_shadow() -> void:
	shadow = {"hp":20.0,"max_hp":20.0,"atk":8.0,"def":4.0,"a2_cd":0,"veil":0.0,"fray":false}

func start_encounter(id: String, profile: Dictionary) -> void:
	if active:
		return
	reset_shadow()
	encounter_id = id
	enemy = profile.duplicate(true)
	enemy.max_hp = enemy.get("hp", 10.0)
	active = true
	action_locked = false
	if bool(enemy.get("guard",false)):
		enemy.guard = true
		enemy.guard_phase = "brace"
	emit_signal("encounter_started", id)
	_emit_state()

func shadow_action(skill: String) -> void:
	if not active or action_locked:
		return
	if skill == "A2" and shadow.a2_cd > 0:
		return

	action_locked = true
	_emit_state()

	var guarded:=bool(enemy.get("guard",false))
	var coeff:=float(loadout.get("a1_coeff",1.0))
	var guard_mult:=float(loadout.get("a1_guard_mult",0.65))
	var veil_gain:=0.0
	var cooldown:=0
	var state_mult:=1.0

	if skill=="A2":
		coeff=float(loadout.get("a2_coeff",1.30))
		guard_mult=float(loadout.get("a2_guard_mult",0.55))
		veil_gain=float(loadout.get("a2_veil",0.15))
		cooldown=int(loadout.get("a2_cd",3))
		if bool(shadow.get("fray",false)):
			state_mult*=FRAY_BONUS
			shadow.fray=false
	else:
		shadow.fray=true

	if guarded:
		state_mult*=guard_mult

	var dealt:=CombatResolver.damage(float(shadow.atk),coeff,float(enemy.def),state_mult)
	if skill=="A2":
		shadow.a2_cd=cooldown+1
		shadow.veil=veil_gain

	emit_signal("shadow_attack_presented", skill, dealt, guarded)
	await get_tree().create_timer(0.34).timeout
	if not active:
		action_locked=false
		return

	enemy.hp -= dealt
	_emit_state()

	if enemy.hp <= 0.0:
		await get_tree().create_timer(0.28).timeout
		active = false
		action_locked = false
		emit_signal("encounter_finished", encounter_id)
		_emit_state()
		return

	await get_tree().create_timer(0.18).timeout
	var incoming := _prepare_enemy_turn()
	emit_signal("enemy_attack_presented", incoming)
	await get_tree().create_timer(0.30).timeout
	if not active:
		action_locked=false
		return

	shadow.hp -= incoming
	if shadow.a2_cd > 0:
		shadow.a2_cd -= 1

	if shadow.hp <= 0.0:
		active = false
		action_locked = false
		_emit_state()
		emit_signal("encounter_failed", encounter_id)
		return

	action_locked = false
	_emit_state()

func _prepare_enemy_turn() -> float:
	var incoming: float = enemy.get("damage", 2.0)
	if shadow.veil > 0.0:
		incoming *= (1.0 - shadow.veil)
		shadow.veil = 0.0
	if enemy.get("guard_phase", "") == "brace":
		enemy.guard = false
		enemy.guard_phase = "open"
	return incoming

func _emit_state() -> void:
	emit_signal("combat_state_changed", {
		"active":active,
		"action_locked":action_locked,
		"encounter_id":encounter_id,
		"shadow":shadow.duplicate(true),
		"enemy":enemy.duplicate(true),
		"loadout":loadout.duplicate(true)
	})
