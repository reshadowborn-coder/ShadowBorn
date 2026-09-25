class_name BattleStage
extends Node3D

var actor_nodes: Dictionary = {}
var actor_home: Dictionary = {}
var actor_labels: Dictionary = {}
var actor_busy: Dictionary = {}
var battle_camera: Camera3D
var clock := 0.0

func _ready() -> void:
	_build_environment()
	set_process(true)

func apply_state(snapshot: Dictionary) -> void:
	var units: Array = snapshot.get("units",[])
	for unit_variant in units:
		var unit: Dictionary = unit_variant
		var id := str(unit["id"])
		if not actor_nodes.has(id):
			_spawn_actor(unit)
		_update_label(unit)

func play_windup(attacker_id: String,target_id: String,skill_id: String) -> void:
	if not actor_nodes.has(attacker_id) or not actor_nodes.has(target_id):
		return
	actor_busy[attacker_id] = true
	var attacker: Node3D = actor_nodes[attacker_id]
	var target: Node3D = actor_nodes[target_id]
	CharacterFactory.play_named_animation(attacker,["attack","Attack","Attack_01","Basic_Attack"])

	var home: Vector3 = actor_home[attacker_id]
	var direction := (target.position-home).normalized()
	var distance := 1.05
	if skill_id == "shadow_lunge":
		distance = 1.65
	elif skill_id == "hound_rend":
		distance = 1.22

	var anticipation := create_tween()
	anticipation.tween_property(attacker,"position",home-direction*0.16,0.08)
	anticipation.tween_property(attacker,"position",home+direction*distance,0.15 if skill_id!="shadow_lunge" else 0.19).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if skill_id == "shadow_lunge":
		var cam := create_tween()
		cam.set_parallel(true)
		cam.tween_property(battle_camera,"fov",33.5,0.17)
		cam.tween_property(battle_camera,"position",Vector3(0.45,3.35,9.65),0.17)

func play_impact(attacker_id: String,target_id: String,skill_id: String,damage: int,effect: String) -> void:
	if not actor_nodes.has(target_id):
		return
	var target: Node3D = actor_nodes[target_id]
	var home: Vector3 = actor_home[target_id]
	CharacterFactory.play_named_animation(target,["hit","Hit","Damage","Hit_01"])

	var direction := 1.0 if home.x > 0 else -1.0
	var hit := create_tween()
	hit.tween_property(target,"position",home+Vector3(0.24*direction,0.06,0),0.055)
	hit.tween_property(target,"position",home,0.13).set_trans(Tween.TRANS_BACK)
	_spawn_impact_flash(target.global_position+Vector3(0,1.0,0))
	_spawn_damage_text(target.global_position+Vector3(0,2.2,0),damage,effect)

	if actor_nodes.has(attacker_id):
		var attacker: Node3D = actor_nodes[attacker_id]
		var a_home: Vector3 = actor_home[attacker_id]
		var recover := create_tween()
		recover.tween_interval(0.06)
		recover.tween_property(attacker,"position",a_home,0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		recover.tween_callback(func():
			actor_busy[attacker_id] = false
			CharacterFactory.play_named_animation(attacker,["idle","Idle","Idle_Combat"])
		)

	if skill_id == "shadow_lunge":
		var cam_back := create_tween()
		cam_back.set_parallel(true)
		cam_back.tween_property(battle_camera,"fov",38.0,0.26)
		cam_back.tween_property(battle_camera,"position",Vector3(0.25,3.42,10.15),0.26)

func play_death(actor_id: String) -> void:
	if not actor_nodes.has(actor_id):
		return
	var actor: Node3D = actor_nodes[actor_id]
	actor_busy[actor_id] = true
	if CharacterFactory.play_named_animation(actor,["death","Death","Die"]):
		return
	var home: Vector3 = actor_home[actor_id]
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(actor,"rotation_degrees:z",-82.0 if home.x>0 else 82.0,0.40).set_trans(Tween.TRANS_QUAD)
	t.tween_property(actor,"position:y",-0.12,0.40)

func _process(delta: float) -> void:
	clock += delta
	for id_variant in actor_nodes.keys():
		var id := str(id_variant)
		if bool(actor_busy.get(id,false)):
			continue
		var actor: Node3D = actor_nodes[id]
		var home: Vector3 = actor_home[id]
		var phase := float(abs(id.hash()%100))*0.071
		actor.position = home+Vector3(0,sin(clock*1.55+phase)*0.025,0)
		var visual := actor.get_node_or_null("Visual") as Node3D
		if visual:
			visual.rotation_degrees.z = sin(clock*0.92+phase)*0.55

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006,0.008,0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12,0.145,0.19)
	env.ambient_light_energy = 0.50
	env.fog_enabled = true
	env.fog_light_color = Color(0.06,0.075,0.095)
	env.fog_light_energy = 0.50
	env.fog_density = 0.025
	world.environment = env
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52,-28,0)
	moon.light_color = Color(0.60,0.72,1.0)
	moon.light_energy = 0.95
	moon.shadow_enabled = true
	add_child(moon)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-3.1,2.4,-1.4)
	rim.light_color = Color(0.23,0.36,0.75)
	rim.light_energy = 3.4
	rim.omni_range = 5.2
	add_child(rim)

	var fire := OmniLight3D.new()
	fire.position = Vector3(4.8,1.8,-1.6)
	fire.light_color = Color(1.0,0.28,0.07)
	fire.light_energy = 3.6
	fire.omni_range = 4.8
	add_child(fire)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(15.5,9.5)
	plane.material = _mat(Color(0.045,0.050,0.058),0.78,0.05)
	floor.mesh = plane
	add_child(floor)

	_add_box(Vector3(0,2.45,-4.05),Vector3(15.5,4.9,0.55),Color(0.067,0.074,0.084))
	_add_box(Vector3(-7.45,1.9,-0.4),Vector3(0.52,3.8,7.5),Color(0.060,0.066,0.075))
	_add_box(Vector3(7.45,1.9,-0.4),Vector3(0.52,3.8,7.5),Color(0.060,0.066,0.075))

	for x in [-5.2,-2.6,2.6,5.2]:
		_add_box(Vector3(x,1.75,-3.75),Vector3(0.36,3.5,0.34),Color(0.105,0.11,0.12))
		var top := _box_node(Vector3(0.68,0.16,0.58),Color(0.13,0.135,0.145))
		top.position = Vector3(x,3.50,-3.75)
		add_child(top)

	_build_brazier(Vector3(4.8,0,-1.6))
	_build_graves()

	battle_camera = Camera3D.new()
	battle_camera.current = true
	battle_camera.fov = 38.0
	battle_camera.position = Vector3(0.25,3.42,10.15)
	add_child(battle_camera)
	battle_camera.look_at(Vector3(0.0,1.05,-0.45),Vector3.UP)

func _build_graves() -> void:
	for i in range(5):
		var side := -1.0 if i%2==0 else 1.0
		var root := Node3D.new()
		root.position = Vector3(side*(5.8+0.25*(i%2)),0,-2.5+1.35*i)
		root.rotation_degrees.y = -12.0+float(i)*7.0
		add_child(root)
		var base := _box_node(Vector3(1.15,0.16,0.54),Color(0.075,0.08,0.09))
		base.position.y = 0.08
		root.add_child(base)
		var marker := _box_node(Vector3(0.62,1.00,0.18),Color(0.09,0.095,0.105))
		marker.position = Vector3(0,0.58,0)
		root.add_child(marker)

func _spawn_actor(unit: Dictionary) -> void:
	var id := str(unit["id"])
	var root := Node3D.new()
	root.name = id
	root.position = Vector3(-2.65,0,0.15) if id=="shadow" else Vector3(2.95,0,-0.10)
	root.rotation_degrees.y = -66.0 if id=="shadow" else 66.0
	add_child(root)
	actor_nodes[id] = root
	actor_home[id] = root.position
	actor_busy[id] = false

	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	var model := CharacterFactory.create_shadow() if id=="shadow" else CharacterFactory.create_hound()
	if id=="grave_hound":
		model.scale = Vector3(1.08,1.08,1.08)
	visual.add_child(model)
	CharacterFactory.play_named_animation(model,["idle","Idle","Idle_Combat"])

	var label := Label3D.new()
	label.position = Vector3(0,2.75,0) if id=="shadow" else Vector3(0,1.78,0)
	label.font_size = 28
	label.outline_size = 9
	root.add_child(label)
	actor_labels[id] = label

func _update_label(unit: Dictionary) -> void:
	var id := str(unit["id"])
	if not actor_labels.has(id):
		return
	var hp := int(unit["hp"])
	var max_hp := maxi(1,int(unit["max_hp"]))
	var ratio := clampf(float(hp)/float(max_hp),0,1)
	var filled := int(round(ratio*10.0))
	var label: Label3D = actor_labels[id]
	label.text = "%s\n%s%s" % [str(unit["name"]),"█".repeat(filled),"░".repeat(10-filled)]

func _spawn_impact_flash(pos: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.30
	mesh.radial_segments = 12
	mesh.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72,0.82,1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.72,0.82,1.0)
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	flash.mesh = mesh
	flash.position = pos
	add_child(flash)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(flash,"scale",Vector3.ONE*3.2,0.12)
	t.tween_property(flash,"modulate:a",0.0,0.12)
	t.chain().tween_callback(flash.queue_free)

func _spawn_damage_text(pos: Vector3,damage: int,effect: String) -> void:
	var label := Label3D.new()
	label.text = "-%d%s" % [damage,("  "+effect) if not effect.is_empty() else ""]
	label.font_size = 44
	label.outline_size = 11
	label.position = pos
	add_child(label)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(label,"position",pos+Vector3(0,0.65,0),0.55)
	t.tween_property(label,"modulate:a",0.15,0.55)
	t.chain().tween_callback(label.queue_free)

func _mat(color: Color,rough: float,metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
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

func _cylinder(radius: float,height: float,color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh.material = _mat(color,0.62,0.18)
	n.mesh = mesh
	return n

func _sphere(radius: float,color: Color,emission: bool=false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mat := _mat(color,0.62,0.0)
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.7
	mesh.material = mat
	n.mesh = mesh
	return n

func _build_brazier(pos: Vector3) -> void:
	var stand := _cylinder(0.09,1.10,Color(0.10,0.09,0.085))
	stand.position = pos+Vector3(0,0.55,0)
	add_child(stand)
	var bowl := _cylinder(0.32,0.16,Color(0.16,0.09,0.05))
	bowl.position = pos+Vector3(0,1.14,0)
	add_child(bowl)
	for i in range(3):
		var flame := _sphere(0.10,Color(1.0,0.23+0.09*i,0.035),true)
		flame.position = pos+Vector3((i-1)*0.08,1.35+0.05*i,0)
		flame.scale.y = 1.6
		add_child(flame)
