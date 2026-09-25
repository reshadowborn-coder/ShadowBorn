class_name TempleNpcIdle
extends Node3D

@export_enum("keeper","smith","merchant","engraver","warden") var motion_profile:="keeper"
@export var phase:=0.0

var reduced_motion:=false
var elapsed:=0.0
var reaction_remaining:=0.0
const REACTION_DURATION:=1.25
var body:Node3D
var head:Node3D
var arm_l:Node3D
var arm_r:Node3D
var tool:Node3D
var body_basis:=Basis.IDENTITY
var head_basis:=Basis.IDENTITY
var arm_l_basis:=Basis.IDENTITY
var arm_r_basis:=Basis.IDENTITY
var tool_basis:=Basis.IDENTITY
var body_position:=Vector3.ZERO
var head_position:=Vector3.ZERO
var arm_l_position:=Vector3.ZERO
var arm_r_position:=Vector3.ZERO
var tool_position:=Vector3.ZERO

func _ready()->void:
	add_to_group("temple_npc_idle")
	body=get_node_or_null("Body")
	head=get_node_or_null("Head")
	arm_l=get_node_or_null("ArmL")
	arm_r=get_node_or_null("ArmR")
	tool=get_node_or_null("Tool")
	if body:
		body_basis=body.basis
		body_position=body.position
	if head:
		head_basis=head.basis
		head_position=head.position
	if arm_l:
		arm_l_basis=arm_l.basis
		arm_l_position=arm_l.position
	if arm_r:
		arm_r_basis=arm_r.basis
		arm_r_position=arm_r.position
	if tool:
		tool_basis=tool.basis
		tool_position=tool.position

func set_reduced_motion(value:bool)->void:
	reduced_motion=value

func _process(delta:float)->void:
	elapsed=fmod(elapsed+delta,120.0)
	reaction_remaining=maxf(0.0,reaction_remaining-delta)
	var scale:=0.30 if reduced_motion else 1.0
	var t:=elapsed+phase
	match motion_profile:
		"smith":
			_animate_smith(t,scale)
		"merchant":
			_animate_merchant(t,scale)
		"engraver":
			_animate_engraver(t,scale)
		"warden":
			_animate_warden(t,scale)
		_:
			_animate_keeper(t,scale)
	if reaction_remaining>0.0:
		_animate_reaction(scale)

func play_interaction_reaction()->void:
	reaction_remaining=REACTION_DURATION

func _animate_reaction(scale:float)->void:
	var progress:=1.0-(reaction_remaining/REACTION_DURATION)
	var pulse:=sin(progress*PI)
	match motion_profile:
		"smith":
			_set_rotation(head,head_basis,Vector3(deg_to_rad(-4.0*pulse)*scale,deg_to_rad(18.0*pulse)*scale,0))
			_set_rotation(arm_r,arm_r_basis,Vector3(deg_to_rad(-22.0)*scale,0,deg_to_rad(-8.0)*scale))
			_set_rotation(tool,tool_basis,Vector3(deg_to_rad(-18.0)*scale,0,0))
		"merchant":
			_set_rotation(head,head_basis,Vector3(deg_to_rad(-3.0*pulse)*scale,deg_to_rad(-16.0*pulse)*scale,0))
			_set_rotation(arm_l,arm_l_basis,Vector3(deg_to_rad(-18.0*pulse)*scale,0,deg_to_rad(-16.0*pulse)*scale))
			_set_rotation(arm_r,arm_r_basis,Vector3(deg_to_rad(-18.0*pulse)*scale,0,deg_to_rad(16.0*pulse)*scale))
		"engraver":
			_set_rotation(head,head_basis,Vector3(deg_to_rad(-10.0*pulse)*scale,deg_to_rad(12.0*pulse)*scale,0))
			_set_rotation(arm_r,arm_r_basis,Vector3(deg_to_rad(-12.0)*scale,0,deg_to_rad(-4.0)*scale))
			_set_rotation(tool,tool_basis,Vector3(deg_to_rad(-12.0)*scale,0,0))
		_:
			_set_rotation(head,head_basis,Vector3(deg_to_rad(7.0*pulse)*scale,0,0))
			_set_rotation(body,body_basis,Vector3(0,0,deg_to_rad(1.5*pulse)*scale))

func _set_rotation(node:Node3D,base:Basis,euler_delta:Vector3)->void:
	if not is_instance_valid(node):
		return
	node.basis=base*Basis.from_euler(euler_delta)

func _breathe(t:float,scale:float,amount:float=0.018)->void:
	if body:
		body.position=body_position+Vector3(0,sin(t*1.35)*amount*scale,0)

func _animate_keeper(t:float,scale:float)->void:
	_breathe(t,scale,0.022)
	_set_rotation(body,body_basis,Vector3(0,0,sin(t*0.42)*deg_to_rad(1.2)*scale))
	_set_rotation(head,head_basis,Vector3(sin(t*0.31)*deg_to_rad(1.2)*scale,sin(t*0.23)*deg_to_rad(8.0)*scale,0))
	_set_rotation(arm_l,arm_l_basis,Vector3(sin(t*0.52)*deg_to_rad(2.0)*scale,0,deg_to_rad(-4.0)*scale))
	_set_rotation(arm_r,arm_r_basis,Vector3(sin(t*0.49+1.2)*deg_to_rad(2.0)*scale,0,deg_to_rad(4.0)*scale))

func _animate_smith(t:float,scale:float)->void:
	_breathe(t,scale,0.016)
	var cycle:=fmod(t,2.6)/2.6
	var lift:=0.0
	if cycle<0.56:
		lift=smoothstep(0.0,0.56,cycle)
	elif cycle<0.72:
		lift=1.0-smoothstep(0.56,0.72,cycle)
	var hammer_angle:=deg_to_rad(-18.0-82.0*lift*scale)
	_set_rotation(arm_r,arm_r_basis,Vector3(hammer_angle,0,deg_to_rad(-8.0)*scale))
	_set_rotation(tool,tool_basis,Vector3(hammer_angle*0.92,0,0))
	_set_rotation(head,head_basis,Vector3(deg_to_rad(8.0+3.0*sin(t*0.7))*scale,deg_to_rad(-4.0)*scale,0))
	_set_rotation(arm_l,arm_l_basis,Vector3(deg_to_rad(-16.0+4.0*sin(t*1.1))*scale,0,deg_to_rad(10.0)*scale))

func _animate_merchant(t:float,scale:float)->void:
	_breathe(t,scale,0.020)
	_set_rotation(head,head_basis,Vector3(0,sin(t*0.34)*deg_to_rad(12.0)*scale,0))
	var gesture:=maxf(0.0,sin(t*1.15+0.7))
	gesture*=gesture
	_set_rotation(arm_l,arm_l_basis,Vector3(deg_to_rad(-8.0-12.0*gesture)*scale,0,deg_to_rad(-8.0)*scale))
	_set_rotation(arm_r,arm_r_basis,Vector3(deg_to_rad(-10.0-18.0*gesture)*scale,0,deg_to_rad(9.0)*scale))
	if head:
		head.position=head_position+Vector3(0,sin(t*0.68)*0.010*scale,0)

func _animate_engraver(t:float,scale:float)->void:
	_breathe(t,scale,0.014)
	_set_rotation(body,body_basis,Vector3(deg_to_rad(5.0)*scale,0,sin(t*0.5)*deg_to_rad(0.8)*scale))
	_set_rotation(head,head_basis,Vector3(deg_to_rad(12.0+2.0*sin(t*0.8))*scale,sin(t*0.29)*deg_to_rad(4.0)*scale,0))
	var scratch:=sin(t*4.1)
	_set_rotation(arm_r,arm_r_basis,Vector3(deg_to_rad(-28.0+8.0*scratch)*scale,0,deg_to_rad(-6.0)*scale))
	_set_rotation(tool,tool_basis,Vector3(deg_to_rad(-22.0+10.0*scratch)*scale,0,0))
	_set_rotation(arm_l,arm_l_basis,Vector3(deg_to_rad(-18.0)*scale,0,deg_to_rad(7.0)*scale))

func _animate_warden(t:float,scale:float)->void:
	_breathe(t,scale,0.010)
	_set_rotation(body,body_basis,Vector3(0,sin(t*0.21)*deg_to_rad(1.2)*scale,sin(t*0.38)*deg_to_rad(.8)*scale))
	_set_rotation(head,head_basis,Vector3(sin(t*0.27)*deg_to_rad(1.5)*scale,sin(t*0.19)*deg_to_rad(5.0)*scale,0))
	_set_rotation(arm_l,arm_l_basis,Vector3(deg_to_rad(-6.0)*scale,0,deg_to_rad(-10.0)*scale))
	_set_rotation(arm_r,arm_r_basis,Vector3(deg_to_rad(-5.0+2.0*sin(t*0.44))*scale,0,deg_to_rad(7.0)*scale))
