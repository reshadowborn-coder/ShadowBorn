class_name MultiEnemyEncounter
extends Node

signal state_changed(state:Dictionary)
signal finished
signal failed
signal solo_limit_reached

const FRAY_BONUS := 1.15
const SOLO_LIMIT_ROUNDS := 2

var enemies:Array=[]
var selected:=0
var shadow_hp:=20.0
var companion_active:=false
var active:=false
var a2_cd:=0
var rounds:=0
var solo_limit_mode:=false
var limit_reached:=false
var fray:=false
var veil:=0.0
var loadout:Dictionary=ShadowLoadout.profile("")

func set_loadout(family:String)->void:
	loadout=ShadowLoadout.profile(family)

func start(profiles:Array,with_companion:bool,force_solo_limit:bool=false)->void:
	enemies=profiles.duplicate(true)
	if enemies.is_empty():
		active=false
		push_warning("Multi-enemy encounter cannot start without enemies")
		_emit()
		return
	for e in enemies:
		e["current_hp"]=float(e.hp)
	selected=0
	shadow_hp=20.0
	companion_active=with_companion
	a2_cd=0
	rounds=0
	solo_limit_mode=force_solo_limit
	limit_reached=false
	fray=false
	veil=0.0
	active=true
	_emit()

func select_target(index:int)->void:
	if not active or index<0 or index>=enemies.size() or float(enemies[index].current_hp)<=0:
		return
	selected=index
	_emit()

func shadow_action(skill:String)->void:
	if not active or skill not in ["A1","A2"]:
		return
	if skill=="A2" and a2_cd>0:
		return

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
	var next_hp:=maxf(0.0,float(e.current_hp)-damage)
	# The first Room 5 encounter is an authored tutorial limit, not a hidden
	# DPS check. Keep enemies non-lethal until the story beat resolves.
	if solo_limit_mode:
		next_hp=maxf(1.0,next_hp)
	e.current_hp=next_hp
	enemies[selected]=e

	if companion_active and not _all_dead():
		_companion_assist()

	if _all_dead():
		active=false
		_emit()
		finished.emit()
		return

	_enemy_phase()
	rounds+=1
	if a2_cd>0:
		a2_cd-=1

	if solo_limit_mode and rounds>=SOLO_LIMIT_ROUNDS:
		active=false
		limit_reached=true
		_emit()
		solo_limit_reached.emit()
		return

	if shadow_hp<=0.0:
		active=false
		_emit()
		failed.emit()
		return

	_select_living()
	_emit()

func _companion_assist()->void:
	_select_living()
	var e:Dictionary=enemies[selected]
	var p:=StoryCompanion.profile()
	var damage:=CombatResolver.damage(float(p.atk),float(p.a1.coeff),float(e.def))
	e.current_hp=maxf(0.0,float(e.current_hp)-damage)
	enemies[selected]=e

func _enemy_phase()->void:
	var veil_pending:=veil
	for e in enemies:
		if float(e.current_hp)<=0.0:
			continue
		var incoming:=float(e.damage)
		if veil_pending>0.0:
			incoming*=(1.0-veil_pending)
			veil_pending=0.0
			veil=0.0
		shadow_hp=maxf(0.0,shadow_hp-incoming)
		if solo_limit_mode:
			# Room 5 first contact is a fixed story limit, not a balance check.
			# Enemy tuning may change presentation pressure, but cannot kill
			# Shadow before the authored round limit is reached.
			shadow_hp=maxf(1.0,shadow_hp)

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
		"selected":selected,
		"companion_active":companion_active,
		"a2_cd":a2_cd,
		"rounds":rounds,
		"solo_limit_mode":solo_limit_mode,
		"limit_reached":limit_reached,
		"fray":fray,
		"veil":veil,
		"loadout":loadout.duplicate(true)
	})
