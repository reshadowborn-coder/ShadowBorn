class_name BattleStage
extends Node3D

const SHADOW_SCENE := "res://assets/characters/shadow/shadow.glb"
const RAT_SCENE := "res://assets/characters/rat/rat.glb"

var actor_nodes: Dictionary = {}
var actor_home: Dictionary = {}
var actor_labels: Dictionary = {}
var actor_busy: Dictionary = {}
var material_cache: Dictionary = {}
var battle_camera: Camera3D
var clock := 0.0

func _ready() -> void:
	_build_environment()
	set_process(true)

func apply_state(snapshot: Dictionary) -> void:
	var units: Array = snapshot.get("units",[])
	var live_ids: Dictionary = {}
	var enemy_index := 0
	for unit_variant in units:
		var unit: Dictionary = unit_variant
		var id := str(unit.get("id",""))
		live_ids[id] = true
		if not actor_nodes.has(id):
			var team := str(unit.get("team",""))
			var pos := _player_position() if team == "player" else _enemy_position(enemy_index)
			if team == "enemy":
				enemy_index += 1
			_spawn_actor(unit,pos)
		elif str(unit.get("team","")) == "enemy":
			enemy_index += 1
		_update_label(unit)
	for id_variant in actor_nodes.keys():
		var id := str(id_variant)
		if not live_ids.has(id):
			_remove_actor(id)

func show_wave(wave: int, total: int) -> void:
	var banner := Label3D.new()
	banner.text = "WAVE %d / %d" % [wave,total]
	banner.font_size = 54
	banner.outline_size = 12
	banner.position = Vector3(0,4.2,-1.2)
	add_child(banner)
	var tween := create_tween()
	tween.tween_property(banner,"position",Vector3(0,4.55,-1.2),0.55)
	tween.tween_interval(0.55)
	tween.tween_callback(banner.queue_free)

func play_windup(attacker_id: String, target_id: String, skill_id: String) -> void:
	if not actor_nodes.has(attacker_id) or not actor_nodes.has(target_id):
		return
	actor_busy[attacker_id] = true
	var attacker: Node3D = actor_nodes[attacker_id]
	var target: Node3D = actor_nodes[target_id]
	var home: Vector3 = actor_home[attacker_id]
	var direction := (target.global_position - attacker.global_position).normalized()
	var distance := 0.90 if skill_id != "shadow_lunge" else 1.42
	var strike := home + Vector3(direction.x,0.0,direction.z) * distance
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(attacker,"position",strike,0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(attacker,"rotation_degrees:y",attacker.rotation_degrees.y + (-8.0 if attacker.position.x < 0 else 8.0),0.13)
	if skill_id == "shadow_lunge":
		t.tween_property(battle_camera,"fov",34.0,0.14)

func play_impact(attacker_id: String, target_id: String, skill_id: String, damage: int, effect: String) -> void:
	if not actor_nodes.has(target_id):
		return
	var target: Node3D = actor_nodes[target_id]
	var target_home: Vector3 = actor_home[target_id]
	var kick := -0.18 if target_home.x > 0 else 0.18
	var hit := create_tween()
	hit.tween_property(target,"position",target_home + Vector3(kick,0.05,0),0.055)
	hit.tween_property(target,"position",target_home,0.12).set_trans(Tween.TRANS_BACK)
	_spawn_damage_text(target_home + Vector3(0,2.6,0),damage,effect)
	if actor_nodes.has(attacker_id):
		var attacker: Node3D = actor_nodes[attacker_id]
		var home: Vector3 = actor_home[attacker_id]
		var recover := create_tween()
		recover.tween_property(attacker,"position",home,0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		recover.parallel().tween_property(attacker,"rotation_degrees:y",_home_yaw(attacker_id),0.20)
		recover.tween_callback(func(): actor_busy[attacker_id] = false)
	if skill_id == "shadow_lunge":
		create_tween().tween_property(battle_camera,"fov",39.0,0.24)

func play_death(actor_id: String) -> void:
	if not actor_nodes.has(actor_id):
		return
	actor_busy[actor_id] = true
	var actor: Node3D = actor_nodes[actor_id]
	var t := create_tween()
	t.tween_property(actor,"rotation_degrees",Vector3(-12.0,actor.rotation_degrees.y,-82.0),0.38).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(actor,"position:y",-0.18,0.38)

func _process(delta: float) -> void:
	clock += delta
	for id_variant in actor_nodes.keys():
		var id := str(id_variant)
		if bool(actor_busy.get(id,false)):
			continue
		var actor: Node3D = actor_nodes[id]
		var home: Vector3 = actor_home[id]
		var phase := float(abs(id.hash() % 100)) * 0.071
		actor.position = home + Vector3(0,sin(clock*1.55+phase)*0.025,0)
		var visual := actor.get_node_or_null("Visual") as Node3D
		if visual:
			visual.rotation_degrees.z = sin(clock*0.92+phase)*0.65

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.010,0.013,0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.14,0.17,0.22)
	env.ambient_light_energy = 0.58
	env.fog_enabled = true
	env.fog_light_color = Color(0.055,0.07,0.085)
	env.fog_light_energy = 0.55
	env.fog_density = 0.022
	world.environment = env
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48,-24,0)
	moon.light_color = Color(0.70,0.80,1.0)
	moon.light_energy = 1.05
	moon.shadow_enabled = true
	add_child(moon)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(17,10)
	plane.material = _material(Color(0.050,0.058,0.066),0.40,0.12)
	floor.mesh = plane
	add_child(floor)

	var water := MeshInstance3D.new()
	var water_plane := PlaneMesh.new()
	water_plane.size = Vector2(4.4,9.2)
	water_plane.material = _material(Color(0.025,0.052,0.058),0.18,0.18)
	water.mesh = water_plane
	water.position = Vector3(0,-0.035,-0.4)
	add_child(water)

	_add_box(Vector3(0,2.6,-4.3),Vector3(16,5.2,0.55),Color(0.075,0.083,0.092))
	_add_box(Vector3(-7.55,2.2,-0.5),Vector3(0.55,4.4,8.2),Color(0.070,0.078,0.086))
	_add_box(Vector3(7.55,2.2,-0.5),Vector3(0.55,4.4,8.2),Color(0.070,0.078,0.086))

	for x in [-5.7,-2.85,2.85,5.7]:
		_add_arch(x)

	for x in [-6.15,6.15]:
		_add_pipe(x)
		_add_brazier(Vector3(x,0,-2.2))

	for z in [-3.2,-1.1,1.0,3.1]:
		_add_box(Vector3(-6.95,0.18,z),Vector3(1.0,0.24,1.2),Color(0.09,0.095,0.10))
		_add_box(Vector3(6.95,0.18,z+0.35),Vector3(1.1,0.22,1.0),Color(0.085,0.09,0.095))

	battle_camera = Camera3D.new()
	battle_camera.position = Vector3(0.15,3.65,10.7)
	battle_camera.fov = 39.0
	battle_camera.current = true
	add_child(battle_camera)
	battle_camera.look_at(Vector3(0,1.28,-0.85),Vector3.UP)

func _add_arch(x: float) -> void:
	_add_box(Vector3(x-0.72,1.95,-3.96),Vector3(0.38,3.9,0.34),Color(0.11,0.12,0.13))
	_add_box(Vector3(x+0.72,1.95,-3.96),Vector3(0.38,3.9,0.34),Color(0.11,0.12,0.13))
	var crown := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.58
	ring.outer_radius = 0.90
	ring.rings = 16
	ring.ring_segments = 24
	ring.material = _material(Color(0.105,0.115,0.125),0.88,0.0)
	crown.mesh = ring
	crown.position = Vector3(x,3.45,-3.95)
	crown.rotation_degrees.x = 90
	crown.scale = Vector3(1,1,0.72)
	add_child(crown)

func _add_pipe(x: float) -> void:
	var pipe := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 0.18
	mesh.height = 6.8
	mesh.radial_segments = 18
	mesh.material = _material(Color(0.08,0.085,0.09),0.50,0.58)
	pipe.mesh = mesh
	pipe.position = Vector3(x,2.65,-3.60)
	pipe.rotation_degrees.z = 90
	add_child(pipe)

func _add_brazier(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0,1.72,0)
	light.light_color = Color(1.0,0.31,0.08)
	light.light_energy = 4.0
	light.omni_range = 5.0
	add_child(light)
	var stand := _cylinder(0.11,1.20,Color(0.11,0.10,0.095))
	stand.position = pos + Vector3(0,0.60,0)
	add_child(stand)
	var bowl := _cylinder(0.42,0.16,Color(0.15,0.095,0.055))
	bowl.position = pos + Vector3(0,1.25,0)
	add_child(bowl)
	for i in range(3):
		var flame := _sphere(0.13,Color(0.95,0.24+0.08*i,0.04))
		flame.position = pos + Vector3((i-1)*0.11,1.48+0.06*i,0)
		flame.scale.y = 1.8
		add_child(flame)

func _spawn_actor(unit: Dictionary, pos: Vector3) -> void:
	var id := str(unit["id"])
	var root := Node3D.new()
	root.name = id
	root.position = pos
	root.rotation_degrees.y = _home_yaw_for_team(str(unit["team"]))
	add_child(root)
	actor_nodes[id] = root
	actor_home[id] = pos
	actor_busy[id] = false

	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	var loaded := _try_add_external_model(visual,unit)
	if not loaded:
		if str(unit["team"]) == "player":
			_build_shadow_fallback(visual)
		else:
			_build_rat_fallback(visual,str(unit.get("kind","rat")) == "venom")

	var label := Label3D.new()
	label.position = Vector3(0,2.75,0)
	label.font_size = 30
	label.outline_size = 8
	root.add_child(label)
	actor_labels[id] = label
	_update_label(unit)

func _try_add_external_model(parent: Node3D, unit: Dictionary) -> bool:
	var path := SHADOW_SCENE if str(unit["team"]) == "player" else RAT_SCENE
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var model := packed.instantiate()
	parent.add_child(model)
	return true

func _build_shadow_fallback(parent: Node3D) -> void:
	var armor := Color(0.035,0.045,0.065)
	var edge := Color(0.16,0.19,0.25)
	var skin := Color(0.42,0.34,0.30)
	var leg_l := _capsule(0.13,0.88,armor); leg_l.position=Vector3(-0.17,0.55,0); parent.add_child(leg_l)
	var leg_r := _capsule(0.13,0.88,armor); leg_r.position=Vector3(0.17,0.55,0); parent.add_child(leg_r)
	var torso := _capsule(0.37,1.18,armor); torso.position=Vector3(0,1.35,0); parent.add_child(torso)
	var shoulder_l := _sphere(0.24,edge); shoulder_l.position=Vector3(-0.43,1.58,0); parent.add_child(shoulder_l)
	var shoulder_r := _sphere(0.24,edge); shoulder_r.position=Vector3(0.43,1.58,0); parent.add_child(shoulder_r)
	var arm_l := _capsule(0.10,0.76,armor); arm_l.position=Vector3(-0.47,1.22,0); arm_l.rotation_degrees.z=-8; parent.add_child(arm_l)
	var arm_r := _capsule(0.10,0.76,armor); arm_r.position=Vector3(0.47,1.22,0); arm_r.rotation_degrees.z=8; parent.add_child(arm_r)
	var neck := _cylinder(0.13,0.18,skin); neck.position=Vector3(0,1.89,0); parent.add_child(neck)
	var head := _sphere(0.285,skin); head.position=Vector3(0,2.14,0); head.scale=Vector3(0.92,1.07,0.90); parent.add_child(head)
	var hood := _sphere(0.305,armor); hood.position=Vector3(0,2.26,-0.035); hood.scale=Vector3(1.03,0.73,1.04); parent.add_child(hood)
	var mask := _box_node(Vector3(0,2.13,0.257),Vector3(0.46,0.16,0.035),Color(0.012,0.016,0.025)); parent.add_child(mask)
	for ex in [-0.09,0.09]:
		var eye := _sphere(0.032,Color(0.46,0.64,1.0),true); eye.position=Vector3(ex,2.15,0.286); parent.add_child(eye)
	var cloak := _box_node(Vector3(0,1.17,-0.23),Vector3(0.72,1.18,0.06),Color(0.055,0.06,0.085)); cloak.rotation_degrees.x=7; parent.add_child(cloak)
	var sword := _box_node(Vector3(0.59,1.11,0.05),Vector3(0.07,1.24,0.045),Color(0.46,0.50,0.58),true); sword.rotation_degrees.z=-18; parent.add_child(sword)
	var guard := _box_node(Vector3(0.45,0.75,0.05),Vector3(0.32,0.075,0.07),edge,true); guard.rotation_degrees.z=-18; parent.add_child(guard)

func _build_rat_fallback(parent: Node3D, venom: bool) -> void:
	var fur := Color(0.15,0.13,0.12) if not venom else Color(0.10,0.17,0.11)
	var skin := Color(0.33,0.23,0.20)
	var body := _sphere(0.46,fur); body.position=Vector3(0,0.57,0); body.scale=Vector3(1.22,0.82,0.88); parent.add_child(body)
	var head := _sphere(0.32,fur); head.position=Vector3(-0.47,0.78,0.02); head.scale=Vector3(1.05,0.92,0.96); parent.add_child(head)
	for side in [-1.0,1.0]:
		var ear := _sphere(0.12,skin); ear.position=Vector3(-0.47,1.05,0.20*side); ear.scale=Vector3(0.60,1.0,0.34); parent.add_child(ear)
		var eye := _sphere(0.036,Color(0.95,0.17,0.06),true); eye.position=Vector3(-0.73,0.87,0.14*side); parent.add_child(eye)
	for i in range(4):
		var leg := _capsule(0.055,0.31,skin)
		leg.position=Vector3(-0.20+0.28*(i/2),0.25,-0.25+0.50*(i%2))
		leg.rotation_degrees.z=10 if i<2 else -10
		parent.add_child(leg)
	var tail_parent := Node3D.new(); tail_parent.position=Vector3(0.50,0.55,0); parent.add_child(tail_parent)
	for i in range(5):
		var seg := _cylinder(0.048-float(i)*0.005,0.34,skin)
		seg.position=Vector3(0.17+0.28*i,0.04+0.05*i,0.05*sin(float(i)))
		seg.rotation_degrees.z=82
		tail_parent.add_child(seg)
	if venom:
		var gland := _sphere(0.16,Color(0.18,0.48,0.17),true); gland.position=Vector3(-0.20,0.70,0.38); gland.scale=Vector3(1.2,0.75,0.75); parent.add_child(gland)

func _player_position() -> Vector3:
	return Vector3(-2.75,0.0,0.25)

func _enemy_position(index: int) -> Vector3:
	return [Vector3(2.75,0.0,0.30),Vector3(3.65,0.0,-1.18),Vector3(3.55,0.0,1.38)][mini(index,2)]

func _home_yaw(id: String) -> float:
	if id == "shadow":
		return -68.0
	return 68.0

func _home_yaw_for_team(team: String) -> float:
	return -68.0 if team == "player" else 68.0

func _update_label(unit: Dictionary) -> void:
	var id := str(unit["id"])
	if not actor_labels.has(id):
		return
	var label: Label3D = actor_labels[id]
	var hp := int(unit.get("hp",0))
	var max_hp := maxi(1,int(unit.get("max_hp",1)))
	var ratio := clampf(float(hp)/float(max_hp),0.0,1.0)
	var filled := int(round(ratio*10.0))
	label.text = "%s\n%s%s  %d/%d" % [str(unit["name"]),"█".repeat(filled),"░".repeat(10-filled),hp,max_hp]

func _remove_actor(id: String) -> void:
	if actor_nodes.has(id):
		var node: Node = actor_nodes[id]
		node.queue_free()
	actor_nodes.erase(id)
	actor_home.erase(id)
	actor_labels.erase(id)
	actor_busy.erase(id)

func _spawn_damage_text(pos: Vector3, damage: int, effect: String) -> void:
	var label := Label3D.new()
	label.text = "-%d%s" % [damage, ("  "+effect) if not effect.is_empty() else ""]
	label.font_size = 42
	label.outline_size = 10
	label.position = pos
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label,"position",pos+Vector3(0,0.65,0),0.52).set_trans(Tween.TRANS_QUAD)
	tween.tween_interval(0.20)
	tween.tween_callback(label.queue_free)

func _material(color: Color, roughness: float=0.78, metallic: float=0.0, emission: bool=false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [str(color),roughness,metallic,str(emission)]
	if material_cache.has(key):
		return material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
	material_cache[key] = mat
	return mat

func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	add_child(_box_node(pos,size,color))

func _box_node(pos: Vector3, size: Vector3, color: Color, metal: bool=false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color,0.62 if metal else 0.90,0.55 if metal else 0.0)
	node.mesh = mesh
	node.position = pos
	return node

func _capsule(radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 10
	mesh.material = _material(color)
	node.mesh = mesh
	return node

func _sphere(radius: float, color: Color, emission: bool=false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	mesh.material = _material(color,0.72,0.0,emission)
	node.mesh = mesh
	return node

func _cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh.material = _material(color,0.70,0.20)
	node.mesh = mesh
	return node
