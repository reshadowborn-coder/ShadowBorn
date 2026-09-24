class_name MultiEnemyEncounter
extends Node

signal state_changed(state:Dictionary)
signal finished
signal failed
signal solo_limit_reached

const A2_COOLDOWN := 3
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

func start(profiles:Array,with_companion:bool,force_solo_limit:bool=false)->void:
	enemies=profiles.duplicate(true)
	for e in enemies:
		e["current_hp"]=float(e.hp)
	selected=0
	shadow_hp=20.0
	companion_active=with_companion
	a2_cd=0
	rounds=0
	solo_limit_mode=force_solo_limit
	limit_reached=false
	active=true
	_emit()

func select_target(index:int)->void:
	if not active or index<0 or index>=enemies.size() or float(enemies[index].current_hp)<=0:
		return
	selected=index
	_emit()

func shadow_action(skill:String)->void:
	if not active:
		return
	if skill=="A2" and a2_cd>0:
		return

	var e:Dictionary=enemies[selected]
	var coeff:=1.0 if skill=="A1" else 1.30
	var damage:=8.0*coeff*100.0/(100.0+float(e.def))
	e.current_hp=maxf(0.0,float(e.current_hp)-damage)
	enemies[selected]=e

	if skill=="A2":
		a2_cd=A2_COOLDOWN+1

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
	var damage:=float(p.atk)*float(p.a1.coeff)*100.0/(100.0+float(e.def))
	e.current_hp=maxf(0.0,float(e.current_hp)-damage)
	enemies[selected]=e

func _enemy_phase()->void:
	for e in enemies:
		if float(e.current_hp)>0.0:
			shadow_hp=maxf(0.0,shadow_hp-float(e.damage))

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
		"limit_reached":limit_reached
	})
