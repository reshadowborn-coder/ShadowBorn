extends Node

var screen_layer: CanvasLayer
var stage: BattleStage
var hud: CombatHUD
var battle: BattleController

func _ready() -> void:
	_show_title()

func _clear_screen() -> void:
	if is_instance_valid(screen_layer):
		screen_layer.queue_free()
	screen_layer = null

func _show_title() -> void:
	_clear_runtime()
	_clear_screen()
	screen_layer = CanvasLayer.new()
	screen_layer.layer = 50
	add_child(screen_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.010,0.014,0.022)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var halo := Polygon2D.new()
	halo.polygon = PackedVector2Array([Vector2(480,0),Vector2(1440,0),Vector2(1240,1080),Vector2(680,1080)])
	halo.color = Color(0.06,0.08,0.13,0.55)
	root.add_child(halo)

	var title := Label.new()
	title.text = "SHADOWBORN"
	title.position = Vector2(420,210)
	title.size = Vector2(1080,110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",74)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "THE CRADLE ABOVE  •  THE SEWERS BELOW"
	subtitle.position = Vector2(520,318)
	subtitle.size = Vector2(880,46)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size",22)
	root.add_child(subtitle)

	var line := ColorRect.new()
	line.color = Color(0.32,0.42,0.66,0.72)
	line.position = Vector2(760,390)
	line.size = Vector2(400,2)
	root.add_child(line)

	var enter := _screen_button(root,"NEW GAME",Vector2(710,520),Vector2(500,82))
	enter.pressed.connect(_show_campaign)

	var note := Label.new()
	note.text = "Turn-based dark fantasy RPG • iPhone-first"
	note.position = Vector2(660,630)
	note.size = Vector2(600,42)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size",18)
	note.modulate = Color(0.72,0.76,0.84)
	root.add_child(note)

func _show_campaign() -> void:
	_clear_runtime()
	_clear_screen()
	screen_layer = CanvasLayer.new()
	screen_layer.layer = 50
	add_child(screen_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.012,0.017,0.024)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var heading := Label.new()
	heading.text = "CAMPAIGN"
	heading.position = Vector2(110,75)
	heading.size = Vector2(600,70)
	heading.add_theme_font_size_override("font_size",46)
	root.add_child(heading)

	var chapter := Label.new()
	chapter.text = "ACT I  —  BENEATH THE TEMPLE"
	chapter.position = Vector2(110,155)
	chapter.size = Vector2(900,54)
	chapter.add_theme_font_size_override("font_size",28)
	root.add_child(chapter)

	var route := ColorRect.new()
	route.color = Color(0.08,0.10,0.14,0.72)
	route.position = Vector2(230,500)
	route.size = Vector2(1250,6)
	root.add_child(route)

	var node := Button.new()
	node.text = "1.1\nSEWERS"
	node.position = Vector2(420,400)
	node.size = Vector2(180,180)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size",24)
	node.add_theme_stylebox_override("normal",_style(Color(0.055,0.07,0.105,1),90))
	node.add_theme_stylebox_override("hover",_style(Color(0.09,0.12,0.18,1),90))
	node.pressed.connect(_start_battle)
	root.add_child(node)

	var locked := Button.new()
	locked.text = "1.2\nLOCKED"
	locked.position = Vector2(820,400)
	locked.size = Vector2(180,180)
	locked.disabled = true
	locked.add_theme_font_size_override("font_size",22)
	locked.add_theme_stylebox_override("disabled",_style(Color(0.025,0.03,0.04,0.9),90))
	root.add_child(locked)

	var desc := Label.new()
	desc.text = "Enter a staged battle room. No free-roam movement: combat, timing and build decisions are the game."
	desc.position = Vector2(300,680)
	desc.size = Vector2(1320,84)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size",22)
	root.add_child(desc)

func _start_battle() -> void:
	_clear_screen()
	stage = BattleStage.new()
	add_child(stage)
	hud = CombatHUD.new()
	add_child(hud)
	battle = BattleController.new()
	add_child(battle)

	battle.state_changed.connect(stage.apply_state)
	battle.state_changed.connect(hud.apply_state)
	battle.actor_ready.connect(func(_id:String): hud.set_player_ready(true))
	battle.action_windup.connect(stage.play_windup)
	battle.action_impact.connect(stage.play_impact)
	battle.actor_died.connect(stage.play_death)
	battle.battle_message.connect(hud.show_message)
	battle.battle_finished.connect(hud.show_result)

	hud.skill_requested.connect(battle.request_player_skill)
	hud.auto_changed.connect(battle.set_auto)
	hud.speed_changed.connect(battle.set_speed)
	hud.leave_requested.connect(_show_campaign)

	battle.start_battle()

func _clear_runtime() -> void:
	if is_instance_valid(stage):
		stage.queue_free()
	if is_instance_valid(hud):
		hud.queue_free()
	if is_instance_valid(battle):
		battle.queue_free()
	stage = null
	hud = null
	battle = null

func _screen_button(parent: Control,text_: String,pos: Vector2,size_: Vector2) -> Button:
	var b := Button.new()
	b.text = text_
	b.position = pos
	b.size = size_
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",24)
	b.add_theme_stylebox_override("normal",_style(Color(0.055,0.07,0.105,1),18))
	b.add_theme_stylebox_override("hover",_style(Color(0.09,0.12,0.18,1),18))
	b.add_theme_stylebox_override("pressed",_style(Color(0.13,0.17,0.25,1),18))
	parent.add_child(b)
	return b

func _style(color: Color,radius: int) -> StyleBoxFlat:
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
	s.border_color = Color(0.27,0.34,0.49,0.65)
	return s
