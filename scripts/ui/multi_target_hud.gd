class_name MultiTargetHUD
extends CanvasLayer

signal target_selected(index:int)
signal skill_pressed(skill:String)

@onready var target_a:Button=$Panel/TargetA
@onready var target_b:Button=$Panel/TargetB
@onready var state:Label=$Panel/State

func _ready()->void:
	hide()
	target_a.pressed.connect(func():target_selected.emit(0))
	target_b.pressed.connect(func():target_selected.emit(1))
	$Panel/A1.pressed.connect(func():skill_pressed.emit("A1"))
	$Panel/A2.pressed.connect(func():skill_pressed.emit("A2"))

func open()->void:show()
func close()->void:hide()

func render(data:Dictionary)->void:
	var es:Array=data.enemies
	if es.size()<2:return
	var s:=int(data.selected)
	target_a.text=("%s  %.0f HP%s"%[es[0].id,es[0].current_hp,"  <" if s==0 else ""])
	target_b.text=("%s  %.0f HP%s"%[es[1].id,es[1].current_hp,"  <" if s==1 else ""])
	state.text="SHADOW %.0f HP%s"%[data.shadow_hp,"  |  ALLY ACTIVE" if data.companion_active else ""]
