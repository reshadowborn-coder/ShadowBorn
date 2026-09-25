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
var turn_label: Label
var message_label: Label
var a1: Button
var a2: Button
var auto_button: Button
var speed_button: Button
var result_panel: Panel
var auto_enabled := false
var speed := 1.0

func _ready() -> void:
	layer = 20
	_build()

func apply_state(snapshot: Dictionary) -> void:
	var units: Array = snapshot.get("units",[])
	var player: Dictionary = {}
	var enemy: Dictionary = {}
	for unit_variant in units:
		var unit: Dictionary = unit_variant
		if str(unit["team"]) == "player":
			player = unit
		else:
			enemy = unit

	if not player.is_empty():
		player_name.text = "SHADOW"
		player_hp.max_value = float(player["max_hp"])
		player_hp.value = float(player["hp"])
		var cds: Array = player.get("cooldowns",[0,0])
		var ready := bool(snapshot.get("player_ready",false))
		a1.disabled = not ready
		a2.disabled = (not ready) or int(cds[1]) > 0
		a2.text = "A2\nSHADOW LUNGE" if int(cds[1]) == 0 else "A2\nCOOLDOWN %d" % int(cds[1])

	if not enemy.is_empty():
		enemy_name.text = str(enemy["name"]).to_upper()
		enemy_hp.max_value = float(enemy["max_hp"])
		enemy_hp.value = float(enemy["hp"])

	var ordered := units.duplicate(true)
	ordered.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.get("meter",0.0)) > float(b.get("meter",0.0)))
	var order: Array[String] = []
	for unit_variant in ordered:
		var unit: Dictionary = unit_variant
		if int(unit["hp"]) > 0:
			order.append("%s %d%%" % [str(unit["name"]),mini(100,int(unit["meter"]))])
	turn_label.text = "   →   ".join(order)

	auto_enabled = bool(snapshot.get("auto",false))
	speed = float(snapshot.get("speed",1.0))
	auto_button.text = "AUTO ON" if auto_enabled else "AUTO OFF"
	speed_button.text = "x2" if speed > 1.5 else "x1"

func set_player_ready(value: bool) -> void:
	a1.disabled = not value
	if value:
		message_label.text = "Choose an action"

func show_message(text: String) -> void:
	message_label.text = text

func show_result(victory: bool) -> void:
	result_panel.visible = true
	var title := result_panel.get_node("Title") as Label
	var body := result_panel.get_node("Body") as Label
	title.text = "CHECKPOINT COMPLETE" if victory else "DEFEAT"
	body.text = "Awakening + first battle are ready for your test." if victory else "Replay the checkpoint and test the battle again."

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top := Panel.new()
	top.position = Vector2(250,20)
	top.size = Vector2(1420,110)
	top.add_theme_stylebox_override("panel",_panel(Color(0.012,0.018,0.029,0.86),18))
	root.add_child(top)

	player_name = _label(top,"SHADOW",Vector2(28,12),Vector2(340,30),20,HORIZONTAL_ALIGNMENT_LEFT)
	enemy_name = _label(top,"GRAVE HOUND",Vector2(1052,12),Vector2(340,30),20,HORIZONTAL_ALIGNMENT_RIGHT)

	player_hp = _bar(top,Vector2(28,52),Vector2(420,18))
	enemy_hp = _bar(top,Vector2(972,52),Vector2(420,18))

	turn_label = _label(top,"",Vector2(455,24),Vector2(510,60),18,HORIZONTAL_ALIGNMENT_CENTER)

	auto_button = _button(root,"AUTO OFF",Vector2(28,28),Vector2(165,60),18)
	auto_button.pressed.connect(func():
		auto_enabled = not auto_enabled
		auto_changed.emit(auto_enabled)
	)

	speed_button = _button(root,"x1",Vector2(28,102),Vector2(95,56),20)
	speed_button.pressed.connect(func():
		speed = 2.0 if speed < 1.5 else 1.0
		speed_changed.emit(speed)
	)

	message_label = _label(root,"",Vector2(600,835),Vector2(720,42),20,HORIZONTAL_ALIGNMENT_CENTER)

	var skill_panel := Panel.new()
	skill_panel.position = Vector2(1248,858)
	skill_panel.size = Vector2(640,190)
	skill_panel.add_theme_stylebox_override("panel",_panel(Color(0.010,0.015,0.025,0.92),28))
	root.add_child(skill_panel)

	a1 = _skill(skill_panel,"A1\nBASIC SLASH",Vector2(24,24))
	a2 = _skill(skill_panel,"A2\nSHADOW LUNGE",Vector2(180,24))
	var a3 := _skill(skill_panel,"A3\nLOCKED",Vector2(336,24))
	var a4 := _skill(skill_panel,"A4\nLOCKED",Vector2(492,24))
	a1.disabled = true
	a2.disabled = true
	a3.disabled = true
	a4.disabled = true
	a1.pressed.connect(func(): skill_requested.emit(0))
	a2.pressed.connect(func(): skill_requested.emit(1))

	result_panel = Panel.new()
	result_panel.visible = false
	result_panel.position = Vector2(610,350)
	result_panel.size = Vector2(700,380)
	result_panel.add_theme_stylebox_override("panel",_panel(Color(0.008,0.012,0.022,0.97),30))
	root.add_child(result_panel)

	var result_title := _label(result_panel,"",Vector2(40,42),Vector2(620,66),40,HORIZONTAL_ALIGNMENT_CENTER)
	result_title.name = "Title"
	var result_body := _label(result_panel,"",Vector2(65,126),Vector2(570,72),20,HORIZONTAL_ALIGNMENT_CENTER)
	result_body.name = "Body"
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var replay := _button(result_panel,"REPLAY CHECKPOINT",Vector2(80,250),Vector2(250,72),19)
	var title_btn := _button(result_panel,"RETURN TO TITLE",Vector2(370,250),Vector2(250,72),19)
	replay.pressed.connect(func(): replay_requested.emit())
	title_btn.pressed.connect(func(): title_requested.emit())

func _skill(parent: Control,text_: String,pos: Vector2) -> Button:
	var b := _button(parent,text_,pos,Vector2(132,142),15)
	b.add_theme_stylebox_override("normal",_panel(Color(0.060,0.078,0.120,0.98),48))
	b.add_theme_stylebox_override("hover",_panel(Color(0.105,0.135,0.205,1.0),48))
	b.add_theme_stylebox_override("pressed",_panel(Color(0.16,0.20,0.30,1.0),48))
	b.add_theme_stylebox_override("disabled",_panel(Color(0.026,0.032,0.045,0.86),48))
	return b

func _button(parent: Control,text_: String,pos: Vector2,size_: Vector2,font_size: int) -> Button:
	var b := Button.new()
	b.text = text_
	b.position = pos
	b.size = size_
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",font_size)
	b.add_theme_stylebox_override("normal",_panel(Color(0.045,0.058,0.090,0.95),14))
	b.add_theme_stylebox_override("hover",_panel(Color(0.075,0.095,0.145,1.0),14))
	b.add_theme_stylebox_override("pressed",_panel(Color(0.11,0.14,0.21,1.0),14))
	parent.add_child(b)
	return b

func _label(parent: Control,text_: String,pos: Vector2,size_: Vector2,font_size: int,align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text_
	l.position = pos
	l.size = size_
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",font_size)
	parent.add_child(l)
	return l

func _bar(parent: Control,pos: Vector2,size_: Vector2) -> ProgressBar:
	var p := ProgressBar.new()
	p.position = pos
	p.size = size_
	p.max_value = 100
	p.value = 100
	p.show_percentage = false
	var bg := _panel(Color(0.025,0.03,0.04,0.95),7)
	var fill := _panel(Color(0.22,0.52,0.34,1.0),7)
	p.add_theme_stylebox_override("background",bg)
	p.add_theme_stylebox_override("fill",fill)
	parent.add_child(p)
	return p

func _panel(color: Color,radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.26,0.33,0.48,0.58)
	return s
