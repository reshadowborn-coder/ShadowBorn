class_name CovenantMenu
extends CanvasLayer
signal weapon_requested(family:String)
@onready var panel:Control=$Panel
@onready var details:Label=$Panel/Details
var selected:=""

func _ready()->void:
	panel.visible=false
	for child in $Panel/Weapons.get_children():
		if child is Button:
			child.pressed.connect(func():_select(str(child.get_meta("family"))))
	$Panel/Confirm.pressed.connect(_confirm)
	$Panel/Confirm.disabled=true

func open()->void: panel.visible=true
func close()->void: panel.visible=false

func _select(family:String)->void:
	if not Act0Progression.WEAPONS.has(family):return
	selected=family
	var d:Dictionary=Act0Progression.WEAPONS[family]
	details.text="%s\n%s\nA1: %s\nA2: %s\nP1: LOCKED — Lv10"%[d.label,d.feel,d.a1,d.a2]
	$Panel/Confirm.disabled=false

func _confirm()->void:
	if selected.is_empty():return
	weapon_requested.emit(selected)
