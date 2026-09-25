class_name SewerRatVisual
extends Node3D

@export_enum("normal","poison") var variant:="normal"
@export var phase:=0.0
var elapsed:=0.0
var body:Node3D
var head:Node3D
var tail:Node3D
var body_basis:=Basis.IDENTITY
var head_basis:=Basis.IDENTITY
var tail_basis:=Basis.IDENTITY
var body_position:=Vector3.ZERO
var head_position:=Vector3.ZERO
var tail_position:=Vector3.ZERO
var body_scale:=Vector3.ONE
var head_scale:=Vector3.ONE
var player:Node3D
var reduced_motion:=false
var attack_timer:=0.0
const ACTIVE_RADIUS_SQUARED:=1600.0
const THREAT_RADIUS_SQUARED:=100.0
const CLOSE_RADIUS_SQUARED:=49.0
const ATTACK_CUE_SECONDS:=0.32

func _ready()->void:
	add_to_group("act1_rat_visual")
	body=get_node_or_null("Body")
	head=get_node_or_null("Head")
	tail=get_node_or_null("Tail")
	if body:
		body_basis=body.basis
		body_position=body.position
		body_scale=body.scale
	if head:
		head_basis=head.basis
		head_position=head.position
		head_scale=head.scale
	if tail:
		tail_basis=tail.basis
		tail_position=tail.position
	call_deferred("_bind_player")

func _bind_player()->void:
	player=get_tree().get_first_node_in_group("player") as Node3D

func set_reduced_motion(value:bool)->void:
	reduced_motion=value

func play_attack_cue()->void:
	if not reduced_motion:
		attack_timer=ATTACK_CUE_SECONDS

func _process(delta:float)->void:
	if not visible:
		return
	var distance_squared:=INF
	if is_instance_valid(player):
		distance_squared=global_position.distance_squared_to(player.global_position)
		if distance_squared>ACTIVE_RADIUS_SQUARED:
			return

	elapsed=fmod(elapsed+delta,120.0)
	attack_timer=maxf(0.0,attack_timer-delta)
	var t:=elapsed+phase
	var motion_scale:=.34 if reduced_motion else 1.0
	var threat:=1.0 if distance_squared<THREAT_RADIUS_SQUARED else 0.0
	var close:=distance_squared<CLOSE_RADIUS_SQUARED
	var cycle:=fmod(t,6.0)
	var sniff_wave:=0.0
	if cycle>=1.0 and cycle<=2.0:
		sniff_wave=sin((cycle-1.0)*PI)
	var idle_threat:=0.0
	if close and cycle>=4.35 and cycle<=4.80 and not reduced_motion:
		idle_threat=sin((cycle-4.35)/.45*PI)
	var attack_wave:=0.0
	if attack_timer>0.0 and not reduced_motion:
		var attack_phase:=1.0-attack_timer/ATTACK_CUE_SECONDS
		attack_wave=sin(clampf(attack_phase,0.0,1.0)*PI)
	var lunge:=maxf(idle_threat*.55,attack_wave)
	var breath:=sin(t*3.2)*.018*motion_scale
	var forward:=-.12*lunge*motion_scale

	if body:
		body.position=body_position+Vector3(0,breath-.018*threat*motion_scale,forward)
		body.basis=body_basis*Basis.from_euler(Vector3(
			deg_to_rad(-3.5)*threat*lunge*motion_scale,
			0,
			sin(t*2.4)*deg_to_rad(2.0)*motion_scale
		))
	if head:
		head.position=head_position+Vector3(0,.045*sniff_wave*motion_scale,forward*1.35)
		head.basis=head_basis*Basis.from_euler(Vector3(
			(sin(t*3.1)*deg_to_rad(2.0)+sniff_wave*deg_to_rad(5.0))*motion_scale,
			sin(t*1.7)*deg_to_rad(7.0)*motion_scale*(1.0-.45*threat),
			0
		))
	if tail:
		tail.position=tail_position
		tail.basis=tail_basis*Basis.from_euler(Vector3(
			0,
			sin(t*4.0)*deg_to_rad(14.0)*motion_scale*(1.0+.30*threat),
			sin(t*2.2)*deg_to_rad(5.0)*motion_scale
		))

	# Keep root scale untouched. CombatPresenter owns root transforms for death
	# animation and the pack HUD owns root scale for selected-target emphasis.
	# Poison breathing lives on child meshes so those systems cannot fight.
	if body:
		var poison_pulse:=1.0
		if variant=="poison":
			poison_pulse+=.035*sin(t*2.8)*motion_scale+.025*attack_wave
		body.scale=body_scale*poison_pulse
	if head:
		var head_pulse:=1.0
		if variant=="poison":
			head_pulse+=.045*sin(t*2.8)*motion_scale+.04*attack_wave
		head.scale=head_scale*head_pulse
