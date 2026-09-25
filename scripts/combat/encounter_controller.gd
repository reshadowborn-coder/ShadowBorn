class_name EncounterController
extends Node

signal encounter_started(id: String)
signal encounter_finished(id: String)
signal encounter_failed(id: String)
signal combat_state_changed(state: Dictionary)
signal shadow_attack_presented(skill: String, damage: float, target_guarded: bool)
signal enemy_attack_presented(damage: float)
signal enemy_beat_presented(action: String, damage: float)
signal command_committed(skill: String)
signal semantic_contact(actor: String, action: String)

const FRAY_BONUS := 1.15
const PRE_TEMPLE_SCRIPTS := {
	"hound": "ENC_HOUND_A1A2_V01",
	"armless": "ENC_ARMLESS_A1A2_V01",
	"shield_boss": "ENC_SHIELD_BRACE_V02_HP87_ATK20"
}

@export var pre_temple_veil_strength := 0.15

var active := false
var action_locked := false
var encounter_id := ""
var shadow := {}
var enemy := {}
var loadout: Dictionary = ShadowLoadout.profile("")
var pre_temple_mode := false
var pre_temple_model = null
var reduced_motion := false

func set_loadout(family: String) -> void:
	loadout = ShadowLoadout.profile(family)

func set_pre_temple_veil(value: float) -> void:
	pre_temple_veil_strength = clampf(value,0.0,0.95)

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value

func reset_shadow() -> void:
	shadow = {"hp":20.0,"max_hp":20.0,"atk":8.0,"def":4.0,"a2_cd":0,"veil":0.0,"fray":false,"poison_turns":0,"poison_damage":0.0}
	pre_temple_model = null
	pre_temple_mode = false

static func _valid_legacy_profile(profile:Dictionary)->bool:
	for key in ["hp","def","damage"]:
		var value=profile.get(key)
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
			return false
		var number:=float(value)
		if number!=number or is_inf(number):
			return false
	if float(profile.get("hp",0.0))<=0.0 or float(profile.get("def",0.0))<0.0 or float(profile.get("damage",0.0))<0.0:
		return false
	if profile.has("guard") and typeof(profile.get("guard"))!=TYPE_BOOL:
		return false
	if profile.has("poison_damage"):
		var poison_damage=profile.get("poison_damage")
		if typeof(poison_damage) not in [TYPE_INT,TYPE_FLOAT]:
			return false
		var poison_number:=float(poison_damage)
		if poison_number!=poison_number or is_inf(poison_number) or poison_number<0.0 or poison_number>10.0:
			return false
	if profile.has("poison_turns"):
		var poison_turns=profile.get("poison_turns")
		if typeof(poison_turns) not in [TYPE_INT,TYPE_FLOAT]:
			return false
		var turns_number:=float(poison_turns)
		if turns_number!=turns_number or is_inf(turns_number) or int(turns_number)<0 or int(turns_number)>10:
			return false
	return true

func start_encounter(id: String, profile: Dictionary) -> bool:
	if active or id.is_empty():
		return false
	encounter_id = id
	pre_temple_mode = PRE_TEMPLE_SCRIPTS.has(id)
	action_locked = false

	if pre_temple_mode:
		pre_temple_model = Ch00CombatModel.new()
		var script_id := str(PRE_TEMPLE_SCRIPTS[id])
		if not pre_temple_model.setup(script_id,pre_temple_veil_strength):
			push_error("Failed to initialize pre-Temple combat script: "+script_id)
			pre_temple_model = null
			pre_temple_mode = false
			encounter_id = ""
			return false
		_sync_pre_temple_snapshot()
	else:
		if not _valid_legacy_profile(profile):
			push_error("Rejected invalid encounter profile: "+id)
			encounter_id = ""
			return false
		reset_shadow()
		encounter_id = id
		enemy = profile.duplicate(true)
		enemy.max_hp = enemy.get("hp",10.0)
		if bool(enemy.get("guard",false)):
			enemy.guard = true
			enemy.guard_phase = "brace"

	active = true
	emit_signal("encounter_started",id)
	_emit_state()
	return true

func shadow_action(skill: String) -> void:
	if not active or action_locked or skill not in ["A1","A2"]:
		return
	if pre_temple_mode:
		_shadow_action_pre_temple(skill)
		return
	_shadow_action_legacy(skill)

func _wait(duration: float) -> void:
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout

func _shadow_action_pre_temple(skill: String) -> void:
	if skill == "A2" and int(shadow.get("a2_cd",0)) > 0:
		return
	action_locked = true
	emit_signal("command_committed",skill)
	_emit_state()

	var guarded := bool(enemy.get("guard",false))
	var result: Dictionary = pre_temple_model.step(skill)
	if result.has("error"):
		push_error("Pre-Temple combat step failed: "+str(result["error"]))
		action_locked = false
		_emit_state()
		return

	var dealt := float(result.get("outgoing_damage",0.0))
	var shadow_timing: Dictionary = CombatPresentationContract.shadow_timing(skill,reduced_motion)
	emit_signal("shadow_attack_presented",skill,dealt,guarded)
	await _wait(float(shadow_timing.get("contact",0.0)))
	if not active:
		action_locked = false
		return

	emit_signal("semantic_contact","shadow",skill)
	_apply_pre_temple_post_action(result)
	_emit_state()

	var terminal := str(result.get("terminal","CONTINUE"))
	await _wait(CombatPresentationContract.remainder_after_contact(shadow_timing))
	if terminal == "WIN":
		active = false
		action_locked = false
		emit_signal("encounter_finished",encounter_id)
		_emit_state()
		return

	await _wait(CombatPresentationContract.inter_beat_gap(reduced_motion))
	var enemy_action := str(result.get("enemy_action","NONE"))
	var incoming := float(result.get("incoming_damage",0.0))
	var enemy_timing: Dictionary = CombatPresentationContract.enemy_timing(enemy_action,reduced_motion)
	emit_signal("enemy_beat_presented",enemy_action,incoming)

	if incoming > 0.0:
		await _wait(float(enemy_timing.get("contact",0.0)))
		if not active:
			action_locked = false
			return
		emit_signal("semantic_contact","enemy",enemy_action)
		_sync_pre_temple_snapshot()
		_emit_state()
		await _wait(CombatPresentationContract.remainder_after_contact(enemy_timing))
	else:
		await _wait(float(enemy_timing.get("recovery_end",0.0)))
		if not active:
			action_locked = false
			return
		_sync_pre_temple_snapshot()
		_emit_state()

	if terminal == "LOSE" or float(shadow.get("hp",0.0)) <= 0.0:
		active = false
		action_locked = false
		_emit_state()
		emit_signal("encounter_failed",encounter_id)
		return

	action_locked = false
	_emit_state()

func _apply_pre_temple_post_action(result: Dictionary) -> void:
	shadow = Dictionary(result.get("post_action_shadow",shadow)).duplicate(true)
	enemy = Dictionary(result.get("post_action_enemy",enemy)).duplicate(true)

func _sync_pre_temple_snapshot() -> void:
	if pre_temple_model == null:
		return
	var snapshot: Dictionary = pre_temple_model.snapshot()
	shadow = Dictionary(snapshot.get("shadow",{})).duplicate(true)
	enemy = Dictionary(snapshot.get("enemy",{})).duplicate(true)

func _shadow_action_legacy(skill: String) -> void:
	if skill == "A2" and int(shadow.get("a2_cd",0)) > 0:
		return

	if int(shadow.get("poison_turns",0))>0:
		shadow.hp=maxf(0.0,float(shadow.hp)-float(shadow.get("poison_damage",0.0)))
		shadow.poison_turns=maxi(0,int(shadow.poison_turns)-1)
		if int(shadow.poison_turns)==0:
			shadow.poison_damage=0.0
		_emit_state()
		if float(shadow.hp)<=0.0:
			active=false
			emit_signal("encounter_failed",encounter_id)
			return

	action_locked = true
	emit_signal("command_committed",skill)
	_emit_state()

	var guarded := bool(enemy.get("guard",false))
	var coeff := float(loadout.get("a1_coeff",1.0))
	var guard_mult := float(loadout.get("a1_guard_mult",0.65))
	var veil_gain := 0.0
	var cooldown := 0
	var state_mult := 1.0

	if skill == "A2":
		coeff = float(loadout.get("a2_coeff",1.30))
		guard_mult = float(loadout.get("a2_guard_mult",0.55))
		veil_gain = float(loadout.get("a2_veil",0.15))
		cooldown = int(loadout.get("a2_cd",3))
		if bool(shadow.get("fray",false)):
			state_mult *= FRAY_BONUS
			shadow.fray = false
	else:
		shadow.fray = true

	if guarded:
		state_mult *= guard_mult

	var dealt := CombatResolver.damage(float(shadow.atk),coeff,float(enemy.def),state_mult)
	if skill == "A2":
		shadow.a2_cd = cooldown+1
		shadow.veil = veil_gain

	var shadow_timing: Dictionary = CombatPresentationContract.shadow_timing(skill,reduced_motion)
	emit_signal("shadow_attack_presented",skill,dealt,guarded)
	await _wait(float(shadow_timing.get("contact",0.0)))
	if not active:
		action_locked = false
		return

	emit_signal("semantic_contact","shadow",skill)
	enemy.hp -= dealt
	_emit_state()
	await _wait(CombatPresentationContract.remainder_after_contact(shadow_timing))

	if enemy.hp <= 0.0:
		active = false
		action_locked = false
		emit_signal("encounter_finished",encounter_id)
		_emit_state()
		return

	await _wait(CombatPresentationContract.inter_beat_gap(reduced_motion))
	var incoming := _prepare_enemy_turn_legacy()
	var enemy_timing: Dictionary = CombatPresentationContract.enemy_timing("ATTACK",reduced_motion)
	emit_signal("enemy_attack_presented",incoming)
	await _wait(float(enemy_timing.get("contact",0.0)))
	if not active:
		action_locked = false
		return

	emit_signal("semantic_contact","enemy","ATTACK")
	shadow.hp -= incoming
	var poison_damage:=float(enemy.get("poison_damage",0.0))
	var poison_turns:=int(enemy.get("poison_turns",0))
	if poison_damage>0.0 and poison_turns>0 and shadow.hp>0.0:
		shadow.poison_damage=maxf(float(shadow.get("poison_damage",0.0)),poison_damage)
		shadow.poison_turns=maxi(int(shadow.get("poison_turns",0)),poison_turns)
	if shadow.a2_cd > 0:
		shadow.a2_cd -= 1
	_emit_state()
	await _wait(CombatPresentationContract.remainder_after_contact(enemy_timing))

	if shadow.hp <= 0.0:
		active = false
		action_locked = false
		_emit_state()
		emit_signal("encounter_failed",encounter_id)
		return

	action_locked = false
	_emit_state()

func _prepare_enemy_turn_legacy() -> float:
	var incoming: float = enemy.get("damage",2.0)
	if shadow.veil > 0.0:
		incoming *= (1.0-shadow.veil)
		shadow.veil = 0.0
	if enemy.get("guard_phase","") == "brace":
		enemy.guard = false
		enemy.guard_phase = "open"
	return incoming

func _emit_state() -> void:
	emit_signal("combat_state_changed",{
		"active":active,
		"action_locked":action_locked,
		"encounter_id":encounter_id,
		"pre_temple_mode":pre_temple_mode,
		"shadow":shadow.duplicate(true),
		"enemy":enemy.duplicate(true),
		"loadout":loadout.duplicate(true)
	})
