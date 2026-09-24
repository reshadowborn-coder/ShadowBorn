class_name MultiTargetHUD
extends CanvasLayer

signal target_selected(index:int)
signal skill_pressed(skill:String)

@onready var target_a:Button=$Panel/TargetA
@onready var target_b:Button=$Panel/TargetB
@onready var state:Label=$Panel/State
@onready var a2:Button=$Panel/A2

func _ready()->void:
	hide()
	target_a.pressed.connect(func():target_selected.emit(0))
	target_b.pressed.connect(func():target_selected.emit(1))
	$Panel/A1.pressed.connect(func():skill_pressed.emit("A1"))
	a2.pressed.connect(func():skill_pressed.emit("A2"))

func open()->void:
	show()

func close()->void:
	hide()

func render(data:Dictionary)->void:
	var es:Array=data.get("enemies",[])
	if es.size()<2:
		return
	var s:=int(data.get("selected",0))
	target_a.text=("%s  %.0f HP%s"%[es[0].get("label",es[0].id),es[0].current_hp,"  <" if s==0 else ""])
	target_b.text=("%s  %.0f HP%s"%[es[1].get("label",es[1].id),es[1].current_hp,"  <" if s==1 else ""])
	target_a.disabled=float(es[0].current_hp)<=0.0
	target_b.disabled=float(es[1].current_hp)<=0.0

	var cd:=int(data.get("a2_cd",0))
	a2.disabled=cd>0
	a2.text="A2  ACTIVE" if cd==0 else "A2  ACTIVE  [CD %d]"%cd

	if bool(data.get("limit_reached",false)):
		state.text="THE SHADOW CANNOT HOLD — RETREAT"
		$Panel/A1.disabled=true
		a2.disabled=true
		return
	var suffix:=""
	if bool(data.get("companion_active",false)):
		suffix="  |  ALLY ACTIVE"
	elif bool(data.get("solo_limit_mode",false)):
		suffix="  |  OUTNUMBERED"
	state.text="SHADOW %.0f HP%s"%[float(data.get("shadow_hp",0.0)),suffix]
