extends Node3D

# Checkpoint 01 production Awakening pocket.
# This scene replaces the old debug BoxMesh/Torus crypt while preserving the
# camera/spawn/sword contract already validated by the opening capture workflow.

const MaterialLibrary = preload("res://scripts/presentation/act0_material_library.gd")
const EnvironmentAssetLibrary = preload("res://scripts/presentation/act0_environment_asset_library.gd")

func _ready() -> void:
	var camera := get_node_or_null("AwakeningCamera") as Camera3D
	if camera != null:
		camera.look_at(Vector3(-2.05,0.68,-2.42),Vector3.UP)
	_build_world()
	_build_floor()
	_build_authored_masonry()
	_build_funeral_props()
	_build_motes()

func _build_world() -> void:
	var world := WorldEnvironment.new()
	world.name = "AwakeningWorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003,0.005,0.009)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.075,0.095,0.135)
	env.ambient_light_energy = 0.38
	env.fog_enabled = true
	env.fog_light_color = Color(0.035,0.050,0.072)
	env.fog_light_energy = 0.42
	env.fog_density = 0.034
	world.environment = env
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.name = "MoonKey"
	moon.rotation_degrees = Vector3(-52,-28,0)
	moon.light_color = Color(0.48,0.62,1.0)
	moon.light_energy = 0.78
	moon.shadow_enabled = true
	add_child(moon)

	var shaft := SpotLight3D.new()
	shaft.name = "ColdShaft"
	shaft.position = Vector3(-1.6,5.6,0.8)
	shaft.rotation_degrees = Vector3(-68,-8,0)
	shaft.light_color = Color(0.36,0.50,1.0)
	shaft.light_energy = 5.6
	shaft.spot_range = 10.0
	shaft.spot_angle = 30.0
	shaft.shadow_enabled = false
	add_child(shaft)

	# Warm contrast comes from outside the corpse focus. Keep it shadowless on mobile.
	var ember := OmniLight3D.new()
	ember.name = "DistantEmber"
	ember.position = Vector3(4.2,1.45,-1.6)
	ember.light_color = Color(1.0,0.25,0.055)
	ember.light_energy = 2.4
	ember.omni_range = 4.2
	ember.shadow_enabled = false
	add_child(ember)

func _build_floor() -> void:
	var floor := MeshInstance3D.new()
	floor.name = "ProductionCobblePreviewFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(13.5,10.5)
	plane.material = MaterialLibrary.create_cemetery_cobble()
	floor.mesh = plane
	if plane.material is ORMMaterial3D:
		floor.set_meta("shadowborn_visual_tier","production")
		floor.set_meta("shadowborn_visual_source",MaterialLibrary.COBBLE_ALBEDO)
	add_child(floor)

func _build_authored_masonry() -> void:
	# Rear funerary wall: three overlapping authored fragments, no flat BoxMesh backdrop.
	var rear := [
		[Vector3(-4.05,0.01,-3.86),Vector3(0.0,2.0,0.0),Vector3(0.92,1.42,1.0)],
		[Vector3(0.10,0.01,-3.92),Vector3(0.0,-1.5,0.0),Vector3(0.88,1.52,1.0)],
		[Vector3(4.20,0.01,-3.88),Vector3(0.0,177.5,0.0),Vector3(0.90,1.40,1.0)]
	]
	for i in range(rear.size()):
		var wall := EnvironmentAssetLibrary.create_wall_fragment_hero()
		if wall == null:
			break
		var data: Array = rear[i]
		wall.name = "AwakeningRearWall_%02d" % i
		wall.position = data[0]
		wall.rotation_degrees = data[1]
		wall.scale = data[2]
		wall.set_meta("shadowborn_visual_tier","production")
		add_child(wall)

	# Side enclosure keeps the shot intimate while using the same authored wall family.
	for entry in [
		[Vector3(-6.00,0.01,-0.45),Vector3(0.0,90.0,0.0),Vector3(0.86,1.22,1.0)],
		[Vector3(6.00,0.01,-0.45),Vector3(0.0,90.0,0.0),Vector3(0.86,1.22,1.0)]
	]:
		var side := EnvironmentAssetLibrary.create_wall_fragment_hero()
		if side == null:
			continue
		var d: Array = entry
		side.position = d[0]
		side.rotation_degrees = d[1]
		side.scale = d[2]
		side.set_meta("shadowborn_visual_tier","production")
		add_child(side)

	# Replace the old TorusMesh "window" with a real damaged negative-space motif.
	var arch := EnvironmentAssetLibrary.create_broken_arch_hero()
	if arch != null:
		arch.name = "AwakeningBrokenFuneraryArch"
		arch.position = Vector3(2.15,0.04,-3.42)
		arch.rotation_degrees.y = -3.0
		arch.scale = Vector3(0.94,1.05,0.94)
		arch.set_meta("shadowborn_visual_tier","production")
		add_child(arch)

	for i in range(3):
		var rubble := EnvironmentAssetLibrary.create_rubble_cluster_hero()
		if rubble == null:
			break
		rubble.name = "AwakeningRubble_%02d" % i
		rubble.position = [
			Vector3(-4.20,0.01,-3.18),
			Vector3(0.55,0.01,-3.30),
			Vector3(4.55,0.01,-3.12)
		][i]
		rubble.rotation_degrees.y = [-14.0,9.0,21.0][i]
		rubble.scale = Vector3.ONE*[0.92,0.82,0.88][i]
		rubble.set_meta("shadowborn_visual_tier","production")
		add_child(rubble)

	# Low boundary fragments frame foreground edges without crossing Shadow.
	var boundary_placements := [
		[Vector3(-5.15,0.01,-1.20),-5.0,0.92],
		[Vector3(-5.05,0.01,1.25),4.0,0.84],
		[Vector3(5.05,0.01,-1.45),176.0,0.88],
		[Vector3(5.10,0.01,1.05),184.0,0.82]
	]
	for i in range(boundary_placements.size()):
		var ruin := EnvironmentAssetLibrary.create_boundary_wall_ruin_hero()
		if ruin == null:
			break
		var d: Array = boundary_placements[i]
		ruin.name = "AwakeningBoundary_%02d" % i
		ruin.position = d[0]
		ruin.rotation_degrees.y = float(d[1])
		var s := float(d[2])
		ruin.scale = Vector3.ONE*s
		ruin.set_meta("shadowborn_visual_tier","production")
		add_child(ruin)

func _build_funeral_props() -> void:
	var slab := EnvironmentAssetLibrary.create_awakening_slab_hero()
	if slab != null:
		slab.name = "ProductionPreviewAwakeningSlab"
		slab.position = Vector3(-2.10,0.015,-2.58)
		slab.rotation_degrees.y = -8.0
		slab.scale = Vector3(1.05,1.0,1.05)
		slab.set_meta("shadowborn_visual_tier","production")
		add_child(slab)

	for i in range(6):
		var root := Node3D.new()
		root.name = "GraveMarkerCluster_%02d" % i
		var side := -1.0 if i%2==0 else 1.0
		root.position = Vector3(side*(4.45+0.28*(i%3)),0,-2.75+1.05*i)
		root.rotation_degrees = Vector3(0,-13.0+7.0*i,-4.0+float((i*5)%9))
		add_child(root)
		var marker := EnvironmentAssetLibrary.create_grave_marker_hero()
		if marker == null:
			continue
		marker.name = "ProductionPreviewGraveMarker_%02d" % i
		var sv := 0.90+0.045*float(i%3)
		marker.scale = Vector3(sv,0.94+0.035*float((i+1)%3),sv)
		marker.set_meta("shadowborn_visual_tier","production")
		root.add_child(marker)

func _build_motes() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "AmbientMotes"
	particles.amount = 28
	particles.lifetime = 5.4
	particles.preprocess = 5.4
	particles.randomness = 0.72
	particles.position = Vector3(0.0,1.55,-1.10)
	particles.visibility_aabb = AABB(Vector3(-6.2,-1.4,-4.2),Vector3(12.4,4.8,8.4))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(5.4,1.55,2.9)
	process.direction = Vector3(0.18,0.45,-0.08)
	process.spread = 78.0
	process.gravity = Vector3(0.0,0.012,0.0)
	process.initial_velocity_min = 0.015
	process.initial_velocity_max = 0.070
	process.scale_min = 0.42
	process.scale_max = 1.05
	process.color = Color(0.20,0.25,0.34,0.30)
	particles.process_material = process

	var quad := QuadMesh.new()
	quad.size = Vector2(0.030,0.030)
	var mote_mat := StandardMaterial3D.new()
	mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_mat.albedo_color = Color(0.20,0.25,0.34,0.30)
	mote_mat.emission_enabled = true
	mote_mat.emission = Color(0.075,0.095,0.14)
	mote_mat.emission_energy_multiplier = 0.36
	quad.material = mote_mat
	particles.draw_pass_1 = quad
	add_child(particles)
