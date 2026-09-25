class_name CombatStatusResolver
extends RefCounted

const BASIS_POINTS:=10000
const BASE_RESIST_BP:=1500
const RESIST_BP_PER_STAT:=25
const MAX_RESIST_BP:=9500

static func resistance_chance_bp(source_accuracy:float,target_resistance:float)->int:
	var accuracy:=_finite_non_negative(source_accuracy)
	var resistance:=_finite_non_negative(target_resistance)
	var delta:=resistance-accuracy
	var result:=BASE_RESIST_BP+int(round(delta*float(RESIST_BP_PER_STAT)))
	return clampi(result,0,MAX_RESIST_BP)

static func resolve(
	base_proc_chance_bp:int,
	source_accuracy:float,
	target_resistance:float,
	proc_roll_bp:int,
	resist_roll_bp:int,
	ignore_resistance:bool=false,
	blocked:bool=false
)->Dictionary:
	var chance:=clampi(base_proc_chance_bp,0,BASIS_POINTS)
	var proc_roll:=clampi(proc_roll_bp,0,BASIS_POINTS-1)
	var resist_roll:=clampi(resist_roll_bp,0,BASIS_POINTS-1)
	if blocked:
		return _result(false,false,false,0,"blocked")
	if chance<=0:
		return _result(false,false,false,0,"zero_chance")
	if proc_roll>=chance:
		return _result(true,false,false,0,"proc_miss")
	if ignore_resistance:
		return _result(true,true,false,0,"applied_unresistable")
	var resist_chance:=resistance_chance_bp(source_accuracy,target_resistance)
	if resist_roll<resist_chance:
		return _result(true,true,true,resist_chance,"resisted")
	return _result(true,true,false,resist_chance,"applied")

static func resolve_with_rng(
	base_proc_chance_bp:int,
	source_accuracy:float,
	target_resistance:float,
	rng:CombatDeterministicRng,
	ignore_resistance:bool=false,
	blocked:bool=false
)->Dictionary:
	if rng==null:
		return _result(false,false,false,0,"missing_rng")
	var proc_roll:=rng.next_bp()
	var resist_roll:=rng.next_bp()
	var result:=resolve(
		base_proc_chance_bp,
		source_accuracy,
		target_resistance,
		proc_roll,
		resist_roll,
		ignore_resistance,
		blocked
	)
	result["proc_roll_bp"]=proc_roll
	result["resist_roll_bp"]=resist_roll
	return result

static func _result(
	attempted:bool,
	proc_passed:bool,
	resisted:bool,
	resist_chance_bp:int,
	reason:String
)->Dictionary:
	return {
		"attempted":attempted,
		"proc_passed":proc_passed,
		"resisted":resisted,
		"applied":proc_passed and not resisted,
		"resist_chance_bp":resist_chance_bp,
		"reason":reason
	}

static func _finite_non_negative(value:float)->float:
	if value!=value or is_inf(value):
		return 0.0
	return maxf(0.0,value)
