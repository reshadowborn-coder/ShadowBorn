class_name EncounterController
extends Node

signal encounter_started(id: String)
signal encounter_finished(id: String)
signal encounter_failed(id: String)
signal combat_state_changed(state: Dictionary)
signal shadow_attack_presented(skill: String, damage: float, target_guarded: bool)
signal enemy_attack_presented(damage: float)

var active := false
var action_locked := false
var encounter_id := ""
var shadow := {}
var enemy := {}

func reset_shadow() -> void:
	shadow = {"hp":20.0,"max_hp":20.0,"atk":8.0,"def":4.0,"a2_cd":0,"veil":0.0,"fray":false}

func start_encounter(id: String, profile: Dictionary) -> void:
	if active:
		return
	# Each authored encounter is a discrete battle. Reset here so retry,
	# process restart, and uninterrupted play begin from the same HP/state.
	reset_shadow()
	encounter_id = id
	enemy = profile.duplicate(true)
	enemy.max_hp = enemy.get("hp", 10.0)
	active = true
	action_locked = false
	if id == "shield_boss":
		enemy.guard = true
		enemy.guard_phase = "brace"
	emit_signal("encounter_started", id)
	_emit_state()

func shadow_action(skill: String) -> void:
	if not active or action_locked: return
	if skill == "A2" and shadow.a2_cd > 0: return
	action_locked = true
	var result: Dictionary
	var guarded := enemy.get("guard", false)
	if skill == "A2":
		result = CombatResolver.resolve_a2(shadow, enemy)
		shadow.a2_cd = result.cooldown + 1
		shadow.veil = result.veil
	else:
		result = CombatResolver.resolve_a1(shadow, enemy)
		shadow.fray = true
	emit_signal("shadow_attack_presented", skill, result.damage, guarded)
	await get_tree().create_timer(0.34).timeout
	if not active: return
	enemy.hp -= result.damage
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
	if not active: return
	shadow.hp -= incoming
	if shadow.a2_cd > 0: shadow.a2_cd -= 1
	if shadow.hp <= 0.0:
		active = false
		action_locked = false
		emit_signal("encounter_failed", encounter_id)
	_emit_state()
	action_locked = false

func _prepare_enemy_turn() -> float:
	var incoming: float = enemy.get("damage", 2.0)
	if shadow.veil > 0.0:
		incoming *= (1.0 - shadow.veil)
		shadow.veil = 0.0
	if encounter_id == "shield_boss" and enemy.get("guard_phase", "") == "brace":
		enemy.guard = false
		enemy.guard_phase = "open"
	return incoming

func _emit_state() -> void:
	emit_signal("combat_state_changed", {"active":active,"action_locked":action_locked,"encounter_id":encounter_id,"shadow":shadow.duplicate(true),"enemy":enemy.duplicate(true)})
