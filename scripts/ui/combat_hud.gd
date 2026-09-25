class_name CombatHUD
extends CanvasLayer

signal skill_requested(index: int)
signal auto_changed(enabled: bool)
signal speed_changed(multiplier: float)
signal leave_requested

var root: Control
var wave_label: Label
var timeline_label: Label
var player_label: Label
var message_label: Label
var skill_buttons: Array[Button] = []
var auto_button: Button
var speed_button: Button
var result_panel: Panel
var auto_enabled := false
var speed := 1.0

func _ready() -> void:
	layer = 20
	_build()

func apply_state(snapshot: Dictionary) -> void:
	wave_label.text = "WAVE %d / %d" % [int(snapshot.get("wave",1)),int(snapshot.get("wave_count",1))]
	var units: Array = snapshot.get("units",[])
	var ordered := units.duplicate(true)
	ordered.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.get("meter",0.0)) > float(b.get("meter",0.0)))
	var names: Array[String] = []
	var player: Dictionary = {}
	for unit_variant in ordered:
		var unit: Dictionary = unit_variant
		if int(unit.get("hp",0)) <= 0:
			continue
		names.append("%s %d%%" % [str(unit["name"]),mini(100,int(unit.get("meter",0.0)))])
		if str(unit.get("id","")) == "shadow":
			player = unit
	timeline_label.text = "  →  ".join(names)
	if not player.is_empty():
		var status_names: Array[String] = []
		var statuses: Dictionary = player.get("statuses",{})
		for key in statuses.keys():
			if int(statuses[key]) > 0:
				status_names.append("%s %d" % [str(key).to_upper(),int(statuses[key])])
		var status_text := " • ".join(status_names)
		player_label.text = "SHADOW   HP %d / %d%s" % [int(player["hp"]),int(player["max_hp"]),("   •   "+status_text) if not status_text.is_empty() else ""]
		var cds: Array = player.get("cooldowns",[0,0])
		if skill_buttons.size() > 1:
			skill_buttons[0].text = "A1\nBASIC SLASH"
			skill_buttons[1].text = "A2\nSHADOW LUNGE" if int(cds[1]) == 0 else "A2\nCOOLDOWN %d" % int(cds[1])
			skill_buttons[1].disabled = (not bool(snapshot.get("player_ready",false))) or int(cds[1]) > 0
		skill_buttons[0].disabled = not bool(snapshot.get("player_ready",false))
	auto_enabled = bool(snapshot.get("auto",false))
	speed = float(snapshot.get("speed",1.0))
	auto_button.text = "AUTO  ON" if auto_enabled else "AUTO  OFF"
	speed_button.text = "x2" if speed > 1.5 else "x1"

func set_player_ready(value: bool) -> void:
	for i in range(mini(2,skill_buttons.size())):
		skill_buttons[i].disabled = not value

func show_message(text: String) -> void:
	message_label.text = text

func show_result(victory: bool) -> void:
	result_panel.visible = true
	var title := result_panel.get_node("Title") as Label
	title.text = "VICTORY" if victory else "DEFEAT"
	var body := result_panel.get_node("Body") as Label
	body.text = "The path through the sewers opens." if victory else "The Shadow is cast back toward the Temple."

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top := Panel.new()
	top.position = Vector2(250,20)
	top.size = Vector2(1420,112)
	top.add_theme_stylebox_override("panel",_panel_style(Color(0.018,0.024,0.035,0.88),18))
	root.add_child(top)

	wave_label = Label.new()
	wave_label.position = Vector2(24,12)
	wave_label.size = Vector2(220,36)
	wave_label.add_theme_font_size_override("font_size",22)
	top.add_child(wave_label)

	timeline_label = Label.new()
	timeline_label.position = Vector2(250,12)
	timeline_label.size = Vector2(1140,36)
	timeline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timeline_label.add_theme_font_size_override("font_size",20)
	top.add_child(timeline_label)

	player_label = Label.new()
	player_label.position = Vector2(24,57)
	player_label.size = Vector2(1360,36)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_font_size_override("font_size",22)
	top.add_child(player_label)

	auto_button = _button(root,"AUTO  OFF",Vector2(26,26),Vector2(170,62),20)
	auto_button.pressed.connect(func():
		auto_enabled = not auto_enabled
		auto_button.text = "AUTO  ON" if auto_enabled else "AUTO  OFF"
		auto_changed.emit(auto_enabled)
	)

	speed_button = _button(root,"x1",Vector2(26,102),Vector2(100,58),22)
	speed_button.pressed.connect(func():
		speed = 2.0 if speed < 1.5 else 1.0
		speed_button.text = "x2" if speed > 1.5 else "x1"
		speed_changed.emit(speed)
	)

	message_label = Label.new()
	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.anchor_top = 1.0
	message_label.anchor_bottom = 1.0
	message_label.offset_left = -360
	message_label.offset_right = 360
	message_label.offset_top = -258
	message_label.offset_bottom = -214
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size",20)
	root.add_child(message_label)

	var skill_panel := Panel.new()
	skill_panel.anchor_left = 1.0
	skill_panel.anchor_right = 1.0
	skill_panel.anchor_top = 1.0
	skill_panel.anchor_bottom = 1.0
	skill_panel.offset_left = -690
	skill_panel.offset_right = -28
	skill_panel.offset_top = -200
	skill_panel.offset_bottom = -26
	skill_panel.add_theme_stylebox_override("panel",_panel_style(Color(0.015,0.020,0.030,0.90),24))
	root.add_child(skill_panel)

	var names := ["A1\nBASIC SLASH","A2\nSHADOW LUNGE","A3\nLOCKED","A4\nLOCKED"]
	for i in range(4):
		var b := _button(skill_panel,names[i],Vector2(20+i*158,20),Vector2(142,132),16)
		b.add_theme_stylebox_override("normal",_skill_style(Color(0.07,0.09,0.13,0.98)))
		b.add_theme_stylebox_override("hover",_skill_style(Color(0.11,0.14,0.20,1.0)))
		b.add_theme_stylebox_override("pressed",_skill_style(Color(0.17,0.21,0.30,1.0)))
		b.add_theme_stylebox_override("disabled",_skill_style(Color(0.035,0.04,0.052,0.82)))
		b.disabled = true
		if i < 2:
			b.pressed.connect(func(index:=i): skill_requested.emit(index))
		skill_panel.add_child(b)
		skill_buttons.append(b)

	result_panel = Panel.new()
	result_panel.visible = false
	result_panel.anchor_left = 0.5
	result_panel.anchor_right = 0.5
	result_panel.anchor_top = 0.5
	result_panel.anchor_bottom = 0.5
	result_panel.offset_left = -330
	result_panel.offset_right = 330
	result_panel.offset_top = -170
	result_panel.offset_bottom = 170
	result_panel.add_theme_stylebox_override("panel",_panel_style(Color(0.012,0.016,0.025,0.96),28))
	root.add_child(result_panel)

	var title := Label.new()
	title.name = "Title"
	title.position = Vector2(30,34)
	title.size = Vector2(600,64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",42)
	result_panel.add_child(title)
	var body := Label.new()
	body.name = "Body"
	body.position = Vector2(45,112)
	body.size = Vector2(570,70)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size",19)
	result_panel.add_child(body)
	var leave := _button(result_panel,"RETURN TO CAMPAIGN",Vector2(145,224),Vector2(370,72),20)
	leave.pressed.connect(func(): leave_requested.emit())
	result_panel.add_child(leave)

func _button(parent: Control,text_: String,pos: Vector2,size_: Vector2,font_size: int) -> Button:
	var b := Button.new()
	b.text = text_
	b.position = pos
	b.size = size_
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",font_size)
	b.add_theme_stylebox_override("normal",_panel_style(Color(0.045,0.055,0.078,0.94),14))
	b.add_theme_stylebox_override("hover",_panel_style(Color(0.075,0.09,0.13,1.0),14))
	b.add_theme_stylebox_override("pressed",_panel_style(Color(0.10,0.13,0.19,1.0),14))
	return b

func _panel_style(color: Color,radius: int) -> StyleBoxFlat:
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
	s.border_color = Color(0.22,0.27,0.36,0.55)
	return s

func _skill_style(color: Color) -> StyleBoxFlat:
	var s := _panel_style(color,42)
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_color = Color(0.34,0.41,0.56,0.72)
	return s
