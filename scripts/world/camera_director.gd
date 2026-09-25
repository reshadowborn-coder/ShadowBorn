class_name CameraDirector
extends Node3D

const DEFAULT_OFFSET := Vector3(0, 9, 11)
const DEFAULT_ROTATION := Vector3(-28, 0, 0)
const DEFAULT_FOV := 42.0

const COMBAT_OFFSET := Vector3(7.8, 5.2, 8.8)
const COMBAT_ROTATION := Vector3(-18, 32, 0)
const COMBAT_FOV := 36.0

const REVEAL_OFFSET := Vector3(8.5, 7.0, 13.5)
const REVEAL_ROTATION := Vector3(-20, 27, 0)
const REVEAL_FOV := 34.0

@export var target: Node3D
@export var follow_lerp := 5.0
@onready var camera: Camera3D = $Camera3D

var offset := DEFAULT_OFFSET
var target_rotation := DEFAULT_ROTATION
var target_fov := DEFAULT_FOV
var combat_mode := false
var combat_focus := Vector3.ZERO
var reveal_mode := false
var reveal_focus := Vector3.ZERO
var reduced_motion := false

func _process(delta: float) -> void:
	if not _has_focus():
		return
	var focus := _current_focus()
	var desired := focus + offset
	var alpha := 1.0 - exp(-follow_lerp * delta)
	global_position = global_position.lerp(desired, alpha)
	rotation_degrees = rotation_degrees.lerp(target_rotation, alpha)
	camera.fov = lerpf(camera.fov, target_fov, alpha)

func _has_focus() -> bool:
	return combat_mode or reveal_mode or is_instance_valid(target)

func _current_focus() -> Vector3:
	if combat_mode:
		return combat_focus
	if reveal_mode:
		return reveal_focus
	if is_instance_valid(target):
		return target.global_position
	return Vector3.ZERO

func _apply_framing(next_offset: Vector3, next_rotation: Vector3, next_fov: float) -> void:
	offset = next_offset
	target_rotation = next_rotation
	target_fov = next_fov
	if reduced_motion:
		_snap_to_current_framing()

func _snap_to_current_framing() -> void:
	if not _has_focus():
		return
	global_position = _current_focus() + offset
	rotation_degrees = target_rotation
	camera.fov = target_fov

func enter_combat(shadow_pos: Vector3, enemy_pos: Vector3) -> void:
	reveal_mode = false
	combat_mode = true
	combat_focus = (shadow_pos + enemy_pos) * 0.5
	_apply_framing(COMBAT_OFFSET, COMBAT_ROTATION, COMBAT_FOV)

func exit_combat() -> void:
	combat_mode = false
	_apply_framing(DEFAULT_OFFSET, DEFAULT_ROTATION, DEFAULT_FOV)

func apply_zone(zone: CameraZone) -> void:
	if combat_mode:
		return
	_apply_framing(zone.camera_position, zone.camera_rotation, zone.fov)

func enter_reveal(focus: Vector3) -> void:
	if combat_mode:
		return
	reveal_mode = true
	reveal_focus = focus
	_apply_framing(REVEAL_OFFSET, REVEAL_ROTATION, REVEAL_FOV)

func exit_reveal() -> void:
	reveal_mode = false
	_apply_framing(DEFAULT_OFFSET, DEFAULT_ROTATION, DEFAULT_FOV)

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if reduced_motion:
		_snap_to_current_framing()
