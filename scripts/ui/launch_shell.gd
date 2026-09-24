class_name LaunchShell
extends Control

const CHAPTER_SCENE := "res://scenes/chapter00/chapter00_graybox.tscn"

var main_panel:Panel
var identity_panel:Panel
var continue_button:Button
var identity_mode:="new"

func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_main()
	_build_identity()
	_refresh_continue()

func _build_background()->void:
	var bg:=ColorRect.new()
	bg.color=Color(0.025,0.03,0.04,1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title:=Label.new()
	title.text="SHADOWBORN"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left=0.5
	title.anchor_right=0.5
	title.offset_left=-360
	title.offset_right=360
	title.offset_top=90
	title.offset_bottom=170
	title.add_theme_font_size_override("font_size",46)
	add_child(title)

	var subtitle:=Label.new()
	subtitle.text="ACT 0  •  THE SHADOW AWAKENS"
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle.anchor_left=0.5
	subtitle.anchor_right=0.5
	subtitle.offset_left=-360
	subtitle.offset_right=360
	subtitle.offset_top=168
	subtitle.offset_bottom=215
	subtitle.add_theme_font_size_override("font_size",20)
	add_child(subtitle)

func _panel(size:Vector2)->Panel:
	var p:=Panel.new()
	p.anchor_left=0.5
	p.anchor_top=0.5
	p.anchor_right=0.5
	p.anchor_bottom=0.5
	p.offset_left=-size.x*0.5
	p.offset_top=-size.y*0.5
	p.offset_right=size.x*0.5
	p.offset_bottom=size.y*0.5
	add_child(p)
	return p

func _button(parent:Control,text_:String,y:float)->Button:
	var b:=Button.new()
	b.text=text_
	b.position=Vector2(50,y)
	b.size=Vector2(500,72)
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",22)
	parent.add_child(b)
	return b

func _build_main()->void:
	main_panel=_panel(Vector2(600,360))
	var header:=Label.new()
	header.text="ENTER THE CRADLE OF SHADOWS"
	header.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	header.position=Vector2(40,35)
	header.size=Vector2(520,45)
	header.add_theme_font_size_override("font_size",22)
	main_panel.add_child(header)

	continue_button=_button(main_panel,"CONTINUE",110)
	continue_button.pressed.connect(_continue_game)
	var new_game:=_button(main_panel,"NEW GAME",200)
	new_game.pressed.connect(func():_open_identity("new"))

func _build_identity()->void:
	identity_panel=_panel(Vector2(720,470))
	identity_panel.visible=false

	var header:=Label.new()
	header.text="CHOOSE THE FORM THE SHADOW REMEMBERS"
	header.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	header.position=Vector2(40,35)
	header.size=Vector2(640,45)
	header.add_theme_font_size_override("font_size",22)
	identity_panel.add_child(header)

	var info:=Label.new()
	info.name="Info"
	info.text="This choice defines the opening silhouette. Combat rules remain identical."
	info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	info.position=Vector2(55,90)
	info.size=Vector2(610,70)
	identity_panel.add_child(info)

	var male:=_button(identity_panel,"MALE FORM",180)
	male.position.x=110
	male.size.x=500
	male.pressed.connect(func():_confirm_identity("male"))

	var female:=_button(identity_panel,"FEMALE FORM",270)
	female.position.x=110
	female.size.x=500
	female.pressed.connect(func():_confirm_identity("female"))

	var back:=Button.new()
	back.text="BACK"
	back.position=Vector2(250,375)
	back.size=Vector2(220,55)
	back.focus_mode=Control.FOCUS_NONE
	back.pressed.connect(_close_identity)
	identity_panel.add_child(back)

func _refresh_continue()->void:
	continue_button.disabled=not SaveManager.has_save()

func _continue_game()->void:
	if not SaveManager.has_save():
		return
	var state:=SaveManager.load_state()
	if str(state.get("shadow_identity","")).is_empty():
		_open_identity("continue")
		return
	get_tree().change_scene_to_file(CHAPTER_SCENE)

func _open_identity(mode:String)->void:
	identity_mode=mode
	main_panel.visible=false
	identity_panel.visible=true
	var info:=identity_panel.get_node("Info") as Label
	if mode=="new" and SaveManager.has_save():
		info.text="Starting a new game replaces the current Act 0 save. Choose the remembered form to continue."
	elif mode=="continue":
		info.text="This older save has no recorded form. Choose one once; existing progress will be preserved."
	else:
		info.text="This choice defines the opening silhouette. Combat rules remain identical."

func _close_identity()->void:
	identity_panel.visible=false
	main_panel.visible=true
	_refresh_continue()

func _confirm_identity(identity:String)->void:
	var ok:=SaveManager.create_new_game(identity) if identity_mode=="new" else SaveManager.set_identity_on_existing_save(identity)
	if ok:
		get_tree().change_scene_to_file(CHAPTER_SCENE)
