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
	var touch:=MobileSafeArea.minimum_touch_target(get_viewport(),44.0,80.0)
	var panel_height:=maxf(760.0,210.0+touch*5.0)
	panel.offset_top=-panel_height*0.5
	panel.offset_bottom=panel_height*0.5
	var weapons:Control=$Panel/Weapons
	weapons.size.y=touch*5.0
	for child in weapons.get_children():
		if child is Button:
			child.custom_minimum_size=Vector2(0,touch)
			child.focus_mode=Control.FOCUS_NONE
			var family:=str(child.get_meta("family"))
			child.pressed.connect(func():_select(family))
	confirm.size.y=touch
	confirm.custom_minimum_size.y=touch
	cancel.position.y=confirm.position.y+touch+16.0
	cancel.size.y=touch
	cancel.custom_minimum_size.y=touch
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
