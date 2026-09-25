class_name CombatAbilityOps
extends RefCounted

const DAMAGE:="damage"
const HEAL:="heal"
const APPLY_STATUS:="apply_status"
const REMOVE_STATUS:="remove_status"
const CLEANSE:="cleanse"
const DISPEL:="dispel"
const TURN_METER:="turn_meter"
const SPEED_MODIFIER:="speed_modifier"
const COOLDOWN_DELTA:="cooldown_delta"
const EXTRA_TURN:="extra_turn"
const RESOURCE_DELTA:="resource_delta"
const GRANT_TAG:="grant_tag"
const REMOVE_TAG:="remove_tag"

const TARGETS=[
	"self",
	"primary_target",
	"event_source",
	"event_target",
	"all_allies",
	"all_enemies",
	"lowest_hp_ally",
	"highest_turn_meter_enemy"
]

static func all_ops()->Array[String]:
	return [
		DAMAGE,
		HEAL,
		APPLY_STATUS,
		REMOVE_STATUS,
		CLEANSE,
		DISPEL,
		TURN_METER,
		SPEED_MODIFIER,
		COOLDOWN_DELTA,
		EXTRA_TURN,
		RESOURCE_DELTA,
		GRANT_TAG,
		REMOVE_TAG
	]

static func validate_steps(steps:Array)->Array[String]:
	var errors:Array[String]=[]
	for i in range(steps.size()):
		var step_value=steps[i]
		if typeof(step_value)!=TYPE_DICTIONARY:
			errors.append("step %d is not a dictionary"%i)
			continue
		for error in validate_step(step_value as Dictionary):
			errors.append("step %d: %s"%[i,error])
	return errors

static func validate_step(step:Dictionary)->Array[String]:
	var errors:Array[String]=[]
	if step.has("conditions"):
		var conditions=step.get("conditions")
		if typeof(conditions)!=TYPE_ARRAY:
			errors.append("conditions must be an array")
		else:
			errors.append_array(CombatConditionEvaluator.validate(conditions as Array))
	var op:=str(step.get("op",""))
	if op not in all_ops():
		errors.append("unsupported op: "+op)
		return errors
	var target:=str(step.get("target",""))
	if target not in TARGETS:
		errors.append("invalid target: "+target)

	match op:
		DAMAGE,HEAL:
			if not _has_finite_number(step,"coeff") and not _has_finite_number(step,"flat"):
				errors.append(op+" requires coeff or flat")
		APPLY_STATUS:
			if str(step.get("status_id","")).is_empty():
				errors.append("apply_status requires status_id")
			var chance:=int(step.get("chance_bp",10000))
			if chance<0 or chance>10000:
				errors.append("apply_status chance_bp is outside 0..10000")
			if int(step.get("turns",1))<=0:
				errors.append("apply_status turns must be positive")
			var roll_scope:=str(step.get("roll_scope","per_action"))
			if roll_scope not in ["per_action","per_hit"]:
				errors.append("apply_status roll_scope must be per_action or per_hit")
		REMOVE_STATUS:
			if str(step.get("status_id","")).is_empty() and str(step.get("tag","")).is_empty():
				errors.append("remove_status requires status_id or tag")
		CLEANSE,DISPEL:
			if int(step.get("count",1))<=0:
				errors.append(op+" count must be positive")
		TURN_METER:
			if not _has_finite_number(step,"value_bp"):
				errors.append("turn_meter requires value_bp")
			elif absf(float(step.get("value_bp",0.0)))>30000.0:
				errors.append("turn_meter value_bp exceeds safety bound")
		SPEED_MODIFIER:
			if not _has_finite_number(step,"value_bp"):
				errors.append("speed_modifier requires value_bp")
			elif float(step.get("value_bp",0.0))<-9000.0 or float(step.get("value_bp",0.0))>30000.0:
				errors.append("speed_modifier value_bp exceeds safety bound")
			if int(step.get("turns",0))<=0:
				errors.append("speed_modifier turns must be positive")
		COOLDOWN_DELTA:
			if not _has_finite_number(step,"value"):
				errors.append("cooldown_delta requires value")
			elif absi(int(step.get("value",0)))>99:
				errors.append("cooldown_delta exceeds safety bound")
		EXTRA_TURN:
			var count:=int(step.get("count",1))
			if count<1 or count>CombatTurnTimeline.MAX_EXTRA_TURNS_PER_ACTOR:
				errors.append("extra_turn count exceeds timeline cap")
		RESOURCE_DELTA:
			if str(step.get("resource_id","")).is_empty():
				errors.append("resource_delta requires resource_id")
			if not _has_finite_number(step,"value"):
				errors.append("resource_delta requires finite value")
		GRANT_TAG,REMOVE_TAG:
			if str(step.get("tag","")).is_empty():
				errors.append(op+" requires tag")
	return errors

static func _has_finite_number(step:Dictionary,key:String)->bool:
	if not step.has(key):
		return false
	var value=step[key]
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
		return false
	var number:=float(value)
	return number==number and not is_inf(number)
