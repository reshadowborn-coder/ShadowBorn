class_name TempleWatchMenu
extends CanvasLayer

signal accepted
signal menu_opened
signal menu_closed

var blocker:ColorRect
var panel:Panel
var join_button:Button
var later_button:Button

func _ready()->void:
	layer=18
	blocker=ColorRect.new()
	blocker.color=Color(0,0,0,.52)
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(blocker)
	panel=Panel.new()
	panel.anchor_left=.5
	panel.anchor_top=.5
	panel.anchor_right=.5
	panel.anchor_bottom=.5
	panel.offset_left=-410
	panel.offset_right=410
	panel.offset_top=-230
	panel.offset_bottom=230
	add_child(panel)
	var title:=Label.new()
	title.text="TEMPLE WATCH COVENANT"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.position=Vector2(45,35)
	title.size=Vector2(730,42)
	title.add_theme_font_size_override("font_size",26)
	panel.add_child(title)
	var body:=Label.new()
	body.text="The sewers do not yield to a lone blade.\nSwear to the Temple Watch, stand under its seal,\nand the next descent will be made under covenant law."
	body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.position=Vector2(70,95)
	body.size=Vector2(680,120)
	panel.add_child(body)
	var touch:=MobileSafeArea.minimum_touch_target(get_viewport(),44.0,80.0)
	join_button=Button.new()
	join_button.text="JOIN THE TEMPLE WATCH"
	join_button.position=Vector2(80,250)
	join_button.size=Vector2(660,touch)
	join_button.custom_minimum_size=Vector2(660,touch)
	join_button.focus_mode=Control.FOCUS_NONE
	panel.add_child(join_button)
	later_button=Button.new()
	later_button.text="NOT YET"
	later_button.position=Vector2(80,270+touch)
	later_button.size=Vector2(660,touch)
	later_button.custom_minimum_size=Vector2(660,touch)
	later_button.focus_mode=Control.FOCUS_NONE
	panel.add_child(later_button)
	join_button.pressed.connect(func(): accepted.emit())
	later_button.pressed.connect(close)
	visible=false

func open()->void:
	if visible: return
	visible=true
	menu_opened.emit()

func close()->void:
	if not visible: return
	visible=false
	menu_closed.emit()