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

func _process(delta: float) -> void:
	var focus := combat_focus if combat_mode else (reveal_focus if reveal_mode else (target.global_position if target else global_position))
	var desired := focus + offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_lerp * delta))
	rotation_degrees = rotation_degrees.lerp(target_rotation, 1.0 - exp(-follow_lerp * delta))
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-follow_lerp * delta))

func enter_combat(shadow_pos: Vector3, enemy_pos: Vector3) -> void:
	reveal_mode = false
	combat_mode = true
	combat_focus = (shadow_pos + enemy_pos) * 0.5
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
	offset = Vector3(8.5, 7.0, 13.5)
	target_rotation = Vector3(-20, 27, 0)
	target_fov = 34.0

func exit_reveal() -> void:
	reveal_mode = false
	offset = Vector3(0, 9, 11)
	target_rotation = Vector3(-28, 0, 0)
	target_fov = 42.0
