class_name CovenantMenu
extends CanvasLayer

signal weapon_requested(family:String)
signal menu_opened
signal menu_closed

@onready var panel:Control=$Panel
@onready var details:Label=$Panel/Details
@onready var confirm:Button=$Panel/Confirm
@onready var cancel:Button=$Panel/Cancel
var selected:=""
var blocker:ColorRect

func _ready()->void:
	blocker=ColorRect.new()
	blocker.name="ModalBlocker"
	blocker.color=Color(0,0,0,0.45)
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(blocker)
	move_child(blocker,0)
	blocker.visible=false
	panel.visible=false
	for child in $Panel/Weapons.get_children():
		if child is Button:
			child.pressed.connect(func():_select(str(child.get_meta("family"))))
	confirm.pressed.connect(_confirm)
	cancel.pressed.connect(close)
	confirm.disabled=true

func open()->void:
	if panel.visible:
		return
	selected=""
	details.text="FORGOTTEN COVENANT\nChoose a weapon family to preview A1 / A2.\nP1 remains LOCKED until Lv10."
	confirm.disabled=true
	blocker.visible=true
	panel.visible=true
	menu_opened.emit()

func close()->void:
	if not panel.visible:
		return
	panel.visible=false
	blocker.visible=false
	menu_closed.emit()

func _select(family:String)->void:
	if not Act0Progression.WEAPONS.has(family):
		return
	selected=family
	var d:Dictionary=Act0Progression.WEAPONS[family]
	details.text="%s\n%s\nA1: %s\nA2: %s\nP1: LOCKED — Lv10"%[d.label,d.feel,d.a1,d.a2]
	confirm.disabled=false

func _confirm()->void:
	if selected.is_empty():
		return
	confirm.disabled=true
	weapon_requested.emit(selected)
