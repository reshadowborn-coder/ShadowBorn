class_name TempleNPCAmbient
extends Node3D

enum Style {
	KEEPER,
	SMITH,
	MERCHANT,
	ENGRAVER
}

@export var style:Style = Style.KEEPER
@export var phase_offset := 0.0
@export var motion_scale := 1.0

var _time := 0.0
var _base_position := Vector3.ZERO
var _base_rotation := Vector3.ZERO
var _body:Node3D
var _head:Node3D
var _work_arm:Node3D
var _off_arm:Node3D
var _work_prop:Node3D
var _focus_prop:Node3D

func _ready() -> void:
	_base_position = position
	_base_rotation = rotation_degrees
	_body = get_node_or_null("Body") as Node3D
	_head = get_node_or_null("Head") as Node3D
	_work_arm = get_node_or_null("WorkArm") as Node3D
	_off_arm = get_node_or_null("OffArm") as Node3D
	_work_prop = get_node_or_null("WorkArm/WorkProp") as Node3D
	_focus_prop = get_node_or_null("FocusProp") as Node3D

func _process(delta:float) -> void:
	_time += delta
	match style:
		Style.KEEPER:
			_update_keeper()
		Style.SMITH:
			_update_smith()
		Style.MERCHANT:
			_update_merchant()
		Style.ENGRAVER:
			_update_engraver()

func _wave(speed:float, phase:float=0.0) -> float:
	return sin((_time + phase_offset + phase) * speed) * motion_scale

func _update_keeper() -> void:
	position = _base_position + Vector3(0.0, 0.012 * _wave(1.4), 0.0)
	rotation_degrees = _base_rotation + Vector3(0.0, 1.2 * _wave(0.45), 0.35 * _wave(0.8))
	if _head:
		_head.rotation_degrees.y = 5.0 * _wave(0.33)
		_head.rotation_degrees.x = 1.2 * _wave(0.55, 0.8)

func _update_smith() -> void:
	position = _base_position + Vector3(0.0, 0.008 * _wave(2.0), 0.0)
	rotation_degrees = _base_rotation + Vector3(1.5 * _wave(1.1), 0.6 * _wave(0.55), 0.0)
	if _work_arm:
		# Slow, deliberate working rhythm. The hammer stays parented to the hand.
		var strike := (sin((_time + phase_offset) * 2.35) + 1.0) * 0.5
		_work_arm.rotation_degrees.x = lerpf(-18.0, 28.0, strike) * motion_scale
		_work_arm.rotation_degrees.z = -8.0 * motion_scale
	if _off_arm:
		_off_arm.rotation_degrees.x = -12.0 + 3.0 * _wave(1.15)
	if _head:
		_head.rotation_degrees.x = 2.0 + 1.5 * _wave(0.9)

func _update_merchant() -> void:
	position = _base_position + Vector3(0.0, 0.01 * _wave(1.25), 0.0)
	rotation_degrees = _base_rotation + Vector3(0.0, 1.0 * _wave(0.5), 0.0)
	if _head:
		_head.rotation_degrees.y = 8.0 * _wave(0.28)
		_head.rotation_degrees.x = 1.5 * _wave(0.7, 0.5)
	if _work_arm:
		_work_arm.rotation_degrees.x = -14.0 + 6.0 * _wave(0.8)
		_work_arm.rotation_degrees.z = 7.0 + 2.0 * _wave(0.55)
	if _focus_prop:
		_focus_prop.rotation_degrees.y = 9.0 * _wave(0.7)
		_focus_prop.position.y = 1.18 + 0.012 * _wave(1.3)

func _update_engraver() -> void:
	position = _base_position + Vector3(0.0, 0.008 * _wave(1.0), 0.0)
	rotation_degrees = _base_rotation + Vector3(1.0 * _wave(0.65), 0.5 * _wave(0.35), 0.0)
	if _head:
		_head.rotation_degrees.x = 5.0 + 1.8 * _wave(0.75)
	if _work_arm:
		_work_arm.rotation_degrees.x = -32.0 + 5.0 * _wave(1.4)
		_work_arm.rotation_degrees.z = -10.0 + 2.0 * _wave(0.9)
	if _off_arm:
		_off_arm.rotation_degrees.x = -20.0 + 3.0 * _wave(1.1, 0.4)
	if _focus_prop:
		var pulse := 1.0 + 0.05 * maxf(0.0, _wave(1.8))
		_focus_prop.scale = Vector3.ONE * pulse
