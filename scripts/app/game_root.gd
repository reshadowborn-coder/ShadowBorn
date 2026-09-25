extends Node

var screen_layer: CanvasLayer
var awakening: AwakeningStage
var stage: BattleStage
var hud: CombatHUD
var battle: BattleController

func _ready() -> void:
	_show_title()

func _show_title() -> void:
	_clear_all()
	screen_layer = CanvasLayer.new()
	screen_layer.layer = 50
	add_child(screen_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_layer.add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.006,0.009,0.015)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var halo := Polygon2D.new()
	halo.polygon = PackedVector2Array([Vector2(520,0),Vector2(1400,0),Vector2(1230,1080),Vector2(690,1080)])
	halo.color = Color(0.045,0.062,0.105,0.65)
	root.add_child(halo)

	var title := Label.new()
	title.text = "SHADOWBORN"
	title.position = Vector2(410,225)
	title.size = Vector2(1100,120)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",78)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "THE CRADLE ABOVE  •  THE SEWERS BELOW"
	subtitle.position = Vector2(520,346)
	subtitle.size = Vector2(880,48)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size",22)
	subtitle.modulate = Color(0.74,0.79,0.89)
	root.add_child(subtitle)

	var line := ColorRect.new()
	line.color = Color(0.32,0.44,0.72,0.72)
	line.position = Vector2(760,420)
	line.size = Vector2(400,2)
	root.add_child(line)

	var start := _button(root,"BEGIN",Vector2(710,540),Vector2(500,84))
	start.pressed.connect(_start_awakening)

	var build := Label.new()
	build.text = "CHECKPOINT 01  •  AWAKENING + FIRST BATTLE"
	build.position = Vector2(560,665)
	build.size = Vector2(800,40)
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build.add_theme_font_size_override("font_size",17)
	build.modulate = Color(0.56,0.62,0.72)
	root.add_child(build)

func _start_awakening() -> void:
	_clear_all()
	awakening = AwakeningStage.new()
	add_child(awakening)
	awakening.finished.connect(_start_first_battle)

func _start_first_battle() -> void:
	if is_instance_valid(awakening):
		awakening.queue_free()
	awakening = null
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
	hud.replay_requested.connect(_start_awakening)
	hud.title_requested.connect(_show_title)

	battle.start_battle()

func _clear_all() -> void:
	if is_instance_valid(screen_layer):
		screen_layer.queue_free()
	if is_instance_valid(awakening):
		awakening.queue_free()
	if is_instance_valid(stage):
		stage.queue_free()
	if is_instance_valid(hud):
		hud.queue_free()
	if is_instance_valid(battle):
		battle.queue_free()
	screen_layer = null
	awakening = null
	stage = null
	hud = null
	battle = null

func _button(parent: Control,text_: String,pos: Vector2,size_: Vector2) -> Button:
	var b := Button.new()
	b.text = text_
	b.position = pos
	b.size = size_
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",25)
	b.add_theme_stylebox_override("normal",_style(Color(0.050,0.065,0.105,0.98),18))
	b.add_theme_stylebox_override("hover",_style(Color(0.085,0.11,0.175,1.0),18))
	b.add_theme_stylebox_override("pressed",_style(Color(0.13,0.17,0.26,1.0),18))
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
	s.border_color = Color(0.30,0.38,0.58,0.62)
	return s
