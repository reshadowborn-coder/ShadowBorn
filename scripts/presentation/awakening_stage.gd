class_name AwakeningStage
extends Node3D

signal finished

var camera: Camera3D
var shadow_root: Node3D
var shadow_visual: Node3D
var sword_prop: Node3D
var overlay: CanvasLayer
var subtitle: Label
var skip_button: Button
var fade_rect: ColorRect
var sequence_done := false
var skipping := false
var stone_material_shared: ShaderMaterial

const SWORD_GROUND_HILT := Vector3(-1.18,0.10,-2.20)
const SWORD_GROUND_BLADE_DIR := Vector3(0.72,0.0,-0.69)

func _ready() -> void:
	_build_world()
	_build_shadow_and_sword()
	_build_overlay()
	_play_sequence()

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
	moon.rotation_degrees = Vector3(-52,-28,0)
	moon.light_color = Color(0.48,0.62,1.0)
	moon.light_energy = 0.78
	moon.shadow_enabled = true
	add_child(moon)

	var shaft := SpotLight3D.new()
	shaft.position = Vector3(-1.6,5.6,0.8)
	shaft.rotation_degrees = Vector3(-68,-8,0)
	shaft.light_color = Color(0.36,0.50,1.0)
	shaft.light_energy = 5.6
	shaft.spot_range = 10.0
	shaft.spot_angle = 30.0
	# Mobile rule: the moon is the single real-time shadow caster in this shot.
	# The shaft still provides cold depth separation without a second shadow map.
	shaft.shadow_enabled = false
	add_child(shaft)

	var ember := OmniLight3D.new()
	ember.position = Vector3(4.2,1.45,-1.6)
	ember.light_color = Color(1.0,0.25,0.055)
	ember.light_energy = 2.4
	ember.omni_range = 4.2
	add_child(ember)

	_build_crypt()
	_build_motes()

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 34.0
	camera.position = Vector3(-0.55,1.52,4.25)
	add_child(camera)
	camera.look_at(Vector3(-2.15,1.00,-2.55),Vector3.UP)

func _build_crypt() -> void:
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(13.5,10.5)
	plane.material = _cobblestone_material()
	floor.mesh = plane
	add_child(floor)

	# The corpse wall: close, heavy and broken. It is the visual anchor of the opening shot.
	_add_box(Vector3(-2.50,2.20,-3.85),Vector3(5.8,4.4,0.55),Color(0.067,0.073,0.083))
	_add_box(Vector3(3.45,2.45,-4.15),Vector3(6.3,4.9,0.48),Color(0.061,0.068,0.078))
	_add_box(Vector3(-6.25,1.85,-0.35),Vector3(0.52,3.7,7.6),Color(0.056,0.062,0.071))
	_add_box(Vector3(6.25,1.85,-0.35),Vector3(0.52,3.7,7.6),Color(0.056,0.062,0.071))

	for x in [-4.6,-0.75,2.15,4.75]:
		_add_box(Vector3(x,1.70,-3.58),Vector3(0.40,3.4,0.38),Color(0.10,0.105,0.116))
		var cap := _box_node(Vector3(0.72,0.18,0.62),Color(0.125,0.13,0.14))
		cap.position = Vector3(x,3.41,-3.58)
		add_child(cap)

	var frame := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.16
	torus.rings = 20
	torus.ring_segments = 30
	torus.material = _mat(Color(0.11,0.12,0.135),0.92,0.0)
	frame.mesh = torus
	frame.position = Vector3(2.1,3.15,-3.88)
	frame.rotation_degrees.x = 90
	frame.scale.y = 1.10
	add_child(frame)

	var window_dark := _cylinder(0.88,0.045,Color(0.005,0.008,0.015))
	window_dark.position = Vector3(2.1,3.15,-4.03)
	window_dark.rotation_degrees.x = 90
	add_child(window_dark)

	# Fallen stones frame the body without creating a long empty corridor.
	for i in range(15):
		var r := _box_node(Vector3(0.18+0.05*(i%4),0.12+0.04*(i%3),0.22+0.05*((i+2)%4)),Color(0.068+0.003*i,0.073+0.003*i,0.081+0.003*i))
		r.position = Vector3(-5.2+float((i*31)%100)/10.0,0.08,-3.15+float((i*17)%52)/10.0)
		r.rotation_degrees = Vector3(float(i*11),float(i*27),float(i*7))
		add_child(r)

	# A broken stone bench/altar in the middle depth.
	_add_box(Vector3(1.25,0.26,-0.55),Vector3(2.7,0.44,1.25),Color(0.078,0.082,0.090))
	_add_box(Vector3(1.15,0.57,-0.58),Vector3(2.2,0.18,0.95),Color(0.11,0.112,0.118))

	_build_grave_markers()
	_build_autumn_leaves()
	_build_brazier(Vector3(4.2,0,-1.6))

func _build_shadow_and_sword() -> void:
	shadow_root = Node3D.new()
	shadow_root.name = "AwakeningShadow"
	shadow_root.position = Vector3(-2.15,0.0,-3.15)
	shadow_root.rotation_degrees.y = 18.0
	add_child(shadow_root)

	shadow_visual = CharacterFactory.create_shadow(false)
	shadow_visual.scale = Vector3(1.02,1.02,1.02)
	shadow_root.add_child(shadow_visual)
	CharacterFactory.pose_seated_corpse(shadow_visual)

	sword_prop = CharacterFactory.create_sword_prop()
	# Sword mesh origin sits near the hilt and its local +Y runs along the blade.
	# Keep the hilt close to Shadow's right-side reach and point the blade away
	# from both the body and the camera so the pickup cannot read backwards.
	sword_prop.position = SWORD_GROUND_HILT
	sword_prop.transform = Transform3D(_sword_ground_basis(SWORD_GROUND_BLADE_DIR),sword_prop.position)
	add_child(sword_prop)

func _sword_ground_basis(blade_direction: Vector3) -> Basis:
	var y_axis := blade_direction.normalized()
	var z_axis := Vector3.UP
	var x_axis := y_axis.cross(z_axis).normalized()
	z_axis = x_axis.cross(y_axis).normalized()
	return Basis(x_axis,y_axis,z_axis)

func _build_motes() -> void:
	# One GPU emitter replaces dozens of script-updated scene nodes. The motes are
	# atmosphere only, so they should cost almost no CPU time on the iPhone target.
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

func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 40
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(root)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0,0,0,1)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0,0,0,1)
	top_bar.position = Vector2(0,0)
	top_bar.size = Vector2(1920,72)
	root.add_child(top_bar)

	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color(0,0,0,1)
	bottom_bar.position = Vector2(0,1008)
	bottom_bar.size = Vector2(1920,72)
	root.add_child(bottom_bar)

	subtitle = Label.new()
	subtitle.position = Vector2(360,900)
	subtitle.size = Vector2(1200,70)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size",25)
	subtitle.add_theme_color_override("font_color",Color(0.82,0.85,0.91))
	root.add_child(subtitle)

	skip_button = Button.new()
	skip_button.text = "SKIP"
	skip_button.position = Vector2(1755,94)
	skip_button.size = Vector2(115,48)
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.modulate = Color(1,1,1,0.70)
	skip_button.pressed.connect(_finish_sequence)
	root.add_child(skip_button)

func _play_sequence() -> void:
	var fade := create_tween()
	fade.tween_interval(0.18)
	fade.tween_property(fade_rect,"color:a",0.0,0.62).set_trans(Tween.TRANS_SINE)
	await fade.finished
	if skipping: return

	# Read the corpse immediately; no long exposition beat.
	subtitle.text = ""
	await get_tree().create_timer(0.58).timeout
	if skipping: return

	subtitle.text = "Something returns."
	var wake_cam := create_tween()
	wake_cam.set_parallel(true)
	wake_cam.tween_property(camera,"position",Vector3(-0.10,1.62,3.55),0.42).set_trans(Tween.TRANS_SINE)
	wake_cam.tween_property(camera,"fov",30.5,0.42)
	await wake_cam.finished
	camera.look_at(Vector3(-2.12,1.02,-3.10),Vector3.UP)
	if skipping: return

	var rising := CharacterFactory.play_resurrection(shadow_visual)
	var rise_root := create_tween()
	rise_root.set_parallel(true)
	rise_root.tween_property(shadow_visual,"rotation_degrees",Vector3.ZERO,1.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	rise_root.tween_property(shadow_visual,"position",Vector3.ZERO,1.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	rise_root.tween_property(shadow_root,"position",Vector3(-1.90,0.0,-2.92),1.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	rise_root.tween_property(camera,"position",Vector3(0.95,2.12,5.02),1.18).set_trans(Tween.TRANS_CUBIC)
	await get_tree().create_timer(1.20 if rising else 1.00).timeout
	CharacterFactory.pose_standing(shadow_visual)
	if skipping: return
	camera.look_at(Vector3(-1.55,1.20,-2.20),Vector3.UP)

	await get_tree().create_timer(0.16).timeout
	if skipping: return

	var sword_reveal := create_tween()
	sword_reveal.set_parallel(true)
	sword_reveal.tween_property(camera,"position",Vector3(0.34,1.36,3.02),0.32).set_trans(Tween.TRANS_SINE)
	sword_reveal.tween_property(camera,"fov",32.0,0.32)
	await sword_reveal.finished
	camera.look_at(sword_prop.global_position+Vector3(0,0.17,0),Vector3.UP)
	await get_tree().create_timer(0.18).timeout
	if skipping: return

	subtitle.text = "A blade remembers its hand."
	CharacterFactory.play_pickup(shadow_visual,1.05)
	# The world sword stays physically planted until hand contact. Moving and
	# rotating the prop toward the actor made the old shot look like Shadow was
	# grabbing the blade backwards from the camera.
	var pickup := create_tween()
	pickup.tween_property(shadow_root,"position",Vector3(-1.54,0,-2.44),0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.46).timeout
	CharacterFactory.attach_sword(shadow_visual)
	sword_prop.visible = false
	await get_tree().create_timer(0.18).timeout
	CharacterFactory.play_shadow_idle(shadow_visual)
	if skipping: return

	var hero_shot := create_tween()
	hero_shot.set_parallel(true)
	hero_shot.tween_property(camera,"position",Vector3(-4.55,2.50,4.12),0.42).set_trans(Tween.TRANS_SINE)
	hero_shot.tween_property(camera,"fov",35.0,0.42)
	await hero_shot.finished
	camera.look_at(Vector3(-0.25,1.08,-2.0),Vector3.UP)
	subtitle.text = ""
	await get_tree().create_timer(0.20).timeout
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
	out.tween_property(fade_rect,"color:a",1.0,0.38)
	await out.finished
	finished.emit()

func _cobblestone_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
void fragment() {
	vec2 uv = UV * vec2(12.0, 8.0);
	float row = mod(floor(uv.y),2.0);
	uv.x += row * 0.5;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float edge = min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
	float stone_mask = smoothstep(0.035,0.10,edge);
	float rnd = fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
	float grain = 0.5+0.5*sin(UV.x*91.0+sin(UV.y*69.0)*1.8);
	vec3 stone = mix(vec3(0.040,0.043,0.048),vec3(0.092,0.083,0.071),rnd*0.72);
	stone *= mix(0.80,1.05,grain*0.34);
	ALBEDO = mix(vec3(0.017,0.019,0.020),stone,stone_mask);
	ROUGHNESS = mix(1.0,0.90,stone_mask);
	METALLIC = 0.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _stone_material() -> ShaderMaterial:
	if stone_material_shared != null:
		return stone_material_shared

	# Shared shader + per-instance base color: all wall/rubble boxes reuse one
	# material while still keeping controlled tonal variation. The extra masks
	# add damp staining, fine cracks and restrained moss without extra textures.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
instance uniform vec4 base_color : source_color = vec4(0.08,0.085,0.095,1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float grain_a = 0.5 + 0.5 * sin(uv.x * 83.0 + sin(uv.y * 61.0) * 2.1);
	float grain_b = 0.5 + 0.5 * sin(uv.y * 137.0 + uv.x * 29.0);
	float speck = hash21(floor(uv * vec2(26.0, 31.0)));

	float crack_a = abs(sin(uv.x * 22.0 + sin(uv.y * 9.0) * 1.7));
	float crack_b = abs(sin(uv.y * 17.0 + sin(uv.x * 13.0) * 1.3));
	float crack = 1.0 - smoothstep(0.025, 0.085, min(crack_a, crack_b));

	float damp = smoothstep(0.42, 0.88, 0.58 * grain_b + 0.42 * speck);
	float moss_noise = 0.5 + 0.5 * sin(uv.x * 19.0 - uv.y * 23.0 + grain_a * 2.2);
	float moss = smoothstep(0.78, 0.94, moss_noise) * (0.35 + 0.65 * damp);

	vec3 col = base_color.rgb * mix(0.72, 1.10, grain_a * 0.44);
	col *= mix(0.84, 0.98, damp);
	col *= mix(1.0, 0.55, crack * 0.50);
	col = mix(col, vec3(0.030,0.055,0.036), moss * 0.30);

	ALBEDO = col;
	ROUGHNESS = clamp(0.88 + damp * 0.09 + crack * 0.03 - speck * 0.035, 0.82, 1.0);
	METALLIC = 0.0;
}
"""
	stone_material_shared = ShaderMaterial.new()
	stone_material_shared.shader = shader
	return stone_material_shared

func _build_grave_markers() -> void:
	for i in range(6):
		var root := Node3D.new()
		var side := -1.0 if i%2==0 else 1.0
		root.position = Vector3(side*(4.45+0.28*(i%3)),0,-2.75+1.05*i)
		root.rotation_degrees = Vector3(0,-13.0+7.0*i,-4.0+float((i*5)%9))
		add_child(root)

		var base := _box_node(Vector3(0.92,0.16,0.42),Color(0.067,0.071,0.078))
		base.position.y = 0.08
		root.add_child(base)

		var marker := _box_node(Vector3(0.52,0.88+0.08*(i%2),0.16),Color(0.078,0.083,0.092))
		marker.position.y = 0.52
		root.add_child(marker)

		var cap := _box_node(Vector3(0.62,0.14,0.20),Color(0.085,0.089,0.097))
		cap.position.y = 0.98+0.04*(i%2)
		cap.rotation_degrees.z = -3.0+2.0*i
		root.add_child(cap)

func _build_autumn_leaves() -> void:
	var palettes := [
		Color(0.30,0.095,0.022),
		Color(0.48,0.18,0.032),
		Color(0.34,0.24,0.050)
	]
	for p in range(palettes.size()):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.13,0.008,0.062)
		mesh.material = _mat(palettes[p],0.98,0.0)

		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = 20

		for i in range(20):
			var seed := i+p*23
			var x := -5.8+float((seed*37)%116)/10.0
			var z := -4.0+float((seed*61)%80)/10.0
			var yaw := deg_to_rad(float((seed*47)%360))
			var basis := Basis(Vector3.UP,yaw)
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

func _sphere(radius: float,color: Color,emission: bool=false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mat := _mat(color,0.64,0.0)
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.3
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
	mesh.material = _mat(color,0.66,0.18)
	n.mesh = mesh
	return n

func _build_brazier(pos: Vector3) -> void:
	var stand := _cylinder(0.09,1.05,Color(0.085,0.075,0.070))
	stand.position = pos+Vector3(0,0.52,0)
	add_child(stand)
	var bowl := _cylinder(0.30,0.14,Color(0.14,0.075,0.045))
	bowl.position = pos+Vector3(0,1.08,0)
	add_child(bowl)
	for i in range(3):
		var flame := _sphere(0.095,Color(1.0,0.20+0.09*i,0.03),true)
		flame.position = pos+Vector3((i-1)*0.075,1.28+0.045*i,0)
		flame.scale.y = 1.6
		add_child(flame)
