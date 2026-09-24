class_name MultiEnemyEncounter
extends Node

signal state_changed(state:Dictionary)
signal finished
signal failed

var enemies:Array=[]
var selected:=0
var shadow_hp:=20.0
var companion_active:=false
var active:=false

func start(profiles:Array,with_companion:bool)->void:
	enemies=profiles.duplicate(true)
	for e in enemies:e["current_hp"]=float(e.hp)
	selected=0;shadow_hp=20.0;companion_active=with_companion;active=true;_emit()

func select_target(index:int)->void:
	if not active or index<0 or index>=enemies.size() or float(enemies[index].current_hp)<=0:return
	selected=index;_emit()

func shadow_action(skill:String)->void:
	if not active:return
	var e:Dictionary=enemies[selected]
	var coeff:=1.0 if skill=="A1" else 1.30
	var damage:=8.0*coeff*100.0/(100.0+float(e.def))
	e.current_hp=maxf(0.0,float(e.current_hp)-damage);enemies[selected]=e
	if companion_active and not _all_dead():_companion_assist()
	if _all_dead():active=false;finished.emit();return
	_enemy_phase()
	if shadow_hp<=0.0:active=false;failed.emit();return
	_select_living();_emit()

func _companion_assist()->void:
	_select_living()
	var e:Dictionary=enemies[selected]
	var p:=StoryCompanion.profile()
	var damage:=float(p.atk)*float(p.a1.coeff)*100.0/(100.0+float(e.def))
	e.current_hp=maxf(0.0,float(e.current_hp)-damage);enemies[selected]=e

func _enemy_phase()->void:
	for e in enemies:
		if float(e.current_hp)>0.0:shadow_hp=maxf(0.0,shadow_hp-float(e.damage))

func _all_dead()->bool:
	for e in enemies:
		if float(e.current_hp)>0.0:return false
	return true

func _select_living()->void:
	if selected<enemies.size() and float(enemies[selected].current_hp)>0.0:return
	for i in range(enemies.size()):
		if float(enemies[i].current_hp)>0.0:selected=i;return

func _emit()->void:
	state_changed.emit({"shadow_hp":shadow_hp,"enemies":enemies.duplicate(true),"selected":selected,"companion_active":companion_active})
