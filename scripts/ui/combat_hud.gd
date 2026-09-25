class_name CombatHUD
extends CanvasLayer

signal skill_requested(index: int)
signal auto_changed(enabled: bool)
signal speed_changed(multiplier: float)
signal replay_requested
signal title_requested

var root: Control
var player_hp: ProgressBar
var enemy_hp: ProgressBar
var player_name: Label
var enemy_name: Label
var message_label: Label
var round_label: Label
var timer_label: Label
var a1: Button
var a2: Button
var auto_button: Button
var speed_button: Button
var info_panel: Panel
var result_panel: Panel
var pause_button: Button
var auto_enabled := false
var speed := 1.0
var elapsed := 0.0
var battle_running := true

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _process(delta: float) -> void:
	if battle_running and not get_tree().paused:
		elapsed += delta
		var seconds := int(elapsed)
		timer_label.text = "%d:%02d" % [seconds/60,seconds%60]

func apply_state(snapshot: Dictionary) -> void:
	var units: Array = snapshot.get("units",[])
	var player: Dictionary = {}
	var enemy: Dictionary = {}
	for unit_variant in units:
		var unit: Dictionary = unit_variant
		if str(unit["team"])=="player":
			player=unit
		else:
			enemy=unit

	if not player.is_empty():
		player_name.text = "SHADOW"
		player_hp.max_value=float(player["max_hp"])
		player_hp.value=float(player["hp"])
		var cds: Array=player.get("cooldowns",[0,0])
		var ready:=bool(snapshot.get("player_ready",false))
		a1.disabled=not ready
		a2.disabled=(not ready) or int(cds[1])>0
		a2.text="A2\nSHADOW LUNGE" if int(cds[1])==0 else "A2\n%d" % int(cds[1])

	if not enemy.is_empty():
		enemy_name.text=str(enemy["name"]).to_upper()
		enemy_hp.max_value=float(enemy["max_hp"])
		enemy_hp.value=float(enemy["hp"])

	auto_enabled=bool(snapshot.get("auto",false))
	speed=float(snapshot.get("speed",1.0))
	auto_button.text="AUTO" if not auto_enabled else "AUTO\nON"
	speed_button.text="x2" if speed>1.5 else "x1"
	battle_running=bool(snapshot.get("running",true))

func set_player_ready(value: bool) -> void:
	a1.disabled=not value
	if value:
		message_label.text="CHOOSE AN ACTION"

func show_message(text: String) -> void:
	message_label.text=text

func show_result(victory: bool) -> void:
	battle_running=false
	result_panel.visible=true
	var title:=result_panel.get_node("Title") as Label
	var body:=result_panel.get_node("Body") as Label
	title.text="CHECKPOINT COMPLETE" if victory else "DEFEAT"
	body.text="Awakening and first battle complete." if victory else "Replay the checkpoint and test again."

func _build() -> void:
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Character status remains near the actors' side of the screen, leaving the center open.
	player_name=_label(root,"SHADOW",Vector2(42,46),Vector2(290,34),20,HORIZONTAL_ALIGNMENT_LEFT)
	player_hp=_bar(root,Vector2(42,82),Vector2(335,17))
	enemy_name=_label(root,"GRAVE HOUND",Vector2(1460,205),Vector2(370,34),20,HORIZONTAL_ALIGNMENT_RIGHT)
	enemy_hp=_bar(root,Vector2(1495,242),Vector2(335,17))

	# RAID-like utility cluster: INFO / AUTO / speed in the lower-left corner.
	var info_button:=_circle_button(root,"INFO",Vector2(25,742),Vector2(112,112),20)
	info_button.pressed.connect(func(): info_panel.visible=not info_panel.visible)
	auto_button=_circle_button(root,"AUTO",Vector2(28,858),Vector2(112,112),18)
	auto_button.pressed.connect(func():
		auto_enabled=not auto_enabled
		auto_changed.emit(auto_enabled)
	)
	speed_button=_circle_button(root,"x1",Vector2(150,866),Vector2(124,124),28)
	speed_button.pressed.connect(func():
		speed=2.0 if speed<1.5 else 1.0
		speed_changed.emit(speed)
	)

	# Top-right: pause, round and timer.
	pause_button=_circle_button(root,"Ⅱ",Vector2(1760,24),Vector2(92,92),30)
	pause_button.pressed.connect(_toggle_pause)
	round_label=_label(root,"ROUND 1 / 1",Vector2(1510,130),Vector2(320,42),25,HORIZONTAL_ALIGNMENT_RIGHT)
	timer_label=_label(root,"0:00",Vector2(1590,174),Vector2(240,42),24,HORIZONTAL_ALIGNMENT_RIGHT)

	message_label=_label(root,"",Vector2(650,848),Vector2(650,42),19,HORIZONTAL_ALIGNMENT_CENTER)

	# Skill buttons stay lower-right so the player thumb reaches them easily.
	var skill_panel:=Panel.new()
	skill_panel.position=Vector2(1305,845)
	skill_panel.size=Vector2(575,190)
	skill_panel.add_theme_stylebox_override("panel",_panel(Color(0.006,0.010,0.017,0.55),30,Color(0.17,0.15,0.08,0.20)))
	root.add_child(skill_panel)
	a1=_skill(skill_panel,"A1\nBASIC",Vector2(32,24))
	a2=_skill(skill_panel,"A2\nLUNGE",Vector2(190,24))
	var a3:=_skill(skill_panel,"A3\nLOCKED",Vector2(348,24))
	a1.disabled=true; a2.disabled=true; a3.disabled=true
	a1.pressed.connect(func(): skill_requested.emit(0))
	a2.pressed.connect(func(): skill_requested.emit(1))

	info_panel=Panel.new()
	info_panel.visible=false
	info_panel.position=Vector2(155,670)
	info_panel.size=Vector2(390,170)
	info_panel.add_theme_stylebox_override("panel",_panel(Color(0.012,0.016,0.024,0.96),18,Color(0.65,0.53,0.18,0.65)))
	root.add_child(info_panel)
	var info_text:=_label(info_panel,"TURN METER\nSpeed fills the meter.\nA2 cuts the enemy turn meter.",Vector2(22,18),Vector2(346,132),18,HORIZONTAL_ALIGNMENT_LEFT)
	info_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

	result_panel=Panel.new()
	result_panel.visible=false
	result_panel.position=Vector2(610,350)
	result_panel.size=Vector2(700,380)
	result_panel.add_theme_stylebox_override("panel",_panel(Color(0.008,0.012,0.022,0.97),30,Color(0.52,0.42,0.13,0.72)))
	root.add_child(result_panel)
	var result_title:=_label(result_panel,"",Vector2(40,42),Vector2(620,66),40,HORIZONTAL_ALIGNMENT_CENTER); result_title.name="Title"
	var result_body:=_label(result_panel,"",Vector2(65,126),Vector2(570,72),20,HORIZONTAL_ALIGNMENT_CENTER); result_body.name="Body"; result_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var replay:=_button(result_panel,"REPLAY",Vector2(80,250),Vector2(250,72),19)
	var title_btn:=_button(result_panel,"TITLE",Vector2(370,250),Vector2(250,72),19)
	replay.pressed.connect(func(): replay_requested.emit())
	title_btn.pressed.connect(func(): title_requested.emit())

func _toggle_pause() -> void:
	get_tree().paused=not get_tree().paused
	pause_button.text="▶" if get_tree().paused else "Ⅱ"
	message_label.text="PAUSED" if get_tree().paused else ""

func _circle_button(parent: Control,text_: String,pos: Vector2,size_: Vector2,font_size: int) -> Button:
	var b:=Button.new()
	b.text=text_
	b.position=pos
	b.size=size_
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",font_size)
	b.add_theme_stylebox_override("normal",_panel(Color(0.025,0.035,0.052,0.94),int(size_.x/2),Color(0.73,0.58,0.16,0.95)))
	b.add_theme_stylebox_override("hover",_panel(Color(0.045,0.062,0.090,1.0),int(size_.x/2),Color(0.86,0.69,0.20,1.0)))
	b.add_theme_stylebox_override("pressed",_panel(Color(0.065,0.085,0.12,1.0),int(size_.x/2),Color(0.95,0.78,0.25,1.0)))
	parent.add_child(b)
	return b

func _skill(parent: Control,text_: String,pos: Vector2) -> Button:
	var b:=_button(parent,text_,pos,Vector2(138,142),15)
	b.add_theme_stylebox_override("normal",_panel(Color(0.050,0.065,0.105,0.96),69,Color(0.72,0.57,0.16,0.92)))
	b.add_theme_stylebox_override("hover",_panel(Color(0.085,0.11,0.17,1.0),69,Color(0.90,0.72,0.20,1.0)))
	b.add_theme_stylebox_override("pressed",_panel(Color(0.12,0.15,0.23,1.0),69,Color(0.96,0.80,0.28,1.0)))
	b.add_theme_stylebox_override("disabled",_panel(Color(0.022,0.027,0.038,0.82),69,Color(0.23,0.22,0.18,0.70)))
	return b

func _button(parent: Control,text_: String,pos: Vector2,size_: Vector2,font_size: int) -> Button:
	var b:=Button.new()
	b.text=text_
	b.position=pos
	b.size=size_
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",font_size)
	b.add_theme_stylebox_override("normal",_panel(Color(0.040,0.052,0.080,0.95),14,Color(0.38,0.32,0.13,0.72)))
	b.add_theme_stylebox_override("hover",_panel(Color(0.070,0.090,0.14,1.0),14,Color(0.68,0.54,0.16,0.90)))
	parent.add_child(b)
	return b

func _label(parent: Control,text_: String,pos: Vector2,size_: Vector2,font_size: int,align: HorizontalAlignment) -> Label:
	var l:=Label.new()
	l.text=text_
	l.position=pos
	l.size=size_
	l.horizontal_alignment=align
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",Color(0.93,0.94,0.96))
	l.add_theme_color_override("font_outline_color",Color(0.01,0.012,0.016,0.92))
	l.add_theme_constant_override("outline_size",5)
	parent.add_child(l)
	return l

func _bar(parent: Control,pos: Vector2,size_: Vector2) -> ProgressBar:
	var p:=ProgressBar.new()
	p.position=pos
	p.size=size_
	p.max_value=100
	p.value=100
	p.show_percentage=false
	p.add_theme_stylebox_override("background",_panel(Color(0.015,0.018,0.024,0.92),7,Color(0.12,0.12,0.12,0.8)))
	p.add_theme_stylebox_override("fill",_panel(Color(0.58,0.08,0.07,1.0),7,Color(0.80,0.15,0.10,1.0)))
	parent.add_child(p)
	return p

func _panel(color: Color,radius: int,border: Color) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=color
	s.corner_radius_top_left=radius
	s.corner_radius_top_right=radius
	s.corner_radius_bottom_left=radius
	s.corner_radius_bottom_right=radius
	s.border_width_left=2
	s.border_width_right=2
	s.border_width_top=2
	s.border_width_bottom=2
	s.border_color=border
	return s
