extends Node3D
class_name RaidlikeVerticalSlice

const BG := Color(0.018, 0.022, 0.030, 1.0)
const STONE := Color(0.105, 0.115, 0.135, 1.0)
const STONE_2 := Color(0.145, 0.155, 0.175, 1.0)
const FLOOR := Color(0.055, 0.060, 0.070, 1.0)
const EMBER := Color(0.90, 0.31, 0.08, 1.0)
const SHADOW := Color(0.038, 0.045, 0.065, 1.0)
const SHADOW_EDGE := Color(0.16, 0.18, 0.23, 1.0)
const ENEMY_SKIN := Color(0.28, 0.34, 0.29, 1.0)
const ALLY_SKIN := Color(0.48, 0.38, 0.33, 1.0)

var camera: Camera3D
var actors: Array[Node3D] = []
var actor_data: Array[Dictionary] = []
var current_turn := -1
var player_ready := false
var auto_mode := true
var battle_speed := 1.0
var hud_state: Label
var turn_bar: HBoxContainer
var skill_buttons: Array[Button] = []
var auto_button: Button
var speed_button: Button
var battle_clock := 0.0
var busy := false

func _ready() -> void:
	_build_environment()
	_build_combatants()
	_build_hud()
	_refresh_turn_bar()

func _process(delta: float) -> void:
	var scaled := delta * battle_speed
	battle_clock += scaled
	for i in range(actors.size()):
		var a := actors[i]
		if not is_instance_valid(a):
			continue
		var base_y: float = actor_data[i]["base_y"]
		a.position.y = base_y + sin(battle_clock * 1.7 + float(i) * 0.83) * 0.035
		var chest := a.get_node_or_null("Visual/Chest") as Node3D
		if chest:
			chest.rotation_degrees.z = sin(battle_clock * 1.1 + float(i)) * 0.8
	if busy:
		return
	for i in range(actor_data.size()):
		if actor_data[i]["hp"] <= 0:
			continue
		actor_data[i]["meter"] = minf(100.0, float(actor_data[i]["meter"]) + float(actor_data[i]["speed"]) * scaled * 0.62)
	var next := _find_ready_actor()
	if next >= 0:
		_begin_turn(next)

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.16,0.18,0.22)
	e.ambient_light_energy = 0.52
	e.fog_enabled = true
	e.fog_light_color = Color(0.07,0.08,0.10)
	e.fog_density = 0.022
	e.volumetric_fog_enabled = false
	env.environment = e
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-47,-22,0)
	key.light_color = Color(0.74,0.80,1.0)
	key.light_energy = 1.15
	key.shadow_enabled = true
	add_child(key)

	for x in [-5.7, 5.7]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x,2.2,-2.0)
		lamp.light_color = Color(1.0,0.27,0.07)
		lamp.light_energy = 3.0
		lamp.omni_range = 5.2
		lamp.shadow_enabled = false
		add_child(lamp)
		_make_brazier(Vector3(x,0.0,-2.0))

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0,9.0)
	plane.subdivide_width = 12
	plane.subdivide_depth = 7
	plane.material = _mat(FLOOR,0.92,0.0)
	floor_mesh.mesh = plane
	floor_mesh.position.y = 0.0
	add_child(floor_mesh)

	var dais := _box(Vector3(0,-0.16,-1.7),Vector3(14.2,0.28,5.0),STONE)
	add_child(dais)
	for x in [-6.3,-4.7,4.7,6.3]:
		var pillar := _cylinder(Vector3(x,2.25,-3.2),0.42,4.5,STONE_2)
		add_child(pillar)
		var cap := _cylinder(Vector3(x,4.55,-3.2),0.62,0.24,STONE)
		add_child(cap)
	var rear := _box(Vector3(0,2.1,-4.0),Vector3(14.8,4.2,0.55),STONE)
	add_child(rear)
	for x in [-3.2,0.0,3.2]:
		var arch_root := Node3D.new()
		arch_root.position = Vector3(x,0,-3.68)
		add_child(arch_root)
		var l := _box(Vector3(-0.95,1.45,0),Vector3(0.32,2.9,0.36),STONE_2)
		var r := _box(Vector3(0.95,1.45,0),Vector3(0.32,2.9,0.36),STONE_2)
		var top := _cylinder(Vector3(0,2.95,0),1.08,0.30,STONE_2)
		top.rotation_degrees.x = 90
		top.scale.y = 0.30
		arch_root.add_child(l); arch_root.add_child(r); arch_root.add_child(top)

	var cam_rig := Node3D.new()
	add_child(cam_rig)
	camera = Camera3D.new()
	camera.fov = 39.0
	camera.position = Vector3(0.15,3.65,10.8)
	camera.current = true
	cam_rig.add_child(camera)
	camera.look_at(Vector3(0,1.35,-0.7),Vector3.UP)

func _build_combatants() -> void:
	_add_actor("Shadow",Vector3(-3.2,0.0,0.45),-66.0,true,118.0,52.0,SHADOW,ALLY_SKIN,"sword")
	_add_actor("Acolyte",Vector3(-2.25,0.0,-1.15),-61.0,true,92.0,46.0,Color(0.10,0.08,0.13),ALLY_SKIN,"staff")
	_add_actor("Sewer Rat",Vector3(2.55,0.0,0.55),66.0,false,74.0,45.0,Color(0.18,0.16,0.13),ENEMY_SKIN,"claw")
	_add_actor("Venom Rat",Vector3(3.55,0.0,-1.10),61.0,false,82.0,51.0,Color(0.13,0.21,0.13),ENEMY_SKIN,"claw")

func _add_actor(name_:String,pos:Vector3,yaw:float,is_player:bool,hp:float,speed:float,body:Color,skin:Color,weapon:String) -> void:
	var root := Node3D.new()
	root.name = name_.replace(" ","")
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)

	var shadow := _disc(Vector3(0,0.02,0),0.68,Color(0.0,0.0,0.0,0.46))
	shadow.scale.z = 0.56
	visual.add_child(shadow)

	var leg_l := _capsule(Vector3(-0.17,0.55,0),0.14,0.78,body)
	var leg_r := _capsule(Vector3(0.17,0.55,0),0.14,0.78,body)
	visual.add_child(leg_l); visual.add_child(leg_r)

	var chest := _capsule(Vector3(0,1.35,0),0.39,1.10,body)
	chest.name = "Chest"
	visual.add_child(chest)
	var belt := _cylinder(Vector3(0,1.03,0),0.37,0.16,SHADOW_EDGE)
	visual.add_child(belt)
	var shoulder_l := _sphere(Vector3(-0.43,1.58,0),0.24,SHADOW_EDGE)
	var shoulder_r := _sphere(Vector3(0.43,1.58,0),0.24,SHADOW_EDGE)
	visual.add_child(shoulder_l); visual.add_child(shoulder_r)

	var arm_l := _capsule(Vector3(-0.47,1.22,0),0.11,0.72,body)
	var arm_r := _capsule(Vector3(0.47,1.22,0),0.11,0.72,body)
	arm_l.rotation_degrees.z = -8; arm_r.rotation_degrees.z = 8
	visual.add_child(arm_l); visual.add_child(arm_r)

	var neck := _cylinder(Vector3(0,1.86,0),0.13,0.20,skin)
	visual.add_child(neck)
	var head := _sphere(Vector3(0,2.11,0),0.28,skin)
	head.scale = Vector3(0.92,1.08,0.88)
	visual.add_child(head)
	var hair_or_hood := _sphere(Vector3(0,2.22,-0.015),0.294,body)
	hair_or_hood.scale = Vector3(1.0,0.72,1.0)
	visual.add_child(hair_or_hood)

	# Readable face details: visible in the battle camera instead of blank capsules.
	var eye_mat := Color(0.76,0.84,0.92) if is_player else Color(0.86,0.45,0.20)
	for ex in [-0.092,0.092]:
		var eye := _sphere(Vector3(ex,2.13,0.245),0.035,eye_mat)
		visual.add_child(eye)
	var nose := _sphere(Vector3(0,2.06,0.275),0.038,skin.darkened(0.06))
	nose.scale = Vector3(0.65,1.0,0.75)
	visual.add_child(nose)
	var mouth := _box(Vector3(0,1.985,0.268),Vector3(0.105,0.018,0.018),skin.darkened(0.38))
	visual.add_child(mouth)

	if is_player and name_ == "Shadow":
		var mask := _box(Vector3(0,2.10,0.245),Vector3(0.48,0.18,0.035),Color(0.02,0.025,0.035))
		visual.add_child(mask)
		for ex in [-0.092,0.092]:
			var glow_eye := _sphere(Vector3(ex,2.13,0.274),0.033,Color(0.45,0.58,0.92))
			visual.add_child(glow_eye)

	_add_weapon(visual,weapon,body,is_player)

	actors.append(root)
	actor_data.append({
		"name":name_,
		"player":is_player,
		"hp":hp,
		"max_hp":hp,
		"speed":speed,
		"meter":float(15 + actors.size()*7),
		"base_y":pos.y
	})

func _add_weapon(parent:Node3D,weapon:String,body:Color,is_player:bool)->void:
	match weapon:
		"sword":
			var blade := _box(Vector3(0.63,1.10,0.02),Vector3(0.075,1.15,0.045),Color(0.36,0.40,0.47))
			blade.rotation_degrees.z = -18
			parent.add_child(blade)
			var guard := _box(Vector3(0.48,0.73,0.02),Vector3(0.34,0.07,0.07),SHADOW_EDGE)
			guard.rotation_degrees.z = -18
			parent.add_child(guard)
		"staff":
			var staff := _cylinder(Vector3(0.62,1.16,0.02),0.045,1.55,Color(0.20,0.12,0.08))
			staff.rotation_degrees.z = -15
			parent.add_child(staff)
			var orb := _sphere(Vector3(0.82,1.90,0.02),0.14,Color(0.34,0.18,0.50))
			parent.add_child(orb)
		"claw":
			for zoff in [-0.08,0.0,0.08]:
				var claw := _box(Vector3(-0.58,1.05,0.12+zoff),Vector3(0.35,0.035,0.035),Color(0.38,0.34,0.24))
				claw.rotation_degrees.z = 12
				parent.add_child(claw)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var top_panel := Panel.new()
	top_panel.anchor_left = 0.5
	top_panel.anchor_right = 0.5
	top_panel.offset_left = -560
	top_panel.offset_right = 560
	top_panel.offset_top = 18
	top_panel.offset_bottom = 118
	root.add_child(top_panel)

	turn_bar = HBoxContainer.new()
	turn_bar.position = Vector2(18,14)
	turn_bar.size = Vector2(1084,72)
	turn_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	turn_bar.add_theme_constant_override("separation",12)
	top_panel.add_child(turn_bar)

	hud_state = Label.new()
	hud_state.anchor_left = 0.5
	hud_state.anchor_right = 0.5
	hud_state.offset_left = -260
	hud_state.offset_right = 260
	hud_state.offset_top = 128
	hud_state.offset_bottom = 172
	hud_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_state.text = "AUTO BATTLE • WAITING FOR TURN"
	hud_state.add_theme_font_size_override("font_size",20)
	root.add_child(hud_state)

	var bottom := Panel.new()
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -178
	bottom.offset_bottom = -22
	bottom.anchor_left = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_left = -690
	bottom.offset_right = -24
	root.add_child(bottom)

	var labels := ["A1\nBASIC","A2\nSHADOW LUNGE","A3\nLOCKED","A4\nLOCKED"]
	for i in range(4):
		var b := Button.new()
		b.text = labels[i]
		b.position = Vector2(18 + i*158,18)
		b.size = Vector2(142,116)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size",16)
		if i >= 2:
			b.disabled = true
		else:
			b.pressed.connect(_skill_pressed.bind(i))
		bottom.add_child(b)
		skill_buttons.append(b)

	auto_button = Button.new()
	auto_button.text = "AUTO: ON"
	auto_button.position = Vector2(28,26)
	auto_button.size = Vector2(170,64)
	auto_button.focus_mode = Control.FOCUS_NONE
	auto_button.pressed.connect(_toggle_auto)
	root.add_child(auto_button)

	speed_button = Button.new()
	speed_button.text = "x1"
	speed_button.position = Vector2(214,26)
	speed_button.size = Vector2(100,64)
	speed_button.focus_mode = Control.FOCUS_NONE
	speed_button.pressed.connect(_toggle_speed)
	root.add_child(speed_button)

func _refresh_turn_bar() -> void:
	for c in turn_bar.get_children():
		c.queue_free()
	var order := actor_data.duplicate()
	order.sort_custom(func(a:Dictionary,b:Dictionary): return float(a["meter"]) > float(b["meter"]))
	for data in order:
		if data["hp"] <= 0:
			continue
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(150,66)
		var n := Label.new()
		n.text = str(data["name"])
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var hp := ProgressBar.new()
		hp.max_value = float(data["max_hp"])
		hp.value = float(data["hp"])
		hp.show_percentage = false
		hp.custom_minimum_size = Vector2(150,12)
		var tm := ProgressBar.new()
		tm.max_value = 100.0
		tm.value = float(data["meter"])
		tm.show_percentage = false
		tm.custom_minimum_size = Vector2(150,8)
		box.add_child(n); box.add_child(hp); box.add_child(tm)
		turn_bar.add_child(box)

func _find_ready_actor() -> int:
	var best := -1
	var best_meter := 99.999
	for i in range(actor_data.size()):
		if actor_data[i]["hp"] <= 0:
			continue
		var m := float(actor_data[i]["meter"])
		if m >= 100.0 and m > best_meter:
			best_meter = m
			best = i
	return best

func _begin_turn(index:int) -> void:
	current_turn = index
	actor_data[index]["meter"] = maxf(0.0,float(actor_data[index]["meter"]) - 100.0)
	_refresh_turn_bar()
	var data := actor_data[index]
	hud_state.text = "%s'S TURN" % str(data["name"]).to_upper()
	if data["player"]:
		player_ready = true
		if auto_mode:
			busy = true
			await get_tree().create_timer(0.30 / battle_speed).timeout
			_execute_attack(index,0)
	else:
		busy = true
		await get_tree().create_timer(0.38 / battle_speed).timeout
		_execute_attack(index,0)

func _skill_pressed(skill_index:int) -> void:
	if not player_ready or current_turn < 0 or busy:
		return
	if not actor_data[current_turn]["player"]:
		return
	busy = true
	player_ready = false
	_execute_attack(current_turn,skill_index)

func _execute_attack(attacker_index:int,skill_index:int) -> void:
	var target := _pick_target(not bool(actor_data[attacker_index]["player"]))
	if target < 0:
		_end_battle(bool(actor_data[attacker_index]["player"]))
		return
	var attacker := actors[attacker_index]
	var defender := actors[target]
	var start := attacker.position
	var toward := (defender.position-start).normalized()
	var lunge := start + toward * (0.72 if skill_index == 0 else 1.05)
	var tween := create_tween()
	tween.set_speed_scale(battle_speed)
	tween.tween_property(attacker,"position",lunge,0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	var damage := 16.0 if skill_index == 0 else 29.0
	actor_data[target]["hp"] = maxf(0.0,float(actor_data[target]["hp"])-damage)
	_hit_reaction(defender,damage)
	await get_tree().create_timer(0.13 / battle_speed).timeout
	var back := create_tween()
	back.set_speed_scale(battle_speed)
	back.tween_property(attacker,"position",start,0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	if actor_data[target]["hp"] <= 0:
		await _death(target)
	_refresh_turn_bar()
	player_ready = false
	current_turn = -1
	busy = false
	if _pick_target(true) < 0:
		_end_battle(false)
	elif _pick_target(false) < 0:
		_end_battle(true)
	else:
		hud_state.text = "TURN METER RUNNING"

func _hit_reaction(defender:Node3D,damage:float)->void:
	hud_state.text = "-%d DAMAGE" % int(damage)
	var original := defender.scale
	var t := create_tween()
	t.set_speed_scale(battle_speed)
	t.tween_property(defender,"scale",Vector3(original.x*0.93,original.y*1.03,original.z*0.93),0.07)
	t.tween_property(defender,"scale",original,0.11)

func _death(index:int) -> void:
	var a := actors[index]
	var t := create_tween()
	t.set_speed_scale(battle_speed)
	t.tween_property(a,"rotation_degrees:x",-78.0,0.34).set_trans(Tween.TRANS_QUAD)
	await t.finished

func _pick_target(want_player:bool) -> int:
	for i in range(actor_data.size()):
		if bool(actor_data[i]["player"]) == want_player and float(actor_data[i]["hp"]) > 0.0:
			return i
	return -1

func _end_battle(players_won:bool)->void:
	busy = true
	player_ready = false
	hud_state.text = "VICTORY" if players_won else "DEFEAT"

func _toggle_auto()->void:
	auto_mode = not auto_mode
	auto_button.text = "AUTO: ON" if auto_mode else "AUTO: OFF"

func _toggle_speed()->void:
	battle_speed = 2.0 if battle_speed < 1.5 else 1.0
	speed_button.text = "x2" if battle_speed > 1.5 else "x1"

func _mat(color:Color,rough:float=0.8,metal:float=0.0)->StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func _box(pos:Vector3,size:Vector3,color:Color)->MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color,0.86)
	n.mesh = mesh
	n.position = pos
	return n

func _capsule(pos:Vector3,radius:float,height:float,color:Color)->MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _mat(color,0.76)
	n.mesh = mesh
	n.position = pos
	return n

func _sphere(pos:Vector3,radius:float,color:Color)->MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _mat(color,0.72)
	n.mesh = mesh
	n.position = pos
	return n

func _cylinder(pos:Vector3,radius:float,height:float,color:Color)->MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.material = _mat(color,0.82)
	n.mesh = mesh
	n.position = pos
	return n

func _disc(pos:Vector3,radius:float,color:Color)->MeshInstance3D:
	var n := _cylinder(pos,radius,0.025,color)
	return n

func _make_brazier(pos:Vector3)->void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var stand := _cylinder(Vector3(0,0.65,0),0.12,1.3,Color(0.13,0.13,0.14))
	root.add_child(stand)
	var bowl := _cylinder(Vector3(0,1.25,0),0.42,0.18,Color(0.16,0.10,0.07))
	root.add_child(bowl)
	for i in range(3):
		var flame := _sphere(Vector3((i-1)*0.10,1.48,0),0.13,EMBER)
		flame.scale.y = 1.6
		root.add_child(flame)
