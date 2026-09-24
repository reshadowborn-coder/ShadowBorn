class_name MobileControls
extends CanvasLayer

signal direction_changed(direction:Vector2)

var held:Dictionary={"left":false,"right":false,"up":false,"down":false}
var root:Control
var touch_available:=false

func _ready()->void:
	layer=4
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_add_button("Left","◀",Vector2(36,-176),Vector2(116,-96),"left")
	_add_button("Right","▶",Vector2(196,-176),Vector2(276,-96),"right")
	_add_button("Up","▲",Vector2(116,-256),Vector2(196,-176),"up")
	_add_button("Down","▼",Vector2(116,-96),Vector2(196,-16),"down")
	touch_available=DisplayServer.is_touchscreen_available()
	visible=touch_available

func _add_button(name_:String,label:String,from:Vector2,to:Vector2,key:String)->void:
	var b:=Button.new()
	b.name=name_
	b.text=label
	b.anchor_top=1.0
	b.anchor_bottom=1.0
	b.offset_left=from.x
	b.offset_top=from.y
	b.offset_right=to.x
	b.offset_bottom=to.y
	b.focus_mode=Control.FOCUS_NONE
	b.button_down.connect(func(): _set_held(key,true))
	b.button_up.connect(func(): _set_held(key,false))
	root.add_child(b)

func _set_held(key:String,value:bool)->void:
	held[key]=value
	_emit_direction()

func _emit_direction()->void:
	var x:=float(held["right"])-float(held["left"])
	var y:=float(held["down"])-float(held["up"])
	direction_changed.emit(Vector2(x,y).normalized())

func set_enabled(value:bool)->void:
	visible=touch_available and value
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child in root.get_children():
		if child is Button:
			child.disabled=not value
	if not value:
		for key in held.keys():
			held[key]=false
		_emit_direction()
