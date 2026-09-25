class_name MobileControls
extends CanvasLayer

signal direction_changed(direction:Vector2)

const BUTTON_SIZE:=80.0
const STEP:=80.0

var held:Dictionary={"left":false,"right":false,"up":false,"down":false}
var root:Control
var touch_available:=false

func _ready()->void:
	layer=4
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_add_button("Left","◀","left")
	_add_button("Right","▶","right")
	_add_button("Up","▲","up")
	_add_button("Down","▼","down")
	touch_available=DisplayServer.is_touchscreen_available()
	visible=touch_available
	get_viewport().size_changed.connect(_apply_safe_area)
	call_deferred("_apply_safe_area")

func _add_button(name_:String,label:String,key:String)->void:
	var b:=Button.new()
	b.name=name_
	b.text=label
	b.focus_mode=Control.FOCUS_NONE
	b.custom_minimum_size=Vector2(BUTTON_SIZE,BUTTON_SIZE)
	b.button_down.connect(func(): _set_held(key,true))
	b.button_up.connect(func(): _set_held(key,false))
	root.add_child(b)

func _apply_safe_area()->void:
	if root==null:
		return
	var m:=MobileSafeArea.current(get_viewport())
	var viewport_size:=get_viewport().get_visible_rect().size
	var origin:=Vector2(m.x+24.0,viewport_size.y-m.w-24.0)
	_place("Left",origin+Vector2(0.0,-STEP*2.0))
	_place("Right",origin+Vector2(STEP*2.0,-STEP*2.0))
	_place("Up",origin+Vector2(STEP,-STEP*3.0))
	_place("Down",origin+Vector2(STEP,-STEP))

func _place(name_:String,top_left:Vector2)->void:
	var button:=root.get_node_or_null(name_) as Button
	if button==null:
		return
	button.position=top_left
	button.size=Vector2(BUTTON_SIZE,BUTTON_SIZE)

func _set_held(key:String,value:bool)->void:
	held[key]=value
	_emit_direction()

func _emit_direction()->void:
	var x:=float(held["right"])-float(held["left"])
	var y:=float(held["down"])-float(held["up"])
	direction_changed.emit(Vector2(x,y).normalized())

func reset_input()->void:
	for key in held.keys():
		held[key]=false
	_emit_direction()

func set_enabled(value:bool)->void:
	visible=touch_available and value
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child in root.get_children():
		if child is Button:
			child.disabled=not value
	if not value:
		reset_input()
