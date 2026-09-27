extends Node3D

# Checkpoint 01 Grave Hound production arena wrapper.
# Composition is intentionally cloned from the camera-validated production-preview
# fallback, but owns the environment as a real VisualAssetPolicy scene.
# All visible cemetery hero geometry is project-authored/imported; no BoxMesh wall
# or grave marker is used for the shipping composition.

const MaterialLibrary = preload("res://scripts/presentation/act0_material_library.gd")
const EnvironmentAssetLibrary = preload("res://scripts/presentation/act0_environment_asset_library.gd")

func _ready() -> void:
	var camera := get_node_or_null("BattleCamera") as Camera3D
	var target := get_node_or_null("CameraTarget") as Node3D
	if camera != null and target != null:
		camera.look_at(target.global_position,Vector3.UP)
	_build_environment()

func _build_environment() -> void:
	_build_world_and_lights()

	var floor := MeshInstance3D.new()
	floor.name = "ProductionCobblePreviewFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.5,11.5)
	plane.material = MaterialLibrary.create_cemetery_cobble()
	floor.mesh = plane
	if plane.material is ORMMaterial3D:
		floor.set_meta("shadowborn_visual_tier","production")
		floor.set_meta("shadowborn_visual_source",MaterialLibrary.COBBLE_ALBEDO)
	add_child(floor)

	_build_boundary_ruins()
	_build_wall_and_rubble()

	var gate := EnvironmentAssetLibrary.create_broken_arch_hero()
	if gate != null:
		gate.name = "ProductionPreviewBrokenArch"
		gate.position = Vector3(2.65,0.02,-4.88)
		gate.rotation_degrees.y = -4.0
		gate.scale = Vector3(1.10,1.10,1.10)
		gate.set_meta("shadowborn_visual_tier","production")
		add_child(gate)

	_build_brazier(Vector3(4.25,0,-2.75))
	_build_brazier(Vector3(-5.0,0,-3.55))
	_build_autumn_leaves()
	_build_grave_markers()

func _build_world_and_lights() -> void:
	var world := WorldEnvironment.new()
	world.name = "ArenaWorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008,0.011,0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.135,0.160,0.215)
	env.ambient_light_energy = 0.68
	env.fog_enabled = true
	env.fog_light_color = Color(0.055,0.070,0.095)
	env.fog_light_energy = 0.52
	env.fog_density = 0.022
	world.environment = env
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.name = "MoonKey"
	moon.rotation_degrees = Vector3(-48,-34,0)
	moon.light_color = Color(0.54,0.66,0.96)
	moon.light_energy = 1.02
	moon.shadow_enabled = true
	add_child(moon)

	var player_rim := OmniLight3D.new()
	player_rim.name = "ShadowRim"
	player_rim.position = Vector3(-3.7,2.5,0.5)
	player_rim.light_color = Color(0.28,0.40,0.86)
	player_rim.light_energy = 3.25
	player_rim.omni_range = 5.0
	add_child(player_rim)

	var enemy_fire := OmniLight3D.new()
	enemy_fire.name = "HoundBrazierLight"
	enemy_fire.position = Vector3(4.3,1.65,-2.7)
	enemy_fire.light_color = Color(1.0,0.23,0.05)
	enemy_fire.light_energy = 3.4
	enemy_fire.omni_range = 4.8
	add_child(enemy_fire)

func _build_boundary_ruins() -> void:
	var placements := [
		[Vector3(-6.42,0.01,-3.85),Vector3(0.0,2.0,0.0),Vector3(1.00,0.96,1.08)],
		[Vector3(-6.50,0.01,-1.55),Vector3(0.0,-3.0,0.0),Vector3(0.96,0.88,1.02)],
		[Vector3(-6.38,0.01,0.88),Vector3(0.0,4.5,0.0),Vector3(1.04,1.02,1.06)],
		[Vector3(-6.48,0.01,3.20),Vector3(0.0,-1.5,0.0),Vector3(0.92,0.82,0.96)],
		[Vector3(6.30,0.01,-3.72),Vector3(0.0,178.0,0.0),Vector3(0.98,0.92,1.05)],
		[Vector3(6.42,0.01,-1.35),Vector3(0.0,183.5,0.0),Vector3(1.02,1.00,1.08)],
		[Vector3(6.34,0.01,1.10),Vector3(0.0,176.0,0.0),Vector3(0.94,0.86,1.00)],
		[Vector3(6.45,0.01,3.42),Vector3(0.0,181.0,0.0),Vector3(1.00,0.94,1.04)]
	]
	for i in range(placements.size()):
		var ruin := EnvironmentAssetLibrary.create_boundary_wall_ruin_hero()
		if ruin == null:
			break
		var data: Array = placements[i]
		ruin.name = "ProductionPreviewBoundaryRuin_%02d" % i
		ruin.position = data[0]
		ruin.rotation_degrees = data[1]
		ruin.scale = data[2]
		ruin.set_meta("shadowborn_visual_tier","production")
		add_child(ruin)

func _build_wall_and_rubble() -> void:
	var wall_placements := [
		[Vector3(-4.95,0.02,-5.56),Vector3(0.0,3.0,0.0),Vector3(1.02,1.06,1.0)],
		[Vector3(-0.25,0.02,-5.62),Vector3(0.0,-1.5,0.0),Vector3(0.94,0.98,1.0)],
		[Vector3(4.72,0.02,-5.58),Vector3(0.0,176.0,0.0),Vector3(1.00,1.03,1.0)]
	]
	for i in range(wall_placements.size()):
		var wall := EnvironmentAssetLibrary.create_wall_fragment_hero()
		if wall == null:
			break
		var data: Array = wall_placements[i]
		wall.name = "ProductionPreviewWallFragment_%02d" % i
		wall.position = data[0]
		wall.rotation_degrees = data[1]
		wall.scale = data[2]
		wall.set_meta("shadowborn_visual_tier","production")
		add_child(wall)

	var rubble_placements := [
		[Vector3(-4.10,0.01,-5.05),Vector3(0.0,18.0,0.0),1.05],
		[Vector3(-0.75,0.01,-5.08),Vector3(0.0,-12.0,0.0),0.92],
		[Vector3(5.10,0.01,-5.02),Vector3(0.0,21.0,0.0),1.00]
	]
	for i in range(rubble_placements.size()):
		var rubble := EnvironmentAssetLibrary.create_rubble_cluster_hero()
		if rubble == null:
			break
		var data: Array = rubble_placements[i]
		rubble.name = "ProductionPreviewRubbleCluster_%02d" % i
		rubble.position = data[0]
		rubble.rotation_degrees = data[1]
		var s := float(data[2])
		rubble.scale = Vector3.ONE*s
		rubble.set_meta("shadowborn_visual_tier","production")
		add_child(rubble)

func _build_grave_markers() -> void:
	var placements := [
		[Vector3(-5.65,0.0,-2.35),Vector3(0.0,-18.0,-5.0),0.92],
		[Vector3(-5.95,0.0,2.15),Vector3(0.0,11.0,4.0),0.86],
		[Vector3(5.55,0.0,-3.10),Vector3(0.0,24.0,-3.0),0.96],
		[Vector3(5.95,0.0,2.70),Vector3(0.0,-14.0,5.0),0.88]
	]
	for i in range(placements.size()):
		var marker := EnvironmentAssetLibrary.create_grave_marker_hero()
		if marker == null:
			break
		var data: Array = placements[i]
		marker.name = "ProductionPreviewGraveMarker_%02d" % i
		marker.position = data[0]
		marker.rotation_degrees = data[1]
		var s := float(data[2])
		marker.scale = Vector3.ONE*s
		marker.set_meta("shadowborn_visual_tier","production")
		add_child(marker)

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
			var seed := i+p*19
			var x := -7.0+float((seed*37)%140)/10.0
			var z := -4.7+float((seed*61)%94)/10.0
			var yaw := deg_to_rad(float((seed*53)%360))
			var pitch := deg_to_rad(float(-5+(seed*17)%11))
			var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)
			multi.set_instance_transform(i,Transform3D(basis,Vector3(x,0.018+0.003*(seed%3),z)))
		var instance := MultiMeshInstance3D.new()
		instance.name = "AutumnLeaves_%d" % p
		instance.multimesh = multi
		add_child(instance)

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
		flame.scale.y = 1.6
		add_child(flame)

func _cylinder(radius: float,height: float,color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh.material = _mat(color,0.62,0.18)
	node.mesh = mesh
	return node

func _sphere(radius: float,color: Color,emission: bool=false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var material := _mat(color,0.62,0.0)
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.7
	mesh.material = material
	node.mesh = mesh
	return node

func _mat(color: Color,roughness: float,metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
