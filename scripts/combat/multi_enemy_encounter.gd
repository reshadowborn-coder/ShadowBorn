class_name MultiEnemyEncounter
extends Node

signal state_changed(state:Dictionary)
signal shadow_attack_presented(target_index:int,skill:String,damage:float)
signal enemy_attack_presented(enemy_index:int,damage:float)
signal companion_attack_presented(target_index:int,damage:float)
signal semantic_contact(actor:String,index:int,action:String)
signal command_committed(skill:String)
signal finished
signal failed
signal solo_limit_reached

const FRAY_BONUS := 1.15
const SOLO_LIMIT_ROUNDS := 2
# Compatibility timing for the completed Act 0 Room 5 flow. Act 1 can opt
# into the contact-synchronized presentation timeline without changing Act 0.
const ACTION_LOCK_SECONDS := 0.42
const SHADOW_BASE_SPEED := 100
const COMPANION_BASE_SPEED := 105

var enemies:Array=[]
var selected:=0
var shadow_hp:=20.0
var companion_active:=false
var active:=false
var action_locked:=false
var encounter_generation:=0
var a2_cd:=0
var rounds:=0
var solo_limit_mode:=false
var limit_reached:=false
var fray:=false
var veil:=0.0
var reduced_motion:=false
var presentation_timeline_enabled:=false
var turn_meter_mode_enabled:=false
var turn_timeline:=CombatTurnTimeline.new()
var current_turn:Dictionary={}
var solo_limit_pending:=false
var phase:="idle"
var loadout:Dictionary=ShadowLoadout.profile("")

func set_loadout(family:String)->void:
	loadout=ShadowLoadout.profile(family)

func set_reduced_motion(value:bool)->void:
	reduced_motion=value

func set_presentation_timeline_enabled(value:bool)->void:
	presentation_timeline_enabled=value

func set_turn_meter_mode_enabled(value:bool)->void:
	turn_meter_mode_enabled=value

func apply_turn_control(actor_id:StringName,control_tag:StringName,turns:int,source_id:StringName=&"")->bool:
	if not turn_meter_mode_enabled:
		return false
	return turn_timeline.apply_control(actor_id,control_tag,turns,source_id)

func apply_turn_speed_modifier(actor_id:StringName,source_id:StringName,percent_bp:int,turns:int)->bool:
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
	var applied:=turn_timeline.apply_provoke(actor_id,source_actor_id,turns)
	if applied and actor_id==&"shadow":
		_enforce_shadow_forced_target()
	return applied

func adjust_turn_meter(actor_id:StringName,delta_bp:int)->bool:
	if not turn_meter_mode_enabled:
		return false
	return turn_timeline.adjust_turn_meter(actor_id,delta_bp)

func grant_extra_turn(actor_id:StringName,count:int=1)->bool:
	if not turn_meter_mode_enabled:
		return false
	return turn_timeline.grant_extra_turn(actor_id,count)

static func _valid_profile(profile)->bool:
	if typeof(profile)!=TYPE_DICTIONARY:
		return false
	if str(profile.get("id","")).is_empty():
		return false
	for key in ["hp","def","damage"]:
		var value=profile.get(key)
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
			return false
		var number:=float(value)
		if number!=number or is_inf(number):
			return false
	if float(profile.get("hp",0.0))<=0.0 or float(profile.get("def",0.0))<0.0 or float(profile.get("damage",0.0))<0.0:
		return false
	return true

func start(profiles:Array,with_companion:bool,force_solo_limit:bool=false)->bool:
	if active or profiles.size()!=2:
		push_warning("Multi-enemy encounter requires exactly two inactive-start profiles")
		return false

	var ids:Dictionary={}
	for profile in profiles:
		if not _valid_profile(profile):
			push_warning("Multi-enemy encounter rejected an invalid enemy profile")
			return false
		var id:=str(profile.get("id",""))
		if ids.has(id):
			push_warning("Multi-enemy encounter rejected duplicate enemy IDs")
			return false
		ids[id]=true

	enemies=profiles.duplicate(true)
	for e in enemies:
		e["current_hp"]=float(e.hp)
	encounter_generation+=1
	selected=0
	shadow_hp=20.0
	companion_active=with_companion
	action_locked=false
	a2_cd=0
	rounds=0
	solo_limit_mode=force_solo_limit
	limit_reached=false
	fray=false
	veil=0.0
	phase="ready"
	solo_limit_pending=false
	current_turn.clear()
	active=true
	if turn_meter_mode_enabled:
		_setup_turn_meter()
		action_locked=true
		phase="turn_meter"
		_emit()
		call_deferred("_advance_turn_meter",encounter_generation)
	else:
		_emit()
	return true

func select_target(index:int)->void:
	if not active or action_locked or index<0 or index>=enemies.size() or float(enemies[index].current_hp)<=0:
		return
	if turn_meter_mode_enabled:
		var forced:=turn_timeline.forced_target_id(&"shadow")
		if forced!=&"" and StringName(str((enemies[index] as Dictionary).get("id","")))!=forced:
			_enforce_shadow_forced_target()
			_emit()
			return
	selected=index
	_emit()

func _enforce_shadow_forced_target()->void:
	if not turn_meter_mode_enabled:
		return
	var forced:=turn_timeline.forced_target_id(&"shadow")
	if forced==&"":
		return
	var forced_index:=_enemy_index_for_actor(forced)
	if forced_index>=0 and float((enemies[forced_index] as Dictionary).get("current_hp",0.0))>0.0:
		selected=forced_index

func _wait(duration:float)->void:
	if duration<=0.0:
		return
	await get_tree().create_timer(duration,false).timeout

func _turn_valid(generation:int)->bool:
	return generation==encounter_generation and active and is_inside_tree()

func shadow_action(skill:String)->void:
	if not active or action_locked or skill not in ["A1","A2"]:
		return
	if turn_meter_mode_enabled:
		if skill!="A1" and turn_timeline.active_skills_blocked(&"shadow"):
			return
		_enforce_shadow_forced_target()
	if skill=="A2" and a2_cd>0:
		return
	if turn_meter_mode_enabled:
		_shadow_action_turn_meter(skill)
		return
	if not presentation_timeline_enabled:
		_shadow_action_immediate(skill)
		return

	var generation:=encounter_generation
	var target_index:=selected
	action_locked=true
	phase="shadow"
	command_committed.emit(skill)
	_emit()

	var e:Dictionary=enemies[target_index]
	var coeff:=float(loadout.get("a1_coeff",1.0))
	var guard_mult:=float(loadout.get("a1_guard_mult",0.65))
	var state_mult:=1.0

	if skill=="A2":
		coeff=float(loadout.get("a2_coeff",1.30))
		guard_mult=float(loadout.get("a2_guard_mult",0.55))
		if fray:
			state_mult*=FRAY_BONUS
			fray=false
		a2_cd=int(loadout.get("a2_cd",3))+1
		veil=float(loadout.get("a2_veil",0.15))
	else:
		fray=true

	if bool(e.get("guard",false)):
		state_mult*=guard_mult

	var damage:=CombatResolver.damage(8.0,coeff,float(e.def),state_mult)
	var shadow_timing:=CombatPresentationContract.shadow_timing(skill,reduced_motion)
	shadow_attack_presented.emit(target_index,skill,damage)
	await _wait(float(shadow_timing.get("contact",0.0)))
	if not _turn_valid(generation):
		return

	semantic_contact.emit("shadow",target_index,skill)
	var next_hp:=maxf(0.0,float(e.current_hp)-damage)
	# The first authored pack contact is a narrative solo limit, not a DPS
	# check. Presentation timing may change, but the enemies stay non-lethal
	# until the fixed story beat resolves.
	if solo_limit_mode:
		next_hp=maxf(1.0,next_hp)
	e.current_hp=next_hp
	enemies[target_index]=e
	_emit()

	await _wait(CombatPresentationContract.remainder_after_contact(shadow_timing))
	if not _turn_valid(generation):
		return

	if _all_dead():
		_finish_victory()
		return

	if companion_active:
		await _wait(CombatPresentationContract.inter_beat_gap(reduced_motion))
		if not _turn_valid(generation):
			return
		await _companion_assist(generation)
		if not _turn_valid(generation):
			return
		if _all_dead():
			_finish_victory()
			return

	await _enemy_phase(generation)
	if not _turn_valid(generation):
		return

	rounds+=1
	if a2_cd>0:
		a2_cd-=1

	if solo_limit_mode and rounds>=SOLO_LIMIT_ROUNDS:
		active=false
		action_locked=false
		phase="terminal"
		limit_reached=true
		_emit()
		solo_limit_reached.emit()
		return

	if shadow_hp<=0.0:
		active=false
		action_locked=false
		phase="terminal"
		_emit()
		failed.emit()
		return

	_select_living()
	action_locked=false
	phase="ready"
	_emit()

func _setup_turn_meter()->void:
	turn_timeline.reset()
	turn_timeline.add_actor(&"shadow",&"ally",SHADOW_BASE_SPEED)
	for e in enemies:
		var enemy:Dictionary=e
		var actor_id:=StringName(str(enemy.get("id","")))
		var speed:=maxi(1,int(enemy.get("speed",90)))
		turn_timeline.add_actor(actor_id,&"enemy",speed)
	if companion_active:
		turn_timeline.add_actor(&"story_companion",&"ally",COMPANION_BASE_SPEED)

func _enemy_index_for_actor(actor_id:StringName)->int:
	for i in range(enemies.size()):
		if StringName(str((enemies[i] as Dictionary).get("id","")))==actor_id:
			return i
	return -1

func _advance_turn_meter(generation:int)->void:
	while _turn_valid(generation):
		var ticket:=turn_timeline.next_turn()
		if ticket.is_empty():
			return
		current_turn=ticket.duplicate(true)
		action_locked=true
		phase="turn_meter"
		_emit()

		var actor_id:=StringName(ticket.get("actor_id",&""))
		if bool(ticket.get("skipped",false)):
			await _wait(.04 if reduced_motion else .16)
			if not _turn_valid(generation):
				return
			turn_timeline.end_turn(actor_id)
			current_turn.clear()
			continue

		if actor_id==&"shadow":
			_enforce_shadow_forced_target()
			if solo_limit_pending:
				_finish_solo_limit()
				return
			if rounds>0 and a2_cd>0 and bool(ticket.get("cooldowns_advance",true)):
				a2_cd=maxi(0,a2_cd-1)
			action_locked=false
			phase="shadow_ready"
			_emit()
			return

		if actor_id==&"story_companion":
			await _companion_meter_turn(generation)
			if not _turn_valid(generation):
				return
			turn_timeline.end_turn(actor_id)
			current_turn.clear()
			continue

		var enemy_index:=_enemy_index_for_actor(actor_id)
		if enemy_index<0:
			turn_timeline.end_turn(actor_id)
			current_turn.clear()
			continue
		await _enemy_meter_turn(enemy_index,generation)
		if not _turn_valid(generation):
			return
		turn_timeline.end_turn(actor_id)
		current_turn.clear()
		if solo_limit_pending:
			_finish_solo_limit()
			return
		if shadow_hp<=0.0:
			active=false
			action_locked=false
			phase="terminal"
			_emit()
			failed.emit()
			return

func _shadow_action_turn_meter(skill:String)->void:
	if StringName(current_turn.get("actor_id",&""))!=&"shadow":
		return
	var generation:=encounter_generation
	var target_index:=selected
	action_locked=true
	phase="shadow"
	command_committed.emit(skill)
	_emit()

	var e:Dictionary=enemies[target_index]
	var coeff:=float(loadout.get("a1_coeff",1.0))
	var guard_mult:=float(loadout.get("a1_guard_mult",0.65))
	var state_mult:=1.0

	if skill=="A2":
		coeff=float(loadout.get("a2_coeff",1.30))
		guard_mult=float(loadout.get("a2_guard_mult",0.55))
		if fray:
			state_mult*=FRAY_BONUS
			fray=false
		a2_cd=int(loadout.get("a2_cd",3))
		veil=float(loadout.get("a2_veil",0.15))
	else:
		fray=true

	if bool(e.get("guard",false)):
		state_mult*=guard_mult

	var damage:=CombatResolver.damage(8.0,coeff,float(e.def),state_mult)
	var timing:=CombatPresentationContract.shadow_timing(skill,reduced_motion)
	shadow_attack_presented.emit(target_index,skill,damage)
	await _wait(float(timing.get("contact",0.0)))
	if not _turn_valid(generation):
		return

	semantic_contact.emit("shadow",target_index,skill)
	var next_hp:=maxf(0.0,float(e.current_hp)-damage)
	if solo_limit_mode:
		next_hp=maxf(1.0,next_hp)
	e.current_hp=next_hp
	enemies[target_index]=e
	if next_hp<=0.0:
		turn_timeline.set_alive(StringName(str(e.get("id",""))),false)
	_emit()

	await _wait(CombatPresentationContract.remainder_after_contact(timing))
	if not _turn_valid(generation):
		return

	turn_timeline.end_turn(&"shadow")
	current_turn.clear()
	rounds+=1
	if _all_dead():
		_finish_victory()
		return
	if solo_limit_mode and rounds>=SOLO_LIMIT_ROUNDS:
		solo_limit_pending=true
	await _advance_turn_meter(generation)

func _enemy_meter_turn(enemy_index:int,generation:int)->void:
	if enemy_index<0 or enemy_index>=enemies.size():
		return
	var e:Dictionary=enemies[enemy_index]
	if float(e.get("current_hp",0.0))<=0.0:
		return
	await _wait(CombatPresentationContract.inter_beat_gap(reduced_motion))
	if not _turn_valid(generation):
		return
	var incoming:=float(e.get("damage",0.0))
	if veil>0.0:
		incoming*=(1.0-veil)
		veil=0.0
	var timing:=CombatPresentationContract.enemy_timing("ATTACK",reduced_motion)
	phase="enemy"
	enemy_attack_presented.emit(enemy_index,incoming)
	_emit()
	await _wait(float(timing.get("contact",0.0)))
	if not _turn_valid(generation):
		return
	semantic_contact.emit("enemy",enemy_index,"ATTACK")
	shadow_hp=maxf(0.0,shadow_hp-incoming)
	if solo_limit_mode:
		shadow_hp=maxf(1.0,shadow_hp)
	_emit()
	await _wait(CombatPresentationContract.remainder_after_contact(timing))

func _companion_meter_turn(generation:int)->void:
	_select_living()
	var target_index:=selected
	if target_index<0 or target_index>=enemies.size():
		return
	var e:Dictionary=enemies[target_index]
	var p:=StoryCompanion.profile()
	var damage:=CombatResolver.damage(float(p.atk),float(p.a1.coeff),float(e.def))
	var timing:=CombatPresentationContract.shadow_timing("A1",reduced_motion)
	phase="companion"
	companion_attack_presented.emit(target_index,damage)
	_emit()
	await _wait(float(timing.get("contact",0.0)))
	if not _turn_valid(generation):
		return
	semantic_contact.emit("companion",target_index,"A1")
	e.current_hp=maxf(0.0,float(e.current_hp)-damage)
	enemies[target_index]=e
	if float(e.current_hp)<=0.0:
		turn_timeline.set_alive(StringName(str(e.get("id",""))),false)
	_emit()
	await _wait(CombatPresentationContract.remainder_after_contact(timing))

func _finish_solo_limit()->void:
	active=false
	action_locked=false
	phase="terminal"
	limit_reached=true
	solo_limit_pending=false
	current_turn.clear()
	_emit()
	solo_limit_reached.emit()

func _shadow_action_immediate(skill:String)->void:
	action_locked=true
	command_committed.emit(skill)
	var e:Dictionary=enemies[selected]
	var coeff:=float(loadout.get("a1_coeff",1.0))
	var guard_mult:=float(loadout.get("a1_guard_mult",0.65))
	var state_mult:=1.0

	if skill=="A2":
		coeff=float(loadout.get("a2_coeff",1.30))
		guard_mult=float(loadout.get("a2_guard_mult",0.55))
		if fray:
			state_mult*=FRAY_BONUS
			fray=false
		a2_cd=int(loadout.get("a2_cd",3))+1
		veil=float(loadout.get("a2_veil",0.15))
	else:
		fray=true

	if bool(e.get("guard",false)):
		state_mult*=guard_mult

	var damage:=CombatResolver.damage(8.0,coeff,float(e.def),state_mult)
	shadow_attack_presented.emit(selected,skill,damage)
	var next_hp:=maxf(0.0,float(e.current_hp)-damage)
	if solo_limit_mode:
		next_hp=maxf(1.0,next_hp)
	e.current_hp=next_hp
	enemies[selected]=e

	if companion_active and not _all_dead():
		_companion_assist_immediate()

	if _all_dead():
		active=false
		action_locked=false
		phase="terminal"
		_emit()
		finished.emit()
		return

	_enemy_phase_immediate()
	rounds+=1
	if a2_cd>0:
		a2_cd-=1

	if solo_limit_mode and rounds>=SOLO_LIMIT_ROUNDS:
		active=false
		action_locked=false
		phase="terminal"
		limit_reached=true
		_emit()
		solo_limit_reached.emit()
		return

	if shadow_hp<=0.0:
		active=false
		action_locked=false
		phase="terminal"
		_emit()
		failed.emit()
		return

	_select_living()
	phase="ready"
	_emit()
	_schedule_action_unlock()

func _companion_assist_immediate()->void:
	_select_living()
	var e:Dictionary=enemies[selected]
	var p:=StoryCompanion.profile()
	var damage:=CombatResolver.damage(float(p.atk),float(p.a1.coeff),float(e.def))
	companion_attack_presented.emit(selected,damage)
	e.current_hp=maxf(0.0,float(e.current_hp)-damage)
	enemies[selected]=e

func _enemy_phase_immediate()->void:
	var veil_pending:=veil
	for i in range(enemies.size()):
		var e:Dictionary=enemies[i]
		if float(e.current_hp)<=0.0:
			continue
		var incoming:=float(e.damage)
		if veil_pending>0.0:
			incoming*=(1.0-veil_pending)
			veil_pending=0.0
			veil=0.0
		enemy_attack_presented.emit(i,incoming)
		shadow_hp=maxf(0.0,shadow_hp-incoming)
		if solo_limit_mode:
			shadow_hp=maxf(1.0,shadow_hp)

func _schedule_action_unlock()->void:
	if not active:
		action_locked=false
		return
	if not is_inside_tree():
		action_locked=false
		_emit()
		return
	var generation:=encounter_generation
	get_tree().create_timer(ACTION_LOCK_SECONDS,false).timeout.connect(func():
		if generation!=encounter_generation or not active:
			return
		action_locked=false
		_emit()
	)

func _finish_victory()->void:
	active=false
	action_locked=false
	phase="terminal"
	_emit()
	finished.emit()

func _companion_assist(generation:int)->void:
	_select_living()
	var target_index:=selected
	var e:Dictionary=enemies[target_index]
	var p:=StoryCompanion.profile()
	var damage:=CombatResolver.damage(float(p.atk),float(p.a1.coeff),float(e.def))
	var timing:=CombatPresentationContract.shadow_timing("A1",reduced_motion)
	phase="companion"
	companion_attack_presented.emit(target_index,damage)
	_emit()
	await _wait(float(timing.get("contact",0.0)))
	if not _turn_valid(generation):
		return
	semantic_contact.emit("companion",target_index,"A1")
	e.current_hp=maxf(0.0,float(e.current_hp)-damage)
	enemies[target_index]=e
	_emit()
	await _wait(CombatPresentationContract.remainder_after_contact(timing))

func _enemy_phase(generation:int)->void:
	var veil_pending:=veil
	for i in range(enemies.size()):
		if not _turn_valid(generation):
			return
		var e:Dictionary=enemies[i]
		if float(e.current_hp)<=0.0:
			continue

		await _wait(CombatPresentationContract.inter_beat_gap(reduced_motion))
		if not _turn_valid(generation):
			return

		var incoming:=float(e.damage)
		var consumes_veil:=veil_pending>0.0
		if consumes_veil:
			incoming*=(1.0-veil_pending)
			veil_pending=0.0
		var timing:=CombatPresentationContract.enemy_timing("ATTACK",reduced_motion)
		phase="enemy"
		enemy_attack_presented.emit(i,incoming)
		_emit()
		await _wait(float(timing.get("contact",0.0)))
		if not _turn_valid(generation):
			return

		semantic_contact.emit("enemy",i,"ATTACK")
		if consumes_veil:
			veil=0.0
		shadow_hp=maxf(0.0,shadow_hp-incoming)
		if solo_limit_mode:
			shadow_hp=maxf(1.0,shadow_hp)
		_emit()

		await _wait(CombatPresentationContract.remainder_after_contact(timing))
		if shadow_hp<=0.0 and not solo_limit_mode:
			return

func _all_dead()->bool:
	for e in enemies:
		if float(e.current_hp)>0.0:
			return false
	return true

func _select_living()->void:
	if selected<enemies.size() and float(enemies[selected].current_hp)>0.0:
		return
	for i in range(enemies.size()):
		if float(enemies[i].current_hp)>0.0:
			selected=i
			return

func _emit()->void:
	state_changed.emit({
		"shadow_hp":shadow_hp,
		"enemies":enemies.duplicate(true),
		"action_locked":action_locked,
		"selected":selected,
		"companion_active":companion_active,
		"a2_cd":a2_cd,
		"rounds":rounds,
		"solo_limit_mode":solo_limit_mode,
		"limit_reached":limit_reached,
		"fray":fray,
		"veil":veil,
		"phase":phase,
		"reduced_motion":reduced_motion,
		"presentation_timeline_enabled":presentation_timeline_enabled,
		"turn_meter_mode_enabled":turn_meter_mode_enabled,
		"turn_meter":turn_timeline.snapshot() if turn_meter_mode_enabled else {},
		"current_turn":current_turn.duplicate(true),
		"loadout":loadout.duplicate(true)
	})
