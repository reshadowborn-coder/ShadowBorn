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
@export var activation_distance := 28.0

var _time := 0.0
var _player:Node3D
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
	_player = get_tree().get_first_node_in_group("player") as Node3D

func _process(delta:float) -> void:
	if is_instance_valid(_player):
		var limit := activation_distance * activation_distance
		if global_position.distance_squared_to(_player.global_position) > limit:
			return
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

func _phase(period:float) -> float:
	return fposmod(_time + phase_offset, period)

func _segment(value:float, start:float, end:float) -> float:
	if end <= start:
		return 0.0
	return smoothstep(0.0, 1.0, clampf((value - start) / (end - start), 0.0, 1.0))

func _update_keeper() -> void:
	position = _base_position + Vector3(0.0, 0.012 * _wave(1.4), 0.0)
	rotation_degrees = _base_rotation + Vector3(0.0, 1.2 * _wave(0.45), 0.35 * _wave(0.8))
	if _head:
		_head.rotation_degrees.y = 5.0 * _wave(0.33)
		_head.rotation_degrees.x = 1.2 * _wave(0.55, 0.8)

func _update_smith() -> void:
	position = _base_position + Vector3(0.0, 0.006 * _wave(1.2), 0.0)
	rotation_degrees = _base_rotation + Vector3(0.8 * _wave(0.7), 0.4 * _wave(0.35), 0.0)
	if _work_arm:
		# One authored work beat followed by a real rest, rather than a
		# metronomic hammer loop. The prop remains parented to the hand.
		var t := _phase(4.6)
		var hammer_x := -18.0
		if t < 0.55:
			hammer_x = lerpf(-18.0, -42.0, _segment(t, 0.0, 0.55))
		elif t < 0.76:
			hammer_x = lerpf(-42.0, 30.0, _segment(t, 0.55, 0.76))
		elif t < 1.18:
			hammer_x = lerpf(30.0, -18.0, _segment(t, 0.76, 1.18))
		_work_arm.rotation_degrees.x = hammer_x * motion_scale
		_work_arm.rotation_degrees.z = -8.0 * motion_scale
	if _off_arm:
		_off_arm.rotation_degrees.x = -12.0 + 2.0 * _wave(0.65)
	if _head:
		_head.rotation_degrees.x = 2.0 + 1.1 * _wave(0.48)

func _update_merchant() -> void:
	position = _base_position + Vector3(0.0, 0.008 * _wave(1.0), 0.0)
	rotation_degrees = _base_rotation + Vector3(0.0, 0.7 * _wave(0.32), 0.0)
	var inspect_t := _phase(7.2)
	var inspecting := inspect_t < 2.2
	if _head:
		var inspect_bias := -6.0 if inspecting else 0.0
		_head.rotation_degrees.y = inspect_bias + 6.0 * _wave(0.24)
		_head.rotation_degrees.x = (2.0 if inspecting else 0.0) + 1.0 * _wave(0.52, 0.5)
	if _work_arm:
		_work_arm.rotation_degrees.x = (-20.0 if inspecting else -12.0) + 3.0 * _wave(0.55)
		_work_arm.rotation_degrees.z = 7.0 + 1.5 * _wave(0.38)
	if _focus_prop:
		var inspect_weight := 1.0 - _segment(inspect_t, 1.6, 2.2) if inspecting else 0.0
		_focus_prop.rotation_degrees.y = 14.0 * _wave(0.55) * inspect_weight
		_focus_prop.position.y = 1.18 + 0.018 * inspect_weight

func _update_engraver() -> void:
	position = _base_position + Vector3(0.0, 0.006 * _wave(0.8), 0.0)
	rotation_degrees = _base_rotation + Vector3(0.8 * _wave(0.5), 0.35 * _wave(0.28), 0.0)
	var work_t := _phase(5.8)
	var working := work_t < 2.7
	if _head:
		_head.rotation_degrees.x = (6.0 if working else 2.0) + 1.2 * _wave(0.6)
	if _work_arm:
		var scribble := _wave(2.4) if working else 0.0
		_work_arm.rotation_degrees.x = -30.0 + 4.0 * scribble
		_work_arm.rotation_degrees.z = -10.0 + 2.2 * scribble
	if _off_arm:
		_off_arm.rotation_degrees.x = -20.0 + (2.0 * _wave(0.75, 0.4) if working else 0.0)
	if _focus_prop:
		var pulse := 1.0 + (0.045 * maxf(0.0, _wave(1.9)) if working else 0.0)
		_focus_prop.scale = Vector3.ONE * pulse
