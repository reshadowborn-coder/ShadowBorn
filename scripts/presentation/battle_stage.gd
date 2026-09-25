class_name BattleStage
extends Node3D

const PLAYER_HOME := Vector3(-2.85,0.0,1.55)
const ENEMY_HOME := Vector3(2.65,0.0,-1.20)
const CAMERA_HOME := Vector3(-6.25,4.55,8.10)
const CAMERA_TARGET := Vector3(0.35,1.02,-0.45)

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
	var target_home: Vector3 = actor_home[target_id]
	var direction := (target_home-home).normalized()
	var distance := 1.18
	if skill_id == "shadow_lunge":
		distance = 1.88
	elif skill_id == "hound_rend":
		distance = 1.42

	var anticipation := create_tween()
	anticipation.tween_property(attacker,"position",home-direction*0.18,0.09)
	anticipation.tween_property(attacker,"position",home+direction*distance,0.16 if skill_id!="shadow_lunge" else 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if skill_id == "shadow_lunge":
		var cam := create_tween()
		cam.set_parallel(true)
		cam.tween_property(battle_camera,"position",CAMERA_HOME+Vector3(0.65,-0.22,-0.70),0.18).set_trans(Tween.TRANS_SINE)
		cam.tween_property(battle_camera,"fov",34.0,0.18)

func play_impact(attacker_id: String,target_id: String,skill_id: String,damage: int,effect: String) -> void:
	if not actor_nodes.has(target_id):
		return
	var target: Node3D = actor_nodes[target_id]
	var home: Vector3 = actor_home[target_id]
	CharacterFactory.play_named_animation(target,["hit","Hit","Damage","Hit_01"])

	var attacker_home: Vector3 = actor_home.get(attacker_id,Vector3.ZERO)
	var away := (home-attacker_home).normalized()
	var hit := create_tween()
	hit.tween_property(target,"position",home+away*0.28+Vector3(0,0.05,0),0.055)
	hit.tween_property(target,"position",home,0.14).set_trans(Tween.TRANS_BACK)
	_spawn_impact_flash(target.global_position+Vector3(0,1.0,0))
	_spawn_damage_text(target.global_position+Vector3(0,2.15,0),damage,effect)

	if actor_nodes.has(attacker_id):
		var attacker: Node3D = actor_nodes[attacker_id]
		var a_home: Vector3 = actor_home[attacker_id]
		var recover := create_tween()
		recover.tween_interval(0.07)
		recover.tween_property(attacker,"position",a_home,0.23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		recover.tween_callback(func():
			actor_busy[attacker_id] = false
			CharacterFactory.play_named_animation(attacker,["idle","Idle","Idle_Combat"])
		)

	if skill_id == "shadow_lunge":
		var cam_back := create_tween()
		cam_back.set_parallel(true)
		cam_back.tween_property(battle_camera,"position",CAMERA_HOME,0.28)
		cam_back.tween_property(battle_camera,"fov",37.0,0.28)

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
	t.tween_property(actor,"rotation_degrees:z",-78.0 if home.x>0 else 78.0,0.42).set_trans(Tween.TRANS_QUAD)
	t.tween_property(actor,"position",home+Vector3(0,-0.12,0.14),0.42)

func _process(delta: float) -> void:
	clock += delta
	for id_variant in actor_nodes.keys():
		var id := str(id_variant)
		if bool(actor_busy.get(id,false)):
			continue
		var actor: Node3D = actor_nodes[id]
		var home: Vector3 = actor_home[id]
		var phase := float(abs(id.hash()%100))*0.071
		actor.position = home+Vector3(0,sin(clock*1.48+phase)*0.022,0)
		var visual := actor.get_node_or_null("Visual") as Node3D
		if visual:
			visual.rotation_degrees.z = sin(clock*0.88+phase)*0.45

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004,0.006,0.010)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.095,0.115,0.15)
	env.ambient_light_energy = 0.46
	env.fog_enabled = true
	env.fog_light_color = Color(0.045,0.058,0.075)
	env.fog_light_energy = 0.44
	env.fog_density = 0.022
	world.environment = env
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48,-34,0)
	moon.light_color = Color(0.54,0.66,0.96)
	moon.light_energy = 0.88
	moon.shadow_enabled = true
	add_child(moon)

	var player_rim := OmniLight3D.new()
	player_rim.position = Vector3(-3.7,2.5,0.5)
	player_rim.light_color = Color(0.28,0.40,0.86)
	player_rim.light_energy = 3.0
	player_rim.omni_range = 5.0
	add_child(player_rim)

	var enemy_fire := OmniLight3D.new()
	enemy_fire.position = Vector3(4.3,1.65,-2.7)
	enemy_fire.light_color = Color(1.0,0.23,0.05)
	enemy_fire.light_energy = 3.4
	enemy_fire.omni_range = 4.8
	add_child(enemy_fire)

	# Broad battle platform, composed for a diagonal camera like the supplied RAID references.
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.5,11.5)
	plane.material = _mat(Color(0.043,0.047,0.053),0.83,0.03)
	floor.mesh = plane
	add_child(floor)

	# Raised broken edges leave the central combat lane open.
	for i in range(8):
		var left := _box_node(Vector3(1.0+0.18*(i%3),0.18,0.72),Color(0.064,0.068,0.075))
		left.position = Vector3(-6.65+0.18*(i%2),0.10,-4.3+1.25*i)
		left.rotation_degrees.y = -12+5*i
		add_child(left)
		var right := _box_node(Vector3(1.05+0.12*((i+1)%3),0.18,0.70),Color(0.064,0.068,0.075))
		right.position = Vector3(6.45-0.16*(i%2),0.10,-4.1+1.22*i)
		right.rotation_degrees.y = 10-4*i
		add_child(right)

	# Distant architecture gives depth behind the enemy team instead of a flat wall.
	_add_box(Vector3(0,2.35,-5.55),Vector3(15.8,4.7,0.48),Color(0.050,0.055,0.064))
	for x in [-5.0,-2.2,0.8,3.8,5.7]:
		_add_box(Vector3(x,1.85,-5.20),Vector3(0.38,3.7,0.42),Color(0.085,0.09,0.10))
		var cap := _box_node(Vector3(0.70,0.17,0.60),Color(0.105,0.11,0.12))
		cap.position=Vector3(x,3.70,-5.20)
		add_child(cap)

	# A broken circular motif / gate is centered behind enemies.
	var gate := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.15
	ring.outer_radius = 1.48
	ring.rings = 20
	ring.ring_segments = 30
	ring.material = _mat(Color(0.095,0.10,0.11),0.91,0.0)
	gate.mesh = ring
	gate.position = Vector3(2.8,2.65,-5.02)
	gate.rotation_degrees.x = 90
	gate.scale.y = 1.12
	add_child(gate)

	_build_brazier(Vector3(4.25,0,-2.75))
	_build_brazier(Vector3(-5.0,0,-3.55))

	# Camera: rear-left of player, elevated, aimed diagonally across the field.
	battle_camera = Camera3D.new()
	battle_camera.current = true
	battle_camera.fov = 37.0
	battle_camera.position = CAMERA_HOME
	add_child(battle_camera)
	battle_camera.look_at(CAMERA_TARGET,Vector3.UP)

func _spawn_actor(unit: Dictionary) -> void:
	var id := str(unit["id"])
	var root := Node3D.new()
	root.name = id
	root.position = PLAYER_HOME if id=="shadow" else ENEMY_HOME
	add_child(root)
	actor_nodes[id] = root
	actor_home[id] = root.position
	actor_busy[id] = false

	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	var model := CharacterFactory.create_shadow(true) if id=="shadow" else CharacterFactory.create_hound()
	if id=="grave_hound":
		model.scale = Vector3(1.12,1.12,1.12)
	visual.add_child(model)
	CharacterFactory.play_named_animation(model,["idle","Idle","Idle_Combat"])

	# Face the opponent across the diagonal lane.
	var opponent := ENEMY_HOME if id=="shadow" else PLAYER_HOME
	root.look_at(opponent,Vector3.UP)
	root.rotation_degrees.x = 0
	root.rotation_degrees.z = 0

	var label := Label3D.new()
	label.position = Vector3(0,2.65,0) if id=="shadow" else Vector3(0,1.72,0)
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
	mesh.radius = 0.14
	mesh.height = 0.28
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
	var stand := _cylinder(0.09,1.05,Color(0.085,0.075,0.07))
	stand.position = pos+Vector3(0,0.53,0)
	add_child(stand)
	var bowl := _cylinder(0.30,0.15,Color(0.14,0.075,0.045))
	bowl.position = pos+Vector3(0,1.08,0)
	add_child(bowl)
	for i in range(3):
		var flame := _sphere(0.095,Color(1.0,0.22+0.08*i,0.03),true)
		flame.position = pos+Vector3((i-1)*0.075,1.29+0.045*i,0)
		flame.scale.y=1.6
		add_child(flame)
