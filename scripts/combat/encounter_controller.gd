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
const SHADOW_BASE_SPEED := 100
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
var turn_meter_mode_enabled := false
var turn_timeline := CombatTurnTimeline.new()
var current_turn:Dictionary = {}
var encounter_generation := 0
var shadow_completed_turns := 0

# New turn-first effect contracts are authoritative for migrated effects.
# Legacy poison_* dictionary fields remain a compatibility projection for
# existing HUD/tests while the rest of combat migrates incrementally.
var _shadow_effects:Dictionary = {}
var _shadow_tags:CombatTagLedger = CombatTagLedger.new()
var _effect_transaction_id:=0

func set_loadout(family: String) -> void:
	loadout = ShadowLoadout.profile(family)

func set_pre_temple_veil(value: float) -> void:
	pre_temple_veil_strength = clampf(value,0.0,0.95)

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value

func set_turn_meter_mode_enabled(value: bool) -> void:
	turn_meter_mode_enabled = value

func _next_effect_transaction_id()->int:
	_effect_transaction_id+=1
	return _effect_transaction_id

func _clear_shadow_effects()->void:
	_shadow_effects.clear()
	_shadow_tags.clear()
	_effect_transaction_id=0

func _poison_definition(turns:int)->CombatEffectDefinition:
	var definition:=CombatEffectDefinition.new()
	definition.id=&"Status.Poison"
	definition.semantic_tags.assign([&"Status.Poison"])
	definition.duration_policy=CombatEffectDefinition.DurationPolicy.TURN_BASED
	definition.base_duration_turns=maxi(1,turns)
	definition.max_stacks=1
	definition.stacking_policy=CombatEffectDefinition.StackingPolicy.REFRESH
	definition.base_magnitudes={"damage_per_turn":0.0}
	definition.cue_ids.assign([&"Cue.Poison.Apply",&"Cue.Poison.Tick"])
	return definition

func _sync_shadow_effect_compatibility_view()->void:
	var spec=_shadow_effects.get(&"Status.Poison")
	if spec is CombatEffectSpec:
		shadow.poison_turns=maxi(0,(spec as CombatEffectSpec).remaining_turns)
		shadow.poison_damage=maxf(0.0,float((spec as CombatEffectSpec).runtime_magnitudes.get("damage_per_turn",0.0)))
	else:
		shadow.poison_turns=0
		shadow.poison_damage=0.0

func _apply_shadow_poison(damage:float,turns:int,source_actor:StringName)->void:
	if damage<=0.0 or turns<=0 or source_actor==&"":
		return
	var effect_id:=&"Status.Poison"
	var spec=_shadow_effects.get(effect_id)
	if not (spec is CombatEffectSpec):
		var context:=CombatEffectContext.new(source_actor,&"shadow",0,_next_effect_transaction_id())
		context.source_skill_id=&"enemy_poison_attack"
		spec=_poison_definition(turns).create_spec(context)
		(spec as CombatEffectSpec).runtime_magnitudes["damage_per_turn"]=damage
		_shadow_effects[effect_id]=spec
		_shadow_tags.add(effect_id,source_actor)
	else:
		# Preserve the existing authored Act 1 rule exactly: reapplication keeps
		# the stronger damage value and the longer remaining duration.
		(spec as CombatEffectSpec).remaining_turns=maxi((spec as CombatEffectSpec).remaining_turns,turns)
		(spec as CombatEffectSpec).runtime_magnitudes["damage_per_turn"]=maxf(
			float((spec as CombatEffectSpec).runtime_magnitudes.get("damage_per_turn",0.0)),
			damage
		)
	_sync_shadow_effect_compatibility_view()

func _tick_shadow_poison()->float:
	var effect_id:=&"Status.Poison"
	var spec=_shadow_effects.get(effect_id)
	if not (spec is CombatEffectSpec):
		_sync_shadow_effect_compatibility_view()
		return 0.0
	var poison:=spec as CombatEffectSpec
	var before:=float(shadow.get("hp",0.0))
	var damage:=maxf(0.0,float(poison.runtime_magnitudes.get("damage_per_turn",0.0)))
	shadow.hp=maxf(0.0,before-damage)
	var actual_delta:=float(shadow.hp)-before
	poison.calculated_deltas.clear()
	poison.record_delta(&"Health",actual_delta)
	poison.advance_turn()
	if poison.is_expired():
		var source:=poison.context.source_actor_id
		var contribution_count:=_shadow_tags.source_count(effect_id,source)
		if contribution_count>0:
			_shadow_tags.remove(effect_id,source,contribution_count)
		_shadow_effects.erase(effect_id)
	_sync_shadow_effect_compatibility_view()
	return -actual_delta

func reset_shadow() -> void:
	_clear_shadow_effects()
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
	encounter_generation += 1
	shadow_completed_turns = 0
	current_turn.clear()
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
	if turn_meter_mode_enabled and not pre_temple_mode:
		_setup_turn_meter()
		action_locked = true
	emit_signal("encounter_started",id)
	_emit_state()
	if turn_meter_mode_enabled and not pre_temple_mode:
		call_deferred("_advance_turn_meter",encounter_generation)
	return true

func shadow_action(skill: String) -> void:
	if not active or action_locked or skill not in ["A1","A2"]:
		return
	if pre_temple_mode:
		_shadow_action_pre_temple(skill)
		return
	if turn_meter_mode_enabled:
		_shadow_action_turn_meter(skill)
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

func _turn_meter_valid(generation:int)->bool:
	return generation==encounter_generation and active and is_inside_tree()

func _setup_turn_meter()->void:
	turn_timeline.reset()
	turn_timeline.add_actor(&"shadow",&"ally",SHADOW_BASE_SPEED)
	turn_timeline.add_actor(
		StringName(encounter_id),
		&"enemy",
		maxi(1,int(enemy.get("speed",90)))
	)

func apply_turn_control(
	actor_id:StringName,
	control_tag:StringName,
	turns:int,
	source_id:StringName=&""
)->bool:
	if not turn_meter_mode_enabled:
		return false
	return turn_timeline.apply_control(actor_id,control_tag,turns,source_id)

func apply_turn_speed_modifier(
	actor_id:StringName,
	source_id:StringName,
	percent_bp:int,
	turns:int
)->bool:
	if not turn_meter_mode_enabled:
		return false
	return turn_timeline.apply_speed_modifier(actor_id,source_id,percent_bp,turns)

func apply_turn_silence(actor_id:StringName,source_id:StringName,turns:int)->bool:
	if not turn_meter_mode_enabled:
		return false
	return turn_timeline.apply_silence(actor_id,source_id,turns)

func apply_turn_provoke(actor_id:StringName,source_actor_id:StringName,turns:int)->bool:
	if not turn_meter_mode_enabled:
		return false
	return turn_timeline.apply_provoke(actor_id,source_actor_id,turns)

func adjust_turn_meter(actor_id:StringName,delta_bp:int)->bool:
	if not turn_meter_mode_enabled:
		return false
	return turn_timeline.adjust_turn_meter(actor_id,delta_bp)

func grant_extra_turn(actor_id:StringName,count:int=1)->bool:
	if not turn_meter_mode_enabled:
		return false
	return turn_timeline.grant_extra_turn(actor_id,count)

func _advance_turn_meter(generation:int)->void:
	while _turn_meter_valid(generation):
		var ticket:=turn_timeline.next_turn()
		if ticket.is_empty():
			return
		current_turn=ticket.duplicate(true)
		action_locked=true
		_emit_state()
		var actor_id:=StringName(ticket.get("actor_id",&""))

		if actor_id==&"shadow":
			var poison_tick:=_tick_shadow_poison()
			if poison_tick>0.0:
				_emit_state()
			if float(shadow.get("hp",0.0))<=0.0:
				active=false
				action_locked=false
				current_turn.clear()
				_emit_state()
				emit_signal("encounter_failed",encounter_id)
				return

		if bool(ticket.get("skipped",false)):
			await _wait(.04 if reduced_motion else .16)
			if not _turn_meter_valid(generation):
				return
			turn_timeline.end_turn(actor_id)
			current_turn.clear()
			continue

		if actor_id==&"shadow":
			if shadow_completed_turns>0 and int(shadow.get("a2_cd",0))>0 and bool(ticket.get("cooldowns_advance",true)):
				shadow.a2_cd=maxi(0,int(shadow.a2_cd)-1)
			action_locked=false
			_emit_state()
			return

		await _enemy_turn_meter(generation)
		if not _turn_meter_valid(generation):
			return
		turn_timeline.end_turn(actor_id)
		current_turn.clear()
		if float(shadow.get("hp",0.0))<=0.0:
			active=false
			action_locked=false
			_emit_state()
			emit_signal("encounter_failed",encounter_id)
			return

func _shadow_action_turn_meter(skill:String)->void:
	if StringName(current_turn.get("actor_id",&""))!=&"shadow":
		return
	if skill!="A1" and turn_timeline.active_skills_blocked(&"shadow"):
		return
	if skill=="A2" and int(shadow.get("a2_cd",0))>0:
		return
	var generation:=encounter_generation
	action_locked=true
	emit_signal("command_committed",skill)
	_emit_state()

	var guarded:=bool(enemy.get("guard",false))
	var coeff:=float(loadout.get("a1_coeff",1.0))
	var guard_mult:=float(loadout.get("a1_guard_mult",0.65))
	var state_mult:=1.0
	if skill=="A2":
		coeff=float(loadout.get("a2_coeff",1.30))
		guard_mult=float(loadout.get("a2_guard_mult",0.55))
		if bool(shadow.get("fray",false)):
			state_mult*=FRAY_BONUS
			shadow.fray=false
		shadow.a2_cd=int(loadout.get("a2_cd",3))
		shadow.veil=float(loadout.get("a2_veil",0.15))
	else:
		shadow.fray=true
	if guarded:
		state_mult*=guard_mult

	var dealt:=CombatResolver.damage(float(shadow.atk),coeff,float(enemy.def),state_mult)
	dealt*=turn_timeline.incoming_damage_multiplier(StringName(encounter_id))
	var timing:=CombatPresentationContract.shadow_timing(skill,reduced_motion)
	emit_signal("shadow_attack_presented",skill,dealt,guarded)
	await _wait(float(timing.get("contact",0.0)))
	if not _turn_meter_valid(generation):
		return

	emit_signal("semantic_contact","shadow",skill)
	turn_timeline.notify_active_damage(StringName(encounter_id))
	enemy.hp=maxf(0.0,float(enemy.hp)-dealt)
	_emit_state()
	await _wait(CombatPresentationContract.remainder_after_contact(timing))
	if not _turn_meter_valid(generation):
		return

	turn_timeline.end_turn(&"shadow")
	current_turn.clear()
	shadow_completed_turns+=1
	if float(enemy.hp)<=0.0:
		turn_timeline.set_alive(StringName(encounter_id),false)
		active=false
		action_locked=false
		emit_signal("encounter_finished",encounter_id)
		_emit_state()
		return
	await _advance_turn_meter(generation)

func _enemy_turn_meter(generation:int)->void:
	await _wait(CombatPresentationContract.inter_beat_gap(reduced_motion))
	if not _turn_meter_valid(generation):
		return
	var incoming:=_prepare_enemy_turn_legacy()
	incoming*=turn_timeline.incoming_damage_multiplier(&"shadow")
	var timing:=CombatPresentationContract.enemy_timing("ATTACK",reduced_motion)
	emit_signal("enemy_attack_presented",incoming)
	await _wait(float(timing.get("contact",0.0)))
	if not _turn_meter_valid(generation):
		return

	emit_signal("semantic_contact","enemy","ATTACK")
	turn_timeline.notify_active_damage(&"shadow")
	shadow.hp=maxf(0.0,float(shadow.hp)-incoming)
	var poison_damage:=float(enemy.get("poison_damage",0.0))
	var poison_turns:=int(enemy.get("poison_turns",0))
	if poison_damage>0.0 and poison_turns>0 and float(shadow.hp)>0.0:
		_apply_shadow_poison(poison_damage,poison_turns,StringName(encounter_id))
	_emit_state()
	await _wait(CombatPresentationContract.remainder_after_contact(timing))

func _shadow_action_legacy(skill: String) -> void:
	if skill == "A2" and int(shadow.get("a2_cd",0)) > 0:
		return

	if _tick_shadow_poison()>0.0:
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
		_apply_shadow_poison(poison_damage,poison_turns,StringName(encounter_id))
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
		"turn_meter_mode_enabled":turn_meter_mode_enabled,
		"turn_meter":turn_timeline.snapshot() if turn_meter_mode_enabled and not pre_temple_mode else {},
		"current_turn":current_turn.duplicate(true),
		"shadow_completed_turns":shadow_completed_turns,
		"loadout":loadout.duplicate(true)
	})
