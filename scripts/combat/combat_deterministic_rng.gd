class_name CombatDeterministicRng
extends RefCounted

const MODULUS:=2147483648
const MULTIPLIER:=1103515245
const INCREMENT:=12345

var _state:int=1

func _init(seed_value:int=1)->void:
	seed(seed_value)

func seed(seed_value:int)->void:
	var normalized:=abs(seed_value)%MODULUS
	_state=1 if normalized==0 else normalized

func next_u31()->int:
	# Parameters stay inside signed 64-bit range before modulo, making the
	# sequence stable across the currently supported Godot platforms.
	_state=int((_state*MULTIPLIER+INCREMENT)%MODULUS)
	return _state

func next_bp()->int:
	return next_u31()%10000

func snapshot()->Dictionary:
	return {"state":_state}

func restore(data:Dictionary)->bool:
	var raw=data.get("state")
	if typeof(raw)!=TYPE_INT:
		return false
	var value:=int(raw)
	if value<=0 or value>=MODULUS:
		return false
	_state=value
	return true
