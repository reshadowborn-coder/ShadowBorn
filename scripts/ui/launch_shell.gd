class_name LaunchShell
extends Control

const CHAPTER_SCENE := "res://scenes/chapter00/chapter00_graybox.tscn"

var main_panel:Panel
var identity_panel:Panel
var continue_button:Button
var confirm_panel:Panel
var identity_mode:="new"
var pending_identity:=""
var touch_target:=72.0

func _ready()->void:
	touch_target=MobileSafeArea.minimum_touch_target(get_viewport(),44.0,72.0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_main()
	_build_identity()
	_build_replace_confirm()
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
	b.size=Vector2(500,touch_target)
	b.custom_minimum_size=Vector2(500,touch_target)
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",22)
	parent.add_child(b)
	return b

func _build_main()->void:
	var panel_height:=maxf(360.0,110.0+touch_target*2.0+24.0+40.0)
	main_panel=_panel(Vector2(600,panel_height))
	var header:=Label.new()
	header.text="ENTER THE CRADLE OF SHADOWS"
	header.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	header.position=Vector2(40,35)
	header.size=Vector2(520,45)
	header.add_theme_font_size_override("font_size",22)
	main_panel.add_child(header)

	continue_button=_button(main_panel,"CONTINUE",110)
	continue_button.pressed.connect(_continue_game)
	var new_game:=_button(main_panel,"NEW GAME",110.0+touch_target+24.0)
	new_game.pressed.connect(func():_open_identity("new"))

func _build_identity()->void:
	var identity_height:=maxf(470.0,180.0+touch_target*3.0+48.0+30.0)
	identity_panel=_panel(Vector2(720,identity_height))
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

	var female:=_button(identity_panel,"FEMALE FORM",180.0+touch_target+24.0)
	female.position.x=110
	female.size.x=500
	female.pressed.connect(func():_confirm_identity("female"))

	var back:=Button.new()
	back.text="BACK"
	back.position=Vector2(250,180.0+touch_target*2.0+48.0)
	back.size=Vector2(220,touch_target)
	back.custom_minimum_size=Vector2(220,touch_target)
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
	if identity_mode=="new" and SaveManager.has_save():
		pending_identity=identity
		identity_panel.visible=false
		confirm_panel.visible=true
		return
	_commit_identity(identity)


func _build_replace_confirm()->void:
	var confirm_height:=maxf(300.0,195.0+touch_target+35.0)
	confirm_panel=_panel(Vector2(620,confirm_height))
	confirm_panel.visible=false

	var header:=Label.new()
	header.text="REPLACE CURRENT SAVE?"
	header.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	header.position=Vector2(40,35)
	header.size=Vector2(540,45)
	header.add_theme_font_size_override("font_size",24)
	confirm_panel.add_child(header)

	var body:=Label.new()
	body.name="Body"
	body.text="Your current Act 0 progress will be replaced. This cannot be undone from the game menu."
	body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.position=Vector2(55,95)
	body.size=Vector2(510,70)
	confirm_panel.add_child(body)

	var replace:=Button.new()
	replace.text="REPLACE SAVE"
	replace.position=Vector2(55,195)
	replace.size=Vector2(240,touch_target)
	replace.custom_minimum_size=Vector2(240,touch_target)
	replace.focus_mode=Control.FOCUS_NONE
	replace.pressed.connect(_replace_confirmed)
	confirm_panel.add_child(replace)

	var cancel:=Button.new()
	cancel.text="CANCEL"
	cancel.position=Vector2(325,195)
	cancel.size=Vector2(240,touch_target)
	cancel.custom_minimum_size=Vector2(240,touch_target)
	cancel.focus_mode=Control.FOCUS_NONE
	cancel.pressed.connect(_cancel_replace)
	confirm_panel.add_child(cancel)

func _replace_confirmed()->void:
	if pending_identity.is_empty():
		return
	if _commit_identity(pending_identity):
		pending_identity=""

func _cancel_replace()->void:
	pending_identity=""
	var body:=confirm_panel.get_node_or_null("Body") as Label
	if body:
		body.text="Your current Act 0 progress will be replaced. This cannot be undone from the game menu."
	confirm_panel.visible=false
	identity_panel.visible=true

func _commit_identity(identity:String)->bool:
	var ok:=SaveManager.create_new_game(identity) if identity_mode=="new" else SaveManager.set_identity_on_existing_save(identity)
	if ok:
		get_tree().change_scene_to_file(CHAPTER_SCENE)
		return true

	if confirm_panel.visible:
		var body:=confirm_panel.get_node_or_null("Body") as Label
		if body:
			body.text="The save could not be written. Your current game has not been replaced. You can retry or cancel."
	elif identity_panel.visible:
		var info:=identity_panel.get_node_or_null("Info") as Label
		if info:
			info.text="The save could not be written. Check available storage and try again."
	return false

func _unhandled_input(event:InputEvent)->void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if confirm_panel.visible:
		_cancel_replace()
	elif identity_panel.visible:
		_close_identity()
	get_viewport().set_input_as_handled()
