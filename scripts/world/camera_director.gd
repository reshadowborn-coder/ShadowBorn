class_name CameraDirector
extends Node3D

@export var target: Node3D
@export var follow_lerp := 5.0
@onready var camera: Camera3D = $Camera3D
var offset := Vector3(0, 9, 11)
var target_rotation := Vector3(-28, 0, 0)
var target_fov := 42.0
var combat_mode := false
var combat_focus := Vector3.ZERO
var reveal_mode := false
var reveal_focus := Vector3.ZERO
var reduced_motion:=false

func _process(delta: float) -> void:
	var focus := combat_focus if combat_mode else (reveal_focus if reveal_mode else (target.global_position if target else global_position))
	var desired := focus + offset
	var response:=12.0 if reduced_motion else follow_lerp
	global_position = global_position.lerp(desired, 1.0 - exp(-response * delta))
	rotation_degrees = rotation_degrees.lerp(target_rotation, 1.0 - exp(-response * delta))
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-response * delta))

func enter_combat(shadow_pos: Vector3, enemy_pos: Vector3) -> void:
	reveal_mode = false
	combat_mode = true
	combat_focus = (shadow_pos + enemy_pos) * 0.5
	if reduced_motion:
		offset = Vector3(4.2, 7.2, 10.5)
		target_rotation = Vector3(-24, 14, 0)
		target_fov = 39.0
	else:
		offset = Vector3(7.8, 5.2, 8.8)
		target_rotation = Vector3(-18, 32, 0)
		target_fov = 36.0

func exit_combat() -> void:
	combat_mode = false
	offset = Vector3(0, 9, 11)
	target_rotation = Vector3(-28, 0, 0)
	target_fov = 42.0

func apply_zone(zone: CameraZone) -> void:
	if combat_mode: return
	offset = zone.camera_position
	target_rotation = zone.camera_rotation
	target_fov = zone.fov

func enter_reveal(focus: Vector3) -> void:
	if combat_mode: return
	reveal_mode = true
	reveal_focus = focus
	if reduced_motion:
		offset = Vector3(2.2, 8.5, 11.8)
		target_rotation = Vector3(-27, 8, 0)
		target_fov = 40.0
	else:
		offset = Vector3(8.5, 7.0, 13.5)
		target_rotation = Vector3(-20, 27, 0)
		target_fov = 34.0

func exit_reveal() -> void:
	reveal_mode = false
	offset = Vector3(0, 9, 11)
	target_rotation = Vector3(-28, 0, 0)
	target_fov = 42.0


func set_reduced_motion(value:bool)->void:
	reduced_motion=value
