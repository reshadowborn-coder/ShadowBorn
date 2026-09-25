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
var player:Node3D
const ACTIVE_RADIUS_SQUARED:=1600.0

func _ready()->void:
	add_to_group("act1_rat_visual")
	body=get_node_or_null("Body")
	head=get_node_or_null("Head")
	tail=get_node_or_null("Tail")
	if body:
		body_basis=body.basis
		body_position=body.position
	if head: head_basis=head.basis
	if tail: tail_basis=tail.basis
	call_deferred("_bind_player")

func _bind_player()->void:
	player=get_tree().get_first_node_in_group("player") as Node3D

func _process(delta:float)->void:
	if not visible:
		return
	if is_instance_valid(player) and global_position.distance_squared_to(player.global_position)>ACTIVE_RADIUS_SQUARED:
		return
	elapsed=fmod(elapsed+delta,120.0)
	var t:=elapsed+phase
	if body:
		body.position=body_position+Vector3(0,sin(t*3.2)*.018,0)
		body.basis=body_basis*Basis.from_euler(Vector3(0,0,sin(t*2.4)*deg_to_rad(2.0)))
	if head:
		head.basis=head_basis*Basis.from_euler(Vector3(sin(t*3.1)*deg_to_rad(2.0),sin(t*1.7)*deg_to_rad(7.0),0))
	if tail:
		tail.basis=tail_basis*Basis.from_euler(Vector3(0,sin(t*4.0)*deg_to_rad(14.0),sin(t*2.2)*deg_to_rad(5.0)))
	if variant=="poison":
		var pulse:=1.0+.035*sin(t*2.8)
		scale=Vector3.ONE*pulse
	else:
		scale=Vector3.ONE