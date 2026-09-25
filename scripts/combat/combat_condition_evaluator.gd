class_name CombatConditionEvaluator
extends RefCounted

const MAX_DEPTH:=6
const BASIS_POINTS:=10000

const OPS:Array[String]=[
	"all",
	"any",
	"not",
	"has_tag",
	"not_has_tag",
	"hp_pct_lte",
	"hp_pct_gte",
	"turn_meter_lte",
	"turn_meter_gte",
	"resource_lte",
	"resource_gte",
	"alive_allies_lte",
	"alive_allies_gte",
	"alive_enemies_lte",
	"alive_enemies_gte",
	"event_has_tag",
	"event_not_has_tag"
]

const SUBJECTS:Array[String]=["self","primary_target","event_source","event_target"]

static func validate(conditions:Array)->Array[String]:
	var errors:Array[String]=[]
	for i in range(conditions.size()):
		var value=conditions[i]
		if typeof(value)!=TYPE_DICTIONARY:
			errors.append("condition %d is not a dictionary"%i)
			continue
		for error in _validate_condition(value as Dictionary,0):
			errors.append("condition %d: %s"%[i,error])
	return errors

static func evaluate_all(conditions:Array,context:Dictionary)->bool:
	for value in conditions:
		if typeof(value)!=TYPE_DICTIONARY or not evaluate(value as Dictionary,context,0):
			return false
	return true

static func evaluate(condition:Dictionary,context:Dictionary,depth:int=0)->bool:
	if depth>MAX_DEPTH:
		return false
	var op:=str(condition.get("op",""))
	match op:
		"all":
			for child in condition.get("conditions",[]):
				if typeof(child)!=TYPE_DICTIONARY or not evaluate(child as Dictionary,context,depth+1):
					return false
			return true
		"any":
			for child in condition.get("conditions",[]):
				if typeof(child)==TYPE_DICTIONARY and evaluate(child as Dictionary,context,depth+1):
					return true
			return false
		"not":
			var child=condition.get("condition")
			return typeof(child)==TYPE_DICTIONARY and not evaluate(child as Dictionary,context,depth+1)
		"has_tag","not_has_tag":
			var actor:=_actor(condition,context)
			var tag:=str(condition.get("tag",""))
			var has:=tag in _string_array(actor.get("tags",[]))
			return has if op=="has_tag" else not has
		"hp_pct_lte","hp_pct_gte":
			var actor:=_actor(condition,context)
			var hp:=maxf(0.0,float(actor.get("hp",0.0)))
			var max_hp:=maxf(0.0,float(actor.get("max_hp",0.0)))
			if max_hp<=0.0:
				return false
			var actual:=int(round(hp/max_hp*BASIS_POINTS))
			var expected:=int(condition.get("value_bp",0))
			return actual<=expected if op=="hp_pct_lte" else actual>=expected
		"turn_meter_lte","turn_meter_gte":
			var actor:=_actor(condition,context)
			var actual:=int(actor.get("turn_meter_bp",0))
			var expected:=int(condition.get("value_bp",0))
			return actual<=expected if op=="turn_meter_lte" else actual>=expected
		"resource_lte","resource_gte":
			var actor:=_actor(condition,context)
			var resources:Dictionary=actor.get("resources",{})
			var actual:=float(resources.get(str(condition.get("resource_id","")),0.0))
			var expected:=float(condition.get("value",0.0))
			return actual<=expected if op=="resource_lte" else actual>=expected
		"alive_allies_lte","alive_allies_gte","alive_enemies_lte","alive_enemies_gte":
			var self_id:=str(context.get("self_id",""))
			var actors:Dictionary=context.get("actors",{})
			var self_actor:Dictionary=actors.get(self_id,{})
			var self_team:=str(self_actor.get("team",context.get("self_team","")))
			var count:=0
			for raw_id in actors:
				var actor:Dictionary=actors[raw_id]
				if not bool(actor.get("alive",true)):
					continue
				var same:=str(actor.get("team",""))==self_team
				if "allies" in op and same:
					count+=1
				elif "enemies" in op and not same:
					count+=1
			var expected:=int(condition.get("value",0))
			return count<=expected if op.ends_with("_lte") else count>=expected
		"event_has_tag","event_not_has_tag":
			var tag:=str(condition.get("tag",""))
			var has:=tag in _string_array(context.get("event_tags",[]))
			return has if op=="event_has_tag" else not has
	return false

static func _validate_condition(condition:Dictionary,depth:int)->Array[String]:
	var errors:Array[String]=[]
	if depth>MAX_DEPTH:
		errors.append("condition nesting exceeds max depth")
		return errors
	var op:=str(condition.get("op",""))
	if op not in OPS:
		errors.append("unsupported condition op: "+op)
		return errors
	if op in ["all","any"]:
		var children=condition.get("conditions")
		if typeof(children)!=TYPE_ARRAY or (children as Array).is_empty():
			errors.append(op+" requires non-empty conditions")
		else:
			for child in children:
				if typeof(child)!=TYPE_DICTIONARY:
					errors.append(op+" child is not a dictionary")
				else:
					errors.append_array(_validate_condition(child as Dictionary,depth+1))
	elif op=="not":
		var child=condition.get("condition")
		if typeof(child)!=TYPE_DICTIONARY:
			errors.append("not requires one condition")
		else:
			errors.append_array(_validate_condition(child as Dictionary,depth+1))
	elif op in ["has_tag","not_has_tag"]:
		_validate_subject_and_tag(condition,errors)
	elif op in ["event_has_tag","event_not_has_tag"]:
		if str(condition.get("tag","")).is_empty():
			errors.append(op+" requires tag")
	elif op in ["hp_pct_lte","hp_pct_gte","turn_meter_lte","turn_meter_gte"]:
		_validate_subject(condition,errors)
		var value=int(condition.get("value_bp",-1))
		if value<0 or value>BASIS_POINTS:
			errors.append(op+" value_bp must be 0..10000")
	elif op in ["resource_lte","resource_gte"]:
		_validate_subject(condition,errors)
		if str(condition.get("resource_id","")).is_empty():
			errors.append(op+" requires resource_id")
		if not _finite_number(condition.get("value")):
			errors.append(op+" requires finite value")
	elif op.begins_with("alive_"):
		if int(condition.get("value",-1))<0:
			errors.append(op+" requires non-negative value")
	return errors

static func _validate_subject_and_tag(condition:Dictionary,errors:Array[String])->void:
	_validate_subject(condition,errors)
	if str(condition.get("tag","")).is_empty():
		errors.append(str(condition.get("op",""))+" requires tag")

static func _validate_subject(condition:Dictionary,errors:Array[String])->void:
	if str(condition.get("subject","")) not in SUBJECTS:
		errors.append(str(condition.get("op",""))+" has invalid subject")

static func _actor(condition:Dictionary,context:Dictionary)->Dictionary:
	var subject:=str(condition.get("subject",""))
	var id:=""
	match subject:
		"self": id=str(context.get("self_id",""))
		"primary_target": id=str(context.get("primary_target_id",""))
		"event_source": id=str(context.get("event_source_id",""))
		"event_target": id=str(context.get("event_target_id",""))
	return (context.get("actors",{}) as Dictionary).get(id,{})

static func _string_array(values)->Array[String]:
	var out:Array[String]=[]
	if typeof(values)==TYPE_ARRAY:
		for value in values:
			out.append(str(value))
	return out

static func _finite_number(value)->bool:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:
		return false
	var n:=float(value)
	return n==n and not is_inf(n)
