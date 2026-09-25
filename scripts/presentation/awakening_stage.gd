class_name AwakeningStage
extends Node3D

signal finished

var camera: Camera3D
var shadow_root: Node3D
var shadow_visual: Node3D
var overlay: CanvasLayer
var subtitle: Label
var skip_button: Button
var vignette: ColorRect
var top_bar: ColorRect
var bottom_bar: ColorRect
var sequence_done := false
var skipping := false
var clock := 0.0
var motes: Array[Node3D] = []

func _ready() -> void:
	_build_world()
	_build_shadow()
	_build_overlay()
	_play_sequence()

func _process(delta: float) -> void:
	clock += delta
	for i in range(motes.size()):
		var mote := motes[i]
		var base_y := float(mote.get_meta("base_y",0.0))
		var phase := float(mote.get_meta("phase",0.0))
		mote.position.y = base_y + sin(clock*0.45+phase)*0.15
		mote.position.x += sin(clock*0.21+phase)*delta*0.015
	if sequence_done or not is_instance_valid(shadow_root):
		return
	if shadow_root.rotation_degrees.x < 25.0:
		shadow_root.position.y += sin(clock*1.65)*delta*0.008

func _unhandled_input(event: InputEvent) -> void:
	if skipping or sequence_done:
		return
	if event is InputEventScreenTouch and event.pressed:
		_finish_sequence()
	elif event is InputEventMouseButton and event.pressed:
		_finish_sequence()

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004,0.006,0.010)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.10,0.125,0.17)
	env.ambient_light_energy = 0.42
	env.fog_enabled = true
	env.fog_light_color = Color(0.055,0.075,0.10)
	env.fog_light_energy = 0.48
	env.fog_density = 0.032
	world.environment = env
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58,-18,0)
	moon.light_color = Color(0.52,0.66,1.0)
	moon.light_energy = 0.86
	moon.shadow_enabled = true
	add_child(moon)

	var cold := SpotLight3D.new()
	cold.position = Vector3(0,5.4,1.2)
	cold.rotation_degrees = Vector3(-68,0,0)
	cold.light_color = Color(0.38,0.52,1.0)
	cold.light_energy = 5.2
	cold.spot_range = 10.0
	cold.spot_angle = 34.0
	cold.shadow_enabled = true
	add_child(cold)

	for x in [-3.9,3.9]:
		var warm := OmniLight3D.new()
		warm.position = Vector3(x,1.65,-1.0)
		warm.light_color = Color(1.0,0.30,0.08)
		warm.light_energy = 2.8
		warm.omni_range = 4.0
		add_child(warm)
		_build_brazier(Vector3(x,0,-1.0))

	_build_crypt()
	_build_motes()

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 36.0
	camera.position = Vector3(0.78,1.72,4.85)
	add_child(camera)
	camera.look_at(Vector3(0,1.02,0.15),Vector3.UP)

func _build_crypt() -> void:
	var floor_mat := _mat(Color(0.055,0.060,0.067),0.94,0.0)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(13.5,10.0)
	plane.material = floor_mat
	floor.mesh = plane
	add_child(floor)

	_add_box(Vector3(0,2.6,-4.25),Vector3(13.5,5.2,0.55),Color(0.075,0.082,0.092))
	_add_box(Vector3(-6.5,2.2,-0.4),Vector3(0.55,4.4,7.8),Color(0.068,0.074,0.083))
	_add_box(Vector3(6.5,2.2,-0.4),Vector3(0.55,4.4,7.8),Color(0.068,0.074,0.083))

	for x in [-4.6,-2.25,2.25,4.6]:
		_add_box(Vector3(x,1.75,-3.96),Vector3(0.42,3.5,0.34),Color(0.105,0.112,0.124))
		var capital := _box_node(Vector3(0.66,0.18,0.54),Color(0.13,0.135,0.145))
		capital.position = Vector3(x,3.46,-3.96)
		add_child(capital)

	var round_frame := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.18
	torus.rings = 24
	torus.ring_segments = 32
	torus.material = _mat(Color(0.12,0.13,0.145),0.92,0.0)
	round_frame.mesh = torus
	round_frame.position = Vector3(0,3.25,-3.90)
	round_frame.rotation_degrees.x = 90
	round_frame.scale.y = 1.12
	add_child(round_frame)

	var window_void := _disc(0.88,Color(0.008,0.012,0.022))
	window_void.position = Vector3(0,3.25,-4.05)
	window_void.rotation_degrees.x = 90
	add_child(window_void)

	var slab_base := _box_node(Vector3(2.55,0.42,4.15),Color(0.10,0.105,0.115))
	slab_base.position = Vector3(0,0.22,0.25)
	add_child(slab_base)
	var slab_top := _box_node(Vector3(2.20,0.20,3.72),Color(0.15,0.15,0.16))
	slab_top.position = Vector3(0,0.53,0.25)
	add_child(slab_top)
	for z in [-1.16,1.64]:
		var brace := _box_node(Vector3(2.75,0.18,0.25),Color(0.072,0.075,0.082))
		brace.position = Vector3(0,0.40,z)
		add_child(brace)

	for i in range(8):
		var rubble := _box_node(Vector3(0.20+0.07*(i%3),0.14+0.05*(i%2),0.24+0.06*((i+1)%3)),Color(0.08+0.005*i,0.085+0.004*i,0.092+0.004*i))
		rubble.position = Vector3(-5.2+1.45*(i%4),0.08,-3.0+5.2*(i/4))
		rubble.rotation_degrees = Vector3(float(i*7),float(i*31),float(i*11))
		add_child(rubble)

	var root := Node3D.new()
	root.position = Vector3(4.7,0,-2.85)
	add_child(root)
	for i in range(5):
		var cross := _box_node(Vector3(0.10,0.85+0.08*i,0.10),Color(0.07,0.06,0.055))
		cross.position = Vector3(0,0.50+0.12*i,0)
		cross.rotation_degrees.z = -16+8*i
		root.add_child(cross)

func _build_shadow() -> void:
	shadow_root = Node3D.new()
	shadow_root.name = "AwakeningShadow"
	shadow_root.position = Vector3(0,0.82,0.26)
	shadow_root.rotation_degrees = Vector3(86,180,0)
	add_child(shadow_root)
	shadow_visual = CharacterFactory.create_shadow()
	shadow_visual.scale = Vector3(1.06,1.06,1.06)
	shadow_root.add_child(shadow_visual)
	CharacterFactory.play_named_animation(shadow_visual,["idle","Idle","Idle_Combat"])

func _build_motes() -> void:
	for i in range(24):
		var mote := _sphere(0.016+0.004*(i%3),Color(0.25,0.31,0.42),true)
		mote.position = Vector3(-5.4+float((i*37)%108)/10.0,0.55+float((i*19)%33)/10.0,-3.5+float((i*29)%67)/10.0)
		mote.set_meta("base_y",mote.position.y)
		mote.set_meta("phase",float(i)*0.73)
		add_child(mote)
		motes.append(mote)

func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 40
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(root)

	vignette = ColorRect.new()
	vignette.color = Color(0,0,0,1)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)

	top_bar = ColorRect.new()
	top_bar.color = Color(0,0,0,1)
	top_bar.position = Vector2(0,0)
	top_bar.size = Vector2(1920,92)
	root.add_child(top_bar)

	bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0,0,0,1)
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = -92
	bottom_bar.offset_bottom = 0
	bottom_bar.offset_right = 1920
	root.add_child(bottom_bar)

	subtitle = Label.new()
	subtitle.anchor_left = 0.5
	subtitle.anchor_right = 0.5
	subtitle.anchor_top = 1.0
	subtitle.anchor_bottom = 1.0
	subtitle.offset_left = -650
	subtitle.offset_right = 650
	subtitle.offset_top = -175
	subtitle.offset_bottom = -108
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size",27)
	subtitle.add_theme_color_override("font_color",Color(0.86,0.89,0.95))
	root.add_child(subtitle)

	skip_button = Button.new()
	skip_button.text = "SKIP"
	skip_button.position = Vector2(1742,112)
	skip_button.size = Vector2(130,52)
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.modulate = Color(1,1,1,0.74)
	skip_button.pressed.connect(_finish_sequence)
	root.add_child(skip_button)

func _play_sequence() -> void:
	var fade := create_tween()
	fade.tween_interval(0.35)
	fade.tween_property(vignette,"color:a",0.0,1.45).set_trans(Tween.TRANS_SINE)
	await fade.finished
	if skipping: return

	subtitle.text = "Cold stone. No breath. Yet something remembers."
	await get_tree().create_timer(2.0).timeout
	if skipping: return

	for child in shadow_visual.get_children():
		if child.name == "GlowEye":
			child.visible = true
	var pulse := create_tween()
	pulse.tween_property(camera,"fov",32.0,0.55).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(camera,"fov",36.0,0.60).set_trans(Tween.TRANS_SINE)
	await pulse.finished
	if skipping: return

	subtitle.text = "A name returns before a voice."
	var rise := create_tween()
	rise.set_parallel(true)
	rise.tween_property(shadow_root,"rotation_degrees",Vector3(8,180,0),1.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	rise.tween_property(shadow_root,"position",Vector3(0,0.62,0.18),1.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	rise.tween_property(camera,"position",Vector3(3.15,2.55,7.15),1.65).set_trans(Tween.TRANS_CUBIC)
	await rise.finished
	camera.look_at(Vector3(0,1.22,0),Vector3.UP)
	if skipping: return

	await get_tree().create_timer(1.05).timeout
	if skipping: return
	subtitle.text = "SHADOW."
	await get_tree().create_timer(1.35).timeout
	if skipping: return

	subtitle.text = "Stone scrapes beyond the broken gate."
	var warn := create_tween()
	warn.tween_property(camera,"position",Vector3(-2.7,2.20,6.55),0.95).set_trans(Tween.TRANS_SINE)
	await warn.finished
	camera.look_at(Vector3(1.8,0.9,-2.2),Vector3.UP)
	await get_tree().create_timer(1.25).timeout
	if skipping: return
	_finish_sequence()

func _finish_sequence() -> void:
	if skipping or sequence_done:
		return
	skipping = true
	sequence_done = true
	subtitle.text = ""
	skip_button.disabled = true
	var out := create_tween()
	out.tween_property(vignette,"color:a",1.0,0.45)
	await out.finished
	finished.emit()

func _mat(color: Color, rough: float=0.8, metallic: float=0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

func _box_node(size: Vector3,color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color,0.90,0.0)
	n.mesh = mesh
	return n

func _add_box(pos: Vector3,size: Vector3,color: Color) -> void:
	var n := _box_node(size,color)
	n.position = pos
	add_child(n)

func _sphere(radius: float,color: Color,emission: bool=false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mat := _mat(color,0.65,0.0)
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.35
	mesh.material = mat
	n.mesh = mesh
	return n

func _cylinder(radius: float,height: float,color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh.material = _mat(color,0.64,0.22)
	n.mesh = mesh
	return n

func _disc(radius: float,color: Color) -> MeshInstance3D:
	return _cylinder(radius,0.045,color)

func _build_brazier(pos: Vector3) -> void:
	var stand := _cylinder(0.09,1.15,Color(0.10,0.09,0.085))
	stand.position = pos+Vector3(0,0.58,0)
	add_child(stand)
	var bowl := _cylinder(0.34,0.16,Color(0.16,0.09,0.05))
	bowl.position = pos+Vector3(0,1.20,0)
	add_child(bowl)
	for i in range(3):
		var flame := _sphere(0.105,Color(1.0,0.22+0.10*i,0.035),true)
		flame.position = pos+Vector3((i-1)*0.09,1.42+0.055*i,0)
		flame.scale.y = 1.65
		add_child(flame)
