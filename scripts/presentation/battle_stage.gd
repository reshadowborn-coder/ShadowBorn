class_name BattleStage
extends Node3D

const VisualPolicy = preload("res://scripts/presentation/visual_asset_policy.gd")

const MaterialLibrary = preload("res://scripts/presentation/act0_material_library.gd")
const EnvironmentAssetLibrary = preload("res://scripts/presentation/act0_environment_asset_library.gd")

const PLAYER_HOME := Vector3(-2.85,0.0,1.55)
const ENEMY_HOME := Vector3(2.65,0.0,-1.20)
const CAMERA_HOME := Vector3(-6.25,4.55,8.10)
const CAMERA_TARGET := Vector3(0.35,1.02,-0.45)

var actor_nodes: Dictionary = {}
var actor_home: Dictionary = {}
var actor_labels: Dictionary = {}
var actor_busy: Dictionary = {}
var fallback_idle_ids: Dictionary = {}
var battle_camera: Camera3D
var clock := 0.0
var presentation_speed := 1.0
var production_environment: Node3D
var player_home := PLAYER_HOME
var enemy_home := ENEMY_HOME
var camera_home := CAMERA_HOME
var camera_target := CAMERA_TARGET

# Mesh/material resources are immutable during combat. Build them once so A1/A2
# only allocate lightweight MeshInstance3D nodes and tweens on impact.
var vfx_meshes: Dictionary = {}
var vfx_materials: Dictionary = {}
var stone_material_shared: ShaderMaterial

func _ready() -> void:
	_prepare_vfx_resources()
	_build_environment()
	# Real characters animate through AnimationPlayer; per-frame script work is only
	# enabled when an emergency fallback model is actually in use.
	set_process(false)

func apply_state(snapshot: Dictionary) -> void:
	presentation_speed = clampf(float(snapshot.get("speed",1.0)),1.0,2.0)
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
	var home: Vector3 = actor_home[attacker_id]
	var target_home: Vector3 = actor_home[target_id]
	var direction := (target_home-home).normalized()

	if attacker_id == "shadow":
		if skill_id == "shadow_lunge":
			# A2: separate choreography — evasive shadow entry, then a heavy slash.
			CharacterFactory.play_shadow_heavy_prep(attacker,presentation_speed)
			_spawn_shadow_charge(attacker.global_position + Vector3(0,0.85,0))
			var seq := create_tween()
			seq.set_speed_scale(presentation_speed)
			seq.tween_interval(0.28)
			seq.tween_callback(func():
				if is_instance_valid(attacker):
					CharacterFactory.play_shadow_heavy_strike(attacker,presentation_speed)
			)

			var heavy_move := create_tween()
			heavy_move.set_speed_scale(presentation_speed)
			heavy_move.tween_property(attacker,"position",home-direction*0.16,0.11)
			heavy_move.tween_property(attacker,"position",home+direction*2.02,0.43).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

			var cam := create_tween()
			cam.set_speed_scale(presentation_speed)
			cam.set_parallel(true)
			cam.tween_property(battle_camera,"position",camera_home+Vector3(0.78,-0.30,-0.95),0.30).set_trans(Tween.TRANS_SINE)
			cam.tween_property(battle_camera,"fov",32.5,0.30)
		else:
			# A1: short readable sword cut with only a small step.
			CharacterFactory.play_shadow_basic(attacker,presentation_speed)
			var basic_move := create_tween()
			basic_move.set_speed_scale(presentation_speed)
			basic_move.tween_property(attacker,"position",home-direction*0.08,0.07)
			basic_move.tween_property(attacker,"position",home+direction*0.88,0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		CharacterFactory.play_hound_attack(attacker,presentation_speed)
		var hound_move := create_tween()
		hound_move.set_speed_scale(presentation_speed)
		hound_move.tween_property(attacker,"position",home-direction*0.10,0.09)
		hound_move.tween_property(attacker,"position",home+direction*1.28,0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func play_impact(attacker_id: String,target_id: String,skill_id: String,damage: int,effect: String) -> void:
	if not actor_nodes.has(target_id):
		return
	var target: Node3D = actor_nodes[target_id]
	var home: Vector3 = actor_home[target_id]

	if target_id == "shadow":
		CharacterFactory.play_shadow_hit(target,presentation_speed)
	else:
		CharacterFactory.play_hound_hit(target,presentation_speed)

	var attacker_home: Vector3 = actor_home.get(attacker_id,Vector3.ZERO)
	var away := (home-attacker_home).normalized()
	var reaction_distance := 0.34 if skill_id == "shadow_lunge" else 0.18
	var lift := 0.07 if skill_id == "shadow_lunge" else 0.035

	var hit := create_tween()
	hit.set_speed_scale(presentation_speed)
	hit.tween_property(target,"position",home+away*reaction_distance+Vector3(0,lift,0),0.065)
	hit.tween_property(target,"position",home,0.20 if skill_id=="shadow_lunge" else 0.14).set_trans(Tween.TRANS_BACK)

	if skill_id == "shadow_lunge":
		_spawn_heavy_shadow_impact(target.global_position+Vector3(0,0.95,0),away)
		_camera_heavy_kick()
	else:
		_spawn_basic_slash_impact(target.global_position+Vector3(0,0.95,0),away)

	_spawn_damage_text(target.global_position+Vector3(0,2.05,0),damage,effect)

	if actor_nodes.has(attacker_id):
		var attacker: Node3D = actor_nodes[attacker_id]
		var a_home: Vector3 = actor_home[attacker_id]
		var recover := create_tween()
		recover.set_speed_scale(presentation_speed)
		recover.tween_interval(0.14 if skill_id=="shadow_lunge" else 0.06)
		recover.tween_property(attacker,"position",a_home,0.40 if skill_id=="shadow_lunge" else 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		recover.tween_callback(func():
			actor_busy[attacker_id] = false
			if attacker_id == "shadow":
				CharacterFactory.play_shadow_idle(attacker,presentation_speed)
			else:
				CharacterFactory.play_hound_idle(attacker,presentation_speed)
		)

	if skill_id == "shadow_lunge":
		var cam_back := create_tween()
		cam_back.set_speed_scale(presentation_speed)
		cam_back.set_parallel(true)
		cam_back.tween_property(battle_camera,"position",camera_home,0.40)
		cam_back.tween_property(battle_camera,"fov",37.0,0.40)

func play_death(actor_id: String) -> void:
	if not actor_nodes.has(actor_id):
		return
	var actor: Node3D = actor_nodes[actor_id]
	actor_busy[actor_id] = true
	if CharacterFactory.play_death(actor,presentation_speed):
		return
	var home: Vector3 = actor_home[actor_id]
	var t := create_tween()
	t.set_speed_scale(presentation_speed)
	t.set_parallel(true)
	t.tween_property(actor,"rotation_degrees:z",-78.0 if home.x>0 else 78.0,0.42).set_trans(Tween.TRANS_QUAD)
	t.tween_property(actor,"position",home+Vector3(0,-0.12,0.14),0.42)

func _process(delta: float) -> void:
	clock += delta * presentation_speed
	for id_variant in fallback_idle_ids.keys():
		var id := str(id_variant)
		if not actor_nodes.has(id) or bool(actor_busy.get(id,false)):
			continue
		var actor: Node3D = actor_nodes[id]
		var home: Vector3 = actor_home[id]
		var phase := float(abs(id.hash()%100))*0.071
		actor.position = home+Vector3(0,sin(clock*1.48+phase)*0.018,0)

func _build_environment() -> void:
	production_environment = VisualPolicy.instantiate_scene(VisualPolicy.BATTLE_ENVIRONMENT)
	if production_environment != null:
		production_environment.name = "ProductionGraveHoundArena"
		VisualPolicy.tag_visual_tier(production_environment,"production",VisualPolicy.BATTLE_ENVIRONMENT)
		add_child(production_environment)

		var player_anchor := production_environment.find_child("PlayerHome",true,false) as Node3D
		var enemy_anchor := production_environment.find_child("EnemyHome",true,false) as Node3D
		var target_anchor := production_environment.find_child("CameraTarget",true,false) as Node3D
		var authored_camera := production_environment.find_child("BattleCamera",true,false) as Camera3D

		if player_anchor != null:
			player_home = player_anchor.global_position
		else:
			push_error("Production battle scene must provide Node3D named PlayerHome")
		if enemy_anchor != null:
			enemy_home = enemy_anchor.global_position
		else:
			push_error("Production battle scene must provide Node3D named EnemyHome")
		if target_anchor != null:
			camera_target = target_anchor.global_position
		else:
			push_error("Production battle scene must provide Node3D named CameraTarget")
		if authored_camera != null:
			battle_camera = authored_camera
			camera_home = authored_camera.global_position
			battle_camera.current = true
		else:
			push_error("Production battle scene must provide Camera3D named BattleCamera")

		if player_anchor != null and enemy_anchor != null and target_anchor != null and battle_camera != null:
			return
	elif VisualPolicy.is_acceptance_mode():
		push_error("VISUAL ACCEPTANCE BLOCKED: missing production Grave Hound arena: %s" % VisualPolicy.BATTLE_ENVIRONMENT)

	_build_debug_environment()

func _build_debug_environment() -> void:
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
	floor.name = "ProductionCobblePreviewFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.5,11.5)
	plane.material = _cobblestone_material()
	floor.mesh = plane
	if plane.material is ORMMaterial3D:
		floor.set_meta("shadowborn_visual_tier","production_preview")
		floor.set_meta("shadowborn_visual_source",MaterialLibrary.COBBLE_ALBEDO)
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

	# Authored broken arch replaces the old TorusMesh landmark. Its real opening
	# and asymmetric damage produce a funerary silhouette without adding clutter
	# to the combat plane.
	var gate := EnvironmentAssetLibrary.create_broken_arch_hero()
	if gate != null:
		gate.name = "ProductionPreviewBrokenArch"
		gate.position = Vector3(2.65,0.02,-4.88)
		gate.rotation_degrees.y = -4.0
		gate.scale = Vector3(1.10,1.10,1.10)
		add_child(gate)

	_build_brazier(Vector3(4.25,0,-2.75))
	_build_brazier(Vector3(-5.0,0,-3.55))
	_build_autumn_leaves()
	_build_preview_grave_markers()

	# Camera: rear-left of player, elevated, aimed diagonally across the field.
	battle_camera = Camera3D.new()
	battle_camera.current = true
	battle_camera.fov = 37.0
	battle_camera.position = camera_home
	add_child(battle_camera)
	battle_camera.look_at(camera_target,Vector3.UP)

func _build_preview_grave_markers() -> void:
	var placements := [
		[Vector3(-5.65,0.0,-2.35),Vector3(0.0,-18.0,-5.0),0.92],
		[Vector3(-5.95,0.0,2.15),Vector3(0.0,11.0,4.0),0.86],
		[Vector3(5.55,0.0,-3.10),Vector3(0.0,24.0,-3.0),0.96],
		[Vector3(5.95,0.0,2.70),Vector3(0.0,-14.0,5.0),0.88]
	]
	for i in range(placements.size()):
		var marker := EnvironmentAssetLibrary.create_grave_marker_hero()
		if marker == null:
			return
		marker.name = "ProductionPreviewGraveMarker_%02d" % i
		var data: Array = placements[i]
		marker.position = data[0]
		marker.rotation_degrees = data[1]
		var s := float(data[2])
		marker.scale = Vector3(s,s,s)
		add_child(marker)

func _spawn_actor(unit: Dictionary) -> void:
	var id := str(unit["id"])
	var root := Node3D.new()
	root.name = id
	root.position = player_home if id=="shadow" else enemy_home
	add_child(root)
	actor_nodes[id] = root
	actor_home[id] = root.position
	actor_busy[id] = false

	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)

	var model := CharacterFactory.create_shadow(true) if id=="shadow" else CharacterFactory.create_hound()
	if id=="shadow":
		model.scale = Vector3(1.05,1.05,1.05)
	else:
		# First enemy must read as a waist-high undead dog, not a human-sized wolf.
		model.scale = Vector3(0.62,0.62,0.62)
	visual.add_child(model)

	if id=="shadow":
		CharacterFactory.play_shadow_idle(model,presentation_speed)
	else:
		CharacterFactory.play_hound_idle(model,presentation_speed)

	var animation_names := CharacterFactory.animation_names(model)
	if animation_names.is_empty():
		fallback_idle_ids[id] = true
		set_process(true)

	# Face the opponent from the imported model's actual visual forward axis.
	# The dev humanoid and dev hound do not share the same local forward axis, so
	# applying one root look_at() rule made the combat screenshot read back-to-back.
	_face_actor_at_opponent(root,model,id)

	var label := Label3D.new()
	label.position = Vector3(0,2.55,0) if id=="shadow" else Vector3(0,1.15,0)
	label.font_size = 28
	label.outline_size = 9
	root.add_child(label)
	actor_labels[id] = label

func _face_actor_at_opponent(root: Node3D,model: Node3D,id: String) -> void:
	var opponent := enemy_home if id=="shadow" else player_home
	root.look_at(opponent,Vector3.UP)
	root.rotation_degrees.x = 0.0
	root.rotation_degrees.z = 0.0

	# Camera-verified dev-asset corrections. Root -Z still owns gameplay facing;
	# these yaws only correct the imported meshes so their visible chest/head face
	# the opponent. The previous hound yaw of 0° visibly showed its back in battle.
	if id == "shadow":
		model.rotation_degrees.y = 180.0
	else:
		model.rotation_degrees.y = 180.0


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

func _prepare_vfx_resources() -> void:
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(0.72,0.82,1.0)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(0.72,0.82,1.0)
	flash_mat.emission_energy_multiplier = 3.0
	vfx_materials["flash"] = flash_mat
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.14
	flash_mesh.height = 0.28
	flash_mesh.radial_segments = 12
	flash_mesh.rings = 6
	flash_mesh.material = flash_mat
	vfx_meshes["flash"] = flash_mesh

	var basic_mat := StandardMaterial3D.new()
	basic_mat.albedo_color = Color(0.48,0.66,1.0)
	basic_mat.emission_enabled = true
	basic_mat.emission = Color(0.35,0.55,1.0)
	basic_mat.emission_energy_multiplier = 2.2
	vfx_materials["basic_slash"] = basic_mat
	var basic_meshes: Array[BoxMesh] = []
	for i in range(3):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.045,0.035,0.62-float(i)*0.10)
		mesh.material = basic_mat
		basic_meshes.append(mesh)
	vfx_meshes["basic_slash"] = basic_meshes

	var charge_mat := StandardMaterial3D.new()
	charge_mat.albedo_color = Color(0.08,0.16,0.42,0.72)
	charge_mat.emission_enabled = true
	charge_mat.emission = Color(0.08,0.18,0.55)
	charge_mat.emission_energy_multiplier = 1.8
	charge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vfx_materials["shadow_charge"] = charge_mat
	var charge_mesh := TorusMesh.new()
	charge_mesh.inner_radius = 0.26
	charge_mesh.outer_radius = 0.34
	charge_mesh.rings = 12
	charge_mesh.ring_segments = 20
	charge_mesh.material = charge_mat
	vfx_meshes["shadow_charge"] = charge_mesh

	var burst_mat := StandardMaterial3D.new()
	burst_mat.albedo_color = Color(0.025,0.055,0.16,0.75)
	burst_mat.emission_enabled = true
	burst_mat.emission = Color(0.10,0.24,0.78)
	burst_mat.emission_energy_multiplier = 2.8
	burst_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vfx_materials["heavy_burst"] = burst_mat
	var burst_mesh := SphereMesh.new()
	burst_mesh.radius = 0.24
	burst_mesh.height = 0.48
	burst_mesh.radial_segments = 14
	burst_mesh.rings = 8
	burst_mesh.material = burst_mat
	vfx_meshes["heavy_burst"] = burst_mesh

	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.12,0.24,0.64)
	shard_mat.emission_enabled = true
	shard_mat.emission = Color(0.08,0.18,0.62)
	shard_mat.emission_energy_multiplier = 2.0
	vfx_materials["heavy_shards"] = shard_mat
	var shard_meshes: Array[BoxMesh] = []
	for i in range(5):
		var shard_mesh := BoxMesh.new()
		shard_mesh.size = Vector3(0.035,0.035,0.40+0.10*i)
		shard_mesh.material = shard_mat
		shard_meshes.append(shard_mesh)
	vfx_meshes["heavy_shards"] = shard_meshes

func _spawn_impact_flash(pos: Vector3) -> void:
	var flash := MeshInstance3D.new()
	flash.mesh = vfx_meshes["flash"] as Mesh
	flash.position = pos
	add_child(flash)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(flash,"scale",Vector3.ONE*3.2,0.12)
	t.tween_property(flash,"modulate:a",0.0,0.12)
	t.chain().tween_callback(flash.queue_free)

func _spawn_basic_slash_impact(pos: Vector3,direction: Vector3) -> void:
	# A1 stays cheap and readable: three streaks sharing prebuilt resources.
	var meshes: Array = vfx_meshes["basic_slash"]
	for i in range(meshes.size()):
		var streak := MeshInstance3D.new()
		streak.mesh = meshes[i] as Mesh
		streak.position = pos + Vector3(0,0.10*float(i-1),0)
		streak.look_at(pos+direction,Vector3.UP)
		streak.rotation_degrees.z += -24.0+24.0*i
		add_child(streak)
		var t := create_tween()
		t.set_speed_scale(presentation_speed)
		t.set_parallel(true)
		t.tween_property(streak,"scale",Vector3(1.0,1.0,1.8),0.10)
		t.tween_property(streak,"modulate:a",0.0,0.13)
		t.chain().tween_callback(streak.queue_free)

func _spawn_shadow_charge(pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = vfx_meshes["shadow_charge"] as Mesh
	ring.position = pos
	ring.rotation_degrees.x = 90
	add_child(ring)
	var t := create_tween()
	t.set_speed_scale(presentation_speed)
	t.set_parallel(true)
	t.tween_property(ring,"scale",Vector3.ONE*2.6,0.32)
	t.tween_property(ring,"modulate:a",0.0,0.32)
	t.chain().tween_callback(ring.queue_free)

func _spawn_heavy_shadow_impact(pos: Vector3,direction: Vector3) -> void:
	var burst := MeshInstance3D.new()
	burst.mesh = vfx_meshes["heavy_burst"] as Mesh
	burst.position = pos
	add_child(burst)

	var t := create_tween()
	t.set_speed_scale(presentation_speed)
	t.set_parallel(true)
	t.tween_property(burst,"scale",Vector3(4.6,2.6,4.6),0.18).set_trans(Tween.TRANS_QUAD)
	t.tween_property(burst,"modulate:a",0.0,0.22)
	t.chain().tween_callback(burst.queue_free)

	# A2 keeps a broader silhouette but shares five prebuilt shard meshes/materials.
	var shard_meshes: Array = vfx_meshes["heavy_shards"]
	for i in range(shard_meshes.size()):
		var shard := MeshInstance3D.new()
		shard.mesh = shard_meshes[i] as Mesh
		shard.position = pos
		shard.look_at(pos+direction,Vector3.UP)
		shard.rotation_degrees.z += -48.0+24.0*i
		add_child(shard)
		var st := create_tween()
		st.set_speed_scale(presentation_speed)
		st.set_parallel(true)
		st.tween_property(shard,"position",pos+direction*(0.65+0.08*i)+Vector3(0,(i-2)*0.10,0),0.15)
		st.tween_property(shard,"modulate:a",0.0,0.18)
		st.chain().tween_callback(shard.queue_free)

func _camera_heavy_kick() -> void:
	var original := battle_camera.position
	var kick := create_tween()
	kick.set_speed_scale(presentation_speed)
	kick.tween_property(battle_camera,"position",original+Vector3(0.10,-0.06,-0.18),0.045)
	kick.tween_property(battle_camera,"position",original+Vector3(-0.06,0.04,0.08),0.055)
	kick.tween_property(battle_camera,"position",original,0.075)

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

func _cobblestone_material() -> Material:
	var production := MaterialLibrary.create_cemetery_cobble()
	if production != null:
		return production
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
void fragment() {
	vec2 uv = UV * vec2(13.0, 9.0);
	float row = mod(floor(uv.y), 2.0);
	uv.x += row * 0.5;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float edge = min(min(f.x, 1.0-f.x), min(f.y, 1.0-f.y));
	float stone_mask = smoothstep(0.035, 0.095, edge);
	float rnd = fract(sin(dot(cell, vec2(12.9898,78.233))) * 43758.5453);
	float grain = 0.5 + 0.5 * sin((UV.x * 97.0) + sin(UV.y * 73.0) * 1.7);
	float damp_field = 0.5 + 0.5 * sin(UV.x*6.5 - UV.y*5.0 + sin(UV.y*2.8)*1.5);
	float wet = smoothstep(0.67,0.91,damp_field+0.12*rnd)*stone_mask;
	vec3 a = vec3(0.038,0.041,0.045);
	vec3 b = vec3(0.090,0.084,0.074);
	vec3 stone = mix(a,b,rnd*0.72);
	stone *= mix(0.78,1.06,grain*0.35);
	stone *= mix(1.0,0.73,wet);
	vec3 mortar = vec3(0.018,0.021,0.022);
	ALBEDO = mix(mortar,stone,stone_mask);
	ROUGHNESS = mix(1.0,mix(0.88,0.44,wet),stone_mask);
	SPECULAR = mix(0.24,0.60,wet);
	METALLIC = 0.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _stone_material() -> ShaderMaterial:
	if stone_material_shared != null:
		return stone_material_shared
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
instance uniform vec4 base_color : source_color = vec4(0.08,0.085,0.095,1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34,456.21));
	p += dot(p,p+45.32);
	return fract(p.x*p.y);
}

void fragment() {
	vec2 uv = UV;
	float grain = 0.5 + 0.5 * sin(uv.x*83.0 + sin(uv.y*61.0)*2.1);
	float secondary = 0.5 + 0.5 * sin(uv.y*131.0 + uv.x*23.0);
	float speck = hash21(floor(uv*vec2(24.0,29.0)));
	float damp = smoothstep(0.48,0.90,secondary*0.62+speck*0.38);
	float crack_a = abs(sin(uv.x*21.0+sin(uv.y*8.0)*1.6));
	float crack_b = abs(sin(uv.y*16.0+sin(uv.x*11.0)*1.2));
	float crack = 1.0-smoothstep(0.026,0.086,min(crack_a,crack_b));
	float moss_noise = 0.5+0.5*sin(uv.x*18.0-uv.y*25.0+grain*2.0);
	float moss = smoothstep(0.80,0.95,moss_noise)*(0.28+0.72*damp);

	vec3 col = base_color.rgb*mix(0.73,1.09,grain*0.43);
	col *= mix(0.84,0.99,damp);
	col *= mix(1.0,0.56,crack*0.48);
	col = mix(col,vec3(0.030,0.052,0.035),moss*0.26);
	ALBEDO = col;
	ROUGHNESS = clamp(0.87+damp*0.10+crack*0.03-speck*0.03,0.82,1.0);
	METALLIC = 0.0;
}
"""
	stone_material_shared = ShaderMaterial.new()
	stone_material_shared.shader = shader
	return stone_material_shared

func _build_autumn_leaves() -> void:
	var palettes := [
		Color(0.31,0.105,0.028),
		Color(0.48,0.19,0.035),
		Color(0.36,0.25,0.055)
	]
	for p in range(palettes.size()):
		var leaf_mesh := BoxMesh.new()
		leaf_mesh.size = Vector3(0.13,0.008,0.065)
		leaf_mesh.material = _mat(palettes[p],0.98,0.0)

		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = leaf_mesh
		multi.instance_count = 18

		for i in range(18):
			var seed := i + p*19
			var x := -7.0 + float((seed*37)%140)/10.0
			var z := -4.7 + float((seed*61)%94)/10.0
			var yaw := deg_to_rad(float((seed*53)%360))
			var pitch := deg_to_rad(float(-5 + (seed*17)%11))
			var basis := Basis(Vector3.UP,yaw) * Basis(Vector3.RIGHT,pitch)
			multi.set_instance_transform(i,Transform3D(basis,Vector3(x,0.018+0.003*(seed%3),z)))

		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		add_child(instance)

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
	mesh.material = _stone_material()
	n.mesh = mesh
	n.set_instance_shader_parameter("base_color",color)
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
