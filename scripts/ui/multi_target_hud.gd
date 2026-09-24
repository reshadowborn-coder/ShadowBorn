class_name MultiTargetHUD
extends CanvasLayer

signal target_selected(index:int)
signal skill_pressed(skill:String)

@onready var target_a:Button=$Panel/TargetA
@onready var target_b:Button=$Panel/TargetB
@onready var state:Label=$Panel/State
@onready var a1:Button=$Panel/A1
@onready var a2:Button=$Panel/A2

func _ready()->void:
	hide()
	target_a.pressed.connect(func():target_selected.emit(0))
	target_b.pressed.connect(func():target_selected.emit(1))
	a1.pressed.connect(func():skill_pressed.emit("A1"))
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

	var loadout:Dictionary=data.get("loadout",{})
	var a1_name:=str(loadout.get("a1_name","Basic Attack")).to_upper()
	var a2_name:=str(loadout.get("a2_name","Shadow Lunge")).to_upper()
	var cd:=int(data.get("a2_cd",0))
	a1.text="A1  "+a1_name
	a2.disabled=cd>0
	a2.text="A2  "+a2_name if cd==0 else "A2  %s  [CD %d]"%[a2_name,cd]

	if bool(data.get("limit_reached",false)):
		state.text="THE SHADOW CANNOT HOLD — RETREAT"
		a1.disabled=true
		a2.disabled=true
		return
	a1.disabled=false
	var tags:Array[String]=[]
	if bool(data.get("companion_active",false)):
		tags.append("ALLY ACTIVE")
	elif bool(data.get("solo_limit_mode",false)):
		tags.append("OUTNUMBERED")
	if bool(data.get("fray",false)):
		tags.append("FRAY")
	if float(data.get("veil",0.0))>0.0:
		tags.append("VEIL")
	var suffix:="  |  "+"  •  ".join(tags) if not tags.is_empty() else ""
	state.text="SHADOW %.0f HP%s"%[float(data.get("shadow_hp",0.0)),suffix]
